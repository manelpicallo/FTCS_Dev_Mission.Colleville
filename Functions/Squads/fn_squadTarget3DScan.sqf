/*
    ================================================================================
    File: fn_squadTarget3DScan.sqf
    Module: Squads
    Author: FTCS Team
    Description: Squad-level wrapper for the commander target scan (Targeting
                 class). Enters the live acquisition mode from the player's view
                 (preview icons on screen for 5s), then commits the marked
                 target and reopens this squad's orders menu automatically
                 (regenerated, with movement orders enabled by the mark).
                 NOTE: runs SYNCHRONOUSLY from the commanding-menu execution
                 context - the onEachFrame preview survives menu closure, so no
                 spawn/deferral is needed (deferring inside a menu execution
                 context can get the thread killed when the menu closes).
    Params:
        0: NUMBER - Squad slot index (1-based: 1 = SQD_x_1, 2 = SQD_x_2...)
    Returns:
        BOOLEAN - true (delegates to the acquisition window).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_slotIndex", 1]];
diag_log format ["[FTCS][TARGET] squadTarget3DScan invoked (slot %1).", _slotIndex];
diag_log format ["[FTCS][TARGET-SCAN] Entered with slot %1 (player %2).", _slotIndex, name player];

[player, true] call FTCS_fnc_targetMark;
true
