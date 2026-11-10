/*
    ================================================================================
    File: fn_targetMark.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Enters TARGET IDENTIFICATION mode for the commander.
                 Activated when the commander selects "Mark Target" - no further
                 mouse click is needed to START identifying.
                 All aiming aids are drawn via drawIcon3D inside a mission
                 "Draw3D" event handler (the ONLY event where drawIcon3D renders
                 reliably - EachFrame runs before the 3D scene render and its
                 drawIcon3D calls are dropped):
                 * TERRAIN: yellow arrow + "Terrain - <dist>m" at the walk-to point.
                 * OBJECT: cyan marker + "<label> - <dist>m" above the object.
                 COMMIT: the MIDDLE MOUSE BUTTON click (wheel click) captures the
                 currently aimed target: persists it to FTCS_Commander_Target with
                 a capture message, tears down the handlers, and ends the mode.
                 A middle click with nothing under the aim exits without capturing.
                 The mode stays active until commit, cancel, or perceiver death.
    Params:
        0: OBJECT - Perceiver unit (usually the commander/player).
        1: BOOLEAN - Kept for API compatibility (unused here).
    Returns:
        BOOLEAN - true.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_perceiver", objNull], ["_reopenMenu", true]];

if (isNull _perceiver) exitWith { false };
diag_log "[FTCS][TARGET] Identification mode started.";

// Idempotent teardown of a previous acquisition still running
private _prevDraw = missionNamespace getVariable ["FTCS_TGT_DrawEH", -1];
if (_prevDraw >= 0) then { removeMissionEventHandler ["Draw3D", _prevDraw]; };
private _prevClick = missionNamespace getVariable ["FTCS_TGT_ClickEH", -1];
if (_prevClick >= 0) then { (findDisplay 46) displayRemoveEventHandler ["MouseButtonDown", _prevClick]; };
missionNamespace setVariable ["FTCS_Commander_Target", nil];
missionNamespace setVariable ["FTCS_Commander_LiveTarget", nil];

// Live aim sample shared with the click handler through missionNamespace
// (Draw3D handlers run in the render realm: closures across realms are unsafe,
// the namespace handoff is the canonical bridge)
missionNamespace setVariable ["FTCS_TGT_FrameEH", nil];

// --- LIVE IDENTIFICATION: sample the aim ray every DRAW frame --------------------
private _drawEH = addMissionEventHandler ["Draw3D", {
    private _p = player;   // always-valid local object on the client

    private _scan = [_p, 150, 9] call FTCS_fnc_targetScan;
    if (count _scan == 0) exitWith {};

    _scan params ["_isObject", "_targetType", "_objectRef", "_approachPos", "_impactPos", "_distance", "_bearing", "_label"];

    // Draw positions in AGL/ATL (drawIcon3D realm per the working reference
    // example: modelToWorldVisual/getTerrainHeightASL produce visual-space points).
    if (_targetType == "terrain") then {
        // TERRAIN: screen-fixed reticle 12m ahead of the camera (same technique
        // as objects, terrain yellow) - avoids the near-camera projection blowup
        private _reticlePos = positionCameraToWorld [0, 0, 12];
        drawIcon3D
        [
            "a3\ui_f\data\igui\cfg\targeting\impactpoint_ca.paa",
            [1, 0.9, 0.2, 1],
            _reticlePos,
            1,
            1,
            0,
            format ["Terrain - %1m", round _distance],
            1,
            0.03,
            "RobotoCondensed",
            "center"
        ];
    } else {
        // OBJECT: cyan marker at the object's center of mass (visual space,
        // exactly like the working camera-proximity reference example)
        private _centerOfMass = _objectRef modelToWorldVisual (getCenterOfMass _objectRef);
        drawIcon3D
        [
            "a3\ui_f\data\igui\cfg\targeting\impactpoint_ca.paa",
            [0.3, 0.85, 1, 1],
            _centerOfMass,
            1,
            1,
            0,
            format ["%1 - %2m", _label, round _distance],
            1,
            0.03,
            "RobotoCondensed",
            "center"
        ];
    };

    // Live sample exposed for the commit handler (render-realm-safe handoff)
    missionNamespace setVariable ["FTCS_Commander_LiveTarget", _scan];
}];
missionNamespace setVariable ["FTCS_TGT_DrawEH", _drawEH];

systemChat "[TARGET] Target identification active: aim at terrain or an object, wheel-click to capture.";

// --- CAPTURE: middle mouse button (wheel click) ----------------------------------
private _clickEH = (findDisplay 46) displayAddEventHandler ["MouseButtonDown", {
    params ["_display", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];

    if (_button != 1) exitWith {}; // 1 = middle mouse button (wheel click)

    // Teardown: identification + click handlers
    private _did = missionNamespace getVariable ["FTCS_TGT_DrawEH", -1];
    if (_did >= 0) then { removeMissionEventHandler ["Draw3D", _did]; };
    missionNamespace setVariable ["FTCS_TGT_DrawEH", nil];
    (findDisplay 46) displayRemoveEventHandler ["MouseButtonDown", _thisEventHandler];
    missionNamespace setVariable ["FTCS_TGT_ClickEH", nil];

    private _scan = missionNamespace getVariable ["FTCS_Commander_LiveTarget", []];

    if (count _scan == 0) then {
        // Click with nothing under the aim: exit without capturing
        systemChat "[TARGET] Nothing under the aim - identification mode exited.";
    } else {
        // CAPTURE the aimed target
        missionNamespace setVariable ["FTCS_Commander_Target", _scan];
        _scan params ["_isObject", "_targetType", "_objectRef", "_approachPos", "_impactPos", "_distance", "_bearing", "_label"];
        systemChat format ["[TARGET CAPTURED] %1 at %2m.", _label, round _distance];
    };
}];
missionNamespace setVariable ["FTCS_TGT_ClickEH", _clickEH];

true
