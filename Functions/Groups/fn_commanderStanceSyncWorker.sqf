/*
    ================================================================================
    File: fn_commanderStanceSyncWorker.sqf
    Module: Core / Groups
    Author: FTCS Team
    Description: Centralized lightweight event-driven worker (Option A).
                 Monitors commander player physical stance changes and propagates
                 unitPos (UP, MIDDLE, DOWN) to all groups registered in
                 "FOLLOW_COMMANDER_STANCE" without spawning multi-threaded while loops.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)
    ================================================================================
*/

if (!isNil "FTCS_StanceSyncWorker_Active" && {FTCS_StanceSyncWorker_Active}) exitWith {};

FTCS_StanceSyncWorker_Active = true;

[] spawn {
    private _lastStance = "";
    
    while {true} do {
        // Count how many groups currently request commander stance mirroring
        private _followCount = 0;
        {
            if ((_y getOrDefault ["stance", ""]) == "FOLLOW_COMMANDER_STANCE") then {
                _followCount = _followCount + 1;
            };
        } forEach FTCS_Groups_Registry_Table;

        // If no group is in FOLLOW_COMMANDER_STANCE, put worker to sleep
        if (_followCount == 0) then {
            FTCS_StanceSyncWorker_Active = false;
            break;
        };

        private _curStance = stance player;
        if (_curStance != _lastStance) then {
            _lastStance = _curStance;
            
            private _targetUnitPos = switch (_curStance) do {
                case "STAND":  { "UP" };
                case "CROUCH": { "MIDDLE" };
                case "PRONE":  { "DOWN" };
                default        { "AUTO" };
            };

            {
                private _grpId = _x;
                private _grpEntry = _y;
                if ((_grpEntry getOrDefault ["stance", ""]) == "FOLLOW_COMMANDER_STANCE") then {
                    private _grpObj = missionNamespace getVariable [_grpId, grpNull];
                    if (!isNull _grpObj) then {
                        {
                            if (unitPos _x != _targetUnitPos) then {
                                _x setUnitPos _targetUnitPos;
                            };
                        } forEach (units _grpObj);
                    };
                };
            } forEach FTCS_Groups_Registry_Table;
        };

        sleep 0.4;
    };
};

true;
