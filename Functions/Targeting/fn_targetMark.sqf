/*
    ================================================================================
    File: fn_targetMark.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Enters CONTINUOUS TARGET ACQUISITION mode for the commander.
                 While the mode is active, an onEachFrame handler samples the
                 aim ray every frame and draws live aiming aids:
                 - TERRAIN hit : a down-arrow 3D icon at the marked point with
                   "Terrain — <dist>m" above it ("send troops here" cue).
                 - OBJECT hit  : a screen-fixed reticle 12m ahead of the camera
                   with the generic class label and distance.
                 COMMIT: the MOUSE WHEEL BUTTON (middle click — the same gesture
                 that opens the commanding menus) commits the currently aimed
                 target. On commit the target is persisted, the preview and the
                 click handler are removed, and the Squad & Scout Directives
                 menu is reopened (regenerated, movement orders enabled).
                 EXIT without commit: a middle click with NO valid target under
                 the aim exits the mode with a notice (also serves as cancel).
                 No weapon manipulation is performed: the commander keeps his
                 weapon, so care is needed not to discharge during acquisition.
    Params:
        0: OBJECT - Perceiver unit (usually the commander/player).
        1: BOOLEAN - Reopen the Squad & Scout Directives hub after commit
                     (default true).
    Returns:
        BOOLEAN - true (spawned).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_perceiver", objNull], ["_reopenMenu", true]];

if (isNull _perceiver) exitWith { false };

// Start from scratch: clear any previously marked target
missionNamespace setVariable ["FTCS_Commander_Target", nil];
missionNamespace setVariable ["FTCS_Commander_LiveTarget", nil];
diag_log "[FTCS][TARGET] Acquisition mode started (continuous preview + middle-click commit).";

// Defensive teardown of a previous acquisition still running
private _prevFrame = missionNamespace getVariable ["FTCS_TGT_FrameEH", -1];
if (_prevFrame >= 0) then { removeMissionEventHandler ["EachFrame", _prevFrame]; missionNamespace setVariable ["FTCS_TGT_FrameEH", nil]; };
private _prevClick = missionNamespace getVariable ["FTCS_TGT_ClickEH", -1];
if (_prevClick >= 0) then { (findDisplay 46) displayRemoveEventHandler ["MouseButtonDown", _prevClick]; missionNamespace setVariable ["FTCS_TGT_ClickEH", nil]; };

// NOTE: per-frame drawing must use the MISSION event handler "EachFrame"
// (display EHs do not accept "onEachFrame" as an enum - Foreign error).
private _frameEH = addMissionEventHandler ["EachFrame", {
    params ["_perceiver", "_frameEH"];

    if (isNull _perceiver) exitWith {
        removeMissionEventHandler ["EachFrame", _frameEH];
        missionNamespace setVariable ["FTCS_TGT_FrameEH", nil];
    };

    private _scan = [_perceiver, 150, 9] call FTCS_fnc_targetScan;
    if (count _scan == 0) exitWith {};

    _scan params ["_isObject", "_targetType", "_objectRef", "_approachPos", "_impactPos", "_distance", "_bearing", "_label"];

    if (_targetType == "terrain") then {
        // TERRAIN: 3D arrow pinned to the walk-to point, distance caption above
        drawIcon3D
        [
            "\A3\ui_f\data\map\markers\military\end_CA.paa",
            [1, 0.9, 0.2, 1],
            _approachPos,
            1.2,
            1.2,
            0,
            format ["Terrain - %1m", round _distance],
            2,
            0.055,
            "TahomaB"
        ];
    } else {
        // OBJECT: screen-fixed reticle 12m ahead of the camera, class label below
        private _reticlePos = positionCameraToWorld [0, 0, 12];
        drawIcon3D
        [
            "\A3\ui_f\data\map\markers\military\objective_CA.paa",
            [0.3, 0.85, 1, 1],
            _reticlePos,
            0.5,
            0.5,
            0,
            format ["%1 - %2m", _label, round _distance],
            2,
            0.05,
            "TahomaB"
        ];
    };

    // Expose the live sample for the click handler (closure-safe handoff)
    missionNamespace setVariable ["FTCS_Commander_LiveTarget", _scan];
}];
missionNamespace setVariable ["FTCS_TGT_FrameEH", _frameEH];

// --- COMMIT: middle-click via MouseButtonDown display EH ------------------------
// Display EHs only accept CODE STRINGS: the handler code is GENERATED with the
// frame handler id baked as a literal, the live target read from the
// missionNamespace handoff variable, and all inner strings single-quoted (so
// the generated code needs no double-quote escaping). Inner format percent signs
// are escaped as %% so the OUTER format does not consume them.
private _stateCode = format ["
    if (_this select 1 != 1) exitWith {}; // 1 = middle mouse button (wheel click)

    removeMissionEventHandler ['EachFrame', %1];
    missionNamespace setVariable ['FTCS_TGT_FrameEH', nil];
    (findDisplay 46) displayRemoveEventHandler ['MouseButtonDown', _thisEventHandler];
    missionNamespace setVariable ['FTCS_TGT_ClickEH', nil];

    private _scan = missionNamespace getVariable ['FTCS_Commander_LiveTarget', []];

    if (count _scan == 0) then {
        systemChat '[TARGET] Nothing under the aim - acquisition mode exited.';
    } else {
        missionNamespace setVariable ['FTCS_Commander_Target', _scan];
        private _lbl = _scan select 7;
        private _dst = round (_scan select 5);
        systemChat format ['[TARGET] Marked: %1 at %2m.', _lbl, _dst];

        [] spawn { sleep 0.3; showCommandingMenu '#USER:FTCS_MENU_SquadDirectives'; };
    };
", _handlerId];

private _clickEH = (findDisplay 46) displayAddEventHandler ["MouseButtonDown", _stateCode];
missionNamespace setVariable ["FTCS_TGT_ClickEH", _clickEH];

diag_log format ["[FTCS][TARGET] Middle-click commit EH registered (id %1).", _clickEH];

true
