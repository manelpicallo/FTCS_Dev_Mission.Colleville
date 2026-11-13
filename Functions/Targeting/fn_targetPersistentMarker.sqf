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

    // IMPORTANT (researched root cause of the recurring 'Error in expression /
    // 0 elements provided, 3 expected'): the SQF keyword 'continue' is NOT
    // supported inside forEach loops (it only works in 'while do', 'for do' and
    // 'do..while' - see the BI wiki 'continue' keyword page). The SQF parser
    // therefore consumed the following drawIcon3D array literal as operands of
    // the orphan 'continue' binary and the Draw3D closure failed to COMPILE
    // every frame, deterministically, no matter what runtime guards were added.
    // The body below is restructured as pure nested if/then WITHOUT continue.
    {
        private _grpId = _x;
        private _entry = _y;
        private _tgt = _entry getOrDefault ["squadTarget", []];
        // Entry gate: an intact target record is an 8-element array whose type
        // field is a real STRING (never "any", "" or "OBJECT" - corrupted or
        // half-cleared targets after a registry wipe are refused, not drawn).
        if (count _tgt >= 8
            && { typeName (_tgt select 1) == "STRING" }
            && { !((_tgt select 1) in ["any", "", "OBJECT"]) }) then {
            diag_log format ["[FTCS][TGT-MARKER] Drawing marker for %1 (type %2).", _grpId, _tgt select 1];

            _tgt params ["_isObject", "_targetType", "_objectRef", "_approachPos", "_impactPos", "_distance", "_bearing", "_label"];
            // NIL-SAFE position sanity: every field consumed by the draw calls is
            // validated by typeName (nil escapes == and isEqualType comparisons)
            private _impactOk = typeName _impactPos == "ARRAY" && { count _impactPos == 3 }
                && { typeName (_impactPos select 0) == "SCALAR" }
                && { typeName (_impactPos select 1) == "SCALAR" }
                && { typeName (_impactPos select 2) == "SCALAR" };
            // Note: the first eager term typeName _impactPos == "ARRAY" is safe because
            // typeName never throws on any type; the selects live in lazy {} blocks that
            // only evaluate when the container already proved to be an ARRAY of 3.
            private _labelOk = typeName _label == "STRING";
            private _distanceOk = typeName _distance == "SCALAR";
            if (_impactOk && { _labelOk } && { _distanceOk }) then {
                _activeTargets = _activeTargets + 1;

                // Doctrinal squad name stored at capture time alongside the target
                private _sqdName = _entry getOrDefault ["squadTargetSquadName", ""];

                // Marker position: track the object if it is still alive, else
                // the captured world point. Guard against destroyed/partial
                // wrecks whose center of mass is empty: fall back to the stored
                // impact position (as documented above) instead of feeding
                // drawIcon3D a zero-element position.
                private _markerPos = +_impactPos;
                if (typeName _isObject == "BOOL" && { _isObject }
                    && { typeName _objectRef == "OBJECT" }
                    && { !isNull _objectRef } && { alive _objectRef }) then {
                    private _com = getCenterOfMass _objectRef;
                    if (typeName _com == "ARRAY" && { count _com == 3 } && { typeName (_com select 0) == "SCALAR" }) then {
                        private _wpos = _objectRef modelToWorldVisual _com;
                        if (typeName _wpos == "ARRAY" && { count _wpos == 3 }
                            && { typeName (_wpos select 0) == "SCALAR" }
                            && { typeName (_wpos select 1) == "SCALAR" }
                            && { typeName (_wpos select 2) == "SCALAR" }) then { _markerPos = _wpos; };
                    };
                };
                // Final gate: exact 3 SCALAR coordinates before any drawIcon3D call.
                // EVALUATION ORDER MATTERS: the container check (typeName == ARRAY) is
                // EAGER and runs FIRST; all select operations live inside lazy {}
                // blocks so a non-array markerPos can never reach a select.
                if (typeName _markerPos == "ARRAY"
                    && { count _markerPos == 3 }
                    && { typeName (_markerPos select 0) == "SCALAR" }
                    && { typeName (_markerPos select 1) == "SCALAR" }
                    && { typeName (_markerPos select 2) == "SCALAR" }) then {
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
                    if (typeName _sqdName == "STRING" && { _sqdName != "" }) then {
                        // Inline binary expression inside an array literal (vectorAdd followed
                        // by more elements) is misparsed by the SQF compiler - precompute the
                        // position (same family as the 'count + distance2D' parse bug).
                        private _namePos = _markerPos vectorAdd [0, 0, -1.2]; // one line below the target text
                        drawIcon3D
                        [
                            "",                                  // no texture: text-only line
                            [0.2, 1, 0.2, 1],
                            _namePos,
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
                } else {
                    diag_log format ["[FTCS][TGT-MARKER] REFUSED entry %1 (markerPos invalid: %2).", _grpId, str _markerPos];
                };
            };
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
