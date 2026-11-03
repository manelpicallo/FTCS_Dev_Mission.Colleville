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
private _isPlatoonCommander = (isPlayer _leader || {_leader == (leader (missionNamespace getVariable ["FTCS_Group_Commander", grpNull]))} || {(vehicleVarName _leader) find "LEADER" >= 0 && {(vehicleVarName _leader) find "SQD_" < 0}});

// If the commander is actively moving or giving the order, initialize/update advance direction
if (_isPlatoonCommander) then {
    missionNamespace setVariable ["FTCS_Last_Commander_Dir", getDir _leader];
    missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", getDir _leader];
};

[ _groupID, "movingMode", _mode ] call FTCS_fnc_registrySet;

// Retrieve current platoon advance direction
private _platoonDir = missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", missionNamespace getVariable ["FTCS_Last_Commander_Dir", getDir _leader]];

// Initial deployment positioning
if (_mode == "FOLLOWING_COMMANDER_REL") then 
{
    private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
    if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2}) then {
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
    if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2}) then {
        _group move (_leader getPos [_relPos select 0, _relPos select 1]);
        _group setFormDir _platoonDir;
    };
    units _group doFollow leader _group;
};

private _alignedOnStop = false;

while {(([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_COMMANDER_REL") ||
       (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_COMMANDER_ABS") || 
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

        waitUntil { time > _timer || unitReady leader _group || lifeState leader _group == "DEAD" || lifeState leader _group == "INCAPACITATED" };

        { _x disableAI "RADIOPROTOCOL"; } foreach units _group;

        // Continuously update platoon advance direction from commander's active march heading
        if (_isPlatoonCommander) then {
            private _liveDir = getDir _leader;
            missionNamespace setVariable ["FTCS_Last_Commander_Dir", _liveDir];
            missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _liveDir];
        };

        private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
        if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2}) then {
            if (_mode == "FOLLOWING_COMMANDER_REL") then {
                _group move (_leader getRelPos [_relPos select 0, _relPos select 1]);
            } else {
                _group move (_leader getPos [_relPos select 0, _relPos select 1]);
            };
        };

        units _group doFollow leader _group;

        if (time < _timer) then {
            _group setFormDir (getDir _leader);
        };

        _alignedOnStop = false;
    }
    // -------------------------------------------------------------------------
    // 2. STOPPED / STATIC (speed <= 2 km/h): Anchor formation along platoon heading
    // -------------------------------------------------------------------------
    else 
    {
        // Retrieve latest platoon advance direction in that moment
        private _curPlatoonDir = missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", missionNamespace getVariable ["FTCS_Last_Commander_Dir", getDir _leader]];

        if (!_alignedOnStop) then 
        {
            // If the leader is an AI (e.g. Squad Leader), ensure leader faces the platoon advance direction
            if (!isPlayer _leader) then {
                (group _leader) setFormDir _curPlatoonDir;
                _leader setFormDir _curPlatoonDir;
            };

            private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
            if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos >= 2}) then {
                private _dist = _relPos select 0;
                private _relAngle = _relPos select 1;

                // Crucial: Calculate position anchored to leader strictly along the platoon advance direction!
                // Both for Squad Leaders relative to Platoon Leader AND Fireteams relative to Squad Leader.
                private _targetPos = if (_mode == "FOLLOWING_COMMANDER_REL") then {
                    (getPosATL _leader) getPos [_dist, _curPlatoonDir + _relAngle]
                } else {
                    (getPosATL _leader) getPos [_dist, _relAngle]
                };

                _group move _targetPos;
                _group setFormDir _curPlatoonDir;
            };

            _alignedOnStop = true;
        } 
        else 
        {
            // Once units arrive at final stopped position, maintain facing aligned with platoon advance direction
            if (unitReady leader _group) then {
                _group setFormDir _curPlatoonDir;
                if (!isPlayer _leader) then {
                    _leader setFormDir _curPlatoonDir;
                };
            };
        };

        { _x limitSpeed _last_spd; } foreach units _group;
        { _x disableAI "RADIOPROTOCOL"; } foreach units _group;
        sleep 0.5;
    };
};
