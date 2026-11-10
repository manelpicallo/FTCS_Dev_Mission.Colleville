/*
    ================================================================================
    File: fn_initCommandingMenus.sqf
    Module: Interactions
    Author: FTCS Team
    Description: Defines native engine commanding menus (#USER: commandingMenu)
                 derived from FTCS_Menu_Structure_Reference (Doctrine FM 3-21.8).
                 Menus are dynamically adapted across 3 Operational Phases:
                 - Phase 1: APPROACH PHASE (March & Traveling Formations)
                 - Phase 2: CONTACT LIKELY / OVERWATCH (Bounding & LDA Protocols)
                 - Phase 3: COMBAT, ASSAULT & CONSOLIDATION (Unified Combat & Tactics)
                 - TLP: Pre-Mission / CP Planning Interface
                 Active / Implemented options are active ("1", "1").
                 Pending / Non-implemented options are visible but disabled ("1", "0" = grayed out).
                 Navigable via number keys [1-9] or mouse wheel.
    Language: Strictly English (Rule 7, Rule 11)
    
    +-----------------------------------------------------------------------------+
    |                 FTCS COMMANDING MENUS ARCHITECTURE                          |
    +-----------------------------------------------------------------------------+
    |                                                                             |
    |  [PLATOON SERGEANT NET] (Radio / CP / In-Person)                            |
    |    ├── Phase Transition Submenu (#USER:FTCS_MENU_PhaseTransition) [ACTIVE]  |
    |    │                                                                        |
    |    ├── PHASE 1: APPROACH (DEFAULT)                                          |
    |    │     ├── Platoon Formations (#USER:PlatoonFormations_P1)      [ACTIVE]  |
    |    │     ├── Movement Techniques (#USER:MovementTechniques_P1)    [ACTIVE]  |
    |    │     ├── Route & March Control                                [DISABLED]|
    |    │     └── Weapons Control Status                               [DISABLED]|
    |    │                                                                        |
    |    ├── PHASE 2: OVERWATCH / LDA                                   [DISABLED]|
    |    │     ├── Bounding Overwatch                                   [DISABLED]|
    |    │     ├── Halt & 360 Security                                  [DISABLED]|
    |    │     ├── LDA Crossing Protocols                               [DISABLED]|
    |    │     └── Weapons Readiness                                    [DISABLED]|
    |    │                                                                        |
    |    └── PHASE 3: COMBAT & ASSAULT                                  [DISABLED]|
    |          ├── Platoon-Wide Tactics                                 [DISABLED]|
    |          ├── Select Squad: ALPHA / BRAVO / CHARLIE / WEAPONS      [DISABLED]|
    |          ├── Fire Direction & Area Suppression                    [DISABLED]|
    |          ├── Sustainment & MEDEVAC                                [DISABLED]|
    |          └── Fire Support Coordination                            [DISABLED]|
    |                                                                             |
    |  [SQUAD LEADER DIRECT / VISUAL]                                   [DISABLED]|
    |  [PRE-MISSION / CP]: Platoon Planning & TLP Menu                  [DISABLED]|
    |  [SPECIALISTS]: Field Radio, Runner, Medic                        [DISABLED]|
    +-----------------------------------------------------------------------------+
    ================================================================================
*/

// Set default operational phase per platoon (FTCS_Platoon_Phase_1..4, Default: Phase 0 DEPLOYMENT/INSPECTION)
for "_i" from 1 to 4 do {
    if (isNil (format ["FTCS_Platoon_Phase_%1", _i])) then {
        missionNamespace setVariable [format ["FTCS_Platoon_Phase_%1", _i], 0];
    };
};
FTCS_CurrentPhase = missionNamespace getVariable ["FTCS_Platoon_Phase_1", 0];

// Default platoon follow mode (FOLLOWING_COMMANDER_REL vs FOLLOWING_COMMANDER_ABS)
if (isNil "FTCS_Platoon_Follow_Mode") then {
    FTCS_Platoon_Follow_Mode = "FOLLOWING_COMMANDER_REL";
};

// =============================================================================
// 0. OPERATIONAL PHASE TRANSITION SUBMENU (ACTIVE: a1, a2, a3)
// =============================================================================
FTCS_MENU_PhaseTransition = [
    ["Operational Phase Transition", false],
    ["1. Set Phase 1: APPROACH (Traveling & Security)", [2], "", -5, [["expression", "['SET_PHASE_1'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Set Phase 2: CONTACT LIKELY / OVERWATCH (Bounding / LDA)", [3], "", -5, [["expression", "['SET_PHASE_2'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Set Phase 3: COMBAT & ASSAULT (Fire & Maneuver)", [4], "", -5, [["expression", "['SET_PHASE_3'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// Shared Tactical Stance Submenu (ACTIVE)
FTCS_MENU_SquadStance_Common = [
    ["Tactical Stance", false],
    ["1. Auto Stance (Combat Default)", [2], "", -5, [["expression", "['STANCE_AUTO'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Force Stand Up (Rush / Fast Bound)", [3], "", -5, [["expression", "['STANCE_UP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Force Crouch (Cautious Advance)", [4], "", -5, [["expression", "['STANCE_MIDDLE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Force Prone (Take Cover / Pin Down)", [5], "", -5, [["expression", "['STANCE_DOWN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Follow Commander Stance (Mirror)", [6], "", -5, [["expression", "['STANCE_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// Shared Platoon Tactical Stance Submenu (ACTIVE)
FTCS_MENU_PlatoonStance_Common = [
    ["Platoon Tactical Stance", false],
    ["1. Auto Stance (Combat Default)", [2], "", -5, [["expression", "['PLT_STANCE_AUTO'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Force Stand Up (Rush / Fast Bound)", [3], "", -5, [["expression", "['PLT_STANCE_UP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Force Crouch (Cautious Advance)", [4], "", -5, [["expression", "['PLT_STANCE_MIDDLE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Force Prone (Take Cover / Pin Down)", [5], "", -5, [["expression", "['PLT_STANCE_DOWN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Follow Commander Stance (Mirror)", [6], "", -5, [["expression", "['PLT_STANCE_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// =============================================================================
// FASE 1: APPROACH PHASE (Desplazamiento / Sin Contacto)
// =============================================================================

// Submenu: Centralized Squad Selection for Remote Directives via Platoon Sergeant
FTCS_MENU_SquadSelect_Common = [
    ["Direct Squad Command", false],
    ["1. 1st Rifle Squad (Alpha)", [2], "", -5, [["expression", "['SELECT_SQUAD_1'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. 2nd Rifle Squad (Bravo)", [3], "", -5, [["expression", "['SELECT_SQUAD_2'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. 3rd Rifle Squad (Charlie)", [4], "", -5, [["expression", "['SELECT_SQUAD_3'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. 4th Squad / Weapons Section (Delta / Mortars)", [5], "", -5, [["expression", "['SELECT_SQUAD_4'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.1 Platoon Formations Submenu (Phase 1 & Phase 2) - [ACTIVE]
FTCS_MENU_PlatoonFormations_P1 = [
    ["Platoon Formations", false],
    ["1. Platoon Column (Trail / Road March)", [2], "", -5, [["expression", "['PLT_FORM_COLUMN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Platoon Wedge (Security / Cross-country)", [3], "", -5, [["expression", "['PLT_FORM_WEDGE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Platoon Vee (Flexible Front)", [4], "", -5, [["expression", "['PLT_FORM_VEE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Platoon Line (Full Frontage Assault)", [5], "", -5, [["expression", "['PLT_FORM_LINE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Platoon Echelon Right (Right Flank Refused)", [6], "", -5, [["expression", "['PLT_FORM_ECHELON_RIGHT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Platoon Echelon Left (Left Flank Refused)", [7], "", -5, [["expression", "['PLT_FORM_ECHELON_LEFT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["7. Platoon File (Dense Vegetation / Narrow Trail)", [8], "", -5, [["expression", "['PLT_FORM_FILE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["8. Adopt Ground Layout (Lock Positions)", [9], "", -5, [["expression", "['PLT_FORM_LOCK_GROUND'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["9. Follow Mode: Relative (Turn with Leader)", [10], "", -5, [["expression", "['PLT_MODE_RELATIVE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["10. Follow Mode: Absolute (Fixed Compass)", [11], "", -5, [["expression", "['PLT_MODE_ABSOLUTE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.2 Movement Techniques Submenu (Phase 1) - [ACTIVE]
FTCS_MENU_MovementTechniques_P1 = [
    ["Movement Techniques", false],
    ["1. Traveling (Standard March Speed)", [2], "", -5, [["expression", "['TECH_TRAVELING'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Traveling Overwatch (Cautious Advance)", [3], "", -5, [["expression", "['TECH_TRAVELING_OVERWATCH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.3 Route & March Control Submenu (Phase 1) - [ACTIVE]
FTCS_MENU_RouteControl_P1 = [
    ["Route & March Control", false],
    ["1. Normal March Pace", [2], "", -5, [["expression", "['PACE_NORMAL'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Limited (Slow / Patrol) Pace", [3], "", -5, [["expression", "['PACE_LIMITED'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Fast / Rush Pace", [4], "", -5, [["expression", "['PACE_FAST'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Road / Trail March", [5], "#USER:FTCS_MENU_RoadMarchLayout", -5, [["expression", ""]], "1", "1"],
    ["5. Check Route & Checkpoints on Map", [6], "", -5, [["expression", "['CHECK_WAYPOINT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.3.1 Road March Column Layout Submenu (Phase 1) - [ACTIVE]
// Staggered: forms the road column. Compact: requires an already-formed road
// march column (validated at runtime in applyCommandToTarget). Left/Right single
// shoulder columns are also fresh-orderable: ROAD_COLUMN_LEFT/RIGHT deploy the
// full road pipeline with a forced side without any staggered pre-order.
FTCS_MENU_RoadMarchLayout = [
    ["Road March Column Layout", false],
    ["1. Staggered Column (Dual Shoulder)", [2], "", -5, [["expression", "['PLT_ROAD_COLUMN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Leader Trail Column (Follow My Track)", [3], "", -5, [["expression", "['PLT_TRAIL_COLUMN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Compact Column (Close Ranks)", [4], "", -5, [["expression", "['PLT_ROAD_COMPACT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "0"], // enabled at runtime while a road column is active (fn_openSubordinateMenu)
    ["4. Column Left (Single Shoulder)", [5], "", -5, [["expression", "['ROAD_COLUMN_LEFT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "0"],
    ["5. Column Right (Single Shoulder)", [6], "", -5, [["expression", "['ROAD_COLUMN_RIGHT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "0"],
    ["6. Push Out From Road (+3m)", [7], "", -5, [["expression", "['ROAD_EDGE_PUSH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "0"],
    ["7. Pull In To Road (-3m)", [8], "", -5, [["expression", "['ROAD_EDGE_PULL'] call FTCS_fnc_applyCommandToTarget;"]], "1", "0"],
    ["8. Return To Road (Reset)", [9], "", -5, [["expression", "['ROAD_EDGE_RESET'] call FTCS_fnc_applyCommandToTarget;"]], "1", "0"]
];

// 1.4 Weapons Control Status Submenu (Phase 1) - [ACTIVE]
FTCS_MENU_WeaponsControl_P1 = [
    ["Weapons Control Status", false],
    ["1. Weapons Hold (Do Not Fire)", [2], "", -5, [["expression", "['WCS_HOLD'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Weapons Tight (Confirmed Hostile Only)", [3], "", -5, [["expression", "['WCS_TIGHT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.5 Master Platoon Sergeant Menu (Phase 1: Approach)
FTCS_MENU_Sgt_Phase1 = [
    ["Platoon Command (Phase 1: Approach)", false],
    ["1. Operational Phase Transition", [2], "#USER:FTCS_MENU_PhaseTransition", -5, [["expression", ""]], "1", "1"],
    ["2. Platoon Formations", [3], "#USER:FTCS_MENU_PlatoonFormations_P1", -5, [["expression", ""]], "1", "1"],
    ["3. Movement Techniques", [4], "#USER:FTCS_MENU_MovementTechniques_P1", -5, [["expression", ""]], "1", "1"],
    ["4. Tactical Stance", [5], "#USER:FTCS_MENU_PlatoonStance_Common", -5, [["expression", ""]], "1", "1"],
    ["5. Route & March Control", [6], "#USER:FTCS_MENU_RouteControl_P1", -5, [["expression", ""]], "1", "1"],
    ["6. Weapons Control Status", [7], "#USER:FTCS_MENU_WeaponsControl_P1", -5, [["expression", ""]], "1", "1"],
    ["7. Regroup on Commander", [8], "", -5, [["expression", "['PLT_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["8. Platoon Readiness SITREP", [9], "", -5, [["expression", "['PLT_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["9. Platoon Scout Directives", [10], "#USER:FTCS_MENU_Platoon_Scouts", -5, [["expression", ""]], "1", "1"],
    ["10. Squad Directives -> [Select Squad]", [11], "#USER:FTCS_MENU_SquadSelect_Common", -5, [["expression", ""]], "1", "1"]
];

// 1.6 Squad Formations Submenu (Phase 1) - [ACTIVE]
FTCS_MENU_SquadFormations_P1 = [
    ["Squad Formations", false],
    ["1. Squad Column", [2], "", -5, [["expression", "['SQD_FORM_COLUMN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Squad Line", [3], "", -5, [["expression", "['SQD_FORM_LINE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Squad File", [4], "", -5, [["expression", "['SQD_FORM_FILE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Squad Wedge", [5], "", -5, [["expression", "['SQD_FORM_WEDGE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.7 Squad Pace & Spacing Submenu (Phase 1) - [ACTIVE]
FTCS_MENU_SquadPace_P1 = [
    ["March Pace & Spacing", false],
    ["1. Standard Pace (Walk)", [2], "", -5, [["expression", "['SQD_PACE_NORMAL'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Quick Pace (Jog)", [3], "", -5, [["expression", "['SQD_PACE_FAST'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Close Interval (5m Spacing)", [4], "", -5, [["expression", "['SQD_SPACING_CLOSE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Open Interval (10m Spacing)", [5], "", -5, [["expression", "['SQD_SPACING_OPEN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.8 Master Squad Leader Menu (Phase 1: Approach) - [ACTIVE]
FTCS_MENU_Squad_Phase1 = [
    ["Squad Directives (Phase 1: Approach)", false],
    ["1. Squad Formations", [2], "#USER:FTCS_MENU_SquadFormations_P1", -5, [["expression", ""]], "1", "1"],
    ["2. March Pace & Spacing", [3], "#USER:FTCS_MENU_SquadPace_P1", -5, [["expression", ""]], "1", "1"],
    ["3. Tactical Stance", [4], "#USER:FTCS_MENU_SquadStance_Common", -5, [["expression", ""]], "1", "1"],
    ["4. Scout & Security Screen -> [Deploy / Shift]", [5], "#USER:FTCS_MENU_ScoutScreen_Deploy", -5, [["expression", ""]], "1", "1"],
    ["5. Follow Commander / Rejoin", [6], "", -5, [["expression", "['TASK_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Squad SITREP", [7], "", -5, [["expression", "['SQUAD_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// =============================================================================
// FASE 2: CONTACT LIKELY / OVERWATCH PHASE (Aproximación Cauta / Obstáculos)
// =============================================================================

// 2.1 Bounding Overwatch Submenu (Phase 2) - [ACTIVE]
FTCS_MENU_BoundingOverwatch_P2 = [
    ["Bounding Overwatch", false],
    ["1. Successive Bounds (Alternate)", [2], "", -5, [["expression", "['BOUNDING_SUCCESSIVE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Continuous Bounds", [3], "", -5, [["expression", "['BOUNDING_CONTINUOUS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Cease Bounds & Consolidate", [4], "", -5, [["expression", "['BOUNDING_CEASE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 2.2 LDA Support Squad Selection Submenu (Phase 2) - [ACTIVE]
FTCS_MENU_LDA_SelectSBF = [
    ["Assign Support Squad (SBF Base)", false],
    ["1. Squad Alpha (1st Squad)", [2], "", -5, [["expression", "['LDA_SBF_ALPHA'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Squad Bravo (2nd Squad)", [3], "", -5, [["expression", "['LDA_SBF_BRAVO'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Weapons Section (MG Support)", [4], "", -5, [["expression", "['LDA_SBF_WEAPONS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 2.3 LDA Crossing Squad Selection Submenu (Phase 2) - [ACTIVE]
FTCS_MENU_LDA_SelectCrossing = [
    ["Assign Crossing Squad (Security)", false],
    ["1. Squad Alpha (Point Element)", [2], "", -5, [["expression", "['LDA_CROSS_ALPHA'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Squad Bravo (Assault Element)", [3], "", -5, [["expression", "['LDA_CROSS_BRAVO'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Squad Charlie (Reserve Element)", [4], "", -5, [["expression", "['LDA_CROSS_CHARLIE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 2.4 LDA Crossing Protocols Master Submenu (Phase 2) - [ACTIVE]
FTCS_MENU_LDACrossing_P2 = [
    ["LDA Crossing Protocols", false],
    ["1. Assign Support Squad (SBF Base)", [2], "#USER:FTCS_MENU_LDA_SelectSBF", -5, [["expression", ""]], "1", "1"],
    ["2. Assign Crossing Squad (Security)", [3], "#USER:FTCS_MENU_LDA_SelectCrossing", -5, [["expression", ""]], "1", "1"],
    ["3. Execute Platoon Leapfrog", [4], "", -5, [["expression", "['LDA_LEAPFROG'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 2.5 Weapons Readiness Submenu (Phase 2) - [ACTIVE]
FTCS_MENU_WeaponsReadiness_P2 = [
    ["Weapons Readiness", false],
    ["1. Weapons Tight (Return Fire Only)", [2], "", -5, [["expression", "['WCS_TIGHT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Weapons Free (Engage on Sight)", [3], "", -5, [["expression", "['WCS_FREE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 2.6 Master Platoon Sergeant Menu (Phase 2: Overwatch) - [ACTIVE]
FTCS_MENU_Sgt_Phase2 = [
    ["Platoon Command (Phase 2: Overwatch)", false],
    ["1. Platoon Formations (Trail / Cross-country)", [2], "#USER:FTCS_MENU_PlatoonFormations_P1", -5, [["expression", ""]], "1", "1"],
    ["2. Road / Trail March", [3], "#USER:FTCS_MENU_RoadMarchLayout", -5, [["expression", ""]], "1", "1"],
    ["3. Bounding Overwatch", [4], "#USER:FTCS_MENU_BoundingOverwatch_P2", -5, [["expression", ""]], "1", "1"],
    ["4. Squad & Scout Directives", [5], "#USER:FTCS_MENU_SquadDirectives", -5, [["expression", ""]], "1", "1"],
    ["5. Halt & 360 Security", [6], "", -5, [["expression", "['P2_HALT_360'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Tactical Stance", [7], "#USER:FTCS_MENU_PlatoonStance_Common", -5, [["expression", ""]], "1", "1"],
    ["7. LDA Crossing Protocols", [8], "#USER:FTCS_MENU_LDACrossing_P2", -5, [["expression", ""]], "1", "1"],
    ["8. Weapons Readiness", [9], "#USER:FTCS_MENU_WeaponsReadiness_P2", -5, [["expression", ""]], "1", "1"],
    ["9. Regroup on Commander", [10], "", -5, [["expression", "['PLT_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["10. Operational Phase Transition", [11], "#USER:FTCS_MENU_PhaseTransition", -5, [["expression", ""]], "1", "1"]
];

// Submenu: Squad & Scout Directives hub (Phase 2) - rebuilt dynamically in
// fn_openSubordinateMenu with one entry per doctrinal squad plus the scouts row.
FTCS_MENU_SquadDirectives = [
    ["Squad & Scout Directives", false],
    ["1. Scouts Directive", [2], "#USER:FTCS_MENU_Platoon_Scouts", -5, [["expression", ""]], "1", "1"],
    ["2. [Squad 1]", [3], "#USER:FTCS_MENU_SquadOrders_1", -5, [["expression", ""]], "1", "1"],
    ["3. [Squad 2]", [4], "#USER:FTCS_MENU_SquadOrders_2", -5, [["expression", ""]], "1", "1"],
    ["4. [Squad 3]", [5], "#USER:FTCS_MENU_SquadOrders_3", -5, [["expression", ""]], "1", "1"],
    ["5. [Squad 4]", [6], "#USER:FTCS_MENU_SquadOrders_4", -5, [["expression", ""]], "1", "1"]
];

// Squad Orders submenus (Phase 2, one per doctrinal squad slot 1-4) - rebuilt
// dynamically in fn_openSubordinateMenu. Row 1 = target acquisition (always on);
// rows 2-5 = movement orders (visible only with a marked target); rows 6-8 =
// in-formation orders (always on); row 9 = rejoin (highlighted when detached).
// Target-state-aware row enables: the squad-orders menu is rebuilt EVERY time
// it is opened (the reopen after capture calls this section again), so the flags
// are computed PER SQUAD inside the build loop below:
// - WITH a captured target: the Move rows (2-4) enable, the formation-maneuver
//   rows (5-8) disable (a designated target supersedes free-form maneuvering).
// - WITHOUT a target: the inverse. Rows 1, 9, 10 are ALWAYS enabled.
// Per-squad gating: a squad owns a target when ANY of its team registry entries
// carries a "squadTarget" - one squad's capture never enables another squad's
// movement rows. Row 1 (Mark Target) is always enabled for every squad.
private _squadHasTarget = {
    params ["_slotIdx"];
    private _pltIdL = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    private _pltKeyL = format ["PLT_%1", _pltIdL];
    private _pltMapL = (missionNamespace getVariable ["FTCS_Company_Data", createHashMap]) getOrDefault ["platoons", createHashMap];
    private _parsedSqL = (_pltMapL getOrDefault [_pltKeyL, createHashMap]) getOrDefault ["parsedSquads", createHashMap];
    private _sqdKeyL = format ["SQD_%1_%2", _pltIdL, _slotIdx];
    private _sqdDataL = _parsedSqL getOrDefault [_sqdKeyL, createHashMap];
    private _teamsL = _sqdDataL getOrDefault ["tacticalTeams", createHashMap];
    if (count _teamsL == 0) then { _teamsL = _sqdDataL getOrDefault ["teams", createHashMap]; };
    private _has = false;
    {
        private _grpL = (_y) getOrDefault ["group", grpNull];
        if (!isNull _grpL) then {
            private _eL = FTCS_Groups_Registry_Table getOrDefault [groupId _grpL, createHashMap];
            if (count (_eL getOrDefault ["squadTarget", []]) >= 8) exitWith { _has = true; };
        };
    } forEach _teamsL;
    // Legacy fallback: the squad-level group entry when no sub-team resolved
    if (!_has) then {
        private _gSL = _sqdDataL getOrDefault ["group", grpNull];
        if (!isNull _gSL) then {
            private _eSL = FTCS_Groups_Registry_Table getOrDefault [groupId _gSL, createHashMap];
            if (count (_eSL getOrDefault ["squadTarget", []]) >= 8) then { _has = true; };
        };
    };
    _has
};

for "_i" from 1 to 4 do {
    // Per-squad enable state: rows 2-4 (Move) need THIS squad's own target;
    // rows 5-8 are the inverse gate. Row 1, 9, 10 always enabled. The row
    // template lives INSIDE the loop because the enable flags differ per squad.
    private _hasTgt = [_i] call _squadHasTarget;
    private _moveEnable = if (_hasTgt) then { "1" } else { "0" };
    private _formEnable = if (_hasTgt) then { "0" } else { "1" };

    private _squadOrderRows = [
        ["1. Mark Target (aim & confirm)", [2], "", -5, [["expression", "['SQD_TARGET_MARK_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
        ["2. Move to Target (Hold)", [3], "", -5, [["expression", "['SQD_MOVE_ADVANCE_DETACH_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", _moveEnable],
        ["3. Move and Defend Position", [4], "", -5, [["expression", "['SQD_MOVE_ADVANCE_DEFEND_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", _moveEnable],
        ["4. Move & Keep Formation", [5], "", -5, [["expression", "['SQD_MOVE_ADVANCE_KEEP_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", _moveEnable],
        ["5. Hold Current Position / Defend", [6], "", -5, [["expression", "['SQD_DEFEND_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", _formEnable],
        ["6. Open Flank Right", [7], "", -5, [["expression", "['SQD_FLANK_OPEN_R_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", _formEnable],
        ["7. Open Flank Left", [8], "", -5, [["expression", "['SQD_FLANK_OPEN_L_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", _formEnable],
        ["8. Fall Back (+15m)", [9], "", -5, [["expression", "['SQD_FALL_BACK_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", _formEnable],
        ["9. Rejoin Platoon Formation", [10], "", -5, [["expression", "['SQD_REJOIN_FORMATION_%1'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
        ["10. Squad Leader Menu (full)", [11], "#USER:FTCS_MENU_Squad_Phase2", -5, [["expression", ""]], "1", "1"]
    ];

    private _menuArr = [[format ["Squad Orders - Squad %1", _i], false]];
    {
        // Interpolate the squad index into every expression token of the row.
        // Row structure: [label, keys, submenu, priority, EVENTS, visible, enabled]
        // where EVENTS = [["expression", code]] (TWO elements: event name + code).
        // The code lives at EVENTS select 0 select 1 - NOT select 0 (that is the
        // literal word "expression"). Writing back a one-element event breaks the
        // row and blanks the whole menu.
        private _row = +_x;
        private _events = _row select 4;                    // [["expression", code]]
        private _code = (_events select 0) select 1;        // the call string
        private _formattedCode = format [_code, _i];
        _row set [4, [["expression", _formattedCode]]];
        _menuArr pushBack _row;
    } forEach _squadOrderRows;
    diag_log format ["[FTCS][MENUS] SquadOrders_%1 built: %2 rows (sample expr: %3).", _i, count _menuArr, ((_menuArr select 1) select 4 select 0) select 0];
    missionNamespace setVariable [format ["FTCS_MENU_SquadOrders_%1", _i], _menuArr];
};

// Submenu: Platoon-Wide Scout & Screen Deployments - [ACTIVE]
FTCS_MENU_Platoon_Scouts = [
    ["Platoon Scout Directives", false],
    ["1. Deploy Left Flank Screen", [2], "", -5, [["expression", "['PLT_SCOUT_FLANK_L'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Deploy Right Flank Screen", [3], "", -5, [["expression", "['PLT_SCOUT_FLANK_R'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Deploy Front Left Screen", [4], "", -5, [["expression", "['PLT_SCOUT_FRONT_L'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Deploy Front Center Screen", [5], "", -5, [["expression", "['PLT_SCOUT_FRONT_C'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Deploy Front Right Screen", [6], "", -5, [["expression", "['PLT_SCOUT_FRONT_R'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Deploy Rear Reserve Screen", [7], "", -5, [["expression", "['PLT_SCOUT_REAR'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["7. Rejoin All Platoon Scouts", [8], "", -5, [["expression", "['PLT_SCOUT_REJOIN_ALL'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// Submenu: Squad-Level Scout & Security Screen Deployments
FTCS_MENU_ScoutScreen_Deploy = [
    ["Squad Scout Screen", false],
    ["1. Deploy to Left Flank Screen", [2], "", -5, [["expression", "['SQD_SCOUT_SLOT_11'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Deploy to Right Flank Screen", [3], "", -5, [["expression", "['SQD_SCOUT_SLOT_12'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Deploy to Front Center Screen", [4], "", -5, [["expression", "['SQD_SCOUT_SLOT_6'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Deploy to Front Left Screen", [5], "", -5, [["expression", "['SQD_SCOUT_SLOT_7'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Deploy to Front Right Screen", [6], "", -5, [["expression", "['SQD_SCOUT_SLOT_8'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Deploy to Rear Reserve Screen", [7], "", -5, [["expression", "['SQD_SCOUT_SLOT_5'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["7. Rejoin Scouts to Squad", [8], "", -5, [["expression", "['TASK_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 2.7 Master Squad Leader Menu (Phase 2: Overwatch) - [ACTIVE]
FTCS_MENU_Squad_Phase2 = [
    ["Squad Directives (Phase 2: Overwatch)", false],
    ["1. Scout & Security Screen -> [Deploy / Shift]", [2], "#USER:FTCS_MENU_ScoutScreen_Deploy", -5, [["expression", ""]], "1", "1"],
    ["2. Set Overwatch Base", [3], "", -5, [["expression", "['SQD_SET_OVERWATCH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Resume Normal March", [4], "", -5, [["expression", "['SQD_RESUME_MARCH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Tactical Stance", [5], "#USER:FTCS_MENU_SquadStance_Common", -5, [["expression", ""]], "1", "1"],
    ["5. Regroup on Squad Leader", [6], "", -5, [["expression", "['TASK_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// =============================================================================
// FASE 3: COMBAT, ASSAULT & CONSOLIDATION PHASE (Combate Unificado y Maniobra)
// =============================================================================

// 3.1 Platoon-Wide Tactical Orders Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_PlatoonWideTactics_P3 = [
    ["Platoon Tactical Orders", false],
    ["1. Direct Assault Wave (Coordinated)", [2], "", -5, [["expression", "['PLT_ASSAULT_WAVE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Flanking Maneuver -> Left Envelopment", [3], "", -5, [["expression", "['PLT_FLANK_LEFT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Flanking Maneuver -> Right Envelopment", [4], "", -5, [["expression", "['PLT_FLANK_RIGHT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Platoon Base of Fire (All Suppress)", [5], "", -5, [["expression", "['PLT_BASE_OF_FIRE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Platoon Fall Back / Break Contact", [6], "", -5, [["expression", "['PLT_FALLBACK'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.2 Squad Orders: ALPHA Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_SquadOrders_Alpha_P3 = [
    ["Squad Alpha Directives", false],
    ["1. Direct Push Forward", [2], "", -5, [["expression", "['SQD_ALPHA_PUSH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Flanking Maneuver -> Left Flank", [3], "", -5, [["expression", "['SQD_ALPHA_FLANK_L'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Flanking Maneuver -> Right Flank", [4], "", -5, [["expression", "['SQD_ALPHA_FLANK_R'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Fall Back / Break Contact", [5], "", -5, [["expression", "['SQD_ALPHA_FALLBACK'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Suppress Target / Sector", [6], "", -5, [["expression", "['SQD_ALPHA_SUPPRESS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.3 Squad Orders: BRAVO Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_SquadOrders_Bravo_P3 = [
    ["Squad Bravo Directives", false],
    ["1. Direct Push Forward", [2], "", -5, [["expression", "['SQD_BRAVO_PUSH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Flanking Maneuver -> Left Flank", [3], "", -5, [["expression", "['SQD_BRAVO_FLANK_L'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Flanking Maneuver -> Right Flank", [4], "", -5, [["expression", "['SQD_BRAVO_FLANK_R'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Fall Back / Break Contact", [5], "", -5, [["expression", "['SQD_BRAVO_FALLBACK'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Suppress Target / Sector", [6], "", -5, [["expression", "['SQD_BRAVO_SUPPRESS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.4 Squad Orders: CHARLIE Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_SquadOrders_Charlie_P3 = [
    ["Squad Charlie Directives", false],
    ["1. Direct Push Forward", [2], "", -5, [["expression", "['SQD_CHARLIE_PUSH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Flanking Maneuver -> Left Flank", [3], "", -5, [["expression", "['SQD_CHARLIE_FLANK_L'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Flanking Maneuver -> Right Flank", [4], "", -5, [["expression", "['SQD_CHARLIE_FLANK_R'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Fall Back / Break Contact", [5], "", -5, [["expression", "['SQD_CHARLIE_FALLBACK'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Suppress Target / Sector", [6], "", -5, [["expression", "['SQD_CHARLIE_SUPPRESS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.5 Squad Orders: WEAPONS Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_SquadOrders_Weapons_P3 = [
    ["Weapons Section Directives", false],
    ["1. Establish Support by Fire (SBF Base)", [2], "", -5, [["expression", "['SQD_WEAPONS_SBF'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Heavy Suppression on Sector", [3], "", -5, [["expression", "['SQD_WEAPONS_SUPPRESS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Reposition Weapons Section", [4], "", -5, [["expression", "['SQD_WEAPONS_REPOSITION'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Redistribute Ammunition (Bearers)", [5], "", -5, [["expression", "['SQD_WEAPONS_RESUPPLY'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.6 Fire Direction & Area Suppression Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_FireDirection_P3 = [
    ["Fire Direction & Suppression", false],
    ["1. Suppress Target Reference Point (TRP)", [2], "", -5, [["expression", "['FIRE_SUPPRESS_TRP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Shift Fire to Target Sector", [3], "", -5, [["expression", "['FIRE_SHIFT_SECTOR'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Cease Fire / Check Fire", [4], "", -5, [["expression", "['FIRE_CEASE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.7 Sustainment & MEDEVAC Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_Sustainment_P3 = [
    ["Sustainment & MEDEVAC", false],
    ["1. Platoon Roster & Casualty Check", [2], "", -5, [["expression", "['SUSTAIN_ROSTER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Establish Casualty Collection Point (CCP)", [3], "", -5, [["expression", "['SUSTAIN_ESTABLISH_CCP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Request 9-Line MEDEVAC / Triage", [4], "", -5, [["expression", "['SUSTAIN_MEDEVAC'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Distribute Platoon Ammunition", [5], "", -5, [["expression", "['SUSTAIN_AMMO'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.8 Fire Support Coordination Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_FireSupport_P3 = [
    ["Fire Support Coordination", false],
    ["1. Call Mortar HE Barrage (60mm/81mm)", [2], "", -5, [["expression", "['FS_MORTAR_BARRAGE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Call Smoke Screen Mission", [3], "", -5, [["expression", "['FS_SMOKE_SCREEN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Call Illumination Flares (Night)", [4], "", -5, [["expression", "['FS_ILLUM_FLARES'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.9 Master Platoon Sergeant Menu (Phase 3: Combat) - [ACTIVE]
FTCS_MENU_Sgt_Phase3 = [
    ["Platoon Command (Phase 3: Combat)", false],
    ["1. Operational Phase Transition", [2], "#USER:FTCS_MENU_PhaseTransition", -5, [["expression", ""]], "1", "1"],
    ["2. Platoon-Wide Tactical Orders", [3], "#USER:FTCS_MENU_PlatoonWideTactics_P3", -5, [["expression", ""]], "1", "1"],
    ["3. Tactical Stance", [4], "#USER:FTCS_MENU_PlatoonStance_Common", -5, [["expression", ""]], "1", "1"],
    ["4. Select Squad: [ ALPHA ]", [5], "#USER:FTCS_MENU_SquadOrders_Alpha_P3", -5, [["expression", ""]], "1", "1"],
    ["5. Select Squad: [ BRAVO ]", [6], "#USER:FTCS_MENU_SquadOrders_Bravo_P3", -5, [["expression", ""]], "1", "1"],
    ["6. Select Squad: [ CHARLIE ]", [7], "#USER:FTCS_MENU_SquadOrders_Charlie_P3", -5, [["expression", ""]], "1", "1"],
    ["7. Select Squad: [ WEAPONS ]", [8], "#USER:FTCS_MENU_SquadOrders_Weapons_P3", -5, [["expression", ""]], "1", "1"],
    ["8. Fire Direction & Suppression", [9], "#USER:FTCS_MENU_FireDirection_P3", -5, [["expression", ""]], "1", "1"],
    ["9. Sustainment & MEDEVAC", [10], "#USER:FTCS_MENU_Sustainment_P3", -5, [["expression", ""]], "1", "1"],
    ["10. Fire Support Coordination", [11], "#USER:FTCS_MENU_FireSupport_P3", -5, [["expression", ""]], "1", "1"]
];

// 3.10 Push Forward Distance Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_PushForward_P3 = [
    ["Push Forward (Bound)", false],
    ["1. Advance 5 Meters", [2], "", -5, [["expression", "['PUSH_5M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Advance 10 Meters", [3], "", -5, [["expression", "['PUSH_10M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Advance 15 Meters", [4], "", -5, [["expression", "['PUSH_15M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Advance 25 Meters", [5], "", -5, [["expression", "['PUSH_25M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.11 Fall Back Distance Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_FallBack_P3 = [
    ["Fall Back (Bound)", false],
    ["1. Fall Back 5 Meters", [2], "", -5, [["expression", "['FALLBACK_5M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Fall Back 10 Meters", [3], "", -5, [["expression", "['FALLBACK_10M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Fall Back 15 Meters", [4], "", -5, [["expression", "['FALLBACK_15M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Fall Back 25 Meters", [5], "", -5, [["expression", "['FALLBACK_25M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.12 Shift Lateral Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_ShiftLateral_P3 = [
    ["Shift Lateral Position", false],
    ["1. Shift Left 5 Meters", [2], "", -5, [["expression", "['SHIFT_L_5M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Shift Left 10 Meters", [3], "", -5, [["expression", "['SHIFT_L_10M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Shift Right 5 Meters", [4], "", -5, [["expression", "['SHIFT_R_5M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Shift Right 10 Meters", [5], "", -5, [["expression", "['SHIFT_R_10M'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.13 Local Combat & Terrain Tactics Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_LocalCombatTactics_P3 = [
    ["Local Terrain Tactics", false],
    ["1. Move to Point / Cover at Crosshair", [2], "", -5, [["expression", "['TACTIC_MOVE_COVER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Breach / Clear Targeted Building", [3], "", -5, [["expression", "['TACTIC_BREACH_CLEAR'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Push Forward Under Fire", [4], "#USER:FTCS_MENU_PushForward_P3", -5, [["expression", ""]], "1", "1"],
    ["4. Fall Back Under Fire", [5], "#USER:FTCS_MENU_FallBack_P3", -5, [["expression", ""]], "1", "1"],
    ["5. Break Contact / Fall Back", [6], "", -5, [["expression", "['TACTIC_BREAK_CONTACT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Flanking Maneuver -> Left Flank", [7], "", -5, [["expression", "['TACTIC_FLANK_LEFT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["7. Flanking Maneuver -> Right Flank", [8], "", -5, [["expression", "['TACTIC_FLANK_RIGHT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["8. Shift Lateral Position", [9], "#USER:FTCS_MENU_ShiftLateral_P3", -5, [["expression", ""]], "1", "1"]
];

// 3.14 Direct Target Engagement & Suppression Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_DirectEngagement_P3 = [
    ["Target Engagement", false],
    ["1. Engage Target at Crosshair", [2], "", -5, [["expression", "['ENGAGE_CROSSHAIR'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Suppress Window / Nest at Crosshair", [3], "", -5, [["expression", "['SUPPRESS_CROSSHAIR'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Assault that Position Now!", [4], "", -5, [["expression", "['ASSAULT_CROSSHAIR'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.15 Post-Assault Consolidation Submenu (Phase 3) - [ACTIVE]
FTCS_MENU_PostAssault_P3 = [
    ["Post-Assault Consolidation", false],
    ["1. Shift Sector / Change Facing (360)", [2], "", -5, [["expression", "['CONSOLIDATE_FACING'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Check Casualties & First Aid", [3], "", -5, [["expression", "['CONSOLIDATE_AMMO'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Reorganize Perimeter & Consolidate", [4], "", -5, [["expression", "['CONSOLIDATE_PERIMETER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 3.16 Master Squad Leader Menu (Phase 3: Combat) - [ACTIVE]
FTCS_MENU_Squad_Phase3 = [
    ["Squad Directives (Phase 3: Combat)", false],
    ["1. Local Combat & Terrain Tactics", [2], "#USER:FTCS_MENU_LocalCombatTactics_P3", -5, [["expression", ""]], "1", "1"],
    ["2. Target Engagement & Suppression", [3], "#USER:FTCS_MENU_DirectEngagement_P3", -5, [["expression", ""]], "1", "1"],
    ["3. Post-Assault Consolidation", [4], "#USER:FTCS_MENU_PostAssault_P3", -5, [["expression", ""]], "1", "1"],
    ["4. Tactical Stance", [5], "#USER:FTCS_MENU_SquadStance_Common", -5, [["expression", ""]], "1", "1"],
    ["5. Regroup on Squad Leader", [6], "", -5, [["expression", "['TASK_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Squad Combat SITREP", [7], "", -5, [["expression", "['SQUAD_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// =============================================================================
// 4. PRE-MISSION / TLP (PLATOON PLANNING & PREPARATION - CP INTERFACE) - [ACTIVE]
// =============================================================================
FTCS_MENU_TLP_Planning = [
    ["Platoon Planning & TLP (CP)", false],
    ["1. Mission & Terrain Analysis (METT-TC)", [2], "", -5, [["expression", "['TLP_ANALYSIS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Platoon Roster & Personnel", [3], "", -5, [["expression", "['TLP_ROSTER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Sustainment & Loadout Distribution", [4], "", -5, [["expression", "['TLP_SUSTAINMENT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Fire Support Planning (TRPs)", [5], "", -5, [["expression", "['TLP_FIRE_SUPPORT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. OPORD TacMap & Route Planner", [6], "", -5, [["expression", "['TLP_TACMAP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// =============================================================================
// 5. SPECIALIZED ROLES (RTO, Runner, Medic, Visual Signals) - [ACTIVE]
// =============================================================================
FTCS_MENU_RadioComms = [
    ["Field Radio (SCR-300)", false],
    ["1. Radio SITREP from Platoons", [2], "", -5, [["expression", "['RADIO_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Transmit Fire Mission (Artillery)", [3], "", -5, [["expression", "['RADIO_ARTILLERY'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Request Armor Support", [4], "", -5, [["expression", "['RADIO_ARMOR'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Battalion Net Check", [5], "", -5, [["expression", "['RADIO_CHECK'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

FTCS_MENU_RunnerDispatch = [
    ["Dispatch Messenger", false],
    ["1. Dispatch: 1st Platoon Leader", [2], "", -5, [["expression", "['RUNNER_PLT_1'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Dispatch: 2nd Platoon Leader", [3], "", -5, [["expression", "['RUNNER_PLT_2'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Dispatch: 3rd Platoon Leader", [4], "", -5, [["expression", "['RUNNER_PLT_3'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Dispatch: Weapons Platoon Leader", [5], "", -5, [["expression", "['RUNNER_PLT_4'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

FTCS_MENU_MedicalTriage = [
    ["Combat Medic / Medical", false],
    ["1. Establish Casualty Collection Point (CCP)", [2], "", -5, [["expression", "['SUSTAIN_ESTABLISH_CCP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Treat Nearest Wounded", [3], "", -5, [["expression", "['MEDIC_TREAT_WOUNDED'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Medical Supply Status", [4], "", -5, [["expression", "['MEDIC_STATUS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

FTCS_MENU_VisualSignals = [
    ["Visual Hand Signals", false],
    ["1. Signal: HALT & TAKE COVER", [2], "", -5, [["expression", "['VISUAL_HALT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Signal: FOLLOW ME", [3], "", -5, [["expression", "['VISUAL_FOLLOW'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Signal: DROP PRONE", [4], "", -5, [["expression", "['VISUAL_PRONE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Signal: SPREAD OUT", [5], "", -5, [["expression", "['VISUAL_SPREAD'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Signal: RUSH FORWARD", [6], "", -5, [["expression", "['VISUAL_RUSH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

FTCS_CommandingMenus_Initialized = true;
diag_log "FTCS: Native Commanding Menus (#USER: commandingMenu) initialized successfully. Active options: Phase Transition, Platoon Formations, Movement Techniques. Other options disabled (grayed out).";
