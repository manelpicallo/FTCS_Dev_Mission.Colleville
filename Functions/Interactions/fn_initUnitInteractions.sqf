/*
    File: fn_initUnitInteractions.sqf
    Module: Ctrl_Interactions
    Author: FTCS Team
    Description: Dynamically initializes physical and contextual commanding actions 
                 across Company HQ, Platoon HQ, and Squads with robust role resolution, 
                 strict anti-duplication caching, clean action labels, and strict priority ordering.
                 Each action invokes its own dedicated native commandingMenu (#USER: commandingMenu)
                 navigable via number keys [1-9] or mouse wheel.
                 Supports direct line-of-sight visual checks (cursorObject), distance-based channel routing
                 (Voice <= 20m vs Visual Signals 20-60m), and proximity summons ([Call]).
    Language: Strictly English (Rule 7)
*/

private _playerSide = side group player;
private _processedUnits = [];

// Ensure native commanding menus are initialized in memory
if (isNil "FTCS_CommandingMenus_Initialized") then {
    call FTCS_fnc_initCommandingMenus;
};

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

// Helper to determine menu type robustly from role key or variable name
private _fnc_resolveRoleMenu = {
    params ["_roleStr"];
    private _upper = toUpper _roleStr;
    
    if (_upper find "RADIO" >= 0 || _upper find "RTO" >= 0 || _upper find "COMM" >= 0) exitWith {"RADIO"};
    if (_upper find "XO" >= 0 || (_upper find "SERGEANT" >= 0 && {_upper find "PLT_" < 0 && _upper find "PLATOON_" < 0}) || (_upper find "SGT" >= 0 && {_upper find "PLT_" < 0 && _upper find "PLATOON_" < 0}) || _upper find "GUIDE" >= 0) exitWith {"STAFF"};
    if (_upper find "MEDIC" >= 0 || _upper find "SANIT" >= 0 || _upper find "DOCTOR" >= 0) exitWith {"MEDIC"};
    if (_upper find "MESSENGER" >= 0 || _upper find "RUNNER" >= 0) exitWith {"RUNNER"};
    
    ""
};

// Helper function to add specific Company HQ staff tactical actions (XO / First Sergeant)
private _fnc_addCompanyHQActions = {
    params ["_unit"];
    
    if (_unit == player) exitWith {};
    
    private _cacheKeyBase = format ["%1_COMPANY_HQ", _unit];
    if (_cacheKeyBase in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKeyBase;

    // Direct Order via commandingMenu (Requires looking directly at the unit)
    [
        _unit,
        "<t color='#00FFCC'>[Orders] Company Directives</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            [_target, _caller, _actionId, ["STAFF", "Company Staff"]] call FTCS_fnc_openSubordinateMenu;
        },
        [], 2.0, 15.0, "cursorObject == _target"
    ] call FTCS_fnc_addEngineAction;

    // Emergency direct action
    [
        _unit,
        "<t color='#FF4500'>[Emergency] Break Contact</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            ['CO_BREAK_CONTACT'] call FTCS_fnc_applyCommandToTarget;
        },
        [], 1.9, 15.0, "cursorObject == _target"
    ] call FTCS_fnc_addEngineAction;
};

// Helper function to add subordinate interaction actions when a Platoon Commander talks to Company HQ (Captain / XO)
private _fnc_addSubordinateCompanyHQActions = {
    params ["_unit"];
    
    if (_unit == player) exitWith {};
    
    private _cacheKeyBase = format ["%1_SUBORDINATE_CO_HQ", _unit];
    if (_cacheKeyBase in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKeyBase;

    [
        _unit,
        "<t color='#FF8C00'>[Report] Request Reinforcements & Supplies</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            systemChat "[LOGISTICS] Request for ammunition resupply and reinforcements logged at Company HQ.";
            hint parseText "<t color='#FFAA00'>[Company Logistics]</t><br/><t color='#FFFFFF'>Request received:</t> Ammunition & supplies dispatch queued.";
        },
        [], 2.0, 10.0, "cursorObject == _target"
    ] call FTCS_fnc_addEngineAction;

    [
        _unit,
        "<t color='#00CED1'>[Report] Submit Tactical SITREP</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            private _pltGrp = group player;
            private _effectiveCount = { alive _x } count (units _pltGrp);
            systemChat format ["[SITREP] Platoon status delivered to Company HQ: %1 soldiers combat ready.", _effectiveCount];
            hint parseText format ["<t color='#00CED1'>[Tactical SITREP Received]</t><br/><t color='#FFFFFF'>Origin:</t> %1<br/><t color='#00FFCC'>Readiness:</t> %2 active personnel.", groupId _pltGrp, _effectiveCount];
        },
        [], 1.9, 10.0, "cursorObject == _target"
    ] call FTCS_fnc_addEngineAction;
};

// Helper function to add specific Platoon Sergeant tactical actions
private _fnc_addPlatoonSergeantActions = {
    params ["_unit", "_platoonKey"];
    
    if (_unit == player) exitWith {};
    
    private _cacheKeyBase = format ["%1_PLATOON_SGT_%2", _unit, _platoonKey];
    if (_cacheKeyBase in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKeyBase;

    // Resolve semantic platoon name from doctrinal data (e.g. "1st Rifle Platoon")
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltData = _platoonsMap getOrDefault [_platoonKey, createHashMap];
    private _pltName = _pltData getOrDefault ["name", _platoonKey];

    // 1. Direct entire platoon orders through Platoon Sergeant (Dynamic by Operational Phase)
    [
        _unit,
        format ["<t color='#00FFCC'>[Orders: %1] Platoon Command Net (Sgt)</t>", _pltName],
        { 
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_pKey", "_pName"];
            [_target, _caller, _actionId, ["PLATOON_SERGEANT", _pName]] call FTCS_fnc_openSubordinateMenu;
        },
        [_platoonKey, _pltName], 2.1, 20.0, "cursorObject == _target"
    ] call FTCS_fnc_addEngineAction;

    // 2. Direct Phase Transition action
    [
        _unit,
        "<t color='#FFAA00'>[Phase] Transition Operational Phase</t>",
        { 
            params ["_target", "_caller", "_actionId"];
            [_target, _caller, _actionId, ["PHASE_TRANSITION", "Operational Phase"]] call FTCS_fnc_openSubordinateMenu;
        },
        [], 2.0, 20.0, "cursorObject == _target"
    ] call FTCS_fnc_addEngineAction;

    // 3. Dynamic squad tasking actions through Platoon Sergeant (individual squad orders)
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
    private _squadKeys = keys _parsedSquads;
    _squadKeys sort true;

    private _priorityOffset = 0.0;
    {
        private _sqdKey = _x;
        if (_sqdKey find "_0" < 0) then {
            private _sqdData = _parsedSquads get _sqdKey;
            private _sqdName = _sqdData getOrDefault ["name", _sqdKey];
            
            private _sqdCacheKey = format ["%1_SGT_TASK_SQD_%2", _unit, _sqdKey];
            if (!(_sqdCacheKey in FTCS_AssignedActionsCache)) then {
                FTCS_AssignedActionsCache pushBack _sqdCacheKey;
                
                private _actionPriority = 1.9 - _priorityOffset;
                _priorityOffset = _priorityOffset + 0.1;

                [
                    _unit,
                    format ["<t color='#00BFFF'>[Orders: %1] Direct to %2</t>", _pltName, _sqdName],
                    {
                        params ["_target", "_caller", "_actionId", "_arguments"];
                        _arguments params ["_targetSqdKey", "_targetSqdName"];
                        [_target, _caller, _actionId, ["SQUAD", _targetSqdName]] call FTCS_fnc_openSubordinateMenu;
                    },
                    [_sqdKey, _sqdName],
                    _actionPriority,
                    20.0,
                    "cursorObject == _target"
                ] call FTCS_fnc_addEngineAction;
            };
        };
    } forEach _squadKeys;
};

// Helper function to add specific Platoon HQ tactical actions (strictly for Platoon Leader)
private _fnc_addPlatoonHQActions = {
    params ["_unit", "_platoonKey"];
    
    if (_unit == player) exitWith {};

    // Safety check: ensure radio operators or medics in Platoon HQ never receive Platoon HQ command actions
    private _uVar = toUpper (vehicleVarName _unit);
    if (_uVar find "RADIO" >= 0 || _uVar find "RTO" >= 0 || _uVar find "MEDIC" >= 0 || _uVar find "RUNNER" >= 0) exitWith {};
    
    private _cacheKeyBase = format ["%1_PLATOON_HQ_%2", _unit, _platoonKey];
    if (_cacheKeyBase in FTCS_AssignedActionsCache) exitWith {};
    FTCS_AssignedActionsCache pushBack _cacheKeyBase;

    // Resolve semantic platoon name from doctrinal data (e.g. "1st Rifle Platoon")
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltData = _platoonsMap getOrDefault [_platoonKey, createHashMap];
    private _pltName = _pltData getOrDefault ["name", _platoonKey];

    // Direct Platoon Orders to entire platoon (Opens #USER:FTCS_MENU_PlatoonLeader)
    [
        _unit,
        format ["<t color='#00FFCC'>[Orders: %1] Direct Entire Platoon</t>", _pltName],
        { 
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_pKey", "_pName"];
            [_target, _caller, _actionId, ["PLATOON", _pName]] call FTCS_fnc_openSubordinateMenu;
        },
        [_platoonKey, _pltName], 2.0, 60.0, "cursorObject == _target"
    ] call FTCS_fnc_addEngineAction;

    // Dynamic Doctrinal Squad Tasking Actions (individual squad orders)
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
    private _squadKeys = keys _parsedSquads;
    _squadKeys sort true;

    private _priorityOffset = 0.0;
    {
        private _sqdKey = _x;
        if (_sqdKey find "_0" < 0) then {
            private _sqdData = _parsedSquads get _sqdKey;
            private _sqdName = _sqdData getOrDefault ["name", _sqdKey];
            
            private _sqdCacheKey = format ["%1_TASK_SQD_%2", _unit, _sqdKey];
            if (!(_sqdCacheKey in FTCS_AssignedActionsCache)) then {
                FTCS_AssignedActionsCache pushBack _sqdCacheKey;
                
                private _actionPriority = 1.9 - _priorityOffset;
                _priorityOffset = _priorityOffset + 0.1;

                [
                    _unit,
                    format ["<t color='#00BFFF'>[Orders: %1] Direct to %2</t>", _pltName, _sqdName],
                    {
                        params ["_target", "_caller", "_actionId", "_arguments"];
                        _arguments params ["_targetSqdKey", "_targetSqdName"];
                        [_target, _caller, _actionId, ["SQUAD", _targetSqdName]] call FTCS_fnc_openSubordinateMenu;
                    },
                    [_sqdKey, _sqdName],
                    _actionPriority,
                    20.0,
                    "cursorObject == _target"
                ] call FTCS_fnc_addEngineAction;
            };
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
                "<t color='#FF4500'>[Radio Net] Field Radio Comms</t>",
                { 
                    params ["_target", "_caller", "_actionId"];
                    [_target, _caller, _actionId, ["RADIO", "Field Radio Net"]] call FTCS_fnc_openSubordinateMenu;
                },
                [], 1.8, 5.0, "cursorObject == _target"
            ] call FTCS_fnc_addEngineAction;
        };
        case "MEDIC": {
            [
                _unit,
                "<t color='#00FF00'>[Medical] Triage & CCP</t>",
                { 
                    params ["_target", "_caller", "_actionId"];
                    [_target, _caller, _actionId, ["MEDIC", "Combat Medic"]] call FTCS_fnc_openSubordinateMenu;
                },
                [], 1.8, 5.0, "cursorObject == _target"
            ] call FTCS_fnc_addEngineAction;
        };
        case "RUNNER": {
            [
                _unit,
                "<t color='#D2B48C'>[Dispatch] Send Runner with Orders</t>",
                { 
                    params ["_target", "_caller", "_actionId"];
                    [_target, _caller, _actionId, ["RUNNER", "HQ Runner"]] call FTCS_fnc_openSubordinateMenu;
                },
                [], 1.8, 5.0, "cursorObject == _target"
            ] call FTCS_fnc_addEngineAction;
        };
    };
};

// 1. Process Company HQ Assigned Roles (XO, First Sergeant, RTO, Runners, Medic)
private _companyHQ = FTCS_Company_Data getOrDefault ["companyHQ", createHashMap];
private _assignedRoles = _companyHQ getOrDefault ["assignedRoles", createHashMap];

if (count _assignedRoles > 0) then {
    {
        private _roleKey = _x;
        private _unit = _y;
        
        // Strict check: Process only actual Company HQ roles starting with HQ_
        if ((toUpper _roleKey) find "HQ_" == 0) then {
            if (!isNull _unit && {_unit != player} && {alive _unit} && {side _unit == _playerSide}) then {
                private _menu = [_roleKey] call _fnc_resolveRoleMenu;
                if (_menu == "STAFF") then {
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

    // Register proximity voice summons on player for key staff roles (Only for Company Commander)
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
                    case "HQ_FIRST_SERGEANT": { "First Sergeant" };
                    case "HQ_RADIO_OPERATOR": { "Radioman" };
                    default { "" };
                };
                
                if (_roleLabel != "") then {
                    // Voice Call: "XO, on me!" - Callable without looking directly at the unit (Proximity <= 20m)
                    private _actionId = [
                        player,
                        format ["<t color='#FFAA00'>[Call] ""%1, to me!""</t>", _roleLabel],
                        {
                            params ["_target", "_caller", "_actionId", "_arguments"];
                            _arguments params ["_targetStaff", "_roleName"];
                            
                            systemChat format ["[SHOUT] Commander summons %1 to his position.", _roleName];
                            _targetStaff doMove (getPosATL player);
                        },
                        [_staffUnit, _roleLabel],
                        1.4,
                        20.0,
                        format ["(isNull cursorObject || {cursorObject != (missionNamespace getVariable ['%1', objNull])}) && {player distance (missionNamespace getVariable ['%1', objNull]) <= 20} && {alive (missionNamespace getVariable ['%1', objNull])}", _roleKey]
                    ] call FTCS_fnc_addEngineAction;

                    if (_actionId > -1) then {
                        FTCS_PlayerStaffActionsCache pushBack _actionId;
                    };
                };
            };
        } forEach _assignedRoles;

        // Register Global Air Directives (Self-Orders to Company / Free-air Wheel Action)
        private _airActionId = [
            player,
            "<t color='#00FFCC'>[Company Orders] General Directives</t>",
            {
                params ["_target", "_caller", "_actionId"];
                [_target, _caller, _actionId, ["COMPANY_GENERAL", "Full Company"]] call FTCS_fnc_openSubordinateMenu;
            },
            [],
            1.2,
            0.0,
            "isNull cursorObject || {cursorObject distance player > 20}"
        ] call FTCS_fnc_addEngineAction;

        if (_airActionId > -1) then {
            FTCS_PlayerStaffActionsCache pushBack _airActionId;
        };
    };

    // If player is a Platoon Commander, register Platoon Formation self-actions directly on the Lieutenant
    if (_playerRole == "PLATOON_COMMANDER") then {
        private _pltLeaderAction = [
            player,
            "<t color='#00FFCC'>[Platoon Orders] Command Net (Radio / Voice)</t>",
            {
                params ["_target", "_caller", "_actionId"];
                private _pKey = format ["PLT_%1", missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1]];
                [_target, _caller, _actionId, ["PLATOON_SERGEANT", format ["Platoon Leader (%1)", _pKey]]] call FTCS_fnc_openSubordinateMenu;
            },
            [],
            1.5,
            0.0,
            "isNull cursorObject || {cursorObject distance player > 20}"
        ] call FTCS_fnc_addEngineAction;

        private _phaseAction = [
            player,
            "<t color='#FFAA00'>[Operational Phase] Set Doctrinal Phase</t>",
            {
                params ["_target", "_caller", "_actionId"];
                [_target, _caller, _actionId, ["PHASE_TRANSITION", "Operational Phase"]] call FTCS_fnc_openSubordinateMenu;
            },
            [],
            1.4,
            0.0,
            "isNull cursorObject || {cursorObject distance player > 20}"
        ] call FTCS_fnc_addEngineAction;

        private _tlpAction = [
            player,
            "<t color='#E0BB20'>[Planning] Platoon TLP & Mission Prep</t>",
            {
                params ["_target", "_caller", "_actionId"];
                [_target, _caller, _actionId, ["TLP_PLANNING", "Pre-Mission TLP"]] call FTCS_fnc_openSubordinateMenu;
            },
            [],
            1.3,
            0.0,
            "isNull cursorObject || {cursorObject distance player > 20}"
        ] call FTCS_fnc_addEngineAction;
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
                    [_squadLeader, _pltKey] call _fnc_addPlatoonHQActions;
                };

                // In multi-team Platoon HQ, check tacticalTeams (Team 1 = Command, Team 2 = Support)
                private _tacticalTeamsHQ = _sqdData getOrDefault ["tacticalTeams", createHashMap];
                {
                    private _tKey = _x;
                    private _tData = _y;
                    private _tGroup = _tData getOrDefault ["group", grpNull];
                    if (!isNull _tGroup) then {
                        {
                            private _soldier = _x;
                            if (!isNull _soldier && {_soldier != player} && {alive _soldier} && {side _soldier == _playerSide}) then {
                                private _unitVar = vehicleVarName _soldier;
                                private _upVar = toUpper _unitVar;
                                
                                if (_upVar find "RADIO" >= 0 || _upVar find "RTO" >= 0) then {
                                    [_soldier, "RADIO"] call _fnc_addSpecialAction;
                                } else {
                                    if (_upVar find "SERGEANT" >= 0 || _upVar find "SGT" >= 0) then {
                                        [_soldier, _pltKey] call _fnc_addPlatoonSergeantActions;
                                    } else {
                                        private _menu = [_unitVar] call _fnc_resolveRoleMenu;
                                        if (_menu != "" && _menu != "STAFF") then {
                                            [_soldier, _menu] call _fnc_addSpecialAction;
                                        };
                                    };
                                };
                            };
                        } forEach (units _tGroup);
                    };
                } forEach _tacticalTeamsHQ;

                if (!isNull _squadGroup) then {
                    {
                        private _soldier = _x;
                        if (!isNull _soldier && {_soldier != player} && {alive _soldier} && {side _soldier == _playerSide}) then {
                            private _unitVar = vehicleVarName _soldier;
                            private _upVar = toUpper _unitVar;
                            
                            // Explicit role mapping: RTO gets RADIO menu, not Platoon Sergeant HQ actions
                            if (_upVar find "RADIO" >= 0 || _upVar find "RTO" >= 0) then {
                                [_soldier, "RADIO"] call _fnc_addSpecialAction;
                            } else {
                                if (_upVar find "SERGEANT" >= 0 || _upVar find "SGT" >= 0) then {
                                    [_soldier, _pltKey] call _fnc_addPlatoonSergeantActions;
                                } else {
                                    private _menu = [_unitVar] call _fnc_resolveRoleMenu;
                                    if (_menu != "" && _menu != "STAFF") then {
                                        [_soldier, _menu] call _fnc_addSpecialAction;
                                    };
                                };
                            };
                        };
                    } forEach (units _squadGroup);
                };
            } else {
                // Standard Combat Squads: Direct Order when looking at the Squad Leader
                if (!isNull _squadLeader && {_squadLeader != player}) then {
                    private _sqdName = _sqdData getOrDefault ["name", _sqdId];
                    private _sqdCache = format ["%1_SQUAD_ORDERS", _squadLeader];
                    
                    if (!(_sqdCache in FTCS_AssignedActionsCache)) then {
                        FTCS_AssignedActionsCache pushBack _sqdCache;
                        
                        [
                            _squadLeader,
                            format ["<t color='#00BFFF'>[Orders] %1 Leader</t>", _sqdName],
                            {
                                params ["_target", "_caller", "_actionId", "_arguments"];
                                _arguments params ["_sName"];
                                [_target, _caller, _actionId, ["SQUAD", _sName]] call FTCS_fnc_openSubordinateMenu;
                            },
                            [_sqdName],
                            2.0,
                            60.0,
                            "cursorObject == _target"
                        ] call FTCS_fnc_addEngineAction;
                    };
                };

                if (!isNull _squadGroup) then {
                    {
                        private _soldier = _x;
                        if (!isNull _soldier && {_soldier != player} && {alive _soldier} && {side _soldier == _playerSide}) then {
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
                private _teamKey = _x;
                private _teamData = _y;
                private _teamGroup = _teamData getOrDefault ["group", grpNull];
                private _teamName = _teamData getOrDefault ["name", _teamKey];
                
                // Do not assign generic combat Team Orders to Platoon HQ sub-teams (e.g. Command Element / Support Element)
                private _isPlatoonHQTeam = (_sqdId find "_0" >= 0);

                if (!isNull _teamGroup && {!_isPlatoonHQTeam}) then {
                    private _teamLeader = leader _teamGroup;
                    if (!isNull _teamLeader && {_teamLeader != player}) then {
                        private _teamCache = format ["%1_TEAM_ORDERS", _teamLeader];
                        if (!(_teamCache in FTCS_AssignedActionsCache)) then {
                            FTCS_AssignedActionsCache pushBack _teamCache;
                            
                            [
                                _teamLeader,
                                format ["<t color='#FFA500'>[Team Orders] %1</t>", _teamName],
                                {
                                    params ["_target", "_caller", "_actionId", "_arguments"];
                                    _arguments params ["_tName"];
                                    [_target, _caller, _actionId, ["TEAM", _tName]] call FTCS_fnc_openSubordinateMenu;
                                },
                                [_teamName],
                                1.8,
                                30.0,
                                "cursorObject == _target"
                            ] call FTCS_fnc_addEngineAction;
                        };
                    };

                    {
                        private _soldier = _x;
                        if (!isNull _soldier && {_soldier != player} && {alive _soldier} && {side _soldier == _playerSide}) then {
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

diag_log format ["FTCS: Unit interactions initialized successfully with native commandingMenu architecture (Player Role: %1, Platoon ID: %2).", _playerRole, _playerPlatoonID];
true;
