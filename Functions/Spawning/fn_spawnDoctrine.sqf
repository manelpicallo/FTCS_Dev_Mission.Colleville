/*
    ================================================================================
    File: fn_spawnDoctrine.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Generic Data-Driven Spawner. Consumes a pure doctrinal HashMap 
                 definition (generated from 3DEN composition), checks required mods, 
                 calculates 2D planar rotation relative to the platoon advance direction,
                 instantiates groups/vehicles with correct ranks and variable names, 
                 and automatically kicks off the full FTCS core registration chain.
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) OOP port.
    ================================================================================
*/

params [
    ["_doctrineData", createHashMap],
    ["_spawnAnchorPos", [0, 0, 0]],
    ["_advanceDir", 0]
];

// -----------------------------------------------------------------------------
// 1. Validate Input Data
// -----------------------------------------------------------------------------
if (count _doctrineData == 0) exitWith {
    diag_log "FTCS Spawn Error: Provided doctrine data HashMap is empty.";
    hint "FTCS Spawn Error: Empty doctrine data.";
    false;
};

private _doctrineId   = _doctrineData getOrDefault ["doctrineID", "US_AIRBORNE"];
private _companyLetter = _doctrineData getOrDefault ["companyLetter", "E"];
private _requiredMods  = _doctrineData getOrDefault ["requiredMods", []];
private _entities      = _doctrineData getOrDefault ["entities", []];

// -----------------------------------------------------------------------------
// 2. Mod Compatibility Verification
// -----------------------------------------------------------------------------
private _missingMods = [];
{
    private _modPrefix = _x;
    // Map short mod tags to known CfgPatches or check directly
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

if (count _missingMods > 0) exitWith {
    private _errorMsg = format ["FTCS Mod Warning: Faltan los siguientes mods requeridos para la doctrina '%1': %2", _doctrineId, _missingMods joinString ", "];
    diag_log _errorMsg;
    hint _errorMsg;
    false;
};

// -----------------------------------------------------------------------------
// 3. Coordinate Rotation & Group Map Setup
// -----------------------------------------------------------------------------
private _spawnX = _spawnAnchorPos select 0;
private _spawnY = _spawnAnchorPos select 1;
private _spawnZ = if (count _spawnAnchorPos > 2) then { _spawnAnchorPos select 2 } else { 0 };

// Cache of spawned groups by their groupVar name in the composition
private _spawnedGroups = createHashMap;

// Default side for player faction
private _factionSide = side group player;
if (_factionSide == civilian || _factionSide == sideUnknown) then { _factionSide = west; };

// -----------------------------------------------------------------------------
// 4. Instantiate Entities
// -----------------------------------------------------------------------------
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

    // Rotate offset [offX, offY] around advance direction (trigonometric rotation in 2D)
    // In Arma: 0 = North (+Y), 90 = East (+X).
    // Cartesian X_rot = X * cos(dir) + Y * sin(dir), Y_rot = -X * sin(dir) + Y * cos(dir)
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
        // Vehicle Spawning
        private _veh = createVehicle [_classType, _finalPos, [], 0, "CAN_COLLIDE"];
        _veh setDir _finalDir;
        _veh setPosATL _finalPos;

        if (_varName != "") then {
            _veh setVehicleVarName _varName;
            missionNamespace setVariable [_varName, _veh, true];
        };
    } else {
        // Soldier Spawning
        // Locate or create the group mapped to this groupVar
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

// -----------------------------------------------------------------------------
// 5. Automatic Full FTCS Core Pipeline Registration
// -----------------------------------------------------------------------------
diag_log format ["FTCS: Doctrine '%1' spawned at %2 with direction %3. Triggering registration pipeline...", _doctrineId, _spawnAnchorPos, _advanceDir];

// 5.1. Apply military doctrine structure
[_doctrineId, _companyLetter] call FTCS_fnc_applyDoctrine;

// 5.2. Scan spawned groups, vehicles, and assigned unit roles
call FTCS_fnc_parseEditorGroups;

// 5.3. Initialize Company Command (isolate commander if in mixed group)
call FTCS_fnc_initCompanyCommand;

// 5.4. Synchronize visual group names
call FTCS_fnc_syncGroupNames;

// 5.5. Initialize the Master Encapsulated Group Registry
call FTCS_fnc_registryInit;

// 5.6. Initialize dynamic interactions & proximity actions
call FTCS_fnc_initUnitInteractions;

diag_log format ["FTCS: Doctrine '%1' fully deployed, registered and operational.", _doctrineId];
true;
