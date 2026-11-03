/*
    ================================================================================
    File: fn_groupSetROE.sqf
    Module: Core / Groups
    Author: FTCS Team / Manel P.
    Description: Configures Rules of Engagement (setCombatMode: BLUE, GREEN, YELLOW, WHITE, RED)
                 and synchronizes cleanly into FTCS_Groups_Registry_Table.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)
    ================================================================================
*/

params [
    ["_group", grpNull],
    ["_roe", "FIRE_IF_FIRED_UPON"]
];

if (isNull _group) exitWith { false };

private _groupID = groupId _group;

switch (_roe) do {

    case "HOLD_FIRE": {
        _group setCombatMode "BLUE";
        [_groupID, "roe", "HOLD_FIRE"] call FTCS_fnc_registrySet;
    };

    case "FIRE_IF_FIRED_UPON": {
        _group setCombatMode "GREEN";
        [_groupID, "roe", "FIRE_IF_FIRED_UPON"] call FTCS_fnc_registrySet;
    };

    case "FIRE_AT_WILL": {
        _group setCombatMode "YELLOW";
        [_groupID, "roe", "FIRE_AT_WILL"] call FTCS_fnc_registrySet;
    };

    case "HOLD_FIRE_COVER": {
        _group setCombatMode "WHITE";
        [_groupID, "roe", "HOLD_FIRE_COVER"] call FTCS_fnc_registrySet;
    };

    case "FIRE_AT_WILL_COVER": {
        _group setCombatMode "RED";
        [_groupID, "roe", "FIRE_AT_WILL_COVER"] call FTCS_fnc_registrySet;
    };

    default {
        _group setCombatMode "GREEN";
        [_groupID, "roe", _roe] call FTCS_fnc_registrySet;
    };
};

true;
