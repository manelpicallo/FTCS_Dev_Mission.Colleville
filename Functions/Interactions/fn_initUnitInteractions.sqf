/*
    File: fn_initUnitInteractions.sqf
    Module: Ctrl_Interactions
    Author: FTCS Team
    Description: Dynamically initializes generic selection actions and role-based special actions 
                 across Company HQ, Platoon HQ, and Squads with robust role resolution, 
                 strict anti-duplication caching, clean action labels, and strict priority ordering.
                 Doctrinal data (FTCS_Company_Data) is prioritized over group existence.
                 Filtered dynamically based on player command scope (Company Commander vs Platoon Commander).
*/

private _playerSide = side group player;
private _processedUnits = [];

// Reset or initialize action assignment cache to prevent duplicates
FTCS_AssignedActionsCache = [];

// Retrieve player command scope to restrict/filter interaction menus accordingly
private _commandScope = if (!isNil "FTCS_Player_Command_Scope" && {FTCS_Player_Command_Scope isEqualType createHashMap}) then {
    FTCS_Player_Command_Scope
} else {
    missionNamespace getVariable ["FTCS_Player_Command_Scope", createHashMap]
};
private _playerRole = _commandScope getOrDefault ["role", "COMPANY_COMMANDER"];
private _playerPlatoonID = _commandScope getOrDefault ["platoonID", 0];

// Helper function to add generic selection action (excluding player)
private _fnc_addGenericAction = {
    params ["_unit"];
    if (_unit == player) exitWith {};
    
    if (!(_unit in _processedUnits) && {alive _unit} && {side _unit == _playerSide}) then {
        _processedUnits pushBack _unit;
        
        [
            _unit,
            format ["<t color='#FFFF00'>Select %1</t>", name _unit],
            {
                params ["_target"];
                Type_Selected = "SOLDIER";
                Selected_Units_list set [0, _target];
            },
            [],
            0.5,
            10.0,
            "true"
        ] call FTCS_fnc_addEngineAction;
    };
};

// Helper function to add specific Company HQ tactical actions (XO / First Sergeant)
private _fnc_addCompanyHQActions = {
    params ["_unit"];
    
    if (_unit == player) exitWith {};
    
    private _cacheKeyBase = format ["%1_COMPANY_HQ", _unit];
    if (_cacheKeyBase in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKeyBase;

    // 1. Emergency Actions (Highest Priority)
    [
        _unit,
        "<t color='#FF4500'>Emergency: Break Contact</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            ["BREAK_CONTACT", group _target] remoteExec ["FTCS_fnc_handleCompanyEmergency", 2];
        },
        [], 2.0, 15.0, "true"
    ] call FTCS_fnc_addEngineAction;

    [
        _unit,
        "<t color='#FFD700'>Emergency: Artillery Evasion</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            ["ARTILLERY_EVASION", group _target] remoteExec ["FTCS_fnc_handleCompanyEmergency", 2];
        },
        [], 1.9, 15.0, "true"
    ] call FTCS_fnc_addEngineAction;

    // 2. Global Company Orders
    [
        _unit,
        "<t color='#00FFCC'>Company Orders</t>",
        { createDialog "FTCS_CompanyCommand_Dialog"; },
        [], 1.8, 10.0, "true"
    ] call FTCS_fnc_addEngineAction;

    // 3. Dynamic Doctrinal Platoon Tasking Actions (Ordered: HQ, 1st, 2nd, 3rd, etc.)
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _platoonKeys = keys _platoonsMap;
    _platoonKeys sort true;

    private _priorityOffset = 0.0;
    {
        private _pltKey = _x;
        private _pltData = _platoonsMap get _pltKey;
        private _pltName = _pltData getOrDefault ["name", _pltKey];
        
        private _pltCacheKey = format ["%1_TASK_%2", _unit, _pltKey];
        if (!(_pltCacheKey in FTCS_AssignedActionsCache)) then {
            FTCS_AssignedActionsCache pushBack _pltCacheKey;
            
            private _actionPriority = 1.7 - _priorityOffset;
            _priorityOffset = _priorityOffset + 0.1;

            [
                _unit,
                format ["<t color='#00BFFF'>Orders to: %1</t>", _pltName],
                {
                    params ["_target", "_caller", "_actionId", "_arguments"];
                    _arguments params ["_targetPltKey", "_targetPltName"];
                    
                    FTCS_SelectedPlatoonKey = _targetPltKey;
                    systemChat format ["Directing orders to: %1", _targetPltName];
                    createDialog "FTCS_PlatoonTasking_Dialog";
                },
                [_pltKey, _pltName],
                _actionPriority,
                10.0,
                "true"
            ] call FTCS_fnc_addEngineAction;
        };
    } forEach _platoonKeys;
};

// Helper function to add subordinate interaction actions when a Platoon Commander talks to Company HQ (Captain / XO)
private _fnc_addSubordinateCompanyHQActions = {
    params ["_unit"];
    
    if (_unit == player) exitWith {};
    
    private _cacheKeyBase = format ["%1_SUBORDINATE_CO_HQ", _unit];
    if (_cacheKeyBase in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKeyBase;

    // 1. Request Reinforcements / Supplies (Subordinate Menu Option)
    [
        _unit,
        "<t color='#FF8C00'>Request Reinforcements & Supplies</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            systemChat "Transmitting request for reinforcements and supplies to Company HQ...";
            ["REQUEST_SUPPLIES", group player] remoteExec ["FTCS_fnc_handleCompanyLogistics", 2];
        },
        [], 2.0, 10.0, "true"
    ] call FTCS_fnc_addEngineAction;

    // 2. Submit Tactical SITREP (Subordinate Menu Option)
    [
        _unit,
        "<t color='#00CED1'>Submit Tactical SITREP</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            systemChat "Submitting Platoon SITREP to Company Commander / XO...";
            ["SUBMIT_SITREP", group player] remoteExec ["FTCS_fnc_handleCompanySITREP", 2];
        },
        [], 1.9, 10.0, "true"
    ] call FTCS_fnc_addEngineAction;
};

// Helper function to add specific Platoon HQ tactical actions (Platoon Leader / Platoon Sergeant)
private _fnc_addPlatoonHQActions = {
    params ["_unit", "_platoonKey"];
    
    if (_unit == player) exitWith {};
    
    private _cacheKeyBase = format ["%1_PLATOON_HQ_%2", _unit, _platoonKey];
    if (_cacheKeyBase in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKeyBase;

    // 1. Emergency Actions (Highest Priority)
    [
        _unit,
        "<t color='#FF4500'>Emergency: Suppress Target</t>",
        { 
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_pltKey"];
            ["PLATOON_SUPPRESS", _pltKey] remoteExec ["FTCS_fnc_handlePlatoonEmergency", 2];
        },
        [_platoonKey], 2.0, 3.0, "true"
    ] call FTCS_fnc_addEngineAction;

    [
        _unit,
        "<t color='#FFD700'>Emergency: Smoke Screen</t>",
        { 
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_pltKey"];
            ["PLATOON_SMOKE", _pltKey] remoteExec ["FTCS_fnc_handlePlatoonEmergency", 2];
        },
        [_platoonKey], 1.9, 3.0, "true"
    ] call FTCS_fnc_addEngineAction;

    // 2. Global Platoon Orders
    [
        _unit,
        "<t color='#00FFCC'>Platoon Orders</t>",
        { 
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_pltKey"];
            FTCS_SelectedPlatoonKey = _pltKey;
            createDialog "FTCS_PlatoonCommand_Dialog"; 
        },
        [_platoonKey], 1.8, 3.0, "true"
    ] call FTCS_fnc_addEngineAction;

    // 3. Dynamic Doctrinal Squad Tasking Actions (Direct from FTCS_Company_Data)
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltData = _platoonsMap getOrDefault [_platoonKey, createHashMap];
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
    
    private _squadKeys = keys _parsedSquads;
    _squadKeys sort true;

    private _priorityOffset = 0.0;
    {
        private _sqdKey = _x;
        private _sqdData = _parsedSquads get _sqdKey;
        
        // Pure Doctrinal Name Retrieval: Always reads the TO&E name property
        private _sqdName = _sqdData getOrDefault ["name", _sqdKey];
        
        private _sqdCacheKey = format ["%1_TASK_SQD_%2", _unit, _sqdKey];
        if (!(_sqdCacheKey in FTCS_AssignedActionsCache)) then {
            FTCS_AssignedActionsCache pushBack _sqdCacheKey;
            
            private _actionPriority = 1.7 - _priorityOffset;
            _priorityOffset = _priorityOffset + 0.1;

            [
                _unit,
                format ["<t color='#00BFFF'>Orders to: %1</t>", _sqdName],
                {
                    params ["_target", "_caller", "_actionId", "_arguments"];
                    _arguments params ["_targetSqdKey", "_targetSqdName"];
                    
                    FTCS_SelectedSquadKey = _targetSqdKey;
                    systemChat format ["Directing orders to: %1", _targetSqdName];
                    createDialog "FTCS_SquadTasking_Dialog";
                },
                [_sqdKey, _sqdName],
                _actionPriority,
                10.0,
                "true"
            ] call FTCS_fnc_addEngineAction;
        };
    } forEach _squadKeys;
};

// Helper function to add standard special actions uniquely per unit and menu type
private _fnc_addSpecialAction = {
    params ["_unit", "_menuType"];
    
    if (_unit == player) exitWith {};
    
    private _cacheKey = format ["%1_%2", _unit, _menuType];
    if (_cacheKey in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKey;

    switch (_menuType) do {
        case "RADIO": {
            [
                _unit,
                "<t color='#FF4500'>Radio SITREP</t>",
                { createDialog "FTCS_RadioMenu_Dialog"; },
                [], 1.6, 10.0, "true"
            ] call FTCS_fnc_addEngineAction;
        };
        case "MEDICAL": {
            [
                _unit,
                "<t color='#00FF00'>Medical Triage</t>",
                { createDialog "FTCS_MedicalMenu_Dialog"; },
                [], 1.6, 10.0, "true"
            ] call FTCS_fnc_addEngineAction;
        };
        case "RUNNER": {
            [
                _unit,
                "<t color='#D2B48C'>Dispatch Runner</t>",
                { createDialog "FTCS_RunnerMenu_Dialog"; },
                [], 1.6, 10.0, "true"
            ] call FTCS_fnc_addEngineAction;
        };
    };
};

// Helper to determine menu type robustly from role key or variable name
private _fnc_resolveRoleMenu = {
    params ["_roleStr"];
    private _upper = toUpper _roleStr;
    
    if (_upper find "RADIO" >= 0 || _upper find "RTO" >= 0 || _upper find "COMM" >= 0) exitWith {"RADIO"};
    if (_upper find "XO" >= 0 || (_upper find "SERGEANT" >= 0 && {_upper find "PLT_" < 0 && _upper find "PLATOON_" < 0}) || (_upper find "SGT" >= 0 && {_upper find "PLT_" < 0 && _upper find "PLATOON_" < 0}) || _upper find "GUIDE" >= 0) exitWith {"COMPANY_HQ"};
    if (_upper find "MEDIC" >= 0 || _upper find "SANIT" >= 0 || _upper find "DOCTOR" >= 0) exitWith {"MEDICAL"};
    if (_upper find "MESSENGER" >= 0 || _upper find "RUNNER" >= 0) exitWith {"RUNNER"};
    
    ""
};

// 1. Process Company HQ Assigned Roles (XO, First Sergeant, etc.)
private _companyHQ = FTCS_Company_Data getOrDefault ["companyHQ", createHashMap];
private _assignedRoles = _companyHQ getOrDefault ["assignedRoles", createHashMap];

if (count _assignedRoles > 0) then {
    {
        private _roleKey = _x;
        private _unit = _y;
        
        // Strict check: Process only actual Company HQ roles starting with HQ_
        if ((toUpper _roleKey) find "HQ_" == 0) then {
            if (!isNull _unit && {_unit != player} && {alive _unit} && {side _unit == _playerSide}) then {
                [_unit] call _fnc_addGenericAction;
                
                private _menu = [_roleKey] call _fnc_resolveRoleMenu;
                if (_menu == "COMPANY_HQ") then {
                    if (_playerRole == "COMPANY_COMMANDER") then {
                        [_unit] call _fnc_addCompanyHQActions;
                    } else {
                        if (_playerRole == "PLATOON_COMMANDER") then {
                            [_unit] call _fnc_addSubordinateCompanyHQActions;
                        };
                    };
                } else {
                    if (_menu != "") then {
                        [_unit, _menu] call _fnc_addSpecialAction;
                    };
                };
            };
        };
    } forEach _assignedRoles;

    // Register dynamic proximity self-actions on player for the Command Staff (Only for Company Commander)
    if (_playerRole == "COMPANY_COMMANDER") then {
        if (isNil "FTCS_PlayerStaffActionsCache") then {
            FTCS_PlayerStaffActionsCache = [];
        } else {
            {
                player removeAction _x;
            } forEach FTCS_PlayerStaffActionsCache;
            FTCS_PlayerStaffActionsCache = [];
        };

        {
            private _roleKey = _x;
            private _staffUnit = _y;
            
            if (!isNull _staffUnit && {_staffUnit != player}) then {
                private _roleLabel = switch (toUpper _roleKey) do {
                    case "HQ_XO_LIEUTENANT": { "XO" };
                    case "HQ_FIRST_SERGEANT": { "Company Sergeant" };
                    case "HQ_RADIO_OPERATOR": { "RTO" };
                    default { "" };
                };
                
                if (_roleLabel != "") then {
                    private _actionId = [
                        player,
                        format ["<t color='#00FFCC'>[Staff] Order %1</t>", _roleLabel],
                        {
                            params ["_target", "_caller", "_actionId", "_arguments"];
                            _arguments params ["_targetStaff", "_roleName"];
                            
                            FTCS_SelectedStaffUnit = _targetStaff;
                            createDialog "FTCS_StaffTasking_Dialog";
                        },
                        [_staffUnit, _roleLabel],
                        1.5,
                        15.0,
                        format ["(isNull cursorTarget || {cursorTarget distance player > 15.0} || {side cursorTarget != side group player}) && {_this distance (missionNamespace getVariable ['%1', objNull]) < 15} && {alive (missionNamespace getVariable ['%1', objNull])}", _roleKey]
                    ] call FTCS_fnc_addEngineAction;

                    if (_actionId > -1) then {
                        FTCS_PlayerStaffActionsCache pushBack _actionId;
                    };
                };
            };
        } forEach _assignedRoles;
    };
};

// 2. Process Tactical Platoons and Squads (Filtered by player command scope)
private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];

{
    private _pltKey = _x;
    private _pltData = _y;
    private _pltIndex = parseNumber ((_pltKey splitString "_") select 1);

    // If player is a Platoon Commander, skip processing tactical actions for other platoons
    if (_playerRole == "PLATOON_COMMANDER" && {_pltIndex != _playerPlatoonID}) then {
        // Skip alien platoons
    } else {
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

        {
            private _sqdId = _x;
            private _sqdData = _y;
            private _squadGroup = _sqdData getOrDefault ["group", grpNull];
            private _squadLeader = _sqdData getOrDefault ["leader", objNull];

            // Process Platoon HQ Element (_0 identifier)
            if (_sqdId find "_0" >= 0) then {
                if (!isNull _squadLeader && {_squadLeader != player}) then {
                    [_squadLeader] call _fnc_addGenericAction;
                    [_squadLeader, _pltKey] call _fnc_addPlatoonHQActions;
                };

                if (!isNull _squadGroup) then {
                    {
                        private _soldier = _x;
                        if (!isNull _soldier && {_soldier != player} && {alive _soldier} && {side _soldier == _playerSide}) then {
                            [_soldier] call _fnc_addGenericAction;

                            private _unitVar = vehicleVarName _soldier;
                            private _menu = [_unitVar] call _fnc_resolveRoleMenu;
                            
                            if (_menu == "COMPANY_HQ") then {
                                if (_playerRole == "COMPANY_COMMANDER") then {
                                    [_soldier] call _fnc_addCompanyHQActions;
                                };
                            } else {
                                if (_menu != "") then {
                                    [_soldier, _menu] call _fnc_addSpecialAction;
                                } else {
                                    private _idx = (units _squadGroup) find _soldier;
                                    if (_idx == 1) then {
                                        // Platoon Sergeant / Deputy Leader gets Platoon HQ actions
                                        [_soldier, _pltKey] call _fnc_addPlatoonHQActions;
                                    };
                                };
                            };
                        };
                    } forEach (units _squadGroup);
                };
            } else {
                // Standard Squads
                if (!isNull _squadLeader && {_squadLeader != player}) then {
                    [_squadLeader] call _fnc_addGenericAction;
                };

                if (!isNull _squadGroup) then {
                    {
                        private _soldier = _x;
                        if (!isNull _soldier && {_soldier != player} && {alive _soldier} && {side _soldier == _playerSide}) then {
                            [_soldier] call _fnc_addGenericAction;

                            private _unitVar = vehicleVarName _soldier;
                            private _menu = [_unitVar] call _fnc_resolveRoleMenu;
                            if (_menu != "") then {
                                [_soldier, _menu] call _fnc_addSpecialAction;
                            };
                        };
                    } forEach (units _squadGroup);
                };
            };

            private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
            {
                private _teamData = _y;
                private _teamGroup = _teamData getOrDefault ["group", grpNull];
                if (!isNull _teamGroup) then {
                    {
                        private _soldier = _x;
                        if (!isNull _soldier && {_soldier != player} && {alive _soldier} && {side _soldier == _playerSide}) then {
                            [_soldier] call _fnc_addGenericAction;

                            private _unitVar = vehicleVarName _soldier;
                            private _menu = [_unitVar] call _fnc_resolveRoleMenu;
                            if (_menu != "") then {
                                [_soldier, _menu] call _fnc_addSpecialAction;
                            };
                        };
                    } forEach (units _teamGroup);
                };
            } forEach _tacticalTeams;

        } forEach _parsedSquads;
    };

} forEach _platoonsMap;

diag_log format ["FTCS: Unit interactions initialized successfully (Player Role: %1, Platoon ID: %2).", _playerRole, _playerPlatoonID];
true;