/*
    ================================================================================
    File: fn_loadDoctrineData.sqf
    Module: Core
    Author: FTCS Team
    Description: Centralized Data-Driven Doctrine Loader & Registry Accessor.
                 Resolves a doctrine key (as delivered by the deployment UI)
                 into its on-disk template file under Doctrines\Data\, compiles
                 it into a HashMap, and validates that it contains spawnable
                 entities. Also exposes the dynamic directory of available
                 doctrines (built from Doctrines_Registry.sqf) so the deployment
                 dropdown always reflects every registered doctrine instead of
                 a hardcoded list.
                 SQF has no directory enumeration, so the registry file is the
                 single source of truth: adding one line there makes a new
                 doctrine available everywhere (UI + spawn chain).
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) OOP port.

    Usage:
        ["US_AIRBORNE"] call FTCS_fnc_loadDoctrineData  -> HashMap (doctrine data)
        [] call FTCS_fnc_loadDoctrineData               -> Array [available doctrines]

    Returns:
        With key param  : [HashMap] Doctrine data (empty HashMap if load fails).
        Without key arg : [Array of HashMaps] One entry per registered doctrine:
                          [["label", "doctrineKey", dataHashMap], ...]
    ================================================================================
*/

params [["_doctrineKey", "", [""]]];

// -----------------------------------------------------------------------------
// Directory mode: return the full list of registered doctrines (for the dropdown)
// -----------------------------------------------------------------------------
if (_doctrineKey == "LIST") exitWith {
    private _list = [];
    private _registryPath = "Doctrines\Data\Doctrines_Registry.sqf";

    if !(fileExists _registryPath) exitWith {
        diag_log "FTCS LoadDoctrine Error: Doctrines_Registry.sqf not found. No doctrines available.";
        _list;
    };

    private _fileNames = call compile preprocessFileLineNumbers _registryPath;
    if !( _fileNames isEqualType []) exitWith {
        diag_log "FTCS LoadDoctrine Error: Doctrines_Registry.sqf did not compile to an Array.";
        _list;
    };

    {
        private _data = [_x] call FTCS_fnc_loadDoctrineData;
        if (count _data > 0) then {
            private _docId = _data getOrDefault ["doctrineID", _x];
            private _label = format ["%1 (%2)", _docId, _x];
            _list pushBack [_label, _docId, _data];
        };
    } forEach _fileNames;

    diag_log format ["FTCS LoadDoctrine: %1 doctrine(s) available in registry.", count _list];
    _list;
};

// -----------------------------------------------------------------------------
// Load mode: resolve a specific doctrine key into its data HashMap
// -----------------------------------------------------------------------------
if (_doctrineKey == "") exitWith {
    diag_log "FTCS LoadDoctrine Error: Empty doctrine key.";
    createHashMap;
};

// 1. Scan the registry: each registered file is compiled and matched by its
//    internal "doctrineID" first, falling back to the raw filename.
private _registryPath = "Doctrines\Data\Doctrines_Registry.sqf";
private _doctrineData = createHashMap;

if (fileExists _registryPath) then {
    private _fileNames = call compile preprocessFileLineNumbers _registryPath;
    if (_fileNames isEqualType []) then {
        {
            private _path = format ["Doctrines\Data\%1.sqf", _x];
            if (fileExists _path) then {
                private _loaded = call compile preprocessFileLineNumbers _path;
                if (_loaded isEqualType createHashMap) then {
                    private _docId = _loaded getOrDefault ["doctrineID", ""];
                    private _fileNameKey = toUpper _x;
                    private _requested = toUpper _doctrineKey;
                    // Match by doctrineID, by filename (with or without version suffix)
                    if (_docId == _requested || {_fileNameKey == _requested} || {_fileNameKey find _requested == 0}) exitWith {
                        _doctrineData = _loaded;
                        diag_log format ["FTCS LoadDoctrine: Doctrine key '%1' resolved to file '%2'.", _doctrineKey, _x];
                    };
                } else {
                    diag_log format ["FTCS LoadDoctrine Error: File '%1' did not compile to a HashMap.", _path];
                };
            };
        } forEach _fileNames;
    };
};

// 2. Validate content
if (count _doctrineData == 0) exitWith {
    diag_log format ["FTCS LoadDoctrine Error: No valid doctrine file found for key '%1'.", _doctrineKey];
    createHashMap;
};

private _entityCount = count (_doctrineData getOrDefault ["entities", []]);
if (_entityCount == 0) then {
    diag_log format ["FTCS LoadDoctrine Warning: Doctrine '%1' loaded but 'entities' array is empty. Nothing will deploy.", _doctrineKey];
} else {
    diag_log format ["FTCS LoadDoctrine: Doctrine '%1' validated with %2 entities.", _doctrineKey, _entityCount];
};

_doctrineData;
