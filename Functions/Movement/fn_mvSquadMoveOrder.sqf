/*
    ================================================================================
    File: fn_mvSquadMoveOrder.sqf
    Module: Movement
    Author: FTCS Team
    Description: Contextual movement dispatcher for squad move-to-point orders.
                 The SINGLE entry point every squad movement menu/shortcut must
                 use: it reads the squad's active movingMode and delegates to the
                 matching Movement-class primitive, so each movement context has
                 exactly one implementation of its arrival geometry:
                     FOLLOWING_COMMANDER_REL / _ABS -> fn_mvFormationShift
                         (cross-country formation shift: geometry preserved,
                          target becomes the new squad anchor)
                     FREE_MOVE                     -> fn_mvSquadAdvanceToPoint
                         (free move: contact-line arrival geometry)
                     FOLLOWING_ROAD / FOLLOWING_TRAIL -> (future primitives;
                         refused for now with clear feedback)
                 Caller supplies only squad + marked target: the mode decides the
                 variant, the menus stay mode-agnostic.
    Params:
        0: GROUP - Squad group receiving the move order.
        1: ARRAY - Target world position [x, y, z] (marked/confirmed point).
    Returns:
        BOOLEAN - true when a primitive accepted the order.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_squad", grpNull], ["_targetPos", [0, 0, 0]]];

if (isNull _squad || { count _targetPos < 2 }) exitWith { false };

private _grpId = groupId _squad;
private _mode = [_grpId, "movingMode"] call FTCS_fnc_registryGet;

switch (true) do {
    case (_mode in ["FOLLOWING_COMMANDER_REL", "FOLLOWING_COMMANDER_ABS"]): {
        [_squad, _targetPos] call FTCS_fnc_mvFormationShift;
        true
    };
    case (_mode == "FREE_MOVE"): {
        [_squad, _targetPos] call FTCS_fnc_mvSquadAdvanceToPoint;
        true
    };
    default {
        systemChat format ["[MV ORDER] %1: no movement primitive for mode '%2'.", _grpId, _mode];
        diag_log format ["[FTCS][MV-ORDER] Refused %1 (mode %2).", _grpId, _mode];
        false
    };
};
