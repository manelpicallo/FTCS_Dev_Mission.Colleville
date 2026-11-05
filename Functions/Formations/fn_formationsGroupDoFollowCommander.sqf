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

private _groupID = groupId _group;
private _not_able_time = 1;  
private _timer = time;
private _spd = speed _leader;
private _last_spd = 10;

// Identify if the reference leader is the main platoon commander (player or platoon HQ leader)
private _isPlatoonCommander = (isPlayer _leader || {_leader == (leader (missionNamespace getVariable ["FTCS_Group_Commander", grpNull]))} || {_leader == (missionNamespace getVariable ["FTCS_Platoon_Leader_Unit", objNull])} || {(vehicleVarName _leader) find "LEADER" >= 0 && {(vehicleVarName _leader) find "SQD_" < 0}});

// If the commander is actively moving or giving the order, initialize/update advance direction in relative mode only
if (_isPlatoonCommander && {_mode != "FOLLOWING_COMMANDER_ABS"}) then {
    missionNamespace setVariable ["FTCS_Last_Commander_Dir", getDir _leader];
    missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", getDir _leader];
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
        // When stopped, anchor strictly along the platoon advance direction
        private _refHeading = if (speed _leader > 2) then { getDir _leader } else { _platoonDir };
        _group move ((getPosATL _leader) getPos [_dist, _refHeading + _relAngle]);
        _group setFormDir _refHeading;
    };
    units _group doFollow leader _group;
};

if (_mode == "FOLLOWING_COMMANDER_ABS") then 
{
    private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
    if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2} && {(_relPos select 0) >= 0}) then {
        _group move ((getPosATL _leader) getPos [_relPos select 0, _platoonDir + (_relPos select 1)]);
        _group setFormDir _platoonDir;
    };
    units _group doFollow leader _group;
};

private _alignedOnStop = false;
private _facingAppliedOnReady = false;

while {(([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == _mode) || 
       (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "HALT")} do
{
    _spd = speed _leader;

    // -------------------------------------------------------------------------
    // 1. ACTIVE MARCHING (speed > 2 km/h): Dynamic formation tracking
    // -------------------------------------------------------------------------
    if (_spd > 2) then 
    {
        _last_spd = _spd;
        { _x limitSpeed _spd; } foreach units _group;

        _timer = time + _not_able_time;

        waitUntil { 
            time > _timer || 
            ([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != _mode || 
            unitReady leader _group || 
            lifeState leader _group == "DEAD" || 
            lifeState leader _group == "INCAPACITATED" 
        };

        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != _mode) exitWith {};

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

        if (time < _timer) then {
            if (_mode == "FOLLOWING_COMMANDER_REL") then {
                _group setFormDir (getDir _leader);
            } else {
                _group setFormDir _platoonDir;
            };
        };

        _alignedOnStop = false;
        _facingAppliedOnReady = false;
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
        private _platoonLeaderDir = getDir _platoonLeader;

        if (!_alignedOnStop) then 
        {
            // If the leader is an AI (e.g. Squad Leader), ensure leader faces the platoon leader stop direction
            if (!isPlayer _leader) then {
                private _leaderFacing = if (_mode == "FOLLOWING_COMMANDER_REL") then { _curPlatoonDir } else { _platoonLeaderDir };
                (group _leader) setFormDir _leaderFacing;
            };

            private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
            if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2} && {(_relPos select 0) >= 0}) then {
                private _dist = _relPos select 0;
                private _relAngle = _relPos select 1;

                // Crucial: Calculate position anchored to leader strictly along the platoon advance direction!
                // Both for Squad Leaders relative to Platoon Leader AND Fireteams relative to Squad Leader.
                private _targetPos = if (_mode == "FOLLOWING_COMMANDER_REL") then {
                    (getPosATL _leader) getPos [_dist, _curPlatoonDir + _relAngle]
                } else {
                    (getPosATL _leader) getPos [_dist, _platoonDir + _relAngle]
                };

                _group move _targetPos;
                if (_mode == "FOLLOWING_COMMANDER_REL") then {
                    _group setFormDir _curPlatoonDir;
                } else {
                    _group setFormDir _platoonLeaderDir;
                };
            };

            _alignedOnStop = true;
        };

        // Once units arrive at final stopped position (unitReady), apply facing strictly ONCE
        if (!_facingAppliedOnReady && {unitReady (leader _group)}) then 
        {
            private _targetFacing = if (_mode == "FOLLOWING_COMMANDER_REL") then { _curPlatoonDir } else { _platoonLeaderDir };
            _group setFormDir _targetFacing;
            if (!isPlayer _leader) then {
                (group _leader) setFormDir _targetFacing;
            };
            _facingAppliedOnReady = true;
        };

        { _x limitSpeed _last_spd; } foreach units _group;
        { _x disableAI "RADIOPROTOCOL"; } foreach units _group;
        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) != _mode) exitWith {};
        sleep 0.5;
    };
};
