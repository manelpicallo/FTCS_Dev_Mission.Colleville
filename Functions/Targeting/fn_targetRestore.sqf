/*
    ================================================================================
    File: fn_targetRestore.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Legacy teardown helper retained for API completeness. Current
                 targetMark acquires through display onEachFrame + MouseButtonDown
                 handlers that clean themselves up on commit, so this function is
                 no longer called in the live flow. Kept registered to avoid
                 breaking any external reference and for reuse as a generic
                 handler-teardown utility.
    Params:
        0: STRING - onEachFrame handler id to remove.
        1: NUMBER - MouseButtonDown display EH id to remove (default -1).
    Returns:
        BOOLEAN - true after teardown.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_handlerId", ""], ["_ehId", -1]];

if (_handlerId != "") then {
    [_handlerId, "onEachFrame"] call BIS_fnc_removeStackedEventHandler;
};
if (_ehId >= 0) then {
    (findDisplay 46) displayRemoveEventHandler ["MouseButtonDown", _ehId];
};
missionNamespace setVariable ["FTCS_TGT_ClickEH", nil];

true
