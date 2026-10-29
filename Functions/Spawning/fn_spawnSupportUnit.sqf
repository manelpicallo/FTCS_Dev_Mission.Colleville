/*
    ================================================================================
    File: fn_spawnSupportUnit.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Spawns attached support units (fixed artillery or mobile armored assets).
                 Fixed support is positioned at a designated editor marker; mobile support
                 is positioned in the main deployment area. Integrates spawned vehicles
                 and groups into the FTCS core registry.
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) OOP port.
    ================================================================================
*/

params [
    ["_supportData", createHashMap],
    ["_targetPos", [0, 0, 0]],
    ["_advanceDir", 0],
    ["_factionSide", side group player]
];

if (count _supportData == 0) exitWith {
    diag_log "FTCS Support Spawn Error: Empty support data HashMap.";
    false;
};

if (_factionSide == civilian || _factionSide == sideUnknown) then { _factionSide = west; };

private _supportId    = _supportData getOrDefault ["supportID", "SUPPORT_ASSET"];
private _name         = _supportData getOrDefault ["name", "Support Element"];
private _isStatic     = _supportData getOrDefault ["isStatic", false];
private _requiredMods = _supportData getOrDefault ["requiredMods", []];
private _entities     = _supportData getOrDefault ["entities", []];

// 1. Mod Compatibility Verification with fallback support
private _missingMods = [];
{
    private _modPrefix = _x;
    private _patchClass = switch (_modPrefix) do {
        case "SPE":   { "WW2_Assets_c_Characters_Americans_c" };
        case "LIB":   { "WW2_Core_c" };
        case "fow":   { "fow_main" };
        case "IFA3":  { "WW2_Core_c" };
        default       { _modPrefix };
    };

    if (!isClass (configFile >> "CfgPatches" >> _patchClass) && {!isClass (configFile >> "CfgPatches" >> _modPrefix)}) then {
        _missingMods pushBack _modPrefix;
    };
} forEach _requiredMods;

if (count _missingMods > 0) then {
    private _fallback = _supportData getOrDefault ["fallbackEntities", []];
    if (count _fallback > 0) then {
        diag_log format ["FTCS Support Warning: Mods %1 not found. Using fallback entities for '%2'.", _missingMods joinString ", ", _supportId];
        _entities = _fallback;
    } else {
        diag_log format ["FTCS Support Error: Missing mods %1 for support '%2'.", _missingMods joinString ", ", _supportId];
    };
};

if (count _entities == 0) exitWith {
    diag_log format ["FTCS Support Error: No entities to spawn for '%1'.", _supportId];
    false;
};

// 2. Trigonometric Offset Rotation and Placement
private _spawnX = _targetPos select 0;
private _spawnY = _targetPos select 1;
private _spawnZ = if (count _targetPos > 2) then { _targetPos select 2 } else { 0 };

private _spawnedGroups = createHashMap;
private _spawnedVehicles = [];

{
    _x params [
        "_classType", 
        "_offsetXYZ", 
        "_relDir", 
        "_varName", 
        "_groupVar", 
        "_rank", 
        "_isVehicle"
    ];

    _offsetXYZ params ["_offX", "_offY", "_offZ"];

    private _rad = _advanceDir;
    private _sinA = sin _rad;
    private _cosA = cos _rad;

    private _rotX = (_offX * _cosA) + (_offY * _sinA);
    private _rotY = ((-_offX * _sinA) + (_offY * _cosA));

    private _finalPos = [
        _spawnX + _rotX, 
        _spawnY + _rotY, 
        _spawnZ + _offZ
    ];

    private _finalDir = (_advanceDir + _relDir) % 360;

    if (_isVehicle) then {
        private _veh = createVehicle [_classType, _finalPos, [], 0, "CAN_COLLIDE"];
        _veh setDir _finalDir;
        _veh setPosATL _finalPos;

        if (_varName != "") then {
            _veh setVehicleVarName _varName;
            missionNamespace setVariable [_varName, _veh, true];
        };

        _spawnedVehicles pushBack _veh;

        // Register vehicle in FTCS vehicles map
        private _editorVehicles = FTCS_Company_Data getOrDefault ["editorVehicles", createHashMap];
        _editorVehicles set [_varName, createHashMapFromArray [
            ["vehicle", _veh],
            ["crew", crew _veh]
        ]];
        FTCS_Company_Data set ["editorVehicles", _editorVehicles];
    } else {
        private _group = grpNull;
        if (_groupVar != "" && {_groupVar in _spawnedGroups}) then {
            _group = _spawnedGroups get _groupVar;
        } else {
            _group = createGroup [_factionSide, true];
            if (_groupVar != "") then {
                _spawnedGroups set [_groupVar, _group];
                _group setGroupIdGlobal [_groupVar];
                missionNamespace setVariable [_groupVar, _group, true];
            };
        };

        private _unit = _group createUnit [_classType, _finalPos, [], 0, "CAN_COLLIDE"];
        _unit setDir _finalDir;
        _unit setPosATL _finalPos;

        if (_rank != "") then {
            _unit setRank _rank;
        };

        if (_varName != "") then {
            _unit setVehicleVarName _varName;
            missionNamespace setVariable [_varName, _unit, true];
        };
    };
} forEach _entities;

// 3. Crew Assignment & Registry Integration
{
    private _groupVar = _x;
    private _group = _y;
    private _groupId = groupId _group;

    // Check if there are vehicles that need crew assigned
    {
        private _veh = _x;
        if ((count crew _veh == 0) && (count units _group > 0) && !_isStatic) then {
            private _availableUnits = (units _group) select { vehicle _x == _x };
            if (count _availableUnits > 0) then {
                (_availableUnits select 0) moveInDriver _veh;
            };
            if (count _availableUnits > 1) then {
                (_availableUnits select 1) moveInGunner _veh;
            };
            if (count _availableUnits > 2) then {
                (_availableUnits select 2) moveInCommander _veh;
            };
        };
    } forEach _spawnedVehicles;

    // Register into Master Encapsulated Group Registry
    if !(_groupId in FTCS_Groups_Registry_Table) then {
        FTCS_Groups_Registry_Table set [_groupId, createHashMapFromArray [
            ["movingMode", "AT_WILL"],
            ["stance", "AT_WILL"],
            ["awareMode", "SAFE"],
            ["speed", "NORMAL"],
            ["roe", "FIRE_IF_FIRED_UPON"],
            ["task", "AT_WILL"],
            ["formationType", "COLUMN"],
            ["allocationSlot", -1],
            ["formationPosition", [-1, -1, FTCS_Group_Commander]],
            ["relPosition", [-1, -1, FTCS_Group_Commander]]
        ]];
    };

    // Register into Company Teams map
    private _teamsMap = FTCS_Company_Data getOrDefault ["teams", createHashMap];
    _teamsMap set [_groupId, createHashMapFromArray [
        ["name", format ["Attached Support: %1 (%2)", _name, _groupId]],
        ["group", _group],
        ["units", units _group]
    ]];
    FTCS_Company_Data set ["teams", _teamsMap];

} forEach _spawnedGroups;

diag_log format ["FTCS Support: '%1' successfully spawned at %2 (Static: %3).", _name, _targetPos, _isStatic];
true;
