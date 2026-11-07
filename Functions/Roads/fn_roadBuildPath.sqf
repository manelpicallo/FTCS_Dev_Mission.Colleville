/*
    ================================================================================
    File: fn_roadBuildPath.sqf
    Module: Roads
    Author: FTCS Team
    Description: Builds a continuous sequence of road waypoints starting from an initial
                 road segment and progressing backwards (in the direction opposite to
                 the platoon leader's facing), traversing connected road segments.
    Params:
        0: OBJECT - Starting road segment.
        1: NUMBER - Required total path distance in meters (e.g. 150m for platoon depth).
        2: NUMBER - Desired forward advance direction (troops deploy behind this heading).
    Returns:
        ARRAY of ARRAY: [[posATL, tangentDir, roadWidth], ...] sampled every ~3 to 5m.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params ["_startRoad", ["_requiredDistance", 200], ["_forwardHeading", 0]];

if (isNull _startRoad) exitWith { [] };

private _visited = [_startRoad];
private _currentSegment = _startRoad;
private _rawWaypoints = [getPosATL _startRoad];
private _accumulatedDist = 0;

// Rearward direction is opposite of forward heading
private _rearHeading = (_forwardHeading + 180) % 360;

// Traverse connected road segments towards rearward direction
while {_accumulatedDist < _requiredDistance} do {
    private _connected = roadsConnectedTo _currentSegment;
    private _candidates = _connected - _visited;

    if (count _candidates == 0) exitWith {};

    // Select candidate that best aligns with the rearward progression vector
    private _currentPos = getPosATL _currentSegment;
    private _bestCandidate = objNull;
    private _bestDiff = 999;

    {
        private _candPos = getPosATL _x;
        private _candBearing = _currentPos getDir _candPos;
        // Compare with rear heading: smallest angular difference means continuing backwards along road
        private _diff = abs ((_candBearing - _rearHeading + 180 + 360) % 360 - 180);
        if (_diff < _bestDiff) then {
            _bestDiff = _diff;
            _bestCandidate = _x;
        };
    } forEach _candidates;

    if (isNull _bestCandidate) exitWith {};

    private _nextPos = getPosATL _bestCandidate;
    private _stepDist = _currentPos distance2D _nextPos;
    _accumulatedDist = _accumulatedDist + _stepDist;
    _rawWaypoints pushBack _nextPos;
    _visited pushBack _bestCandidate;
    _currentSegment = _bestCandidate;

    // Update rear heading along road curvature to handle bends smoothly
    _rearHeading = _currentPos getDir _nextPos;
};

// Interpolate waypoints into densely sampled points (~3m spacing) with tangents and road widths
private _sampledPath = [];
private _startInfo = getRoadInfo _startRoad;
private _defaultWidth = if (count _startInfo > 1) then { _startInfo select 1 } else { 3.5 };

if (_accumulatedDist < _requiredDistance) then {
    // Project along last rear heading to fulfill full requested distance
    private _lastPt = _rawWaypoints select (count _rawWaypoints - 1);
    for "_d" from 3 to (_requiredDistance - _accumulatedDist) step 3 do {
        _rawWaypoints pushBack (_lastPt getPos [_d, _rearHeading]);
    };
};

for "_i" from 0 to (count _rawWaypoints - 2) do {
    private _pA = _rawWaypoints select _i;
    private _pB = _rawWaypoints select (_i + 1);
    private _segDist = _pA distance2D _pB;
    private _segDir = _pB getDir _pA; // Forward orientation along road (from rear to front)
    private _steps = ceil (_segDist / 3.0) max 1;
    private _stepFrac = 1.0 / _steps;

    for "_s" from 0 to (_steps - 1) do {
        private _t = _s * _stepFrac;
        private _pt = [
            (_pA select 0) + ((_pB select 0) - (_pA select 0)) * _t,
            (_pA select 1) + ((_pB select 1) - (_pA select 1)) * _t,
            (_pA select 2) + ((_pB select 2) - (_pA select 2)) * _t
        ];
        _sampledPath pushBack [_pt, _segDir, _defaultWidth];
    };
};

_sampledPath
