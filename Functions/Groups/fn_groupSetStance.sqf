/*
    ================================================================================
    File: fn_groupSetStance.sqf
    Module: Core / Groups
    Author: FTCS Team / Manel P.
    Description: Adjusts group physical stance (AUTO, UP, MIDDLE, DOWN, FOLLOW_COMMANDER)
                 and synchronizes cleanly into FTCS_Groups_Registry_Table.
                 For FOLLOW_COMMANDER_STANCE, registers the group and launches the
                 centralized lightweight stance worker (Option A).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)
    ================================================================================
*/

params [
    ["_group", grpNull],
    ["_stance", "AUTO"]
];

if (isNull _group) exitWith { false };

private _groupID = groupId _group;

switch (_stance) do {

    case "GO_UP": {
        {
            if (stance _x == "CROUCH") then { _x setUnitPos "UP"; };
            if (stance _x == "PRONE") then { _x setUnitPos "MIDDLE"; };
        } forEach (units _group);
        [_groupID, "stance", "FORCE_UP"] call FTCS_fnc_registrySet;
    };

    case "GO_DOWN": {
        {
            if (stance _x == "STAND") then { _x setUnitPos "MIDDLE"; };
            if (stance _x == "CROUCH") then { _x setUnitPos "DOWN"; };
        } forEach (units _group);
        [_groupID, "stance", "FORCE_MIDDLE"] call FTCS_fnc_registrySet;
    };

    case "AUTO": {
        { _x setUnitPos "AUTO"; } forEach (units _group);
        [_groupID, "stance", "AUTO"] call FTCS_fnc_registrySet;
    };

    case "FORCE_LOW";
    case "FORCE_DOWN": {
        { _x setUnitPos "DOWN"; } forEach (units _group);
        [_groupID, "stance", "FORCE_DOWN"] call FTCS_fnc_registrySet;
    };

    case "FORCE_MIDDLE": {
        { _x setUnitPos "MIDDLE"; } forEach (units _group);
        [_groupID, "stance", "FORCE_MIDDLE"] call FTCS_fnc_registrySet;
    };

    case "FORCE_UP": {
        { _x setUnitPos "UP"; } forEach (units _group);
        [_groupID, "stance", "FORCE_UP"] call FTCS_fnc_registrySet;
    };

    case "FOLLOW_COMMANDER_STANCE": {
        [_groupID, "stance", "FOLLOW_COMMANDER_STANCE"] call FTCS_fnc_registrySet;
        [_groupID, "groupObj", _group] call FTCS_fnc_registrySet;
        // Launch central stance worker (Option A) if not active
        call FTCS_fnc_commanderStanceSyncWorker;
    };

    default {
        { _x setUnitPos "AUTO"; } forEach (units _group);
        [_groupID, "stance", _stance] call FTCS_fnc_registrySet;
    };
};

true;
