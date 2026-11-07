/*
    ================================================================================
    File: fn_roadGetPointsBehind.sqf
    Module: Roads
    Author: FTCS Team
    Description: Given a reference leader position and heading, traverses connected
                 road segments backward along the road corridor, producing a continuous
                 spline/polyline of waypoints following actual curves of the asphalt.
    Params:
        0: OBJECT or ARRAY - Platoon Leader unit or current position.
        1: NUMBER - Total depth required in meters behind leader (e.g. 200m).
    Returns:
        ARRAY of ARRAY: [[centerPosATL, tangentDir, roadWidth], ...] sampled every ~2 to 3m.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_leaderRef", player], ["_totalDepth", 220]];

private _leaderPos = if (_leaderRef isEqualType objNull) then { getPosATL _leaderRef } else { _leaderRef };
private _leaderDir = if (_leaderRef isEqualType objNull) then { getDir _leaderRef } else { 0 };

// Find nearest road segment under or immediately behind leader
private _nearRoads = _leaderPos nearRoads 20;
if (count _nearRoads == 0) exitWith { [] };

private _startRoad = [_nearRoads, _leaderPos] call BIS_fnc_nearestPosition;
private _startPos = getPosATL _startRoad;

// Desired progression vector is to the rear of the leader
// If connected segments exist, resolve initial rear heading along road tangent to avoid head turn jitter
private _rearHeading = (_leaderDir + 180) % 360;
private _startConnected = roadsConnectedTo _startRoad;
if (count _startConnected > 0) then {
    private _bestStartDiff = 999;
    private _bestStartDir = _rearHeading;
    {
        private _candBearing = _startPos getDir (getPosATL _x);
        private _diff = abs ((_candBearing - _rearHeading + 180 + 360) % 360 - 180);
        if (_diff < _bestStartDiff) then {
            _bestStartDiff = _diff;
            _bestStartDir = _candBearing;
        };
    } forEach _startConnected;
    _rearHeading = _bestStartDir;
};

private _visited = [_startRoad];
private _currentSegment = _startRoad;
private _rawPoints = [_startPos];
private _accumDist = 0;

while {_accumDist < _totalDepth} do {
    private _connected = roadsConnectedTo _currentSegment;
    private _candidates = _connected - _visited;

    if (count _candidates == 0) exitWith {};

    private _cPos = getPosATL _currentSegment;
    private _bestCand = objNull;
    private _bestDiff = 999;

    {
        private _candPos = getPosATL _x;
        private _bearing = _cPos getDir _candPos;
        private _diff = abs ((_bearing - _rearHeading + 180 + 360) % 360 - 180);
        if (_diff < _bestDiff) then {
            _bestDiff = _diff;
            _bestCand = _x;
        };
    } forEach _candidates;

    if (isNull _bestCand) exitWith {};

    private _nextPos = getPosATL _bestCand;
    private _d = _cPos distance2D _nextPos;
    _accumDist = _accumDist + _d;
    _rawPoints pushBack _nextPos;
    _visited pushBack _bestCand;
    _currentSegment = _bestCand;
    _rearHeading = _cPos getDir _nextPos; // follow curvature
};

// If only 1 segment found or total depth not reached by segments, project backwards along last rear heading
if (_accumDist < _totalDepth) then {
    private _lastPt = _rawPoints select (count _rawPoints - 1);
    for "_step" from 3 to (_totalDepth - _accumDist) step 3 do {
        _rawPoints pushBack (_lastPt getPos [_step, _rearHeading]);
    };
};

// Interpolate waypoints into densely sampled points (~2m spacing) with forward tangents
private _sampledPath = [];

for "_i" from 0 to (count _rawPoints - 2) do {
    private _pA = _rawPoints select _i;
    private _pB = _rawPoints select (_i + 1);
    private _segDist = _pA distance2D _pB;
    private _segDir = _pB getDir _pA; // Forward orientation (towards leader)
    private _steps = ceil (_segDist / 2.0) max 1;
    private _stepFrac = 1.0 / _steps;

    for "_s" from 0 to (_steps - 1) do {
        private _t = _s * _stepFrac;
        private _pt = [
            (_pA select 0) + ((_pB select 0) - (_pA select 0)) * _t,
            (_pA select 1) + ((_pB select 1) - (_pA select 1)) * _t,
            (_pA select 2) + ((_pB select 2) - (_pA select 2)) * _t
        ];
        _sampledPath pushBack [_pt, _segDir, 4.0];
    };
};

_sampledPath
