/*
    ================================================================================
    File: fn_roadAdvanceAnchor.sqf
    Module: Roads
    Author: FTCS Team
    Description: Sole owner of the road march anchor progression. Tracks the
                 platoon leader's march position (headDist, arclength along the
                 frozen march-oriented path) by projecting the leader's real
                 displacement (delta movement, NOT head facing) onto the local
                 path tangent at the current head position.
                 Design rules (Option A - fixed global sense):
                 - Path is march-oriented: index 0 = rearmost point, last index
                   = frontmost point. Built ONCE at order time; runtime never
                   re-decides direction, never re-traverses the road graph, and
                   never inverts slots regardless of leader head turns.
                 - Slots sample at (headDist - offsetDist): as the leader
                   advances, every slot slides FORWARD along the road, keeping
                   each group always offsetDist meters behind the leader.
                 - Angular dead-zone: if the leader's real movement direction
                   deviates more than _maxDeviation from the local tangent, the
                   head does NOT advance (erratic walking or spinning in place
                   is ignored).
                 - Junction handling (ALL conditions required simultaneously - AND):
                   (1) real movement bearing deviates beyond the dead-zone,
                   (2) cumulative real displacement since deviation start >= 15 m,
                   (3) a road segment exists within 20 m of the leader position.
                   All timing is measured in SIMULATION time (mission 'time' and
                   the anchor thread's 'sleep'); when the AND holds for
                   _reanchorDelay simulation seconds, the column re-anchors onto
                   the new road branch via FTCS_fnc_roadReanchor.
                  - Stop convergence: when the leader comes to a halt (< 0.5 km/h),
                   headDist snaps to the arclength of the nearest path sample,
                   eliminating the residual lag accumulated by the incremental
                   projection at high march speed (velocity x tick + discarded
                   sub-threshold tail), so static slots rest at their true
                   distance behind the leader.
    Params:
        0: OBJECT - Platoon leader unit (displacement source).
        1: HASHMAP - Road march anchor: { anchorPos, advanceDir, roadPath, headDist, lastAnchorMovePos, devStart, devAccumDist }
                     Modified in-place (headDist / lastAnchorMovePos updated,
                     or fully rebuilt by roadReanchor on junction turn).
        2: NUMBER - Minimum forward step in meters to register progress (default 2).
        3: NUMBER - Maximum angular deviation from local tangent in degrees (default 60).
    Returns:
        NUMBER - Updated headDist (arclength of the leader along the path).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_leader", objNull], ["_anchor", locationNull], ["_minStep", 2.0], ["_maxDeviation", 60]];

if (isNull _leader || { _anchor isEqualTo locationNull } || { count (_anchor getOrDefault ["roadPath", []]) < 2 }) exitWith {
    _anchor getOrDefault ["headDist", 0]
};

private _path = _anchor getOrDefault ["roadPath", []];
private _headDist = _anchor getOrDefault ["headDist", 0];
private _lastMovePos = _anchor getOrDefault ["lastAnchorMovePos", getPosATL _leader];
private _leaderPos = getPosATL _leader;
private _reanchorDelay = 3.0;   // simulation seconds of sustained deviation (mission 'time')
private _reanchorMinDist = 15.0; // cumulative real meters moved since deviation start

// Helper: interpolate along the polyline at a given arclength distance
private _fnc_sampleAt = {
    params ["_distTarget", "_path"];
    private _accum = 0;
    private _foundPt = _path select 0;
    for "_i" from 0 to (count _path - 2) do {
        private _ptA = (_path select _i) select 0;
        private _ptB = (_path select (_i + 1)) select 0;
        private _d = _ptA distance2D _ptB;
        if ((_accum + _d) >= _distTarget) exitWith {
            private _frac = if (_d > 0) then { (_distTarget - _accum) / _d } else { 0 };
            _foundPt = [
                [
                    (_ptA select 0) + ((_ptB select 0) - (_ptA select 0)) * _frac,
                    (_ptA select 1) + ((_ptB select 1) - (_ptA select 1)) * _frac,
                    (_ptA select 2) + ((_ptB select 2) - (_ptA select 2)) * _frac
                ],
                (_path select _i) select 1,
                (_path select _i) select 2
            ];
        };
        _accum = _accum + _d;
    };
    _foundPt
};

// Local tangent at current head point (tangent is march-oriented: rear -> front)
private _sample = [_headDist, _path] call _fnc_sampleAt;
private _localTangent = _sample select 1;

// Real displacement vector of the leader since last accepted step
private _moveVec = _leaderPos vectorDiff _lastMovePos;
private _moveDist = _lastMovePos distance2D _leaderPos;

if (_moveDist >= _minStep) then {
    // Angular dead-zone: compare real movement bearing against local tangent
    private _moveBearing = _lastMovePos getDir _leaderPos;
    private _deviation = abs ((_moveBearing - _localTangent + 180 + 360) % 360 - 180);

    if (_deviation <= _maxDeviation) then {
        // Deviation ended: reset junction persistence accumulators
        _anchor set ["devStart", -1];
        _anchor set ["devAccumDist", 0];

        // Project displacement onto tangent direction (pure scalar 2D math,
        // avoiding vectorDot after array literals which SQF preprocessor misparses)
        private _dx = _moveVec select 0;
        private _dy = _moveVec select 1;
        private _projection = (_dx * (sin _localTangent)) + (_dy * (cos _localTangent));

        // Total arclength of the path (upper clamp for the head position)
        private _maxDist = 0;
        for "_pi" from 0 to (count _path - 2) do {
            _maxDist = _maxDist + (((_path select _pi) select 0) distance2D ((_path select (_pi + 1)) select 0));
        };

        // March sense: positive projection advances the head; negative projection
        // (leader walking backwards along the road) pulls the head back
        private _newDist = _headDist + _projection;
        if (_newDist < 0) then { _newDist = 0; };
        if (_newDist > _maxDist) then { _newDist = _maxDist; };
        _anchor set ["headDist", _newDist];
        _anchor set ["lastAnchorMovePos", _leaderPos];
        _headDist = _newDist;
    } else {
        // ---- Junction trigger evaluation: AND of the three conditions ----
        // (1) sustained deviation: measured in SIMULATION time (mission 'time')
        private _devStart = _anchor getOrDefault ["devStart", -1];
        private _devAccumDist = _anchor getOrDefault ["devAccumDist", 0];

        if (_devStart < 0) then {
            // Deviation just started: open the window and start accumulating distance
            _anchor set ["devStart", time];
            _anchor set ["devAccumDist", _moveDist];
        } else {
            // (2) accumulate real displacement while the deviation persists
            _devAccumDist = _devAccumDist + _moveDist;
            _anchor set ["devAccumDist", _devAccumDist];

            // (3) road branch available near the leader
            private _nearRoads = _leaderPos nearRoads 20;
            private _condRoad = (count _nearRoads > 0);

            if ((time - _devStart) >= _reanchorDelay
                && _devAccumDist >= _reanchorMinDist
                && _condRoad) then {
                private _ok = [_leader, _anchor, _moveBearing] call FTCS_fnc_roadReanchor;
                if (_ok) then {
                    systemChat "[ROAD MARCH] Junction turn detected - column re-anchored to new road bearing.";
                };
                // Reset window either way: on success the anchor is new; on failure
                // (road check passed inside but branch unusable) retry after a fresh window
                _anchor set ["devStart", -1];
                _anchor set ["devAccumDist", 0];
            };
        };
    };
} else {
    // Below minimum step: keep last accepted position and reset accumulators
    // (spinning in place / standing with head turned never triggers re-anchor)
    _anchor set ["lastAnchorMovePos", _lastMovePos];
    _anchor set ["devStart", -1];
    _anchor set ["devAccumDist", 0];

    // Stop convergence: when the leader comes to a halt, the incremental projection
    // may have left headDist lagging behind his real position (velocity x tick +
    // discarded sub-threshold tail). Snap the head to the arclength of the nearest
    // path sample so the static column slots sit at their true distance behind him.
    if (speed _leader < 0.5) then {
        private _bestArc = 0;
        private _bestDist = 1e10;
        private _accum = 0;
        private _count = count _path;
        for "_si" from 0 to (_count - 1) do {
            private _pt = (_path select _si) select 0;
            private _d = _pt distance2D _leaderPos;
            if (_d < _bestDist) then { _bestDist = _d; _bestArc = _accum; };
            if (_si < (_count - 1)) then {
                _accum = _accum + (_pt distance2D ((_path select (_si + 1)) select 0));
            };
        };
        _anchor set ["headDist", _bestArc];
        _headDist = _bestArc;
    };
};

_headDist
