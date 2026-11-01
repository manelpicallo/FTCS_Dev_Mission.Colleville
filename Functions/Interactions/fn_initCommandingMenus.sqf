/*
    ================================================================================
    File: fn_initCommandingMenus.sqf
    Module: Interactions
    Author: FTCS Team
    Description: Defines native engine commanding menus (#USER: commandingMenu)
                 accessible via number keys [1-9] or mouse wheel.
                 Provides dedicated contextual submenus for:
                 - Squad Leaders (Stance, Formations, ROE, Movement, Combat Tasks)
                 - Platoon Leaders (Platoon Sector, Formations, Stance, ROE)
                 - Company Staff (XO, First Sergeant)
                 - Specialized roles (RTO Comms, Runner Dispatch, Combat Medic)
                 - Visual Hand Signals (Distance 20m - 60m)
    Language: Strictly English (Rule 7)
    ================================================================================
*/

// Prevent re-initialization if already built
if (!isNil "FTCS_CommandingMenus_Initialized") exitWith {};

// -----------------------------------------------------------------------------
// 1. SQUAD LEADER SUBMENUS (Accessible via #USER:FTCS_MENU_SquadLeader)
// -----------------------------------------------------------------------------

// 1.1 Squad Stance Submenu
FTCS_MENU_SquadStance = [
    ["Squad Stance", false],
    ["Auto Stance (Combat Default)", [2], "", -5, [["expression", "['STANCE_AUTO'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Force Stand Up (Rush / Fast Bound)", [3], "", -5, [["expression", "['STANCE_UP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Force Crouch (Cautious Advance)", [4], "", -5, [["expression", "['STANCE_MIDDLE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Force Prone (Take Cover / Pin Down)", [5], "", -5, [["expression", "['STANCE_DOWN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.2 Squad Formation Submenu
FTCS_MENU_SquadFormation = [
    ["Squad Formation", false],
    ["Column (Road / Trail Advance)", [2], "", -5, [["expression", "['FORM_COLUMN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Line (Assault / Skirmish)", [3], "", -5, [["expression", "['FORM_LINE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Wedge (All-round Security)", [4], "", -5, [["expression", "['FORM_WEDGE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Echelon Right", [5], "", -5, [["expression", "['FORM_ECH_R'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Echelon Left", [6], "", -5, [["expression", "['FORM_ECH_L'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.3 Squad Rules of Engagement (ROE) Submenu
FTCS_MENU_SquadROE = [
    ["Rules of Engagement", false],
    ["Fire at Will", [2], "", -5, [["expression", "['ROE_OPEN_FIRE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Hold Fire / Return Fire Only", [3], "", -5, [["expression", "['ROE_HOLD_FIRE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Cease Fire", [4], "", -5, [["expression", "['ROE_CEASE_FIRE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.4 Squad Tactical Tasks Submenu
FTCS_MENU_SquadTasks = [
    ["Tactical Directives", false],
    ["Establish Support by Fire (SBF)", [2], "", -5, [["expression", "['TASK_SBF'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Suppress Target Position", [3], "", -5, [["expression", "['TASK_SUPPRESS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Orderly Fallback / Consolidate", [4], "", -5, [["expression", "['TASK_FALLBACK'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Regroup on Commander", [5], "", -5, [["expression", "['TASK_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// 1.5 Master Squad Leader Menu
FTCS_MENU_SquadLeader = [
    ["Squad Orders", false],
    ["1. Tactical Stance", [2], "#USER:FTCS_MENU_SquadStance", -5, [["expression", ""]], "1", "1"],
    ["2. Squad Formation", [3], "#USER:FTCS_MENU_SquadFormation", -5, [["expression", ""]], "1", "1"],
    ["3. Movement Pace (Advance / Halt)", [4], "", -5, [["expression", "['TOGGLE_PACE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Rules of Engagement (ROE)", [5], "#USER:FTCS_MENU_SquadROE", -5, [["expression", ""]], "1", "1"],
    ["5. Tactical Tasks (SBF, Fallback)", [6], "#USER:FTCS_MENU_SquadTasks", -5, [["expression", ""]], "1", "1"],
    ["6. Follow Commander", [7], "", -5, [["expression", "['TASK_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["7. Check Ammo & Casualty SITREP", [8], "", -5, [["expression", "['SQUAD_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// -----------------------------------------------------------------------------
// 2. PLATOON LEADER SUBMENUS (Accessible via #USER:FTCS_MENU_PlatoonLeader)
// -----------------------------------------------------------------------------

FTCS_MENU_PlatoonFormation = [
    ["Platoon Formation", false],
    ["Platoon Column", [2], "", -5, [["expression", "['PLT_FORM_COLUMN'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Platoon Line (Full Frontage)", [3], "", -5, [["expression", "['PLT_FORM_LINE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Platoon Wedge", [4], "", -5, [["expression", "['PLT_FORM_WEDGE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["Vee Formation", [5], "", -5, [["expression", "['PLT_FORM_VEE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

FTCS_MENU_PlatoonLeader = [
    ["Platoon Orders", false],
    ["1. Platoon Advance / Halt", [2], "", -5, [["expression", "['PLT_TOGGLE_PACE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Platoon Formation", [3], "#USER:FTCS_MENU_PlatoonFormation", -5, [["expression", ""]], "1", "1"],
    ["3. Assign Axis of Advance", [4], "", -5, [["expression", "['PLT_ASSIGN_AXIS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Rules of Engagement", [5], "#USER:FTCS_MENU_SquadROE", -5, [["expression", ""]], "1", "1"],
    ["5. Follow Commander (Regroup)", [6], "", -5, [["expression", "['PLT_FOLLOW_COMMANDER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Request Platoon SITREP", [7], "", -5, [["expression", "['PLT_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// -----------------------------------------------------------------------------
// 3. COMPANY HQ STAFF SUBMENUS (XO / First Sergeant)
// -----------------------------------------------------------------------------

FTCS_MENU_CompanyStaff = [
    ["Company HQ Directives", false],
    ["1. Company Reorganization / Assembly", [2], "", -5, [["expression", "['CO_ASSEMBLE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Emergency: Break Contact", [3], "", -5, [["expression", "['CO_BREAK_CONTACT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Emergency: Artillery Evasion", [4], "", -5, [["expression", "['CO_ARTY_EVASION'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Redistribute Ammunition", [5], "", -5, [["expression", "['CO_RESUPPLY'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Full Company SITREP", [6], "", -5, [["expression", "['CO_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// -----------------------------------------------------------------------------
// 4. SPECIALIZED ROLES (RTO, Runner, Medic)
// -----------------------------------------------------------------------------

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
    ["1. Establish Casualty Collection Point (CCP)", [2], "", -5, [["expression", "['MEDIC_ESTABLISH_CCP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Treat Nearest Wounded", [3], "", -5, [["expression", "['MEDIC_TREAT_WOUNDED'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Medical Supply Status", [4], "", -5, [["expression", "['MEDIC_STATUS'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// -----------------------------------------------------------------------------
// 5. VISUAL HAND SIGNALS (Distance 20m - 60m with Line of Sight)
// -----------------------------------------------------------------------------

FTCS_MENU_VisualSignals = [
    ["Visual Hand Signals", false],
    ["1. Signal: HALT & TAKE COVER", [2], "", -5, [["expression", "['VISUAL_HALT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Signal: FOLLOW ME", [3], "", -5, [["expression", "['VISUAL_FOLLOW'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Signal: DROP PRONE", [4], "", -5, [["expression", "['VISUAL_PRONE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Signal: SPREAD OUT", [5], "", -5, [["expression", "['VISUAL_SPREAD'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Signal: RUSH FORWARD", [6], "", -5, [["expression", "['VISUAL_RUSH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

FTCS_CommandingMenus_Initialized = true;
diag_log "FTCS: Native Commanding Menus (#USER: commandingMenu) initialized successfully.";

// -----------------------------------------------------------------------------
// 6. FIRETEAM / TACTICAL TEAM SUBMENUS (Accessible via #USER:FTCS_MENU_TeamOrders)
// -----------------------------------------------------------------------------

FTCS_MENU_TeamManeuver = [
    ["Team Maneuvers", false],
    ["1. Scout Ahead / Recon Bound", [2], "", -5, [["expression", "['TEAM_SCOUT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Establish Suppressive Base (Overwatch)", [3], "", -5, [["expression", "['TEAM_OVERWATCH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Flank Left", [4], "", -5, [["expression", "['TEAM_FLANK_L'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Flank Right", [5], "", -5, [["expression", "['TEAM_FLANK_R'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Leapfrog / Bounding Bound", [6], "", -5, [["expression", "['TEAM_BOUNDING'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

FTCS_MENU_TeamOrders = [
    ["Fireteam Directives", false],
    ["1. Tactical Role: Recon & Point (Scout)", [2], "", -5, [["expression", "['TEAM_ROLE_SCOUT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Tactical Role: Base of Fire (BAR / LMG)", [3], "", -5, [["expression", "['TEAM_ROLE_SUPPORT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Tactical Role: Assault & Clearing", [4], "", -5, [["expression", "['TEAM_ROLE_ASSAULT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Team Maneuvers (Overwatch, Flank)", [5], "#USER:FTCS_MENU_TeamManeuver", -5, [["expression", ""]], "1", "1"],
    ["5. Hold Current Position (Anchor)", [6], "", -5, [["expression", "['TEAM_HOLD'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Regroup on Squad Leader", [7], "", -5, [["expression", "['TEAM_REGROUP_SQUAD'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// -----------------------------------------------------------------------------
// 7. COMPANY GENERAL DIRECTIVES (Accessible on self via #USER:FTCS_MENU_CompanyGeneral)
// -----------------------------------------------------------------------------

FTCS_MENU_CompanyGeneral = [
    ["Company Directives", false],
    ["1. Company Halt & Take Cover", [2], "", -5, [["expression", "['CO_GENERAL_HALT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Company Advance at Normal Pace", [3], "", -5, [["expression", "['CO_GENERAL_ADVANCE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. All Units: Fire at Will", [4], "", -5, [["expression", "['CO_GENERAL_FIRE_WILL'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. All Units: Hold Fire (Cease Fire)", [5], "", -5, [["expression", "['CO_GENERAL_HOLD_FIRE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Assemble on Company Commander", [6], "", -5, [["expression", "['CO_GENERAL_REGROUP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Overall Company Combat SITREP", [7], "", -5, [["expression", "['CO_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];

// -----------------------------------------------------------------------------
// 8. PLATOON SERGEANT SUBMENUS (Accessible via #USER:FTCS_MENU_PlatoonSergeant)
// -----------------------------------------------------------------------------

FTCS_MENU_PlatoonSergeant = [
    ["Platoon Sergeant Orders", false],
    ["1. Form Up & Lead Support Element", [2], "", -5, [["expression", "['PLT_SGT_FORM_SUPPORT'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["2. Direct Platoon Stance: Cautious", [3], "", -5, [["expression", "['PLT_SGT_STANCE_CROUCH'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["3. Direct Platoon Stance: Prone / Cover", [4], "", -5, [["expression", "['PLT_SGT_STANCE_PRONE'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["4. Redistribute Platoon Ammunition", [5], "", -5, [["expression", "['PLT_SGT_RESUPPLY'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["5. Follow Lieutenant / Regroup", [6], "", -5, [["expression", "['PLT_SGT_FOLLOW_LEADER'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"],
    ["6. Check Platoon Ammo & Casualties", [7], "", -5, [["expression", "['PLT_SGT_SITREP'] call FTCS_fnc_applyCommandToTarget;"]], "1", "1"]
];
