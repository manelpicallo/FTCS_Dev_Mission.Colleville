/*
    ================================================================================
    File: fn_targetClear.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Clears the currently marked commander target (removes
                 FTCS_Commander_Target from missionNamespace). Used when a
                 consumer order has been executed and the target should not
                 linger for the next order, or when the commander explicitly
                 cancels the marked target.
    Params:
        None.
    Returns:
        BOOLEAN - true if a target was cleared, false if there was none.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

private _hadTarget = !(isNil "FTCS_Commander_Target");
missionNamespace setVariable ["FTCS_Commander_Target", nil];
_hadTarget
