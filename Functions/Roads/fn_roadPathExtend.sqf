/*
    ================================================================================
    File: fn_roadPathExtend.sqf
    Module: Roads
    Author: FTCS Team
    Description: Extends an already-built sampled road path in-place with
                 straight-line points continuing the last tangent of the path.
                 Used to keep full column coverage without any runtime graph
                 re-traversal (which could pick a wrong branch at junctions).
    Params:
        0: ARRAY - Sampled road path [[posATL, tangentDir, roadWidth], ...].
        1: NUMBER - Extra meters to append beyond current path length.
        2: BOOL - Extension direction relative to the last tangent:
                  false (default) = REARWARD (opposite of last tangent, for
                  rear-oriented paths where the tail is the last element),
                  true = FORWARD (along the last tangent, for march-oriented
                  paths where the front is the last element).
    Returns:
        ARRAY - The same path array reference, extended in-place.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_path", []], ["_extraMeters", 60], ["_extendForward", false]];

if (count _path < 2) exitWith { _path };

private _lastSample = _path select (count _path - 1);
_lastSample params ["_lastPt", "_lastDir", "_width"];

// Rearward extension continues against the tangent; forward extension along it
private _extDir = if (_extendForward) then { _lastDir } else { (_lastDir + 180) % 360 };

private _steps = ceil (_extraMeters / 3.0) max 1;
private _stepLen = _extraMeters / _steps;

for "_i" from 1 to _steps do {
    private _pt = _lastPt getPos [_stepLen * _i, _extDir];
    // Tangent stays forward-oriented (rear -> front) to match path convention
    _path pushBack [_pt, _lastDir, _width];
};

_path
