/*
    ================================================================================
    File: fn_targetPersistentMarker.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Draws the PERSISTENT captured-target markers in the 3D world.
                 Every squad entry in the registry that owns a captured target
                 ("squadTarget" field) gets a red marker pinned to its target
                 position, visible from any bearing, until the target is consumed
                 (a Move order fires) or replaced (a new capture by the same squad).
                 Marker behaviour per target type:
                 - OBJECT: the marker tracks the object's center of mass each
                   frame (modelToWorldVisual). If the object is destroyed or null,
                   the marker falls back to the stored impact position.
                 - TERRAIN: the marker stays at the captured world point (ATL).
                 VISUAL: GREEN marker with two caption lines - line 1 is the
                 target text (<label> - <dist>m for objects, the same wording
                 as the acquisition aid), line 2 below it is the DOCTRINAL name
                 of the owning squad (captured once into the registry alongside
                 the target as "squadTargetSquadName"). Icon: impactpointnolos_ca
                 (fixed lock-on symbol for a committed target).
                 LIFECYCLE: a single Draw3D handler runs while at least one squad
                 target exists; it removes itself when the last one is cleared.
                 Entry points: spawned by fn_targetMark after each capture; torn
                 down (removeMissionEventHandler) when consuming orders clear the
                 owning squad's target (fn_targetClear handles the handler purge).
    Params:
        NONE (reads the registry each frame; safe to spawn repeatedly -
              idempotent: an existing handler is reused, never duplicated).
    Returns:
        NOTHING (spawned).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

// Idempotent: if the persistent marker handler is already running, do nothing
// (a new capture updates the registry data, not the handler).
if (!isNil "FTCS_TGT_PersistEH") exitWith { diag_log "[FTCS][TGT-MARKER] Handler already running - spawn ignored (idempotent)."; };

// Single Draw3D loop over all squad targets in the registry
FTCS_TGT_PersistEH = addMissionEventHandler ["Draw3D", {
    private _activeTargets = 0;

    {
        private _grpId = _x;
        private _entry = _y;
        private _tgt = _entry getOrDefault ["squadTarget", []];
        if (count _tgt < 8) then { continue; };
        diag_log format ["[FTCS][TGT-MARKER] Drawing marker for %1 (type %2).", _grpId, _tgt select 1];

        _tgt params ["_isObject", "_targetType", "_objectRef", "_approachPos", "_impactPos", "_distance", "_bearing", "_label"];
        _activeTargets = _activeTargets + 1;

        // Doctrinal squad name stored at capture time alongside the target
        private _sqdName = _entry getOrDefault ["squadTargetSquadName", ""];

        // Marker position: track the object if it is still alive, else the
        // captured world point
        private _markerPos = _impactPos;
        if (_isObject && { !isNull _objectRef }) then {
            _markerPos = _objectRef modelToWorldVisual (getCenterOfMass _objectRef);
        };

        // GREEN persistent marker, lock-on icon (impactpointnolos_ca):
        // line 1 = target text, line 2 = owning squad's doctrinal name below it
        drawIcon3D
        [
            "a3\ui_f\data\igui\cfg\targeting\impactpointnolos_ca.paa",
            [0.2, 1, 0.2, 1],
            _markerPos,
            1,
            1,
            0,
            format ["%1 - %2m", _label, round _distance],
            1,
            0.03,
            "RobotoCondensed",
            "center"
        ];
        if (_sqdName != "") then {
            drawIcon3D
            [
                "",                                  // no texture: text-only line
                [0.2, 1, 0.2, 1],
                _markerPos vectorAdd [0, 0, -1.2],  // one line below the target text
                1,
                1,
                0,
                _sqdName,
                1,
                0.03,
                "RobotoCondensed",
                "center"
            ];
        };
    } forEach FTCS_Groups_Registry_Table;

    // Self-teardown: nothing left to mark (trace once per frame is noisy: only
    // log when going from active to empty by checking the handler still exists)
    if (_activeTargets == 0) then {
        diag_log "[FTCS][TGT-MARKER] No active squad targets - handler self-terminating.";
        removeMissionEventHandler ["Draw3D", _thisEventHandler];
        missionNamespace setVariable ["FTCS_TGT_PersistEH", nil];
    };
}];
