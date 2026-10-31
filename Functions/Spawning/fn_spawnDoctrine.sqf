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
    ["_advanceDir", 0],
    ["_commandEchelon", "COMPANY"],
    ["_playerUnit", if (hasInterface) then { player } else { objNull }],
    ["_customCompanyHQPos", []],
    ["_customCompanyHQDir", -1]
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

// Default side for doctrine force: determined by the doctrine template itself
// (or derived from the first combat unit's config side), supporting WEST (BLUFOR),
// EAST (OPFOR), and RESISTANCE/INDEPENDENT (los aliados / independientes).
// The local player is dynamically switched into this side's group during deployment.
private _factionSide = _doctrineData getOrDefault ["side", sideUnknown];
if !(_factionSide in [west, east, resistance, independent]) then {
    // Attempt auto-detection from the first soldier class in entities
    if (count _entities > 0) then {
        private _firstClass = (_entities select 0) select 0;
        private _sideNum = getNumber (configFile >> "CfgVehicles" >> _firstClass >> "side");
        _factionSide = switch (_sideNum) do {
            case 0: { east };
            case 1: { west };
            case 2: { resistance }; // independent
            default { sideUnknown };
        };
    };
};
if !(_factionSide in [west, east, resistance, independent]) then {
    _factionSide = side group player;
};
if (_factionSide == civilian || _factionSide == sideUnknown) then { _factionSide = resistance; };

// Ensure internal side cohesion: in Arma 3, RESISTANCE/INDEPENDENT factions must
// explicitly be marked friendly to themselves at mission level so disparate
// independent groups never treat each other as hostiles under default map diplomacy.
if (_factionSide == resistance) then {
    resistance setFriend [resistance, 1];
};

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

    // Filter entities when Platoon echelon is selected: deploy only Company HQ and 1st Platoon
    private _skipEntity = false;
    if (_commandEchelon == "PLATOON") then {
        private _upGroup = toUpper _groupVar;
        private _upVar   = toUpper _varName;
        private _isCompanyHQ = (_upGroup == "SQUAD_0_0" || _upGroup find "SQUAD_0_0_" == 0 || _upGroup find "SQD_0_0_" == 0) || (_upVar find "HQ_" == 0);
        private _isPlatoon1  = (_upGroup find "SQUAD_1_" == 0 || _upGroup find "SQD_1_" == 0) || (_upVar find "PLT_1_" == 0 || _upVar find "SQD_1_" == 0);
        if (!_isCompanyHQ && !_isPlatoon1) then {
            _skipEntity = true;
        };
    };

    if (!_skipEntity) then {
        _offsetXYZ params ["_offX", "_offY", "_offZ"];

        // Determine if this entity belongs to the Company HQ
        private _isEntityCompanyHQ = (_groupVar == "SQUAD_0_0") || ((toUpper _varName) find "HQ_" == 0);

        // Calculate dynamic anchor position and direction for this entity
        private _curAnchorX = _spawnX;
        private _curAnchorY = _spawnY;
        private _curAnchorZ = _spawnZ;
        private _curAdvanceDir = _advanceDir;

        // If a custom Company HQ position was provided and this entity belongs to Company HQ, relocate anchor
        if (_isEntityCompanyHQ && {count _customCompanyHQPos >= 2}) then {
            _curAnchorX = _customCompanyHQPos select 0;
            _curAnchorY = _customCompanyHQPos select 1;
            _curAnchorZ = if (count _customCompanyHQPos > 2) then { _customCompanyHQPos select 2 } else { 0 };
            if (_customCompanyHQDir >= 0) then {
                _curAdvanceDir = _customCompanyHQDir;
            };
        };

        // Rotate offset [offX, offY] around advance direction (trigonometric rotation in 2D)
        // In Arma: 0 = North (+Y), 90 = East (+X).
        // Cartesian X_rot = X * cos(dir) + Y * sin(dir), Y_rot = -X * sin(dir) + Y * cos(dir)
        private _rad = _curAdvanceDir;
        private _sinA = sin _rad;
        private _cosA = cos _rad;

        private _rotX = (_offX * _cosA) + (_offY * _sinA);
        private _rotY = ((-_offX * _sinA) + (_offY * _cosA));

        // Horizontal world coordinates for this entity
        private _worldX = _curAnchorX + _rotX;
        private _worldY = _curAnchorY + _rotY;

        // Vertical positioning:
        // - Vehicles: respect explicit positive Z offset (for platforms/ramps), else snap to terrain
        // - Infantry: ALWAYS clamp directly to the local terrain surface (ATL Z = 0) so units
        //   spawned on sloping or elevated maps (e.g., Colleville hills) never spawn in mid-air
        //   and suffer falling damage upon instantiation.
        private _finalZ = if (_isVehicle) then {
            if (_offZ > 0.5) then { _offZ } else { 0 };
        } else {
            0
        };

        private _finalPos = [_worldX, _worldY, _finalZ];
        private _finalDir = (_curAdvanceDir + _relDir) % 360;

        // Intelligent groupVar fallback if missing
        // Infers the parent group from encoded slot names (varName) to preserve
        // the original composition hierarchy instead of collapsing everything.
        if (_groupVar == "") then {
            private _upVar = toUpper _varName;
            if (_upVar find "HQ_" == 0) then { _groupVar = "SQUAD_0_0"; };
            // SQD_<platoon>_<squad>_... naming maps 1:1 to SQUAD_<platoon>_<squad>
            if (_upVar find "SQD_" == 0) then {
                private _parts = (_upVar select [4]) splitString "_";
                if (count _parts >= 2) then {
                    _groupVar = format ["SQUAD_%1_%2", _parts select 0, _parts select 1];
                };
            };
            if (_groupVar == "") then {
                if (_upVar find "PLT_1_" == 0) then { _groupVar = "SQUAD_1_0"; };
                if (_upVar find "PLT_2_" == 0) then { _groupVar = "SQUAD_2_0"; };
                if (_upVar find "PLT_3_" == 0) then { _groupVar = "SQUAD_3_0"; };
            };
            if (_groupVar == "") then { _groupVar = "SQUAD_1_1"; };
        };

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

            // Check if this slot represents the player's chosen command role
            private _isPlayerSlot = false;
            if (!isNull _playerUnit && {alive _playerUnit}) then {
                if (_commandEchelon == "COMPANY" && {_varName == "HQ_CO_CAPTAIN"}) then {
                    _isPlayerSlot = true;
                };
                if (_commandEchelon == "PLATOON" && {_varName == "PLT_1_LEADER"}) then {
                    _isPlayerSlot = true;
                };
            };

            if (_isPlayerSlot) then {
                // Position player directly into their designated commander slot (flush with terrain)
                _playerUnit setPosATL _finalPos;
                _playerUnit setVelocity [0, 0, 0];
                _playerUnit setDir _finalDir;
                [_playerUnit] joinSilent _group;

                if (_rank != "") then {
                    _playerUnit setRank _rank;
                };

                if (_varName != "") then {
                    _playerUnit setVehicleVarName _varName;
                    missionNamespace setVariable [_varName, _playerUnit, true];
                };

                _group selectLeader _playerUnit;
            } else {
                private _unit = _group createUnit [_classType, _finalPos, [], 0, "CAN_COLLIDE"];
                _unit setDir _finalDir;
                _unit setPosATL _finalPos;
                _unit setVelocity [0, 0, 0];

                if (_rank != "") then {
                    _unit setRank _rank;
                };

                if (_varName != "") then {
                    _unit setVehicleVarName _varName;
                    missionNamespace setVariable [_varName, _unit, true];
                };
            };
        };
    };

} forEach _entities;

// -----------------------------------------------------------------------------
// 5. Automatic Full FTCS Core Pipeline Registration
// -----------------------------------------------------------------------------
diag_log format ["FTCS: Doctrine '%1' spawned at %2 with direction %3 (Echelon: %4). Triggering registration pipeline...", _doctrineId, _spawnAnchorPos, _advanceDir, _commandEchelon];

// Set global advance direction
missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _advanceDir];
missionNamespace setVariable ["FTCS_Last_Commander_Dir", _advanceDir];

// 5.1. Apply military doctrine structure. The doctrine data file is passed as a
//      self-contained HashMap: all organizational structure (platoon names, squad
//      designations, team structure, HQ roles) is embedded in the file generated
//      by the composition conversion tool. Legacy string keys still resolve via
//      FTCS_Doctrines for Method 1 compatibility.
[_doctrineData, _companyLetter] call FTCS_fnc_applyDoctrine;

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
