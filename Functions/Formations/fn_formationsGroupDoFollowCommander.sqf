/*
    Author: FTCS Framework / Manel P.
    Function: FTCS_fnc_formationsGroupDoFollowCommander
    Description: Controls the individual group movement loop to follow the commander 
                 in relative or absolute modes (AI-Agnostic).
                 When marching (speed > 2), subordinates dynamically track leader movement.
                 When stopped (speed <= 2), subordinate groups (Squad Leaders following
                 the Platoon Leader, and Fireteams following their Squad Leader) anchor
                 their formation positions and facing strictly aligned with the platoon's
                 advance direction in that moment (FTCS_Platoon_Advance_Direction).
*/

params ["_group", "_mode", "_leader"];

if (isNull _group || isNull _leader) exitWith {};

// Generate unique follow thread identifier to terminate any previous concurrent thread for this group
private _threadID = round (time * 1000) + floor (random 1000);
_group setVariable ["FTCS_FollowThread_ID", _threadID];

private _groupID = groupId _group;
private _not_able_time = 1;  
private _timer = time;
private _spd = speed _leader;
private _last_spd = 10;
private _lastTargetPos = [0, 0, 0];

// Identify if the reference leader is the main platoon commander (player or platoon HQ leader)
private _isPlatoonCommander = (isPlayer _leader || {_leader == (leader (missionNamespace getVariable ["FTCS_Group_Commander", grpNull]))} || {_leader == (missionNamespace getVariable ["FTCS_Platoon_Leader_Unit", objNull])} || {(vehicleVarName _leader) find "LEADER" >= 0 && {(vehicleVarName _leader) find "SQD_" < 0}});

// Only initialize advance direction if not previously defined by a formation order or active march
if (_isPlatoonCommander && {_mode != "FOLLOWING_COMMANDER_ABS"}) then {
    if (isNil { missionNamespace getVariable "FTCS_Platoon_Advance_Direction" }) then {
        missionNamespace setVariable ["FTCS_Last_Commander_Dir", getDir _leader];
        missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", getDir _leader];
    };
};

[ _groupID, "movingMode", _mode ] call FTCS_fnc_registrySet;

// Retrieve current platoon advance direction
private _platoonDir = if (_mode == "FOLLOWING_COMMANDER_ABS") then {
    missionNamespace getVariable ["FTCS_Platoon_Fixed_Abs_Dir", missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", getDir _leader]]
} else {
    missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", missionNamespace getVariable ["FTCS_Last_Commander_Dir", getDir _leader]]
};

// Initial deployment positioning
if (_mode == "FOLLOWING_COMMANDER_REL") then 
{
    private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
    if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2} && {(_relPos select 0) >= 0}) then {
        private _dist = _relPos select 0;
        private _relAngle = _relPos select 1;
        private _refHeading = if (speed _leader > 2) then { getDir _leader } else { _platoonDir };
        _group move ((getPosATL _leader) getPos [_dist, _refHeading + _relAngle]);
    };
    units _group doFollow leader _group;
};

if (_mode == "FOLLOWING_COMMANDER_ABS") then 
{
    private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
    if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2} && {(_relPos select 0) >= 0}) then {
        _group move ((getPosATL _leader) getPos [_relPos select 0, _platoonDir + (_relPos select 1)]);
    };
    units _group doFollow leader _group;
};

private _alignedOnStop = false;
private _facingAppliedOnReady = false;

while {((_group getVariable ["FTCS_FollowThread_ID", -1]) == _threadID) && 
       ((([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == _mode) || 
        (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "HALT"))} do
{
    _spd = speed _leader;

    // Terminate immediately if a newer follow thread was spawned for this group
    if ((_group getVariable ["FTCS_FollowThread_ID", -1]) != _threadID) exitWith {};

    // -------------------------------------------------------------------------
    // 1. ACTIVE MARCHING (speed > 2 km/h): Dynamic formation tracking.
    //    Fixed 1s cadence (no waitUntil/unitReady gating): re-issuing moves on
    //    unit-ready moments caused path re-plan churn and micro-command spam.
    //    Exit conditions are polled inside the loop condition itself.
    // -------------------------------------------------------------------------
    if (_spd > 2) then 
    {
        _last_spd = _spd;
        { _x limitSpeed _spd; } foreach units _group;

        { _x disableAI "RADIOPROTOCOL"; } foreach units _group;

        // Continuously update platoon advance direction from commander's active march heading (relative mode only)
        if (_isPlatoonCommander && {_mode != "FOLLOWING_COMMANDER_ABS"}) then {
            private _liveDir = getDir _leader;
            missionNamespace setVariable ["FTCS_Last_Commander_Dir", _liveDir];
            missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _liveDir];
        };

        private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
        if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2} && {(_relPos select 0) >= 0}) then {
            if (_mode == "FOLLOWING_COMMANDER_REL") then {
                _group move (_leader getRelPos [_relPos select 0, _relPos select 1]);
            } else {
                _group move ((getPosATL _leader) getPos [_relPos select 0, _platoonDir + (_relPos select 1)]);
            };
        };

        units _group doFollow leader _group;

        _alignedOnStop = false;
        _facingAppliedOnReady = false;

        sleep 1.0;
    }
    // -------------------------------------------------------------------------
    // 2. STOPPED / STATIC (speed <= 2 km/h): Anchor formation along platoon heading
    // -------------------------------------------------------------------------
    else 
    {
        // Retrieve latest platoon advance direction in that moment
        private _curPlatoonDir = if (_mode == "FOLLOWING_COMMANDER_ABS") then {
            _platoonDir
        } else {
            missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", missionNamespace getVariable ["FTCS_Last_Commander_Dir", getDir _leader]]
        };

        // Resolve Platoon Leader unit (Lieutenant / Player or NPC Platoon Leader)
        private _platoonLeader = missionNamespace getVariable ["FTCS_Platoon_Leader_Unit", objNull];
        if (isNull _platoonLeader) then {
            _platoonLeader = missionNamespace getVariable ["FTCS_Formation_Visualizer_Leader", objNull];
        };
        if (isNull _platoonLeader) then {
            if (!((vehicleVarName _leader) find "SQD_" >= 0)) then {
                _platoonLeader = _leader;
            };
        };
        if (isNull _platoonLeader) then { _platoonLeader = player; };

        // Determine facing orientation based on follow mode:
        // In both RELATIVE and ABSOLUTE modes, when stopped, the internal unit facing of each group
        // aligns strictly with the platoon's active formation direction / platoon leader's heading.
        private _targetFacing = if (_mode == "FOLLOWING_COMMANDER_REL") then {
            missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", getDir _platoonLeader]
        } else {
            getDir _platoonLeader
        };

        // Read assigned formation polar coordinates
        private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
        private _hasValidPos = (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2} && {(_relPos select 0) >= 0});
        private _targetPos = [0, 0, 0];
        if (_hasValidPos) then {
            private _dist = _relPos select 0;
            private _relAngle = _relPos select 1;
            _targetPos = if (_mode == "FOLLOWING_COMMANDER_REL") then {
                (getPosATL _leader) getPos [_dist, _curPlatoonDir + _relAngle]
            } else {
                (getPosATL _leader) getPos [_dist, _platoonDir + _relAngle]
            };
        };

        // Detect if a new formation was ordered while stopped (target position shift)
        private _posChanged = (_hasValidPos && {(_targetPos distance2D _lastTargetPos) > 1.5});

        if (!_alignedOnStop || _posChanged) then 
        {
            if (_hasValidPos) then {
                _group move _targetPos;
                _lastTargetPos = _targetPos;
            };

            _alignedOnStop = true;
            _facingAppliedOnReady = false;
        };

        // Once units arrive at final stopped position (unitReady), apply facing strictly ONCE
        if (!_facingAppliedOnReady && {unitReady (leader _group) || ((leader _group) distance2D _targetPos < 3)}) then 
        {
            _group setFormDir _targetFacing;
            _facingAppliedOnReady = true;
        };

        // Stopped approach: no explicit limitSpeed (natural arrival pacing),
        // matching the road/trail follow standard; the stale last-march speed
        // is never re-applied once the leader has halted.
        { _x disableAI "RADIOPROTOCOL"; } foreach units _group;
        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != _mode) exitWith {};
        sleep 1.0;
    };
};
