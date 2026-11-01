/*
    ================================================================================
    File: fn_openSubordinateMenu.sqf
    Module: Interactions
    Author: FTCS Team
    Description: Called from an addAction on a subordinate leader. Stores the target
                 context in global variables and invokes the appropriate native
                 commandingMenu (#USER:) according to role, distance, and line of sight.
    Language: Strictly English (Rule 7)
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
    ["_roleLabel", "Subordinate"]
];

// Ensure commanding menus are compiled and initialized
if (isNil "FTCS_CommandingMenus_Initialized") then {
    call FTCS_fnc_initCommandingMenus;
};

// Store active target context for expression evaluation inside commandingMenu items
missionNamespace setVariable ["FTCS_ActiveMenu_Target", _targetUnit];
missionNamespace setVariable ["FTCS_ActiveMenu_Role", _roleLabel];

private _distance = player distance _targetUnit;

// Select appropriate commandingMenu according to role and distance
private _menuName = switch (_menuType) do {
    case "SQUAD": {
        if (_distance <= 20) then {
            "#USER:FTCS_MENU_SquadLeader"
        } else {
            "#USER:FTCS_MENU_VisualSignals"
        }
    };
    case "TEAM": {
        "#USER:FTCS_MENU_TeamOrders"
    };
    case "COMPANY_GENERAL": {
        "#USER:FTCS_MENU_CompanyGeneral"
    };
    case "PLATOON_SERGEANT": {
        "#USER:FTCS_MENU_PlatoonSergeant"
    };
    case "PLATOON": {
        if (_distance <= 20) then {
            "#USER:FTCS_MENU_PlatoonLeader"
        } else {
            "#USER:FTCS_MENU_VisualSignals"
        }
    };
    case "STAFF": {
        "#USER:FTCS_MENU_CompanyStaff"
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
        "#USER:FTCS_MENU_SquadLeader"
    };
};

showCommandingMenu _menuName;
