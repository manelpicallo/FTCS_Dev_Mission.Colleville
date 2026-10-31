/*
    File: fn_applyDoctrine.sqf
    Module: Ctrl_Doctrines
    Author: FTCS Team
    Description: Clears old structures and builds exact platoons, Company HQ command roles, 
                 Platoon HQ slots (SQD_X_0) with flexible sub-teams (Team 1, Team 2, expandable up to 3+ teams), 
                 combat squads with nested tactical teams (up to 4 teams), and unified support/mortar squads 
                 based on the selected military doctrine (Pure Backend Logic).

    ========================================================================
    FTCS COMPANY DATA STRUCTURE HIERARCHY MAP (Backend HashMap Model)
    ========================================================================
    
    FTCS_Company_Data (HashMap)
    ├── "companyID"        -> STRING ("CO_A", "CO_E", etc.)
    ├── "isMechanized"     -> BOOLEAN (true/false)
    ├── "transportAsset"   -> STRING (Vehicle class or "")
    ├── "selectedIDs"      -> ARRAY (["ALL"])
    ├── "selectedType"     -> STRING ("COMPANY")
    ├── "squadsRegistry"   -> HashMap (Squad ID -> Squad Data HashMap)
    └── "platoons"         -> HashMap (Platoon ID -> Platoon Data HashMap)
          │
          ├── "PLT_0" (Company HQ - Flexible Sub-Teams Architecture)
          │     ├── "name"           -> "Company HQ"
          │     ├── "isMechanized"   -> false
          │     ├── "transportAsset" -> ""
          │     └── "teams"          -> HashMap (Team ID -> Team Data HashMap):
          │           ├── "SQD_0_0_TEAM_1" -> [name: "Command Element", assignedRoles: [CO_CAPTAIN, XO_LIEUTENANT, FIRST_SERGEANT]]
          │           ├── "SQD_0_0_TEAM_2" -> [name: "Signals & Liaison", assignedRoles: [COMM_SERGEANT, RADIO_OPERATOR, MESSENGER_1, MESSENGER_2]]
          │           └── "SQD_0_0_TEAM_3" -> [name: "Medical & Support", assignedRoles: [COMPANY_MEDIC, VEHICLE_MECHANIC]]
          │
          └── "PLT_1" (Example: 1st Platoon)
                ├── "name"           -> "1st Airborne Platoon"
                ├── "isMechanized"   -> false
                ├── "transportAsset" -> ""
                └── "squads"         -> ARRAY of Squad IDs / Platoon HQ Slots:
                      │
                      ├── "SQD_1_0" (Platoon Leadership HQ Slot with flexible sub-teams)
                      │     ├── Team 1 (Command Element: Platoon Leader, Platoon RTO)
                      │     └── Team 2 (Support Element: Platoon Sergeant, Platoon Runner, Platoon Medic)
                      │
                      ├── "SQD_1_1" (1st Rifle Squad - HashMap in squadsRegistry)
                      │     ├── "name"        -> "1st Rifle Squad"
                      │     ├── "platoonID"   -> "PLT_1"
                      │     └── "teams"       -> HashMap (Team ID -> Team Data HashMap):
                      │           ├── "SQD_1_1_TEAM_1" -> [name: "Scout Team", parentSquad: "SQD_1_1", type: "TEAM_1", tacticalRole: "ASSAULT", members: []]
                      │           ├── "SQD_1_1_TEAM_2" -> [name: "Rifle Team A", parentSquad: "SQD_1_1", type: "TEAM_2", tacticalRole: "ASSAULT", members: []]
                      │           ├── "SQD_1_1_TEAM_3" -> [name: "Rifle Team B", parentSquad: "SQD_1_1", type: "TEAM_3", tacticalRole: "ASSAULT", members: []]
                      │           └── "SQD_1_1_TEAM_4" -> [name: "BAR Support Team", parentSquad: "SQD_1_1", type: "TEAM_4", tacticalRole: "SUPPORT", members: []]
                      │
                      └── "SQD_1_4" (Mortar Section - Unified Group without sub-teams)
                            ├── "name"        -> "60mm Mortar Squad"
                            ├── "platoonID"   -> "PLT_1"
                            └── "isUnified"   -> true
    ========================================================================
*/

params ["_doctrineInput", ["_companyLetter", "A"]];

// Resolve the doctrine template. Two input modes (data-driven + legacy):
// - HashMap: a self-contained doctrine data file (Doctrines\Data\*.sqf) loaded
//   by the composition conversion tool. All organizational structure is embedded
//   in the file itself; no lookup in FTCS_Doctrines is performed.
// - String: a legacy doctrine key resolved against the old hardcoded registry
//   FTCS_Doctrines (Method 1: predefined editor-variable units). Kept for
//   backwards compatibility only.
private _doctrine = _doctrineInput;
private _doctrineKey = "";
if (_doctrineInput isEqualType "") then {
    _doctrineKey = _doctrineInput;
    _doctrine = FTCS_Doctrines get _doctrineKey;
    if (isNil "_doctrine") exitWith { diag_log "FTCS Error: Invalid doctrine selected."; };
} else {
    _doctrineKey = _doctrine getOrDefault ["doctrineID", "UNKNOWN"];
};

// 1. Save choices to global configuration
FTCS_Config set ["activeDoctrine", _doctrineKey];
FTCS_Config set ["companyLetter", _companyLetter];

// Robust retrieval supporting both key formats across different doctrines
private _platoonNames = _doctrine getOrDefault ["platoons", _doctrine getOrDefault ["platoonNames", []]];
private _squadsCount = _doctrine getOrDefault ["squadsPerPlatoon", 3];
private _isMechanized = _doctrine getOrDefault ["isMechanized", false];
private _transportAsset = _doctrine getOrDefault ["transportAsset", ""];

// Fallback for squad names/types, HQ roles, and flexible team structures across doctrines
private _squadNamesPool = _doctrine getOrDefault ["squadNames", _doctrine getOrDefault ["squadTypes", ["Squad 1", "Squad 2", "Squad 3", "Squad 4"]]];
// Per-squad semantic designations embedded in self-contained doctrine data files
// (composition Method 2): "SQD_X_Y" -> "1st Rifle Squad", "Mortar Section", etc.
// Takes precedence over the generic squadTypes pool; missing entries fall back to it.
private _squadDesignations = _doctrine getOrDefault ["squadDesignations", createHashMap];
private _companyHQRoles = _doctrine getOrDefault ["companyHQRoles", []];
private _teamStructureNames = _doctrine getOrDefault ["teamStructure", ["Assault Team", "Support Team"]];
private _teamRoles = _doctrine getOrDefault ["teamRoles", []];
private _platoonHQStructure = _doctrine getOrDefault ["platoonHQTeamStructure", [
    ["Command Element", ["PLATOON_LEADER", "PLATOON_RTO"]],
    ["Support Element", ["PLATOON_SERGEANT", "PLATOON_RUNNER", "PLATOON_MEDIC"]]
]];

// 2. Update Company Identifier in structural data
FTCS_Company_Data set ["companyID", format ["CO_%1", _companyLetter]];
FTCS_Company_Data set ["isMechanized", _isMechanized];
FTCS_Company_Data set ["transportAsset", _transportAsset];

// 3. Clear and rebuild Platoons, HQ elements, & Squads dynamically with doctrine names
private _newPlatoonsMap = createHashMap;
private _allSquadsMap = createHashMap; // Global registry for squad and team nodes
private _tacticalPlatoonIndex = 1;

{
    private _pltName = _x;

    // Check if this specific platoon entry represents the Company Headquarters
    if (_pltName == "Company HQ") then {
        /* 
           ================================================================
           COMPANY HQ ELEMENT PARSING (Top-level Command Element)
           ================================================================
           Populates the Company HQ platoon under PLT_0 to match editor 
           naming convention (squad_0_0) and parser logic.
        */
        private _squadsArray = [];
        {
            private _roleId = format ["HQ_%1", _x];
            _squadsArray pushBack _roleId;
        } forEach _companyHQRoles;

        _newPlatoonsMap set ["PLT_0", createHashMapFromArray [
            ["name", _pltName],
            ["squads", _squadsArray],
            ["isMechanized", _isMechanized],
            ["transportAsset", _transportAsset]
        ]];
    } else {
        /* 
           ================================================================
           TACTICAL PLATOONS SETUP (PLT_1, PLT_2, PLT_3...)
           ================================================================
           Ensures tactical platoons start strictly from index 1 to align 
           with editor squad nomenclature (squad_1_0, squad_1_1, etc.).
        */
        private _pltId = format ["PLT_%1", _tacticalPlatoonIndex];
        private _squadsArray = [];

        // Platoon HQ Leadership Slot (SQD_X_0 with flexible sub-teams: Team 1, Team 2, expandable up to 3+)
        private _pltHqId = format ["SQD_%1_0", _tacticalPlatoonIndex];
        _squadsArray pushBack _pltHqId;

        private _pltHqTeamsMap = createHashMap;
        {
            private _teamPair = _x;
            private _teamName = _teamPair select 0;
            private _rolesList = _teamPair select 1;
            private _teamSuffix = format ["TEAM_%1", _forEachIndex + 1];
            private _teamId = format ["SQD_%1_0_%2", _tacticalPlatoonIndex, _teamSuffix];

            _pltHqTeamsMap set [_teamId, createHashMapFromArray [
                ["name", _teamName],
                ["parentSquad", _pltHqId],
                ["type", _teamSuffix],
                ["tacticalRole", "HQ_ELEMENT"],
                ["assignedRoles", _rolesList],
                ["members", []]
            ]];
        } forEach _platoonHQStructure;

        // Register Platoon HQ element explicitly with flexible sub-teams
        _allSquadsMap set [_pltHqId, createHashMapFromArray [
            ["name", "HQ Squad"],
            ["platoonID", _pltId],
            ["teams", _pltHqTeamsMap]
        ]];

        // Generate exact number of combat/support squads for this platoon
        for "_s" from 1 to _squadsCount do {
            
            // Pick doctrine specific squad name if available
            // Priority: explicit per-squad designation from the doctrine file
            // (squadDesignations HashMap, Method 2), then the generic pool
            // (squadTypes/names, Method 1), then positional default.
            private _squadId = format ["SQD_%1_%2", _tacticalPlatoonIndex, _s];
            private _doctrinalSquadName = if (count _squadDesignations > 0 && {_squadId in _squadDesignations}) then {
                _squadDesignations get _squadId
            } else {
                if (_s - 1 < count _squadNamesPool) then {
                    _squadNamesPool select (_s - 1)
                } else {
                    format ["Squad %1", _s]
                }
            };

            // Detect if this squad is a mortar or heavy support section (unified group handling)
            private _isMortarSquad = (toLower _doctrinalSquadName) find "mortar" >= 0 || (toLower _doctrinalSquadName) find "mortero" >= 0;

            if (_isMortarSquad) then {
                /* 
                   ============================================================
                   UNIFIED SUPPORT / MORTAR SQUAD SETUP
                   ============================================================
                   Mortar or heavy support sections bypass multi-team splitting 
                   and operate as a unified single group.
                */
                _allSquadsMap set [_squadId, createHashMapFromArray [
                    ["name", _doctrinalSquadName],
                    ["platoonID", _pltId],
                    ["isUnified", true]
                ]];
            } else {
                /* 
                   ============================================================
                   TACTICAL TEAMS SETUP (Flexible Multi-Team per Rifle Squad)
                   ============================================================
                   Builds nested Teams map dynamically from doctrine team structure 
                   supporting up to 4 teams per squad with specific tactical roles.
                */
                private _teamsMap = createHashMap;
                {
                    private _teamName = _x;
                    private _teamSuffix = format ["TEAM_%1", _forEachIndex + 1];
                    private _teamId = format ["SQD_%1_%2_%3", _tacticalPlatoonIndex, _s, _teamSuffix];

                    // Resolve tactical role from doctrine or assign fallback based on position
                    private _tacticalRole = if (_forEachIndex < count _teamRoles) then {
                        _teamRoles select _forEachIndex
                    } else {
                        if (_forEachIndex == (count _teamStructureNames - 1)) then { "SUPPORT" } else { "ASSAULT" }
                    };

                    _teamsMap set [_teamId, createHashMapFromArray [
                        ["name", _teamName],
                        ["parentSquad", _squadId],
                        ["type", _teamSuffix],
                        ["tacticalRole", _tacticalRole],
                        ["members", []]
                    ]];
                } forEach _teamStructureNames;

                // Register standard rifle squad data object in global registry
                _allSquadsMap set [_squadId, createHashMapFromArray [
                    ["name", _doctrinalSquadName],
                    ["platoonID", _pltId],
                    ["teams", _teamsMap]
                ]];
            };

            _squadsArray pushBack _squadId;
        };

        // Store generated platoon data
        _newPlatoonsMap set [_pltId, createHashMapFromArray [
            ["name", _pltName],
            ["squads", _squadsArray],
            ["isMechanized", _isMechanized],
            ["transportAsset", _transportAsset]
        ]];

        _tacticalPlatoonIndex = _tacticalPlatoonIndex + 1;
    };

} forEach _platoonNames;

// Overwrite company internal data
FTCS_Company_Data set ["platoons", _newPlatoonsMap];
FTCS_Company_Data set ["squadsRegistry", _allSquadsMap];
FTCS_Company_Data set ["selectedIDs", ["ALL"]];
FTCS_Company_Data set ["selectedType", "COMPANY"];

// Log success in backend
diag_log format ["FTCS: Doctrine Applied successfully -> %1 (Company %2, Mechanized: %3)", _doctrineKey, _companyLetter, _isMechanized];
true;