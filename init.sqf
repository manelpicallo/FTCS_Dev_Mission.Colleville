/*
    File: init.sqf
    Author: FTCS Team / Manel P.
    Description: Mission entry point. Initializes FTCS global data structures, 
                 loads doctrine definitions, parses editor groups, and synchronizes 
                 visual group names using a fully encapsulated group registry architecture.
*/

// Prevent duplicate initialization on clients or re-entries
if (!isNil "FTCS_Initialized") exitWith {};

// Ensure internal side cohesion: in Arma 3, RESISTANCE/INDEPENDENT factions must
// explicitly be marked friendly to themselves at mission level so disparate
// independent groups never treat each other as hostiles under default map diplomacy.
resistance setFriend [resistance, 1];

// 1. Initialize Global Backend Data HashMaps
FTCS_Config = createHashMap;
FTCS_Doctrines = createHashMap;

/*
    ===================================================================================
    FTCS COMPREHENSIVE DATA STRUCTURE SPECIFICATION & ARCHITECTURE
    ===================================================================================

    1. FTCS_Company_Data (HashMap) - Master Hierarchy & Selection Core
       -------------------------------------------------------------------------------
       Master core structure governing company deployment and selection:
       - "companyID"    : [String] Tactical company identifier code (e.g., "CO_E").
       - "platoons"     : [HashMap] Hierarchical collection of subordinate platoons [platoonID -> HashMap].
       - "teams"        : [HashMap] Collection of squads and tactical teams [teamID -> HashMap].
       - "selectedIDs"  : [Array of Strings] IDs of groups or elements currently selected 
                          to receive orders (e.g., ["ALL"], ["1squad"], ["Group_0_0"]).
       - "selectedType" : [String] Active tactical scope of the menu or AI ("COMPANY", "PLATOON", "SQUAD", "VEHICLE").

    2. FTCS_Groups_Registry_Table (HashMap) - Master Encapsulated Group Registry
       -------------------------------------------------------------------------------
       Master per-group encapsulated data registry [groupId -> Sub-HashMap]. Centralizes all real-time 
       tactical behavior, state machine properties, geometry, and ORBAT slot allocations agnostic to UI:
       
       Sub-HashMap properties per group:
       * "movingMode"         : [String] Active movement state ("AT_WILL", "FOLLOWING_COMMANDER_REL", "FOLLOWING_COMMANDER_ABS", "HALT", "STOP", "CONVOY").
       * "stance"             : [String] Mandatory tactical stance ("AUTO", "FORCE_UP", "FORCE_MIDDLE", "FORCE_DOWN").
       * "awareMode"          : [String] Alert level and situational awareness ("CARELESS", "SAFE", "AWARE", "COMBAT", "STEALTH").
       * "speed"              : [String] Movement speed limit ("FULL", "NORMAL", "LIMITED").
       * "roe"                : [String] Rules of Engagement ("HOLD_FIRE", "FIRE_AT_WILL", "FIRE_IF_FIRED_UPON").
       * "task"               : [String] Assigned tactical task in progress ("AT_WILL", "MOVING", "SUPPRESSING", "ATTACKING", "WATCHING", "WAITING").
       * "allocationSlot"     : [Scalar] Numerical slot assignment in platoon formations (0, 1, 2, 3...).
       * "formationPosition"  : [Array] Assigned geometric formation slot [Distance, Direction, Leader Object].
       * "relPosition"        : [Array] Current relative position vector or coordinates [Distance, Direction, Reference Leader].

    3. Vehicle and Miscellaneous Mapping Tables
       -------------------------------------------------------------------------------
       - Groups_Vehicle_Names_Table : Logical identifiers and visual names for vehicles/convoys.
    ===================================================================================
*/

FTCS_Company_Data = createHashMapFromArray [
    ["companyID", "CO_E"],
    ["platoons", createHashMap],
    ["teams", createHashMap],
    ["selectedIDs", ["ALL"]],
    ["selectedType", "COMPANY"]
];

// Master fully encapsulated registry table for groups (Model: [groupId -> Sub-HashMap of data, states & geometry])
FTCS_Groups_Registry_Table = createHashMap;

// Vehicle and miscellaneous auxiliary mapping tables
Groups_Vehicle_Names_Table = createHashMap;

// Selection state lists (used by unit/group/vehicle selection actions)
Type_Selected = "INFANTRY";
Selected_list = [];
Selected_Units_list = [];
Selected_Vehicle_list = [];

// 2. Safe Execution Block: Wait until CfgFunctions are fully compiled by the engine
[
    { !isNil "FTCS_fnc_configDoctrines" },
    {
        // Execute once functions are guaranteed to be compiled and ready
        call FTCS_fnc_configDoctrines;

        // 3. Check if mission starts with pre-placed / assigned editor units
        private _hasAssignedUnits = false;
        {
            private _varName = _x;
            if ((toLower _varName) find "squad_" == 0 || (toLower _varName) find "sqd_" == 0) then {
                private _val = missionNamespace getVariable [_varName, objNull];
                if (!isNull _val) exitWith { _hasAssignedUnits = true; };
            };
        } forEach (allVariables missionNamespace);

        if (!_hasAssignedUnits) then {
            private _subordinateCount = count (allUnits select { side _x == side group player && _x != player });
            if (_subordinateCount > 0) then {
                _hasAssignedUnits = true;
            };
        };

        if (_hasAssignedUnits) then {
            // Apply Default Military Doctrine (101st Airborne / Easy Company)
            ["US_AIRBORNE", "E"] call FTCS_fnc_applyDoctrine;

            // 4. Parse editor-placed groups, vehicles, and individual HQ/medical roles
            call FTCS_fnc_parseEditorGroups;

            // 4.1. Initialize Company Command (Isolate Captain)
            call FTCS_fnc_initCompanyCommand;

            // 4.2. Synchronize visual group names in the game engine (Arma 3 setGroupId abstraction)
            // Executed BEFORE registryInit so groupId keys in FTCS_Groups_Registry_Table match final group IDs
            call FTCS_fnc_syncGroupNames;

            // 5. Initialize the Master Encapsulated Group Registry (states, geometry & slots)
            call FTCS_fnc_registryInit;

            // 6. Initialize Context-Sensitive Flat Menus & Interactions
            call FTCS_fnc_initUnitInteractions;

            // 7. Set Global System Initialized Flag
            FTCS_Initialized = true;

            diag_log "FTCS Backend System initialized successfully with editor-placed units.";
        } else {
            // Player starts without assigned units: launch interactive deployment interface over map
            diag_log "FTCS: Player starts without assigned units. Preparing Operational Deployment Interface...";
            
            if (hasInterface) then {
                // Background worker: waits until player object exists, creates temporary player if mission is completely empty
                [] spawn {
                    // 1. Wait until engine initializes the player entity or timeout
                    private _t0 = time;
                    waitUntil {
                        (!isNull player && {alive player}) || 
                        {time - _t0 > 4}
                    };

                    // 2. If mission was started 100% empty (no player entity placed in 3DEN), create a virtual command avatar
                    if (isNull player || {!alive player}) then {
                        diag_log "FTCS: No player unit placed in mission. Creating temporary command entity...";
                        
                        private _grp = createGroup [west, true];
                        private _dummyPos = [1000, 1000, 0];
                        if (count allMapMarkers > 0) then {
                            _dummyPos = getMarkerPos (allMapMarkers select 0);
                        };

                        // Use Spearhead 1944 officer class if available, else vanilla NATO officer
                        private _officerClass = if (isClass (configFile >> "CfgVehicles" >> "SPE_US_101AB_CO")) then {
                            "SPE_US_101AB_CO"
                        } else {
                            "B_Officer_F"
                        };

                        private _tempUnit = _grp createUnit [_officerClass, _dummyPos, [], 0, "NONE"];
                        _tempUnit setVehicleVarName "FTCS_TEMP_PLAYER";
                        missionNamespace setVariable ["FTCS_TEMP_PLAYER", _tempUnit, true];
                        
                        selectPlayer _tempUnit;
                        waitUntil { !isNull player && {alive player} };
                        diag_log "FTCS: Temporary player entity assigned successfully.";
                    };

                    // 3. Add self-action on player to re-open menu if closed
                    player addAction [
                        "<t color='#00FFCC'>[FTCS] Menú de Despliegue Operacional</t>",
                        { [] spawn FTCS_fnc_openDeployMenu; },
                        [],
                        10,
                        false,
                        true,
                        "",
                        "isNil 'FTCS_Initialized' || {!FTCS_Initialized}"
                    ];

                    // 4. Brief delay to ensure UI engine and display systems are ready, then open dialog
                    sleep 0.3;
                    [] spawn FTCS_fnc_openDeployMenu;
                };
            };
        };
    },
    [],
    5.0 // Timeout safeguard (5 seconds max wait)
] call CBA_fnc_waitUntilAndExecute;