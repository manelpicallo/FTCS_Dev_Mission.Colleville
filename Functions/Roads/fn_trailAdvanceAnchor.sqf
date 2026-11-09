/*
    ================================================================================
    File: fn_trailAdvanceAnchor.sqf
    Module: Roads
    Author: FTCS Team
    Description: Sole owner of the leader-trail progression (TRAIL_COLUMN march).
                 Runs every 0.5s from the dispatcher thread and does two jobs:
                 1) RECORD: appends the leader's real positions to the trail
                    whenever he moves at least _recordStep meters in a plausible
                    direction (angular dead-zone vs the trail tip tangent, same
                    policy as the road anchor: head spins never contaminate the
                    track). FINE-MANEUVER BYPASS: short steps (< 5m) record
                    unconditionally, so spinning in place and tight circling
                    keep feeding the trail instead of freezing it - long
                    deviated strides in normal march remain filtered.
                    Backwards/sideways steps refresh the reference without
                    recording.
                 2) STOP CONVERGENCE: when the leader halts (< 0.5 km/h), headDist
                    snaps to the trail tip arclength so static slots rest at their
                    true distance behind him.
                 3) TRIM: drops trail points from the TAIL that are fully consumed
                    by the rearmost slot (arc < headDist - maxTrailOffset - margin),
                    keeping memory bounded during long marches.
                 Slots sample at (headDist - trailOffsetDist) over the trail:
                 each group walks the exact line the leader walked, and every
                 offset point is precisely where the group ahead passed.
    Params:
        0: OBJECT - Platoon leader unit (trail source).
        1: HASHMAP - Trail anchor: { anchorPos, trailPath, headDist, maxTrailOffset,
                     lastAnchorMovePos, generation } mutated in-place.
        2: NUMBER - Minimum movement to record a new trail point (default 2m).
        3: NUMBER - Maximum angular deviation from trail tip tangent (default 60).
    Returns:
        NUMBER - Updated headDist (arclength of the leader along the trail).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_leader", objNull], ["_anchor", locationNull], ["_recordStep", 2.0], ["_maxDeviation", 60]];

if (isNull _leader || { _anchor isEqualTo locationNull }) exitWith {
    _anchor getOrDefault ["headDist", 0]
};

private _path = _anchor getOrDefault ["trailPath", []];
if (count _path == 0) exitWith { _anchor getOrDefault ["headDist", 0] };

private _headDist = _anchor getOrDefault ["headDist", 0];
private _lastMovePos = _anchor getOrDefault ["lastAnchorMovePos", getPosATL _leader];
private _leaderPos = getPosATL _leader;

// --- 1. RECORD: grow the trail behind the walking leader -----------------------
private _moveVec = _leaderPos vectorDiff _lastMovePos;
private _moveDist = _lastMovePos distance2D _leaderPos;

// Current trail tip tangent (direction of the last recorded segment)
private _tipDir = if (count _path >= 2) then {
    ((_path select (count _path - 2)) select 0) getDir ((_path select (count _path - 1)) select 0)
} else {
    getDir _leader
};

if (_moveDist >= _recordStep) then {
    private _moveBearing = _lastMovePos getDir _leaderPos;
    private _deviation = abs ((_moveBearing - _tipDir + 180 + 360) % 360 - 180);

    // Fine-maneuver bypass: with SHORT steps (spin-inside-place, tight circling,
    // repositioning) the angular dead-zone would reject most steps and freeze
    // the trail under the leader. Small moves record unconditionally - head
    // rotations alone still never record (no displacement = no branch entry).
    private _fineManeuver = (_moveDist < 5.0);

    if (_deviation <= _maxDeviation || { _fineManeuver }) then {
        // Record the leader's position and grow the trail arclength
        _path pushBack [_leaderPos, _moveBearing];
        private _stepGain = (((_path select (count _path - 2)) select 0) distance2D _leaderPos);
        _headDist = _headDist + _stepGain;
        _anchor set ["trailPath", _path];
        _anchor set ["headDist", _headDist];
        _anchor set ["lastAnchorMovePos", _leaderPos];
    } else {
        // Deviated move: do not record, refresh the reference window
        _anchor set ["lastAnchorMovePos", _leaderPos];
    };
} else {
    // Below record threshold: refresh reference only (no drift accumulation)
    _anchor set ["lastAnchorMovePos", _lastMovePos];

    // --- 2. STOP CONVERGENCE: snap the head to the trail tip when halted -------
    if (speed _leader < 0.5 && { count _path >= 2 }) then {
        // Trail tip arclength is the total path length by construction (headDist
        // grows exactly by appended segment lengths); snap only on real lag
        private _trailLen = 0;
        for "_i" from 0 to (count _path - 2) do {
            _trailLen = _trailLen + (((_path select _i) select 0) distance2D ((_path select (_i + 1)) select 0));
        };
        if (_headDist < _trailLen) then {
            _anchor set ["headDist", _trailLen];
            _headDist = _trailLen;
        };
    };
};

// --- 3. TRIM: drop fully-consumed tail points ----------------------------------
// Generous 60m tail cushion: trimming by assigned depth alone assumes the
// rearmost group has already WALKED those points; a lagging group would cut
// corners to surviving waypoints. The cushion keeps intermediate points alive
// until even a strongly lagging group has had time to traverse them.
private _maxOffset = _anchor getOrDefault ["maxTrailOffset", 0];
if (_maxOffset > 0 && { count _path > 2 }) then {
    private _trimLimit = (_headDist - _maxOffset - 60.0) max 0; // 60m lag cushion
    if (_trimLimit > 0) then {
        private _dropCount = 0;
        private _accum = 0;
        private _kept = [];
        {
            // Drop points strictly behind the consumed limit (except the last kept
            // boundary point, which anchors interpolation for the rear slot)
            if (_accum < _trimLimit && { _forEachIndex < (count _path - 1) }) then {
                _dropCount = _dropCount + 1;
            } else {
                _kept pushBack _x;
            };
            _accum = _accum + (((_x select 0) distance2D ((_path select (_forEachIndex + 1) min (count _path - 1)) select 0)));
        } forEach _path;

        // Renumber: shift headDist by the dropped arclength so slot sampling
        // (headDist - offset) continues to address the same world points
        if (_dropCount > 0 && { count _kept >= 2 }) then {
            private _droppedLen = 0;
            for "_i" from 0 to (_dropCount - 1) do {
                _droppedLen = _droppedLen + (((_path select _i) select 0) distance2D ((_path select (_i + 1)) select 0));
            };
            _anchor set ["trailPath", _kept];
            _anchor set ["headDist", (_headDist - _droppedLen) max 0];
            diag_log format ["[FTCS][TRAIL] Trim: dropped %1 tail points (%2m), path now %3 pts.", _dropCount, _droppedLen, count _kept];
        };
    };
};

_headDist
