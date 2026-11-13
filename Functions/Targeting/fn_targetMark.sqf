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
                 * TERRAIN: yellow reticle + "Terrain - <dist>m" (screen-fixed,
                   same technique as objects - avoids near-camera projection blowup).
                 * OBJECT: cyan marker + "<label> - <dist>m" above the object.
                 INPUT NOTE: the weapon is silenced with setAmmo 0 during the mode
                 (stored ammunition restored on exit) so stray clicks cannot waste
                 rounds. The dry "clack" is diegetic - the commander is consciously
                 in designation mode. Mouse actions (left fire, right raise, middle
                 action wheel) are NOT suppressed: instead of fighting the native
                 action wheel, the flow works WITH the commanding menu system:
                 COMMIT: the MIDDLE MOUSE BUTTON click (wheel click) captures the
                 currently aimed target: persists it to FTCS_Commander_Target with
                 a capture message, restores weapon ammo, tears down the handlers,
                 and then reopens the squad directives commanding menu (regenerated
                 with the target-dependent rows now ENABLED since a target exists).
                 Opening that commanding menu also displaces the native action
                 wheel - the menu on screen is ours. A middle click with nothing
                 under the aim exits without capturing.
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
missionNamespace setVariable ["FTCS_Commander_LiveTarget", nil];
missionNamespace setVariable ["FTCS_TGT_FrameEH", nil];

// --- INPUT LOCK: silent weapon + consumed mouse events ---------------------------
// Store the current loaded mag state so it can be restored verbatim on exit.
private _weapon = currentWeapon player;
private _storedAmmo = 0;
if (_weapon != "") then {
    _storedAmmo = player ammo _weapon;
    player setAmmo [_weapon, 0];
};
missionNamespace setVariable ["FTCS_TGT_StoredAmmo", _storedAmmo];
missionNamespace setVariable ["FTCS_TGT_StoredWeapon", _weapon];

systemChat "[TARGET] Target identification active: aim at terrain or an object, wheel-click to capture. (mouse actions locked)";

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
        // exactly like the working camera-proximity reference example).
        // Defensive guard: skip the frame if the object vanished/degraded
        // (destroyed between scan and draw, or null ref) - prevents the
        // drawIcon3D zero-element crash seen in the RPT.
        if (isNull _objectRef || {!alive _objectRef}) exitWith {};
        private _com = getCenterOfMass _objectRef;
        if (_com isEqualTo []) exitWith {};
        private _centerOfMass = _objectRef modelToWorldVisual _com;
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

// --- CAPTURE: middle mouse button (wheel click) ----------------------------------
// The handler consumes EVERY mouse button event (returns true) so the engine
// skips the native bindings (left fire, right raise weapon, middle action
// wheel). Only the middle click performs work: the capture.
private _clickEH = (findDisplay 46) displayAddEventHandler ["MouseButtonDown", {
    params ["_display", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];

    if (_button != 2) exitWith { true }; // consume left/right clicks: no native action. 2 = middle mouse button (wheel click); 1 = RIGHT button

    // Teardown: identification + click handlers + weapon ammo restoration
    private _did = missionNamespace getVariable ["FTCS_TGT_DrawEH", -1];
    if (_did >= 0) then { removeMissionEventHandler ["Draw3D", _did]; };
    missionNamespace setVariable ["FTCS_TGT_DrawEH", nil];
    (findDisplay 46) displayRemoveEventHandler ["MouseButtonDown", _thisEventHandler];
    missionNamespace setVariable ["FTCS_TGT_ClickEH", nil];

    // Restore the weapon ammunition silenced at mode entry
    private _wpn = missionNamespace getVariable ["FTCS_TGT_StoredWeapon", ""];
    private _ammo = missionNamespace getVariable ["FTCS_TGT_StoredAmmo", 0];
    if (_wpn != "" && { alive player }) then {
        player setAmmo [_wpn, _ammo];
    };
    missionNamespace setVariable ["FTCS_TGT_StoredAmmo", nil];
    missionNamespace setVariable ["FTCS_TGT_StoredWeapon", nil];

    private _scan = missionNamespace getVariable ["FTCS_Commander_LiveTarget", []];

    if (count _scan == 0) then {
        // Click with nothing under the aim: exit without capturing
        systemChat "[TARGET] Nothing under the aim - identification mode exited.";
    } else {
        // CAPTURE the aimed target, then reopen the ORIGINATING squad's orders
        // menu (FTCS_TGT_OwnerSquadIndex was stored when the commander picked
        // "Mark Target" on that squad). The menu rebuild is target-state-aware:
        // rows 2-4 enable, rows 5-8 disable. Opening the commanding menu also
        // displaces the native action wheel - the menu on screen is ours.
        missionNamespace setVariable ["FTCS_Commander_Target", _scan];
        _scan params ["_isObject", "_targetType", "_objectRef", "_approachPos", "_impactPos", "_distance", "_bearing", "_label"];
        systemChat format ["[TARGET CAPTURED] %1 at %2m.", _label, round _distance];

        // Per-squad target ownership: persist the capture into the owning squad's
        // registry entry ("squadTarget") so each squad holds its own white and
        // the persistent 3D marker can be drawn per squad. The registry is keyed
        // by Arma groupId (radio names like "Alpha 1-1"), NOT by doctrinal keys:
        // resolve the owning squad's actual group from the parsed platoon data
        // (same lookup chain as the squad-order dispatcher) and store under ITS
        // groupId, spreading the target across every team group of the squad so
        // whole-team resolution works downstream.
        private _ownerIdx = missionNamespace getVariable ["FTCS_TGT_OwnerSquadIndex", 1];
        private _pltIdC = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltKeyC = format ["PLT_%1", _pltIdC];
        private _pltMapC = (missionNamespace getVariable ["FTCS_Company_Data", createHashMap]) getOrDefault ["platoons", createHashMap];
        private _pltDataC = _pltMapC getOrDefault [_pltKeyC, createHashMap];
        private _parsedSqC = _pltDataC getOrDefault ["parsedSquads", createHashMap];
        private _sqdKeyC = format ["SQD_%1_%2", _pltIdC, _ownerIdx];
        private _sqdDataC = _parsedSqC getOrDefault [_sqdKeyC, createHashMap];

        private _ownerGroups = [];
        private _teamsC = _sqdDataC getOrDefault ["tacticalTeams", createHashMap];
        if (count _teamsC == 0) then { _teamsC = _sqdDataC getOrDefault ["teams", createHashMap]; };
        { private _g = (_y) getOrDefault ["group", grpNull]; if (!isNull _g) then { _ownerGroups pushBack _g }; } forEach _teamsC;
        if (count _ownerGroups == 0) then {
            private _g = _sqdDataC getOrDefault ["group", grpNull];
            if (!isNull _g) then { _ownerGroups pushBack _g };
        };

        // Doctrinal squad name: read once at capture from the parsed squad data
        // (same "name" field the dynamic menus use) - the persistent marker
        // renders it as a second caption line without any per-frame lookup.
        private _sqdNameC = _sqdDataC getOrDefault ["name", _sqdKeyC];

        private _captured = false;
        {
            private _ownGroup = _x;
            private _ownGrpId = groupId _ownGroup;
            if (!(_ownGrpId in FTCS_Groups_Registry_Table)) then {
                // Defensive: register the group so the target is never lost
                FTCS_Groups_Registry_Table set [_ownGrpId, createHashMap];
            };
            private _ownEntry = FTCS_Groups_Registry_Table getOrDefault [_ownGrpId, createHashMap];
            _ownEntry set ["squadTarget", _scan];
            _ownEntry set ["squadTargetSquadName", _sqdNameC];
            FTCS_Groups_Registry_Table set [_ownGrpId, _ownEntry];
            _captured = true;
            diag_log format ["[FTCS][TARGET] squadTarget stored for '%1' (marker spawn).", _ownGrpId];
        } forEach _ownerGroups;

        if (_captured) then {
            [] spawn FTCS_fnc_targetPersistentMarker;
        } else {
            diag_log format ["[FTCS][TARGET] WARNING: owning squad '%1' resolved to no group - squadTarget NOT stored.", _sqdKeyC];
        };

        [] spawn {
            sleep 0.5; // commanding-menu engine cooldown after the click closes
            // Rebuild the squad-order menus with the NEW target state before
            // reopening: the enable flags of rows 2-8 are computed at build time.
            call FTCS_fnc_initCommandingMenus;
            private _menuName = format ["#USER:FTCS_MENU_SquadOrders_%1",
                missionNamespace getVariable ["FTCS_TGT_OwnerSquadIndex", 1]];
            showCommandingMenu _menuName;
        };
    };

    true // consume the middle click: blocks the native action menu
}];
missionNamespace setVariable ["FTCS_TGT_ClickEH", _clickEH];

true
