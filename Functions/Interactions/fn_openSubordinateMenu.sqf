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
//   select 8 -> Option 8: Relative
//   select 9 -> Option 9: Absolute
private _currentFollowMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
if (_currentFollowMode == "FOLLOWING_COMMANDER_REL") then {
    (FTCS_MENU_PlatoonFormations_P1 select 8) set [6, "0"]; // Relative disabled (gray)
    (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "1"]; // Absolute enabled (white)
} else {
    (FTCS_MENU_PlatoonFormations_P1 select 8) set [6, "1"]; // Relative enabled (white)
    (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "0"]; // Absolute disabled (gray)
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

showCommandingMenu _menuName;
