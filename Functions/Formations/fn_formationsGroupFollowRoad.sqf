/*
    ================================================================================
    File: fn_formationsGroupFollowRoad.sqf
    Module: Formations
    Author: FTCS Team
    Description: Controls individual group movement loop while following the platoon leader
                 along a road/trail corridor.
                 - Continuous navigation: groups advance smoothly along road corridor
                   towards their assigned shoulder positions regardless of whether
                   the platoon leader is actively marching or temporarily stationary.
                 - When marching (speed > 2 km/h): Groups pace their advance dynamically
                   without forced formation facing (natural movement pathing).
                 - When leader is stopped (speed <= 2 km/h): Units continue moving until
                   reaching their assigned shoulder position, then hold and align strictly
                   once to the road tangent.
    Params:
        0: GROUP - Subordinate group to navigate along road.
        1: OBJECT - Reference leader (Platoon Commander / Squad Leader).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params ["_group", "_leader"];

if (isNull _group || isNull _leader) exitWith {};

private _threadID = round (time * 1000) + floor (random 1000);
_group setVariable ["FTCS_FollowThread_ID", _threadID];

private _groupID = groupId _group;
private _not_able_time = 1;
private _timer = time;
private _alignedOnStop = false;
private _facingAppliedOnReady = false;
private _currentMoveTarget = [0, 0, 0];
private _last_spd = 10;

// Helper to calculate exact position along a polyline at a specific distance from start
private _fnc_samplePathAtDistance = {
    params ["_distTarget", "_path"];
    private _accum = 0;
    private _foundPt = _path select (count _path - 1);

    for "_i" from 0 to (count _path - 2) do {
        private _ptA = (_path select _i) select 0;
        private _ptB = (_path select (_i + 1)) select 0;
        private _d = _ptA distance2D _ptB;
        if ((_accum + _d) >= _distTarget) exitWith {
            private _frac = if (_d > 0) then { (_distTarget - _accum) / _d } else { 0 };
            private _dir = (_path select _i) select 1;
            private _width = (_path select _i) select 2;
            private _interpPos = [
                (_ptA select 0) + ((_ptB select 0) - (_ptA select 0)) * _frac,
                (_ptA select 1) + ((_ptB select 1) - (_ptA select 1)) * _frac,
                (_ptA select 2) + ((_ptB select 2) - (_ptA select 2)) * _frac
            ];
            _foundPt = [_interpPos, _dir, _width];
        };
        _accum = _accum + _d;
    };
    _foundPt
};

// Explicitly un-freeze and awaken AI units from assembly area doStop
_group setFormation "COLUMN";
{
    _x enableAI "PATH";
    _x enableAI "MOVE";
    _x disableAI "TARGET";
    _x disableAI "AUTOCOMBAT";
    _x disableAI "COVER";
    _x disableAI "RADIOPROTOCOL";
    _x forceSpeed -1;
    _x doFollow (leader _group);
} forEach (units _group);

(leader _group) enableAI "PATH";
(leader _group) enableAI "MOVE";
(leader _group) disableAI "TARGET";
(leader _group) disableAI "AUTOCOMBAT";
(leader _group) disableAI "COVER";

// An initial doMove command releases the native engine doStop freeze in Arma 3
private _initRoadPos = [ _groupID, "roadTargetPos" ] call FTCS_fnc_registryGet;
if (!isNil "_initRoadPos" && {_initRoadPos isEqualType []} && {count _initRoadPos >= 2}) then {
    (leader _group) doMove _initRoadPos;
    _group move _initRoadPos;
    _currentMoveTarget = _initRoadPos;
};

[ _groupID, "movingMode", "FOLLOWING_ROAD" ] call FTCS_fnc_registrySet;

while {((_group getVariable ["FTCS_FollowThread_ID", -1]) == _threadID) && 
       ((([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_ROAD") || 
        (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "HALT"))} do
{
    // Terminate immediately if a newer follow thread was spawned for this group
    if ((_group getVariable ["FTCS_FollowThread_ID", -1]) != _threadID) exitWith {};

    private _spd = speed _leader;

    // -------------------------------------------------------------------------
    // 1. ACTIVE MARCH ALONG ROAD (leader speed > 2 km/h)
    // -------------------------------------------------------------------------
    if (_spd > 2) then 
    {
        _last_spd = _spd;
        { _x limitSpeed _spd; } forEach (units _group);

        _timer = time + _not_able_time;

        waitUntil { 
            time > _timer || 
            ((_group getVariable ["FTCS_FollowThread_ID", -1]) != _threadID) ||
            ([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != "FOLLOWING_ROAD" || 
            unitReady (leader _group) || 
            lifeState (leader _group) == "DEAD" || 
            lifeState (leader _group) == "INCAPACITATED" 
        };

        if ((_group getVariable ["FTCS_FollowThread_ID", -1]) != _threadID) exitWith {};
        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != "FOLLOWING_ROAD") exitWith {};

        { _x disableAI "RADIOPROTOCOL"; } forEach (units _group);

        // Retrieve assigned road progression distance and shoulder offset
        private _offsetDist = [ _groupID, "roadOffsetDist" ] call FTCS_fnc_registryGet;
        private _shoulderOffset = [ _groupID, "roadShoulderOffset" ] call FTCS_fnc_registryGet;
        if (isNil "_offsetDist") then { _offsetDist = 12.0; };
        if (isNil "_shoulderOffset") then { _shoulderOffset = 0.0; };

        private _curLeaderPos = getPosATL _leader;
        private _curLeaderDir = getDir _leader;

        // Dynamic road slot position: query continuously sampled road waypoints behind the leader
        private _dynPath = [_leader, (_offsetDist + 40)] call FTCS_fnc_roadGetPointsBehind;
        private _dynTargetPos = [0, 0, 0];
        private _dynTangentDir = _curLeaderDir;

        if (count _dynPath >= 2) then {
            private _sample = [_offsetDist, _dynPath] call _fnc_samplePathAtDistance;
            private _roadCenter = _sample select 0;
            _dynTangentDir = _sample select 1;
            private _perpDir = (_dynTangentDir + 90) % 360;
            _dynTargetPos = _roadCenter getPos [abs _shoulderOffset, if (_shoulderOffset < 0) then { (_perpDir + 180) % 360 } else { _perpDir }];
        } else {
            _dynTargetPos = _curLeaderPos getPos [_offsetDist, (_curLeaderDir + 180) % 360];
        };

        // Update registry with current dynamic road target
        [ _groupID, "roadTargetPos", _dynTargetPos ] call FTCS_fnc_registrySet;
        [ _groupID, "roadTangentDir", _dynTangentDir ] call FTCS_fnc_registrySet;

        // Command group movement towards current road position
        _group move _dynTargetPos;
        _currentMoveTarget = _dynTargetPos;
        units _group doFollow leader _group;

        _alignedOnStop = false;
        _facingAppliedOnReady = false;
    }
    // -------------------------------------------------------------------------
    // 2. LEADER STOPPED (speed <= 2 km/h): Units continue advance until in place
    // -------------------------------------------------------------------------
    else 
    {
        private _offsetDist = [ _groupID, "roadOffsetDist" ] call FTCS_fnc_registryGet;
        private _shoulderOffset = [ _groupID, "roadShoulderOffset" ] call FTCS_fnc_registryGet;
        if (isNil "_offsetDist") then { _offsetDist = 12.0; };
        if (isNil "_shoulderOffset") then { _shoulderOffset = 0.0; };

        private _curLeaderPos = getPosATL _leader;
        private _curLeaderDir = getDir _leader;

        private _stopPath = [_leader, (_offsetDist + 40)] call FTCS_fnc_roadGetPointsBehind;
        private _stopTargetPos = [0, 0, 0];
        private _stopTangentDir = _curLeaderDir;

        if (count _stopPath >= 2) then {
            private _sample = [_offsetDist, _stopPath] call _fnc_samplePathAtDistance;
            private _roadCenter = _sample select 0;
            _stopTangentDir = _sample select 1;
            private _perpDir = (_stopTangentDir + 90) % 360;
            _stopTargetPos = _roadCenter getPos [abs _shoulderOffset, if (_shoulderOffset < 0) then { (_perpDir + 180) % 360 } else { _perpDir }];
        } else {
            _stopTargetPos = _curLeaderPos getPos [_offsetDist, (_curLeaderDir + 180) % 360];
        };

        [ _groupID, "roadTargetPos", _stopTargetPos ] call FTCS_fnc_registrySet;
        [ _groupID, "roadTangentDir", _stopTangentDir ] call FTCS_fnc_registrySet;

        private _leaderUnit = leader _group;
        private _distToTarget = _leaderUnit distance2D _stopTargetPos;
        private _isAtDestination = (unitReady _leaderUnit || _distToTarget < 3.5);

        // Keep driving movement until the group is physically at destination
        if (!_isAtDestination) then {
            { _x limitSpeed _last_spd; } forEach (units _group);
            private _posShift = (_stopTargetPos distance2D _currentMoveTarget) > 1.5;
            if (!_alignedOnStop || _posShift) then {
                _group move _stopTargetPos;
                _currentMoveTarget = _stopTargetPos;
                _alignedOnStop = true;
            };
            units _group doFollow _leaderUnit;
            _facingAppliedOnReady = false;
        } else {
            // Group has arrived at assigned shoulder slot: apply road tangent facing once
            if (!_facingAppliedOnReady) then {
                _group setFormDir _stopTangentDir;
                _facingAppliedOnReady = true;
            };
        };

        { _x disableAI "RADIOPROTOCOL"; } forEach (units _group);
        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != "FOLLOWING_ROAD") exitWith {};
        sleep 0.5;
    };
};
