/*
    ================================================================================
    File: fn_targetScan.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Perception engine for commander-aimed world targeting.
                 Casts a ray from the caller's eye along his aim direction and
                 resolves what is found within the search range:
                 - OBJECT ray (lineIntersectsSurfaces): houses, walls, vehicles,
                   trees, rocks... First hit wins.
                 - TERRAIN ray (terrainIntersectAtASL): the ground mesh point.
                 The CLOSEST of the two hits wins (aiming at a tree near ground
                 level must return the tree, not the terrain behind it).
                 Object labels are resolved by classification (Tree / Rock /
                 House / Vehicle / generic class name) because many objects
                 have no displayName in their config.
                 Large objects generate an APPROACH POINT pulled back towards
                 the perceiver (aiming "at a house" = "stop in front of it").
                 PURE perception: no UI, no globals, no state.
    Params:
        0: OBJECT - Perceiver unit (uses eyePos + aim direction).
        1: NUMBER - Max detection range in meters (default 150).
        2: NUMBER - Approach distance from large objects in meters (default 9).
    Returns:
        ARRAY - Target tuple or [] when nothing is hit within range:
            [isObject, targetType, objectRef, approachPos, impactPos,
             distance, bearing, label]
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_perceiver", objNull], ["_maxRange", 150], ["_approachDistance", 9]];

if (isNull _perceiver) exitWith { [] };

private _eyePos = eyePos _perceiver;
private _aimDir = _perceiver weaponDirection (currentWeapon _perceiver);
if (_aimDir isEqualTo [0, 0, 0]) then { _aimDir = vectorDir _perceiver; };
private _aimEnd = _eyePos vectorAdd (_aimDir vectorMultiply _maxRange);

// --- 1. OBJECT RAY --------------------------------------------------------------
private _objDist = _maxRange + 1;
private _evaluatedObj = objNull;
private _objHitPos = [0, 0, 0];

private _intersections = lineIntersectsSurfaces [_eyePos, _aimEnd, _perceiver, objNull, true, 1, "VIEW", "FIRE"];
if (count _intersections > 0) then {
    private _firstHit = _intersections select 0;
    _firstHit params ["_intersectPosASL", "_hitNormal", "_hitObj", "_parentObj"];
    _evaluatedObj = if (!isNull _hitObj) then { _hitObj } else { _parentObj };
    if (!isNull _evaluatedObj) then {
        _objHitPos = ASLToATL _intersectPosASL;
        _objDist = _eyePos distance2D _objHitPos;
    };
};

// --- 2. TERRAIN RAY -------------------------------------------------------------
private _terrainDist = _maxRange + 1;
private _terrainPos = [0, 0, 0];
private _terrainHit = terrainIntersectAtASL [_eyePos, _aimEnd];
if (!(_terrainHit isEqualTo [0, 0, 0]) && { (_terrainHit distance2D [0, 0, 0]) > 0 }) then {
    _terrainPos = ASLToATL _terrainHit;
    _terrainDist = _eyePos distance2D _terrainPos;
};

// --- 3. RESOLVE THE WINNER (closest hit) -----------------------------------------
private _isObject = _objDist < _terrainDist;
private _targetType = "terrain";
private _objectRef = objNull;
private _label = "Terrain";
private _impactPos = _terrainPos;

if (_isObject) then {
    _impactPos = _objHitPos;
    _targetType = "object";
    _objectRef = _evaluatedObj;

    // Label resolution by classification (many objects lack displayName).
    // Three fallbacks in order: kindOf class -> parent class -> raw typeOf,
    // so map-placed objects without config names still get a useful label.
    private _cfgName = typeOf _evaluatedObj;
    private _labelFromClass = { params ["_c"]; getText (configFile >> "CfgVehicles" >> _c >> "displayName") };
    if (_evaluatedObj isKindOf "Tree") then {
        _label = "Tree";
    } else {
        if (_evaluatedObj isKindOf "Rock" || _evaluatedObj isKindOf "Rocks" || _evaluatedObj isKindOf "Stone") then {
            _label = "Rock";
        } else {
            if (_evaluatedObj isKindOf "Bush") then {
                _label = "Bush";
            } else {
                if (_evaluatedObj isKindOf "House" || _evaluatedObj isKindOf "Building" || _evaluatedObj isKindOf "Thing") then {
                    _label = ([_cfgName] call _labelFromClass);
                    if (_label == "") then { _label = "Object"; };
                } else {
                    if (_evaluatedObj isKindOf "AllVehicles") then {
                        _label = ([_cfgName] call _labelFromClass);
                        if (_label == "") then { _label = "Vehicle"; };
                    } else {
                        _label = ([_cfgName] call _labelFromClass);
                        if (_label == "") then { _label = _cfgName; };
                        if (_label == "") then { _label = "Object"; };
                    };
                };
            };
        };
    };
};

private _distance = _eyePos distance2D _impactPos;

// --- 4. APPROACH POINT -----------------------------------------------------------
private _approachPos = +_impactPos;

if (_isObject) then {
    // Large objects: pull the approach point back towards the perceiver so the
    // squad stops IN FRONT of the object, not on top of it. Trees/bushes are
    // thin: no pull-back needed for them.
    private _isTree = _evaluatedObj isKindOf "Tree" || _evaluatedObj isKindOf "Bush";
    private _pullBack = !_isTree;

    if (_pullBack) then {
        private _bb = boundingBoxReal _evaluatedObj;
        private _bbSize = ((_bb select 1) vectorDiff (_bb select 0));
        private _largestDim = (_bbSize select 0) max (_bbSize select 1) max (_bbSize select 2);
        private _pull = _approachDistance max (_largestDim / 2.0);

        private _dirToPerceiver = _eyePos vectorDiff _impactPos;
        _dirToPerceiver set [2, 0];
        private _pullLen = _dirToPerceiver distance2D [0, 0, 0];
        if (_pullLen > 0) then {
            _approachPos = _impactPos vectorAdd (_dirToPerceiver vectorMultiply (_pull / _pullLen));
            _approachPos set [2, getTerrainHeightASL (ATLToASL _approachPos)];
        };
    } else {
        _approachPos set [2, getTerrainHeightASL (ATLToASL _impactPos)];
    };
};

private _bearing = (_eyePos getDir _approachPos);

[
    _isObject,            // 0: isObject
    _targetType,          // 1: targetType ("terrain" | "object")
    _objectRef,           // 2: objectRef (objNull for terrain)
    _approachPos,         // 3: approachPos ATL (where to move to)
    _impactPos,           // 4: impactPos ATL (what was actually hit)
    _distance,            // 5: distance
    _bearing,             // 6: bearing from perceiver
    _label                // 7: human-readable label
]
