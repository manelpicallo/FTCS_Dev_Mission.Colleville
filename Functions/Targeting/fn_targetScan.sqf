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

// Aim direction comes from the CAMERA (the commander's view), NOT from the
// weapon: weaponDirection depends on the weapon raise state and returns dead
// values with the weapon lowered. The view is what the commander points with.
private _eyePos = eyePos _perceiver;
private _aimDir = getCameraViewDirection _perceiver;
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

// --- 2. TERRAIN RAY (ray-march over the terrain mesh) ----------------------------
// terrainIntersectAtASL only registers a hit when the ray formally CROSSES the
// surface - near-horizontal or slightly descending rays often skim it and miss.
// Ray-marching: advance in 1m steps and stop where the aim ray drops below the
// terrain height. Always yields a point when aiming at the ground.
private _terrainDist = _maxRange + 1;
private _terrainPos = [0, 0, 0];
private _foundTerrain = false;
for "_ti" from 1 to 150 do {
    private _step = _ti * 1.0;
    // _eyePos is ASL and _aimDir is a unit vector: the probe is ALREADY in ASL.
    // (The previous ATLToASL here flattened every probe onto the ground at the
    // local column, making the height comparison always true at step 1 and
    // returning a point 5m under the commander's feet.)
    private _probeASL = _eyePos vectorAdd (_aimDir vectorMultiply _step);
    private _terrainHeight = getTerrainHeightASL _probeASL;
    if ((_probeASL select 2) <= _terrainHeight) exitWith {
        // The ray dipped below the terrain at this probe: settle on the surface
        // point directly under the probe (same X,Y, terrain height as Z)
        _terrainPos = ASLToATL [(_probeASL select 0), (_probeASL select 1), _terrainHeight];
        _terrainDist = _eyePos distance2D _terrainPos;
        _foundTerrain = true;
    };
    if (_step >= _maxRange) exitWith {};
};

// --- 3. RESOLVE THE WINNER (closest hit) -----------------------------------------
private _isObject = (_objDist < _terrainDist) && {_objDist <= _maxRange};
private _terrainValid = _foundTerrain && {_terrainDist <= _maxRange};
private _targetType = "terrain";
private _objectRef = objNull;
private _label = "Terrain";

// Neither ray produced a usable point within range
if (!_isObject && !_terrainValid) exitWith { [] };

private _impactPos = if (_isObject) then {
    _objHitPos
} else {
    // Terrain wins: project the approach onto the terrain surface height
    _terrainPos
};

if (_isObject) then {
    _impactPos = _objHitPos;
    _targetType = "object";
    _objectRef = _evaluatedObj;

    // Label resolution: unified keyword classifier over TWO text sources.
    // SOURCE A: classname (typeOf) - most objects carry a config class.
    // SOURCE B: model filename (getModelInfo) - SPE/I44 instance map objects
    //   WITHOUT a classname (typeOf returns ""): the .p3d name is the only
    //   identity those proxies carry (t_fraxinusav2s_f.p3d = ash tree,
    //   i44_telegraphpost01.p3d = telegraph post, ww2_haystack_low.p3d = hay).
    // The SAME keyword table runs over both sources in order (A then B),
    // followed by isKindOf inheritance checks and the displayName fallback.
    private _cfgName = typeOf _evaluatedObj;
    private _labelFromClass = { params ["_c"]; getText (configFile >> "CfgVehicles" >> _c >> "displayName") };

    // Keyword table: [needleA, needleB..., label]. Case-insensitive substring
    // match; first table row whose needles hit wins (order = specificity).
    private _kwTable = [
        [["telegraph", "telephone"], "Telegraph Post"],
        [["lamp", "laterne", "lampe", "lapmpost"], "Lamp Post"],
        [["mound", "tertre"], "Earth Mound"],
        [["power", "podstavec", "electric", "utility", "pole"], "Power Pole"],
        [["stone", "kamen", "boulder"], "Stone"],
        [["rock", "skala"], "Rock"],
        [["hay", "straw", "slama"], "Haystack"],
        [["hedge", "brush", "shrub"], "Bush"],
        [["fence", "plot", "zed", "barrier", "fance", "pance"], "Fence"],
        [["wall", "muro", "sten"], "Wall"],
        [["well", "studna"], "Well"],
        [["barrel", "beco", "drum"], "Barrel"],
        [["crate", "box", "ammobox"], "Crate"],
        [["sign", "tabule"], "Sign"],
        [["ruin", "rubble", "zricenina"], "Ruins"],
        [["trench", "hedgehog", "obstacle", "obelisk"], "Obstacle"],
        [["pipes", "pipe", "trub"], "Pipes"],
        [["tent", "stan"], "Tent"],
        [["grave", "cross", "hrob"], "Grave"],
        [["tree", "oak", "birch", "pine", "spruce", "fraxinus", "quercus", "pinus", "betula"], "Tree"]
    ];

    private _fnc_kwMatch = {
        params ["_text", "_tbl"];
        private _low = toLower _text;
        private _result = "";
        { 
            private _row = _x;
            { if (_low find _x >= 0) exitWith { _result = (_row select 1); }; } forEach (_row select 0);
            if (_result != "") exitWith {};
        } forEach _tbl;
        _result
    };

    // Model filename (only queried when needed - instanced objects)
    private _modelName = "";
    if (_cfgName == "") then {
        private _mi = getModelInfo _evaluatedObj;
        _modelName = _mi param [0, ""];
    };

    // RESOLUTION PIPELINE
    private _resolved = "";
    if (_cfgName != "") then {
        // SOURCE A: class inheritance first (highest confidence)
        if (_evaluatedObj isKindOf "Tree") exitWith { _resolved = "Tree"; };
        if (_evaluatedObj isKindOf "Rock" || _evaluatedObj isKindOf "Rocks" || _evaluatedObj isKindOf "Stone") exitWith { _resolved = "Rock"; };
        if (_evaluatedObj isKindOf "Bush") exitWith { _resolved = "Bush"; };
        if (_evaluatedObj isKindOf "AllVehicles") exitWith {
            _resolved = ([_cfgName] call _labelFromClass);
            if (_resolved == "") then { _resolved = "Vehicle"; };
        };
        // SOURCE A: keyword match over the classname
        _resolved = [_cfgName, _kwTable] call _fnc_kwMatch;
        if (_resolved == "") then {
            _resolved = ([_cfgName] call _labelFromClass);
            if (_resolved == "") then { _resolved = _cfgName; };
        };
    } else {
        // SOURCE B: instanced object without classname - classify by model name
        _resolved = [_modelName, _kwTable] call _fnc_kwMatch;
        if (_resolved == "") then {
            // Prefix heuristic: t_ = tree, b_ = bush (BI vegetation convention)
            if (_modelName find "t_" == 0) exitWith { _resolved = "Tree"; };
            if (_modelName find "b_" == 0) exitWith { _resolved = "Bush"; };
            // Raw model name as last resort before "Object": strip the path and
            // extension, and remove mod-prefix tokens (i44_, ww2_, spe_...) plus
            // technical suffixes (_f, _01, _02, sizes) so the player sees a clean
            // word ("haystack", "telegraphpost") instead of "ww2_s_fance_tall".
            private _base = _modelName;
            if (_base != "") then {
                // filename only: Arma model paths are backslash-separated
                // ("\ww2\obj.p3d"), so one separator suffices. The escaped
                // "\"\"" literal is the safe way to write a lone backslash.
                private _parts = _base splitString "\\";
                _base = _parts select (count _parts - 1);
                _base = (_base splitString ".") select 0;                                       // drop .p3d
                private _tokens = _base splitString "_";
                private _clean = [];
                { 
                    private _tk = toLower _x;
                    if (!(_tk in ["ww2", "i44", "spe", "ifr", "a2", "gm"])) then {
                        if (!(_tk regexMatch "^[0-9]+.*$")) then {     // 01, 02, 8m sizes
                            if (_tk != "f" && {_tk != "v"}) then { _clean pushBack _x; };
                        };
                    };
                } forEach _tokens;
                _resolved = _clean joinString "_";
            };
        };
    };
    _label = if (_resolved != "") then { _resolved } else { "Object" };
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
