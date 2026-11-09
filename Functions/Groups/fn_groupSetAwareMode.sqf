/*
    ================================================================================
    File: fn_groupSetAwareMode.sqf
    Module: Core / Groups
    Author: FTCS Team / Manel P.
    Description: Configures AI group combat awareness, behavior, and micro-AI features
                 (AUTOCOMBAT, TARGET, COVER, SUPPRESSION) and synchronizes the state
                 cleanly into FTCS_Groups_Registry_Table.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)
    ================================================================================
*/

params [
    ["_group", grpNull],
    ["_mode", "AWARE"]
];

if (isNull _group) exitWith { false };

private _groupID = groupId _group;

switch (_mode) do {

    case "STAY_CALM": {
        {
            _x disableAI "TARGET";
            _x disableAI "AUTOCOMBAT";
        } forEach (units _group);
    };

    case "STAY_READY": {
        {
            _x disableAI "TARGET";
            _x enableAI "AUTOCOMBAT";
        } forEach (units _group);
    };

    case "CARELESS": {
        {
            _x disableAI "TARGET";
            _x disableAI "AUTOCOMBAT";
            _x enableAI "AUTOTARGET";
            _x enableAI "SUPPRESSION";
            _x enableAI "COVER";
        } forEach (units _group);

        [_group, "AUTO"] call FTCS_fnc_groupSetStance;
        _group setBehaviour "CARELESS";
        [_groupID, "awareMode", "CARELESS"] call FTCS_fnc_registrySet;
    };

    case "SAFE": {
        {
            _x disableAI "TARGET";
            _x disableAI "AUTOCOMBAT";
            _x enableAI "AUTOTARGET";
            _x enableAI "SUPPRESSION";
            _x enableAI "COVER";
        } forEach (units _group);

        [_group, "AUTO"] call FTCS_fnc_groupSetStance;
        _group setBehaviour "SAFE";
        [_groupID, "awareMode", "SAFE"] call FTCS_fnc_registrySet;
    };

    case "AWARE": {
        {
            _x disableAI "TARGET";
            _x disableAI "AUTOCOMBAT";
            _x enableAI "AUTOTARGET";
            _x enableAI "SUPPRESSION";
            _x enableAI "COVER";
        } forEach (units _group);

        _group setBehaviour "AWARE";
        [_groupID, "awareMode", "AWARE"] call FTCS_fnc_registrySet;
    };

    case "COMBAT": {
        {
            _x disableAI "TARGET";
            _x enableAI "AUTOTARGET";
            _x enableAI "SUPPRESSION";
            _x enableAI "COVER";
            _x enableAI "AUTOCOMBAT";
        } forEach (units _group);

        [_group, "AUTO"] call FTCS_fnc_groupSetStance;
        _group setBehaviourStrong "COMBAT";
        [_groupID, "awareMode", "COMBAT"] call FTCS_fnc_registrySet;
    };

    case "ROAD_MARCH": {
        // Disciplined road march profile: AWARE spacing preserved for formation
        // integrity, but COVER and AUTOTARGET disabled - neither seek-cover
        // detours nor threat-anticipation lead soldiers off the assigned lane.
        // Suppression remains active (react to real fire only).
        {
            _x disableAI "TARGET";
            _x disableAI "AUTOCOMBAT";
            _x disableAI "AUTOTARGET";
            _x disableAI "COVER";
            _x enableAI "SUPPRESSION";
        } forEach (units _group);

        _group setBehaviour "AWARE";
        [_groupID, "awareMode", "ROAD_MARCH"] call FTCS_fnc_registrySet;
    };

    case "STEALTH": {
        {
            _x disableAI "TARGET";
            _x enableAI "AUTOTARGET";
            _x enableAI "SUPPRESSION";
            _x enableAI "COVER";
        } forEach (units _group);

        [_group, "AUTO"] call FTCS_fnc_groupSetStance;
        _group setBehaviourStrong "STEALTH";
        [_groupID, "awareMode", "STEALTH"] call FTCS_fnc_registrySet;
    };

    case "ASSAULT_ADVANCE": {
        {
            _x disableAI "TARGET";
            _x disableAI "SUPPRESSION";
            _x disableAI "COVER";
            _x disableAI "AUTOCOMBAT";
        } forEach (units _group);

        _group setBehaviourStrong "AWARE";
        [_groupID, "awareMode", "ASSAULT_ADVANCE"] call FTCS_fnc_registrySet;
    };

    default {
        _group setBehaviour "AWARE";
        [_groupID, "awareMode", _mode] call FTCS_fnc_registrySet;
    };
};

true;
	