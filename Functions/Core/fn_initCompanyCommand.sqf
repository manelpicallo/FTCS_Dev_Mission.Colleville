/*
    File: fn_initCompanyCommand.sqf
    Module: Core
    Author: FTCS Team
    Description: Detects whether the local player is acting as Company Commander 
                 or a specific Platoon Commander. Automatically isolates the player 
                 if they are part of a mixed group, detaching them into an independent 
                 group so they operate as an independent command node without breaking 
                 the AI hierarchy.
*/

params [];

private _commandScope = if (!isNil "FTCS_Player_Command_Scope" && {FTCS_Player_Command_Scope isEqualType createHashMap}) then {
    FTCS_Player_Command_Scope
} else {
    missionNamespace getVariable ["FTCS_Player_Command_Scope", createHashMap]
};
private _playerRole = _commandScope getOrDefault ["role", "SOLDIER"];
private _platoonID = _commandScope getOrDefault ["platoonID", 0];

switch (_playerRole) do {
    case "COMPANY_COMMANDER": {
        private _companyHQData = FTCS_Company_Data getOrDefault ["companyHQ", createHashMap];
        if (count _companyHQData > 0) then {
            private _assignedRoles = _companyHQData getOrDefault ["assignedRoles", createHashMap];
            private _captain = _assignedRoles getOrDefault ["HQ_CO_CAPTAIN", objNull];

            if (!isNull _captain && {_captain == player}) then {
                // If the player is in a mixed group with other units, isolate them into an independent group
                if (count (units group player) > 1) then {
                    private _oldGroup = group player;
                    [player] joinSilent grpNull;
                    // Refresh old group's remaining units/leader if stored in companyHQ
                    if ((_companyHQData getOrDefault ["group", grpNull]) == _oldGroup) then {
                        _companyHQData set ["units", units _oldGroup];
                        _companyHQData set ["leader", leader _oldGroup];
                    };
                    diag_log "FTCS: Company Commander isolated from mixed group into an independent group.";
                } else {
                    diag_log "FTCS: Company Commander verified as local player (already independent).";
                };
            };
        };
    };

    case "PLATOON_COMMANDER": {
        private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
        private _pltKey = format ["PLT_%1", _platoonID];
        
        if (_platoonsMap get _pltKey isEqualType createHashMap) then {
            private _pltData = _platoonsMap get _pltKey;
            private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
            private _pltHqId = format ["SQD_%1_0", _platoonID];
            
            if (_parsedSquads get _pltHqId isEqualType createHashMap) then {
                private _sqdData = _parsedSquads get _pltHqId;
                private _assignedRoles = _sqdData getOrDefault ["assignedRoles", createHashMap];
                private _pltLeaderVar = format ["PLT_%1_LEADER", _platoonID];
                private _leaderObj = _assignedRoles getOrDefault [_pltLeaderVar, objNull];

                if (!isNull _leaderObj && {_leaderObj == player}) then {
                    // If the Platoon Leader is in a mixed group, isolate them into an independent group
                    if (count (units group player) > 1) then {
                        private _oldGroup = group player;
                        [player] joinSilent grpNull;
                        // Refresh old group's remaining units/leader in SQD_X_0
                        if ((_sqdData getOrDefault ["group", grpNull]) == _oldGroup) then {
                            _sqdData set ["units", units _oldGroup];
                            _sqdData set ["leader", leader _oldGroup];
                        };
                        diag_log format ["FTCS: Platoon Commander (Platoon %1) isolated from mixed group into an independent group.", _platoonID];
                    } else {
                        diag_log format ["FTCS: Platoon Commander (Platoon %1) verified as local player (already independent).", _platoonID];
                    };
                };
            };
        };
    };

    default {
        diag_log format ["FTCS: Local player operating as standard unit / subordinate (Role: %1).", _playerRole];
    };
};

true;