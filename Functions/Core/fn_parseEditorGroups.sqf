/*
    ================================================================================
    File: fn_parseEditorGroups.sqf
    Module: Ctrl_Groups
    Author: FTCS Team
    Description: Scans editor-placed groups, vehicles, and individual HQ/medical units, 
                 parsing their variable names following the FTCS naming convention. 
                 Supports flexible multi-team combat squads (Team 1, Team 2, Team 3, Team 4) 
                 and flexible Platoon HQ sub-teams placed as separate Arma 3 groups, and maps 
                 them generically into FTCS_Company_Data.

    --------------------------------------------------------------------------------
    EDITOR (3DEN) NAMING CONVENTION / CONVENCIÓN DE NOMBRES EN EL EDITOR:
    --------------------------------------------------------------------------------
    Category / Type            | Naming Convention (VarName) | Example            | Description
    ---------------------------|-----------------------------|--------------------|----------------------------------------
    Company HQ Group           | SQUAD_0_0 (or SQD_0_0)      | SQUAD_0_0          | Company Headquarters Group container
    Platoon HQ Group           | SQUAD_<Platoon>_0           | SQUAD_1_0          | Platoon Leadership Group container
    Platoon HQ Sub-Team        | SQUAD_<Platoon>_0_TEAM_X    | SQUAD_1_0_TEAM_1   | Platoon HQ Sub-Team (Team 1, Team 2, Team 3+)
    Regular Squad (Single Grp) | SQUAD_<Platoon>_<Squad>     | SQUAD_1_1          | Standard Rifle Squad (Unified Group)
    Combat Squad Team (Multi)  | SQUAD_<Platoon>_<Squad>_TEAM_X| SQUAD_1_1_TEAM_1 | Flexible Combat Squad Team (Team 1, 2, 3, 4)
    Squad Transport Vehicle    | VEH_<Platoon>_<Squad>       | VEH_1_1            | Transport Vehicle assigned to squad
    Platoon HQ Transport       | VEH_PLT_<Platoon>           | VEH_PLT_1          | Platoon Commander Transport Vehicle
    Company HQ Transport       | VEH_CO                      | VEH_CO             | Company Commander Transport Vehicle

    --------------------------------------------------------------------------------
    INDIVIDUAL HQ & MEDICAL UNIT ROLE NAMES (VARIABLE NAMES FOR UNITS IN EDEN):
    --------------------------------------------------------------------------------
    Individual unit roles are mapped for Company HQ, Platoon HQ, and Squad Medics.
    
    * Company HQ Roles (SQUAD_0_0):
      - HQ_CO_CAPTAIN       -> Company Commander
      - HQ_XO_LIEUTENANT    -> Executive Officer
      - HQ_FIRST_SERGEANT   -> Company First Sergeant
      - HQ_COMM_SERGEANT    -> Communications / Signal Sergeant
      - HQ_RADIO_OPERATOR   -> Heavy RTO (Backpack Radio)
      - HQ_MESSENGER_1      -> Company Runner / Messenger A
      - HQ_MESSENGER_2      -> Company Runner / Messenger B
      - HQ_MEDIC            -> Company Combat Medic

    * Platoon HQ Roles (SQUAD_X_0) [Indexed per Platoon to avoid variable duplicates]:
      - PLT_<X>_LEADER          -> Platoon Leader (e.g. PLT_1_LEADER)
      - PLT_<X>_SERGEANT       -> Platoon Sergeant (e.g. PLT_1_SERGEANT)
      - PLT_<X>_RADIO_OPERATOR -> Platoon RTO (Handy-Talkie) (e.g. PLT_1_RADIO_OPERATOR)
      - PLT_<X>_RUNNER         -> Platoon Messenger / Runner (e.g. PLT_1_RUNNER)
      - PLT_<X>_MEDIC          -> Platoon Combat Medic (e.g. PLT_1_MEDIC)

    * Squad Support Roles:
      - SQUAD_MEDIC         -> Squad Combat Medic (Assigned inside combat squads)

    --------------------------------------------------------------------------------
    FLEXIBLE PLATOON HQ & MULTI-TEAM COMBAT SQUAD STRUCTURE:
    --------------------------------------------------------------------------------
    When Platoon HQ or combat squads are placed as independent sub-team groups:
      - SQUAD_<Platoon>_0_TEAM_1 / TEAM_2 / TEAM_3       : Platoon HQ flexible sub-teams
      - SQUAD_<Platoon>_<Squad>_TEAM_1 / TEAM_2 / TEAM_3 : Combat squad flexible tactical teams (up to 4 teams)
    The parser automatically merges group references into the squad's 'tacticalTeams' 
    map under their respective uppercase team IDs.

    --------------------------------------------------------------------------------
    CASE-INSENSITIVE ROBUSTNESS: All editor tokens are normalized via toLower 
    during evaluation to prevent parsing failures caused by casing inconsistencies.
    ================================================================================
*/

// Retrieve existing structural data
private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
private _squadsRegistry = FTCS_Company_Data getOrDefault ["squadsRegistry", createHashMap];
private _teamsMap = createHashMap;
private _unassignedGroups = [];
private _hqRolesMap = createHashMap;

// Determine player faction side to restrict scanning securely
private _playerSide = side group player;

/*
    ============================================================================
    HQ & MEDICAL UNIT ROLE SCANNING
    ============================================================================
    Scans units matching player side to find specific command/HQ/medical role 
    designations placed in the editor (case-insensitive token check).
*/
{
    private _unit = _x;
    
    if (side _unit == _playerSide) then {
        private _unitVarName = vehicleVarName _unit;
        
        if (_unitVarName != "") then {
            private _unitTokens = _unitVarName splitString "_";
            if (count _unitTokens >= 2 && {((toLower (_unitTokens select 0)) in ["hq", "plt", "squad", "sqd"])}) then {
                _hqRolesMap set [toUpper _unitVarName, _unit];
                };
        };
    };
} forEach allUnits;

/*
    ============================================================================
    EDITOR GROUP SCANNING VIA MISSIONNAMESPACE
    ============================================================================
    Scans global variables directly to find groups assigned via 3DEN editor 
    variable names (e.g., SQUAD_0_0, SQUAD_1_1, SQD_1_1). This correctly matches 
    groups named in the editor without conflicting with individual unit roles.
*/
{
    private _varName = _x;
    private _val = missionNamespace getVariable _varName;
    
    if (!isNil "_val" && {_val isEqualType grpNull}) then {
        private _group = _val;
        
        // Restrict group parsing strictly to player's side units
        if (side _group == _playerSide) then {
            private _groupVarName = _varName;

            // Parse naming tokens: e.g., "SQUAD_1_1", "SQD_1_1" or "SQUAD_1_1_TEAM_1"
            private _tokens = _groupVarName splitString "_";
            
            // Case-insensitive check for SQUAD or SQD prefix
            if (count _tokens >= 3 && {((toLower (_tokens select 0)) in ["squad", "sqd"])}) then {
                private _pltIndex = parseNumber (_tokens select 1);
                private _sqdIndex = _tokens select 2;
                private _teamSuffix = if (count _tokens >= 4) then { toLower (_tokens select 3) } else { "" };
                
                // Direct 1-to-1 mapping: SQUAD_0_0 -> PLT_0, SQUAD_1_X -> PLT_1, etc.
                private _pltKey = format ["PLT_%1", _pltIndex];
                private _sqdId = format ["SQD_%1_%2", _pltIndex, _sqdIndex];

                // Retrieve doctrinal name cleanly from registry
                private _doctrinalName = _sqdId;
                if (_squadsRegistry get _sqdId isEqualType createHashMap) then {
                    _doctrinalName = (_squadsRegistry get _sqdId) getOrDefault ["name", _sqdId];
                };

                // Special case handling for Company HQ (SQUAD_0_0)
                if (_pltIndex == 0 && _sqdIndex == "0") then {
                    FTCS_Company_Data set ["companyHQ", createHashMapFromArray [
                        ["group", _group],
                        ["name", _doctrinalName],
                        ["units", units _group],
                        ["leader", leader _group],
                        ["assignedRoles", _hqRolesMap]
                    ]];
                } else {
                    // Match squad to the corresponding platoon
                    if (_platoonsMap get _pltKey isEqualType createHashMap) then {
                        private _pltData = _platoonsMap get _pltKey;
                        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
                        
                        // Retrieve or initialize squad container hashmap
                        private _squadData = _parsedSquads getOrDefault [_sqdId, createHashMapFromArray [
                            ["squadId", _sqdId],
                            ["name", _doctrinalName],
                            ["tacticalTeams", createHashMap],
                            ["assignedRoles", _hqRolesMap]
                        ]];

                        // Check if it is a Platoon HQ slot (SQD_X_0)
                        if (_sqdIndex == "0") then {
                            if (_teamSuffix in ["team_1", "team_2", "team_3", "command", "support"]) then {
                                private _upperTeamSuffix = toUpper _teamSuffix;
                                private _tacticalTeams = _squadData getOrDefault ["tacticalTeams", createHashMap];
                                private _teamId = format ["TEAM_%1_0_%2", _pltIndex, _upperTeamSuffix];
                                
                                _tacticalTeams set [_teamId, createHashMapFromArray [
                                    ["teamId", _teamId],
                                    ["type", _upperTeamSuffix],
                                    ["group", _group],
                                    ["units", units _group],
                                    ["leader", leader _group]
                                ]];
                                _squadData set ["tacticalTeams", _tacticalTeams];
                            } else {
                                // Fallback unified Platoon HQ group
                                _squadData set ["group", _group];
                                _squadData set ["name", _doctrinalName];
                                _squadData set ["units", units _group];
                                _squadData set ["leader", leader _group];
                            };
                        } else {
                            // Handle multi-team tactical squads vs single-group/unified squads
                            if (_teamSuffix == "team" && count _tokens >= 5) then {
                                private _teamNum = _tokens select 4;
                                private _upperTeamSuffix = format ["TEAM_%1", _teamNum];
                                private _tacticalTeams = _squadData getOrDefault ["tacticalTeams", createHashMap];
                                private _teamId = format ["TEAM_%1_%2_%3", _pltIndex, _sqdIndex, _upperTeamSuffix];
                                
                                _tacticalTeams set [_teamId, createHashMapFromArray [
                                    ["teamId", _teamId],
                                    ["type", _upperTeamSuffix],
                                    ["group", _group],
                                    ["units", units _group],
                                    ["leader", leader _group]
                                ]];
                                
                                _squadData set ["tacticalTeams", _tacticalTeams];

                                // Set main squad leader to Team 1 leader by default
                                if (_upperTeamSuffix == "TEAM_1" || !("leader" in _squadData)) then {
                                    _squadData set ["leader", leader _group];
                                };
                            } else {
                                // Unified single-group squad (e.g. Mortar Section)
                                _squadData set ["group", _group];
                                _squadData set ["name", _doctrinalName];
                                _squadData set ["units", units _group];
                                _squadData set ["leader", leader _group];
                                _squadData set ["isUnified", true];
                            };
                        };

                        _parsedSquads set [_sqdId, _squadData];
                        _pltData set ["parsedSquads", _parsedSquads];
                    };
                };
            } else {
                // Check for ad-hoc tactical teams (case-insensitive)
                if (count _tokens >= 2 && {((toLower (_tokens select 0)) == "team")}) then {
                    _teamsMap set [_groupVarName, createHashMapFromArray [
                        ["name", _groupVarName],
                        ["group", _group],
                        ["units", units _group]
                    ]];
                } else {
                    // Collect unassigned or custom groups not matching naming rules
                    _unassignedGroups pushBack _group;
                };
            };
        };
    };
} forEach (allVariables missionNamespace);

// Parse editor-placed vehicles matching transport convention (case-insensitive)
private _vehiclesMap = createHashMap;
{
    private _veh = _x;
    if (side _veh == _playerSide) then {
        private _vehVarName = vehicleVarName _veh;
        
        if (_vehVarName != "") then {
            private _vehTokens = _vehVarName splitString "_";
            if (count _vehTokens >= 2 && {((toLower (_vehTokens select 0)) == "veh")}) then {
                _vehiclesMap set [_vehVarName, createHashMapFromArray [
                    ["vehicle", _veh],
                    ["crew", crew _veh]
                ]];
            };
        };
    };
} forEach vehicles;

// Inject parsed assets back into the general company structure
FTCS_Company_Data set ["teams", _teamsMap];
FTCS_Company_Data set ["unassignedGroups", _unassignedGroups];
FTCS_Company_Data set ["editorVehicles", _vehiclesMap];
FTCS_Company_Data set ["hqRoles", _hqRolesMap];

// Detect player command scope and level dynamically
private _playerRole = "";
private _platoonScope = 0;

private _companyHQ = FTCS_Company_Data getOrDefault ["companyHQ", createHashMap];
private _hqAssignedRoles = _companyHQ getOrDefault ["assignedRoles", createHashMap];
private _coCaptain = _hqAssignedRoles getOrDefault ["HQ_CO_CAPTAIN", objNull];

if (!isNull _coCaptain && {_coCaptain == player}) then {
    _playerRole = "COMPANY_COMMANDER";
} else {
    // Check if player is any Platoon Leader (PLT_X_LEADER)
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    {
        private _pltKey = _x;
        private _pltData = _y;
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
        private _pltIndex = parseNumber ((_pltKey splitString "_") select 1);
        private _pltHqId = format ["SQD_%1_0", _pltIndex];
        
        if (_parsedSquads get _pltHqId isEqualType createHashMap) then {
            private _sqdData = _parsedSquads get _pltHqId;
            private _assignedRoles = _sqdData getOrDefault ["assignedRoles", createHashMap];
            private _pltLeaderVar = format ["PLT_%1_LEADER", _pltIndex];
            private _pltLeaderObj = _assignedRoles getOrDefault [_pltLeaderVar, objNull];
            
            if (!isNull _pltLeaderObj && {_pltLeaderObj == player}) then {
                _playerRole = "PLATOON_COMMANDER";
                _platoonScope = _pltIndex;
            };
        };
    } forEach _platoonsMap;
};

// Fallback if no specific EDEN variable match but player is group leader of an HQ slot
if (_playerRole == "") then {
    if (leader (group player) == player) then {
        _playerRole = "INDEPENDENT_COMMANDER";
    } else {
        _playerRole = "SOLDIER";
    };
};

FTCS_Player_Command_Scope = createHashMapFromArray [
    ["role", _playerRole],
    ["platoonID", _platoonScope]
];

// Log success in backend
diag_log format ["FTCS: Editor groups parsed. Player Command Scope detected -> Role: %1, Platoon ID: %2", _playerRole, _platoonScope];
true;