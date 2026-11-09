/*
    ================================================================================
    File: fn_formationsGroupFollowTrail.sqf
    Module: Formations
    Author: FTCS Team
    Description: Per-group navigation loop for TRAIL_COLUMN march (mirror of
                 fn_formationsGroupFollowRoad with identical AI discipline):
                 - Marching (leader speed > 2 km/h): group matches the leader's
                   pace exactly (limitSpeed _spd), no slot-chasing acceleration.
                 - Stopped: groups close into their assigned trail slot, then
                   hold and align once to the local trail tangent.
                 - Slot sampling: sample(trailPath, headDist - trailOffsetDist),
                   i.e. the exact point the leader (and the group ahead) walked.
                 - Thread exits when a newer trail order invalidates the
                   generation, or movingMode leaves FOLLOWING_TRAIL.
                 AI profile is set by the dispatcher (ROAD_MARCH aware-mode,
                 NORMAL speed, FIRE_IF_FIRED_UPON, FOLLOW_COMMANDER_STANCE).
    Params:
        0: GROUP - Subordinate group to navigate along the leader trail.
        1: OBJECT - Reference leader (Platoon Commander).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params ["_group", "_leader"];

if (isNull _group || isNull _leader) exitWith {};

private _threadID = round (time * 1000) + floor (random 1000);
_group setVariable ["FTCS_TrailThread_ID", _threadID];

private _groupID = groupId _group;
private _pltIdFor = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
private _tickTime = 1.0;
private _lastTargetPos = [0, 0, 0];
private _alignedOnStop = false;
private _facingAppliedOnReady = false;

// Sampler: interpolate along the trail polyline at a given arclength
private _fnc_sampleTrail = {
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
            private _interpPos = [
                (_ptA select 0) + ((_ptB select 0) - (_ptA select 0)) * _frac,
                (_ptA select 1) + ((_ptB select 1) - (_ptA select 1)) * _frac,
                (_ptA select 2) + ((_ptB select 2) - (_ptA select 2)) * _frac
            ];
            _foundPt = [_interpPos, _dir];
        };
        _accum = _accum + _d;
    };
    _foundPt
};

// No initial move: until the recorded trail covers this group's depth
// (headDist >= offset), the group stands STATIC at its current position and
// is released progressively as the leader walks (column forms on the move).

[ _groupID, "movingMode", "FOLLOWING_TRAIL" ] call FTCS_fnc_registrySet;

while { ((_group getVariable ["FTCS_TrailThread_ID", -1]) == _threadID) &&
        (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_TRAIL") } do
{
    private _spd = speed _leader;
    if ((_group getVariable ["FTCS_TrailThread_ID", -1]) != _threadID) exitWith {};

    private _anchor = missionNamespace getVariable [format ["FTCS_Trail_Anchor_PLT_%1", _pltIdFor], createHashMap];
    private _trailPath = _anchor getOrDefault ["trailPath", []];
    private _headDist = _anchor getOrDefault ["headDist", 0];
    private _offsetDist = [_groupID, "trailOffsetDist"] call FTCS_fnc_registryGet;
    if (isNil "_offsetDist") then { _offsetDist = 12.0; };

    // WAITING state: the recorded trail does not yet cover this group's depth.
    // Hold static (no move, no limitSpeed) until the leader has walked enough;
    // groups release in chain order (nearest offset first) as the trail grows.
    if (_headDist < (_offsetDist + 2.0)) then {
        doStop (leader _group);
        sleep 0.5;
        continue;
    };

    private _targetPos = [0, 0, 0];
    private _tangentDir = getDir _leader;

    if (count _trailPath >= 2) then {
        private _sampleArc = (_headDist - _offsetDist) max 0;
        private _sample = [_sampleArc, _trailPath] call _fnc_sampleTrail;
        _targetPos = _sample select 0;
        _tangentDir = _sample select 1;
        // Clamped to the trail seed point: face the FIRST WALKED segment
        // (point0 -> point1), never the order-time facing stored in the seed
        if (_sampleArc <= 0) then {
            _tangentDir = ((_trailPath select 0) select 0) getDir ((_trailPath select 1) select 0);
        };
        // Compact double-lane placement: lateral offset perpendicular to the
        // local trail tangent (pairs share the arclength, +/-0.75m off the line)
        private _sh = [_groupID, "trailShoulderOffset"] call FTCS_fnc_registryGet;
        if (!isNil "_sh" && { _sh != 0 }) then {
            private _perp = (_tangentDir + 90) % 360;
            _targetPos = _targetPos getPos [abs _sh, if (_sh < 0) then { (_perp + 180) % 360 } else { _perp }];
        };
    } else {
        _targetPos = getPosATL _leader getPos [_offsetDist, (getDir _leader + 180) % 360];
    };

    [ _groupID, "trailTargetPos", _targetPos ] call FTCS_fnc_registrySet;
    [ _groupID, "trailTangentDir", _tangentDir ] call FTCS_fnc_registrySet;

    // Debug telemetry: per-group assigned trail slot marker (orange dot with the
    // group's chain distance label), refreshed in this same 1s tick loop.
    // Guard: groups with non-positive offsets are not chain members - never
    // create orphan markers for them (leftovers from a previous march world).
    if (missionNamespace getVariable ["FTCS_Debug_Mode", false] && { _offsetDist > 0 }) then {
        private _tName = format ["FTCS_DEBUG_TRAIL_SLOT_%1", _groupID];
        if (getMarkerType _tName == "") then {
            createMarkerLocal [_tName, _targetPos];
            _tName setMarkerTypeLocal "mil_dot";
            _tName setMarkerColorLocal "ColorOrange";
            _tName setMarkerSizeLocal [0.75, 0.75];
        };
        _tName setMarkerPosLocal _targetPos;
        _tName setMarkerTextLocal format [" (T%1m)", round _offsetDist];
    };

    if (_spd > 2) then {
        // Marching: exact leader pace, natural pathing, no forced facing
        { _x limitSpeed _spd; } forEach (units _group);
        _group move _targetPos;
        units _group doFollow leader _group;

        _alignedOnStop = false;
        _facingAppliedOnReady = false;

        sleep _tickTime;
    } else {
        // Stopped: close into the slot, then align once to the trail tangent
        private _posChanged = ((_targetPos distance2D _lastTargetPos) > 1.5);
        if (!_alignedOnStop || _posChanged) then {
            _group move _targetPos;
            _lastTargetPos = _targetPos;
            _alignedOnStop = true;
            _facingAppliedOnReady = false;
        };

        if (!_facingAppliedOnReady && { unitReady (leader _group) || ((leader _group) distance2D _targetPos < 3) }) then {
            _group setFormDir _tangentDir;
            _facingAppliedOnReady = true;
        };

        { _x disableAI "RADIOPROTOCOL"; } forEach (units _group);
        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != "FOLLOWING_TRAIL") exitWith {};
        sleep _tickTime;
    };
};

// Thread exit: clean up this group's debug slot marker when leaving trail mode
private _exitMarker = format ["FTCS_DEBUG_TRAIL_SLOT_%1", _groupID];
if (getMarkerType _exitMarker != "") then { deleteMarkerLocal _exitMarker; };
