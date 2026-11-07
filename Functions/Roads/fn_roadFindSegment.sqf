/*
    ================================================================================
    File: fn_roadFindSegment.sqf
    Module: Roads
    Author: FTCS Team
    Description: Locates the nearest road segment either from a specified position or
                 from where the player is looking (screen crosshair / cursor raycast).
                 Analyzes road dimensions and suitability for infantry staggered column.
    Params:
        0: OBJECT or ARRAY - Reference origin (player / unit object or [x,y,z] position).
        1: NUMBER - Search radius in meters (default: 25).
    Returns:
        ARRAY: [
            0: OBJECT (road segment, objNull if none found),
            1: NUMBER (road width in meters),
            2: NUMBER (road heading/direction in degrees),
            3: STRING ("ROAD" if width >= 2.0m, "TRAIL" if narrower, "NONE" if no road)
        ]
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_origin", player], ["_searchRadius", 25]];

private _searchPos = [0, 0, 0];

if (_origin isEqualType objNull) then {
    if (!isNull _origin) then {
        // Check if cursor raycast / line of sight hits terrain or a surface nearby
        private _ins = lineIntersectsSurfaces [
            eyePos _origin,
            (eyePos _origin) vectorAdd ((_origin weaponDirection currentWeapon _origin) vectorMultiply 50),
            _origin,
            objNull,
            true,
            1,
            "GEOM",
            "FIRE"
        ];

        if (count _ins > 0) then {
            _searchPos = (_ins select 0) select 0;
            // Only use look-at pos if close to a road, otherwise fallback to player position
            private _roadsAtLook = _searchPos nearRoads 8;
            if (count _roadsAtLook == 0) then {
                _searchPos = getPosATL _origin;
            };
        } else {
            _searchPos = getPosATL _origin;
        };
    } else {
        _searchPos = getPosATL player;
    };
} else {
    if (_origin isEqualType []) then {
        _searchPos = _origin;
    };
};

// Search for road segments in radius
private _nearRoads = _searchPos nearRoads _searchRadius;

if (count _nearRoads == 0) exitWith {
    [objNull, 0, 0, "NONE"]
};

// Select closest road segment to search position
private _closestRoad = [_nearRoads, _searchPos] call BIS_fnc_nearestPosition;

// Analyze road segment attributes via getRoadInfo and bounding box fallback
private _roadInfo = getRoadInfo _closestRoad;
// In Arma 3, getRoadInfo returns: [mapType, width, isPedestrian, texture, end1, end2, maxSpeed, isBridge]
// On C44/Spearhead maps or certain Arma 3 versions, index 1 can be a string class name or 0.
private _rawWidth = if (count _roadInfo > 1) then { _roadInfo select 1 } else { 0 };
private _width = 0;

if (_rawWidth isEqualType 0 && {_rawWidth > 0}) then {
    _width = _rawWidth;
} else {
    // Determine road width from 3D bounding box geometry of the road object
    private _bb = boundingBoxReal _closestRoad;
    private _dx = abs (((_bb select 1) select 0) - ((_bb select 0) select 0));
    private _dy = abs (((_bb select 1) select 1) - ((_bb select 0) select 1));
    private _smallerDim = _dx min _dy;
    _width = if (_smallerDim > 0.5) then { _smallerDim } else { 4.5 };
};

// Calculate road segment tangent direction from end1 to end2
// In Arma 3, getRoadInfo returns: [mapType, width, isPedestrian, texture, end1, end2, maxSpeed, isBridge]
// where end1 is index 4, end2 is index 5.
private _roadDir = 0;
if (count _roadInfo >= 6) then {
    private _end1 = _roadInfo select 4;
    private _end2 = _roadInfo select 5;
    if (_end1 isEqualType [] && {_end2 isEqualType []}) then {
        _roadDir = _end1 getDir _end2;
    } else {
        // Fallback: direction between connected segments
        private _connected = roadsConnectedTo _closestRoad;
        if (count _connected > 0) then {
            _roadDir = (getPosATL _closestRoad) getDir (getPosATL (_connected select 0));
        } else {
            _roadDir = getDir _closestRoad;
        };
    };
} else {
    private _connected = roadsConnectedTo _closestRoad;
    if (count _connected > 0) then {
        _roadDir = (getPosATL _closestRoad) getDir (getPosATL (_connected select 0));
    } else {
        _roadDir = getDir _closestRoad;
    };
};

// Road classification: width > 1.0m is ROAD (staggered column allowed); <= 1.0m is TRAIL (single file)
private _roadCategory = if (_width > 1.0) then { "ROAD" } else { "TRAIL" };

[_closestRoad, _width, _roadDir, _roadCategory]
