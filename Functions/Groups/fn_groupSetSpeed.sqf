/*
    ================================================================================
    File: fn_groupSetSpeed.sqf
    Module: Core / Groups
    Author: FTCS Team / Manel P.
    Description: Configures group movement speed (setSpeedMode: LIMITED, NORMAL, FULL)
                 and synchronizes cleanly into FTCS_Groups_Registry_Table.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)
    ================================================================================
*/

params [
    ["_group", grpNull],
    ["_type", "NORMAL"],
    ["_factor", 1]
];

if (isNull _group) exitWith { false };

private _groupID = groupId _group;
private _leader = leader _group;

switch (_type) do {

    case "FULL": {
        _group setSpeedMode "FULL";
        { _x forceSpeed (_x getSpeed "FAST"); } forEach (units _group);
        [_groupID, "speed", "FULL"] call FTCS_fnc_registrySet;
    };

    case "NORMAL": {
        _group setSpeedMode "NORMAL";
        private _normSpeed = if (!isNull _leader) then { _leader getSpeed "NORMAL" } else { -1 };
        if (_factor > 0 && _normSpeed > 0) then {
            _normSpeed = _normSpeed / _factor;
            { _x forceSpeed _normSpeed; } forEach (units _group);
        } else {
            { _x forceSpeed -1; } forEach (units _group);
        };
        [_groupID, "speed", "NORMAL"] call FTCS_fnc_registrySet;
    };

    case "LIMITED": {
        _group setSpeedMode "LIMITED";
        { _x forceSpeed (_x getSpeed "SLOW"); } forEach (units _group);
        [_groupID, "speed", "LIMITED"] call FTCS_fnc_registrySet;
    };

    default {
        _group setSpeedMode "NORMAL";
        { _x forceSpeed -1; } forEach (units _group);
        [_groupID, "speed", _type] call FTCS_fnc_registrySet;
    };
};

true;
