/*
    ================================================================================
    File: fn_openSubordinateMenu.sqf
    Module: Interactions
    Author: FTCS Team
    Description: Called from an addAction on a subordinate leader or self command net.
                 Stores active target context in global variables and invokes the
                 appropriate native commandingMenu (#USER:) dynamically adapted
                 to the current Operational Phase (Doctrine FM 3-21.8).
    Language: Strictly English (Rule 7, Rule 11)

    +-----------------------------------------------------------------------------+
    |                    DYNAMIC PHASE MENU ROUTING                               |
    +-----------------------------------------------------------------------------+
    |                                                                             |
    |   [Target Interaction] ──► [Distance Check]                                 |
    |                                │                                            |
    |                    <= 20m ─────┴───── > 20m ──► #USER:FTCS_MENU_VisualSignals|
    |                      │                                                      |
    |        ┌─────────────┴──────────────┐                                       |
    |        ▼                            ▼                                       |
    |  [PLATOON / SERGEANT]            [SQUAD LEADER]                             |
    |        │                            │                                       |
    |   Check FTCS_CurrentPhase      Check FTCS_CurrentPhase                      |
    |        ├─ Phase 1: Approach         ├─ Phase 1: Approach                    |
    |        │   (#USER:Sgt_Phase1)       │   (#USER:Squad_Phase1)                |
    |        ├─ Phase 2: Overwatch        ├─ Phase 2: Overwatch                   |
    |        │   (#USER:Sgt_Phase2)       │   (#USER:Squad_Phase2)                |
    |        └─ Phase 3: Combat           └─ Phase 3: Combat                      |
    |            (#USER:Sgt_Phase3)           (#USER:Squad_Phase3)                |
    +-----------------------------------------------------------------------------+
    ================================================================================
*/

params [
    ["_targetUnit", objNull],
    ["_caller", objNull],
    ["_actionId", -1],
    ["_arguments", []]
];

if (isNull _targetUnit) exitWith {};

_arguments params [
    ["_menuType", "SQUAD"],
    ["_roleLabel", "Subordinate"],
    ["_bypassDistance", false]
];

// Ensure commanding menus are compiled and initialized in memory
if (isNil "FTCS_CommandingMenus_Initialized") then {
    call FTCS_fnc_initCommandingMenus;
};

// Resolve the platoon ID for the active context (platoon of target or player)
private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
if (!isNull _targetUnit) then {
    private _uVar = vehicleVarName _targetUnit;
    if (_uVar != "" && {_uVar find "PLT_" >= 0}) then {
        private _parts = _uVar splitString "_";
        private _idx = _parts find "PLT";
        if (_idx >= 0 && {count _parts > _idx + 1}) then {
            private _parsed = parseNumber (_parts select (_idx + 1));
            if (_parsed > 0) then { _pltId = _parsed; };
        };
    };
};

// Retrieve active operational phase for this specific platoon (Default: Phase 1 - APPROACH)
private _curPhase = missionNamespace getVariable [format ["FTCS_Platoon_Phase_%1", _pltId], 1];

// Store active target context for expression evaluation inside commandingMenu items
missionNamespace setVariable ["FTCS_ActiveMenu_Target", _targetUnit];
missionNamespace setVariable ["FTCS_ActiveMenu_Role", _roleLabel];
missionNamespace setVariable ["FTCS_ActiveMenu_Pos", screenToWorld [0.5, 0.5]];
missionNamespace setVariable ["FTCS_ActiveMenu_CursorObject", cursorObject];

private _distance = player distance _targetUnit;
private _isSelf = (_targetUnit == player);

// Select appropriate commandingMenu according to role, operational phase, and distance
private _menuName = switch (_menuType) do {
    case "SQUAD": {
        if (_distance <= 20 || _isSelf || _bypassDistance) then {
            switch (_curPhase) do {
                case 1: { "#USER:FTCS_MENU_Squad_Phase1" };
                case 2: { "#USER:FTCS_MENU_Squad_Phase2" };
                case 3: { "#USER:FTCS_MENU_Squad_Phase3" };
                default { "#USER:FTCS_MENU_Squad_Phase1" };
            };
        } else {
            "#USER:FTCS_MENU_VisualSignals"
        };
    };
    case "PLATOON_SERGEANT";
    case "PLATOON": {
        if (_distance <= 20 || _isSelf || _bypassDistance) then {
            switch (_curPhase) do {
                case 0: { "#USER:FTCS_MENU_PhaseTransition" }; // Force phase selection if troops still in deployment inspection
                case 1: { "#USER:FTCS_MENU_Sgt_Phase1" };
                case 2: { "#USER:FTCS_MENU_Sgt_Phase2" };
                case 3: { "#USER:FTCS_MENU_Sgt_Phase3" };
                default { "#USER:FTCS_MENU_PhaseTransition" };
            };
        } else {
            "#USER:FTCS_MENU_VisualSignals"
        };
    };
    case "PHASE_TRANSITION": {
        "#USER:FTCS_MENU_PhaseTransition"
    };
    case "TLP_PLANNING": {
        "#USER:FTCS_MENU_TLP_Planning"
    };
    case "RADIO": {
        "#USER:FTCS_MENU_RadioComms"
    };
    case "RUNNER": {
        "#USER:FTCS_MENU_RunnerDispatch"
    };
    case "MEDIC": {
        "#USER:FTCS_MENU_MedicalTriage"
    };
    case "VISUAL": {
        "#USER:FTCS_MENU_VisualSignals"
    };
    default {
        switch (_curPhase) do {
            case 1: { "#USER:FTCS_MENU_Squad_Phase1" };
            case 2: { "#USER:FTCS_MENU_Squad_Phase2" };
            case 3: { "#USER:FTCS_MENU_Squad_Phase3" };
            default { "#USER:FTCS_MENU_Squad_Phase1" };
        };
    };
};

// Synchronize Follow Mode options in Platoon Formations menu:
// The currently active mode appears in gray / disabled ("1", "0") so the alternative is selectable ("1", "1")
// Indices in FTCS_MENU_PlatoonFormations_P1:
//   select 9 -> Option 9: Relative
//   select 10 -> Option 10: Absolute
private _currentFollowMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
if (_currentFollowMode == "FOLLOWING_COMMANDER_REL") then {
    (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "0"]; // Relative disabled (gray)
    (FTCS_MENU_PlatoonFormations_P1 select 10) set [6, "1"]; // Absolute enabled (white)
} else {
    (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "1"]; // Relative enabled (white)
    (FTCS_MENU_PlatoonFormations_P1 select 10) set [6, "0"]; // Absolute disabled (gray)
};

// Dynamically evaluate combat effectiveness of detached scout slots (Slots 11, 12, 7, 6, 8, 5)
// Gray out (disable) options if a combat-effective team already occupies that slot.
// If all soldiers in that team are dead or incapacitated, re-enable ("1", "1") so fresh scouts can reinforce it.
private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
private _activePltKey = format ["PLT_%1", _pltId];
private _activePltData = _platoonsMap getOrDefault [_activePltKey, createHashMap];
private _activeSlotsMap = _activePltData getOrDefault ["formationSlots", createHashMap];

private _fnc_isSlotOccupiedAndEffective = {
    params ["_slotNum"];
    private _isOccupied = false;
    if (_slotNum in _activeSlotsMap) then {
        private _grpCandidate = grpNull;
        if (!isNil "Platoon_Formation_Position_List" && {count Platoon_Formation_Position_List > _slotNum}) then {
            _grpCandidate = (Platoon_Formation_Position_List select _slotNum) select 2;
        };
        if (isNull _grpCandidate && {!isNil "FTCS_Groups_Registry_Table"}) then {
            {
                if ((_y getOrDefault ["allocationSlot", -1]) == _slotNum) exitWith {
                    private _cand = missionNamespace getVariable [_x, grpNull];
                    if (!isNull _cand) then { _grpCandidate = _cand; };
                };
            } forEach FTCS_Groups_Registry_Table;
        };
        if (!isNull _grpCandidate) then {
            private _effectiveCount = { alive _x && {lifeState _x != "INCAPACITATED"} } count (units _grpCandidate);
            _isOccupied = (_effectiveCount > 0);
        };
    };
    _isOccupied
};

// Update Platoon Scout Directives Menu (FTCS_MENU_Platoon_Scouts)
if (!isNil "FTCS_MENU_Platoon_Scouts") then {
    private _occ11 = [11] call _fnc_isSlotOccupiedAndEffective;
    private _occ12 = [12] call _fnc_isSlotOccupiedAndEffective;
    private _occ7  = [7] call _fnc_isSlotOccupiedAndEffective;
    private _occ6  = [6] call _fnc_isSlotOccupiedAndEffective;
    private _occ8  = [8] call _fnc_isSlotOccupiedAndEffective;
    private _occ5  = [5] call _fnc_isSlotOccupiedAndEffective;

    (FTCS_MENU_Platoon_Scouts select 1) set [6, if (_occ11) then { "0" } else { "1" }]; // Left Flank (Slot 11)
    (FTCS_MENU_Platoon_Scouts select 2) set [6, if (_occ12) then { "0" } else { "1" }]; // Right Flank (Slot 12)
    (FTCS_MENU_Platoon_Scouts select 3) set [6, if (_occ7)  then { "0" } else { "1" }]; // Front Left (Slot 7)
    (FTCS_MENU_Platoon_Scouts select 4) set [6, if (_occ6)  then { "0" } else { "1" }]; // Front Center (Slot 6)
    (FTCS_MENU_Platoon_Scouts select 5) set [6, if (_occ8)  then { "0" } else { "1" }]; // Front Right (Slot 8)
    (FTCS_MENU_Platoon_Scouts select 6) set [6, if (_occ5)  then { "0" } else { "1" }]; // Rear (Slot 5)
};

// Update Squad-Level Scout Screen Menu (FTCS_MENU_ScoutScreen_Deploy)
if (!isNil "FTCS_MENU_ScoutScreen_Deploy") then {
    private _occ11 = [11] call _fnc_isSlotOccupiedAndEffective;
    private _occ12 = [12] call _fnc_isSlotOccupiedAndEffective;
    private _occ6  = [6] call _fnc_isSlotOccupiedAndEffective;
    private _occ7  = [7] call _fnc_isSlotOccupiedAndEffective;
    private _occ8  = [8] call _fnc_isSlotOccupiedAndEffective;
    private _occ5  = [5] call _fnc_isSlotOccupiedAndEffective;

    (FTCS_MENU_ScoutScreen_Deploy select 1) set [6, if (_occ11) then { "0" } else { "1" }]; // Slot 11
    (FTCS_MENU_ScoutScreen_Deploy select 2) set [6, if (_occ12) then { "0" } else { "1" }]; // Slot 12
    (FTCS_MENU_ScoutScreen_Deploy select 3) set [6, if (_occ6)  then { "0" } else { "1" }]; // Slot 6
    (FTCS_MENU_ScoutScreen_Deploy select 4) set [6, if (_occ7)  then { "0" } else { "1" }]; // Slot 7
    (FTCS_MENU_ScoutScreen_Deploy select 5) set [6, if (_occ8)  then { "0" } else { "1" }]; // Slot 8
    (FTCS_MENU_ScoutScreen_Deploy select 6) set [6, if (_occ5)  then { "0" } else { "1" }]; // Slot 5
};

// Update Road March Column Layout Menu: Compact option is enabled ONLY while a
// road march column is active (live anchor) AND the current layout is STAGGERED.
// Once compacted, the option disables itself; re-ordering Staggered re-enables it.
if (!isNil "FTCS_MENU_RoadMarchLayout") then {
    private _pltIdM = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    private _anchorM = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltIdM], createHashMap];
    private _roadActive = count (_anchorM getOrDefault ["roadPath", []]) >= 2;
    private _layout = _anchorM getOrDefault ["columnLayout", "STAGGERED"];
    private _roadLayout = (missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltIdM], createHashMap]) getOrDefault ["columnLayout", "STAGGERED"];
    private _trailAnchorM = missionNamespace getVariable [format ["FTCS_Trail_Anchor_PLT_%1", _pltIdM], createHashMap];
    private _trailActive = count (_trailAnchorM getOrDefault ["trailPath", []]) >= 2;
    private _trailLayout = _trailAnchorM getOrDefault ["columnLayout", "STAGGERED"];
    private _edgeSteps = _anchorM getOrDefault ["edgeMarginSteps", 0];
    // Row 3 = Compact Column (rows: 0=title, 1=staggered, 2=trail, 3=compact)
    // Enabled with a road column in STAGGERED/COMPACT layout; DISABLED under a
    // single-shoulder LEFT/RIGHT column (already single-file, nothing to compact)
    private _compactAllowed = _roadActive && { _roadLayout in ["STAGGERED", "COMPACT"] };
    (FTCS_MENU_RoadMarchLayout select 3) set [6, if (_compactAllowed) then { "1" } else { "0" }];
    // Rows 4/5 = single-shoulder columns (LEFT/RIGHT): ALWAYS enabled - they
    // deploy the full road pipeline with a forced side, no prior staggered
    // column required (dispatcher handles both fresh-order and re-chain paths)
    (FTCS_MENU_RoadMarchLayout select 4) set [6, "1"];
    (FTCS_MENU_RoadMarchLayout select 5) set [6, "1"];
    // Rows 6-8 = stepped edge margin controls (road-world only): push available
    // while below the 4-step cap; pull-in and reset only while off-road
    private _row5 = FTCS_MENU_RoadMarchLayout select 6;
    _row5 set [6, if (_roadActive && { _edgeSteps < 4 }) then { "1" } else { "0" }];
    _row5 set [0, if (_edgeSteps > 0) then {
        format ["6. Push Out From Road (+3m) [OUT x%1/4]", _edgeSteps]
    } else {
        "6. Push Out From Road (+3m)"
    }];
    (FTCS_MENU_RoadMarchLayout select 7) set [6, if (_roadActive && { _edgeSteps > 0 }) then { "1" } else { "0" }];
    (FTCS_MENU_RoadMarchLayout select 8) set [6, if (_roadActive && { _edgeSteps > 0 }) then { "1" } else { "0" }];

    // ------------------------------------------------------------------
    // Squad & Scout Directives hub + Squad Orders submenus (dynamic rebuild)
    // One hub entry per doctrinal squad (3 or 4, real doctrine names) plus the
    // scouts row; each Squad Orders submenu shows the movement rows only when a
    // commander target is currently marked (Targeting class), and highlights
    // Rejoin when the squad is detached/pinned from its formation slot.
    // ------------------------------------------------------------------
    private _pltIdD = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    private _pltKeyD = format ["PLT_%1", _pltIdD];
    private _platoonsMapD = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltDataD = _platoonsMapD getOrDefault [_pltKeyD, createHashMap];
    private _parsedSquadsD = _pltDataD getOrDefault ["parsedSquads", createHashMap];

    private _hasTargetD = !(isNil "FTCS_Commander_Target") && { count (missionNamespace getVariable ["FTCS_Commander_Target", []]) >= 8 };

    // Hub rebuild: rows 2-5 map to squads 1-4 (show only existing doctrinal squads)
    private _sqdOrder = ["_1", "_2", "_3", "_4"];
    for "_si" from 1 to 4 do {
        private _sqdKeyD = format ["SQD_%1_%2", _pltIdD, _si];
        private _sDataD = _parsedSquadsD getOrDefault [_sqdKeyD, createHashMap];
        private _hasSquadD = (count _sDataD > 0) || { !isNull (_sDataD getOrDefault ["group", grpNull]) };
        private _hubRow = FTCS_MENU_SquadDirectives select (1 + _si);
        private _doctName = _sDataD getOrDefault ["name", format ["Squad %1", _si]];
        _hubRow set [0, format ["%1. %2", _si + 1, _doctName]];
        _hubRow set [6, if (_hasSquadD) then { "1" } else { "0" }];
    };

    // Squad Orders submenus rebuild (rows: 0=title, 1=mark, 2-4=movement, 5-7=in-formation, 8=rejoin)
    for "_si" from 1 to 4 do {
        private _menuArr = missionNamespace getVariable [format ["FTCS_MENU_SquadOrders_%1", _si], []];
        if (count _menuArr >= 9) then {
            (_menuArr select 0) set [0, format ["Squad Orders - Squad %1%2", _si, if (_hasTargetD) then { " [TGT MARKED]" } else { "" }]];
            for "_ri" from 2 to 4 do {
                (_menuArr select _ri) set [6, if (_hasTargetD) then { "1" } else { "0" }];
            };
        };
    };
};

showCommandingMenu _menuName;
