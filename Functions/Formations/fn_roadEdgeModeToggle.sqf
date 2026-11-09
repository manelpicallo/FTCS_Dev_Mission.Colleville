/*
    ================================================================================
    File: fn_roadEdgeModeToggle.sqf
    Module: Formations
    Author: FTCS Team
    Description: Stepped edge-margin control for the road march column.
                 Manages an integer step counter ("edgeMarginSteps") on the anchor:
                   0 steps  = ON_ROAD   (shoulder slots on the asphalt edges,
                                          85% of the half-width, as at formation time)
                   1+ steps = OFF_ROAD  (shoulder slots pushed (steps * 2m) BEYOND
                                          the road edge, same side preserved,
                                          capped at 4 steps = 8m)
                 Commands (delta):
                   +1  = PUSH OUT:  margin += 2m  (repeatable, cumulative)
                   -1  = PULL IN:   margin -= 2m  (floored at 0 = back on-road)
                    0  = RESET:      margin = 0    (immediate return to the road)
                 Mechanism: only registry offsets are rewritten (roadShoulderOffset /
                 roadTargetPos); runtime consumers (formationsGroupFollowRoad and
                 the live debug worker) re-sample the frozen anchor path
                 transparently on their next tick, so the column physically walks
                 to its new positions - no teleport, no path rebuild.
                 Center-trailed (shoulder == 0) and forward (offset <= 0) groups
                 are NOT touched.
                 The step counter is preserved by junction re-anchors; only the
                 explicit commands change it.
    Params:
        0: NUMBER - Platoon ID whose road march anchor owns the layout.
        1: NUMBER - Delta steps: +1 (push out 2m), -1 (pull in 2m), 0 (reset to road).
    Returns:
        NUMBER - Count of re-positioned groups (-1 if no active road column).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_pltId", 1], ["_deltaSteps", 1]];

private _stepMeters = 3.0;     // meters per margin step
private _maxSteps = 4;         // hard cap: 4 levels = 8m maximum standoff
private _onRoadFactor = 0.85;  // matches the staggered/compact shoulder factor

private _anchor = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltId], createHashMap];
private _roadPath = _anchor getOrDefault ["roadPath", []];
if (count _roadPath < 2) exitWith {
    systemChat "[ROAD EDGE] Error: no active road march column (anchor missing).";
    -1
};

// Compute the new step level (floored at 0, capped at _maxSteps)
private _currentSteps = _anchor getOrDefault ["edgeMarginSteps", 0];
private _newSteps = switch (true) do {
    case (_deltaSteps > 0): { (_currentSteps + 1) min _maxSteps };
    case (_deltaSteps < 0): { (_currentSteps - 1) max 0 };
    default { 0 };
};

private _margin = _newSteps * _stepMeters;
private _headDist = _anchor getOrDefault ["headDist", 0];

// Sampler: interpolate along the march-oriented path at arclength
private _fnc_getRoadSampleLocal = {
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

// Rewrite every participating shoulder group according to the new margin level
private _assignedCount = 0;
{
    private _grpId = _x;
    private _entry = _y;
    private _offsetDist = _entry getOrDefault ["roadOffsetDist", -1];
    private _currentShoulder = _entry getOrDefault ["roadShoulderOffset", 0];

    // Same participation criteria as Compact: rear-marching shoulder teams only
    if (_offsetDist > 0 && {_currentShoulder != 0}) then {
        private _sideSign = if (_currentShoulder < 0) then { -1 } else { 1 };

        // Absolute arclength of this slot on the march-oriented path
        private _absArc = (_headDist - _offsetDist) max 0;
        private _sample = [_absArc, _roadPath] call _fnc_getRoadSampleLocal;
        _sample params ["_centerPos", "_tangent", "_width"];
        private _effectiveWidth = if (_width isEqualType 0 && {_width > 0}) then { _width } else { 4.5 };

        // Target offset: on-road shoulder edge, or that edge plus the stepped margin
        private _newShoulder = if (_margin <= 0) then {
            ((_effectiveWidth / 2.0) * _onRoadFactor) * _sideSign
        } else {
            (((_effectiveWidth / 2.0) + _margin) * _sideSign)
        };

        // Perpendicular offset from the road center line
        private _perpDir = (_tangent + 90) % 360;
        private _finalPos = _centerPos getPos [abs _newShoulder, if (_newShoulder < 0) then { (_perpDir + 180) % 360 } else { _perpDir }];

        _entry set ["roadShoulderOffset", _newShoulder];
        _entry set ["roadTargetPos", _finalPos];
        _entry set ["roadTangentDir", _tangent];
        FTCS_Groups_Registry_Table set [_grpId, _entry];

        _assignedCount = _assignedCount + 1;
    };
} forEach FTCS_Groups_Registry_Table;

_anchor set ["edgeMarginSteps", _newSteps];

systemChat format ["[ROAD EDGE] Margin level %1 (%2m) - %3 groups re-positioned.", _newSteps, _margin, _assignedCount];
_assignedCount
