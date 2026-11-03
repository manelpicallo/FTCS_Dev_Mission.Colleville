/*
    ================================================================================
    File: fn_deploySupportCombosPopulate.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Populates and filters fixed and mobile support asset dropdowns
                 strictly according to the active doctrine's faction family and side.
                 Extracted cleanly from fn_initDeployMenu.sqf per Rule 1 (SRP).
    Language: Strictly English (Rule 7)
    ================================================================================
*/

params [["_doctrineKey", ""]];

if (isNull (findDisplay 88000)) exitWith {};
private _disp = findDisplay 88000;
private _cFixed  = _disp displayCtrl 88024;
private _cMobile = _disp displayCtrl 88025;

lbClear _cFixed;
lbClear _cMobile;

private _docData = [_doctrineKey] call FTCS_fnc_loadDoctrineData;
private _docSide = _docData getOrDefault ["side", sideUnknown];
if !(_docSide in [west, east, resistance, independent]) then {
    _docSide = side group player;
};
if (_docSide == civilian || _docSide == sideUnknown) then { _docSide = west; };

private _docId = _docData getOrDefault ["doctrineID", ""];
private _docSearchStr = format ["%1 %2", toUpper _doctrineKey, toUpper _docId];

// Identify authentic national / faction family from doctrine definition
private _isGerman = (_docSearchStr find "GERMAN" >= 0) || (_docSearchStr find "WEHRMACHT" >= 0) || (_docSearchStr find "STURM" >= 0) || (_docSearchStr find "PANZER" >= 0) || (_docSearchStr find "AXIS" >= 0);
private _isUS = (_docSearchStr find "US_" >= 0) || (_docSearchStr find "PARA" >= 0) || (_docSearchStr find "101" >= 0) || (_docSearchStr find "AIRBORNE" >= 0) || (_docSearchStr find "RANGER" >= 0) || (_docSearchStr find "ARMY" >= 0) || (_docSearchStr find "BRITISH" >= 0) || (_docSearchStr find "ALLIED" >= 0);
private _isSoviet = (_docSearchStr find "SOV" >= 0) || (_docSearchStr find "RUS" >= 0) || (_docSearchStr find "RED" >= 0) || (_docSearchStr find "USSR" >= 0);
private _isJapanese = (_docSearchStr find "JAP" >= 0) || (_docSearchStr find "IJA" >= 0);

private _regPath = "Doctrines\Data\Support_Registry.sqf";
private _regList = if (fileExists _regPath) then {
    call compile preprocessFileLineNumbers _regPath
} else {
    []
};

{
    private _entry = _x;
    private _cat   = _entry getOrDefault ["category", ""];
    private _name  = _entry getOrDefault ["name", "Support Element"];
    private _file  = _entry getOrDefault ["file", ""];
    private _sides = _entry getOrDefault ["sides", []];
    private _facs  = _entry getOrDefault ["factions", []];

    private _entryIsGerman   = ("GERMAN" in _facs) || ("WEHRMACHT" in _facs);
    private _entryIsUS       = ("US" in _facs) || ("ALLIED" in _facs);
    private _entryIsSoviet   = ("SOVIET" in _facs) || ("RED_ARMY" in _facs);
    private _entryIsJapanese = ("JAPAN" in _facs) || ("IJA" in _facs);

    private _matchesFaction = false;
    if (_isGerman && _entryIsGerman) then { _matchesFaction = true; };
    if (_isUS && _entryIsUS) then { _matchesFaction = true; };
    if (_isSoviet && _entryIsSoviet) then { _matchesFaction = true; };
    if (_isJapanese && _entryIsJapanese) then { _matchesFaction = true; };

    // Fallback to strict side matching only if no explicit historical faction was tagged
    if (!_isGerman && !_isUS && !_isSoviet && !_isJapanese) then {
        _matchesFaction = (_docSide in _sides);
    };

    if (_matchesFaction) then {
        if (_cat == "FIXED") then {
            private _idx = _cFixed lbAdd _name;
            _cFixed lbSetData [_idx, _file];
        };
        if (_cat == "MOBILE") then {
            private _idx = _cMobile lbAdd _name;
            _cMobile lbSetData [_idx, _file];
        };
    };
} forEach _regList;

// Safety fallback only if no items matched
if (lbSize _cFixed == 0) then {
    private _defFile = if (_isGerman) then { "Support_Artillery_German" } else { "Support_Artillery" };
    private _defLabel = if (_isGerman) then { "Artillery Battery (8cm GrW 34)" } else { "105mm Artillery (SPE M3 Howitzers)" };
    private _idx = _cFixed lbAdd _defLabel;
    _cFixed lbSetData [_idx, _defFile];
};

if (lbSize _cMobile == 0) then {
    private _defFile = if (_isGerman) then { "Support_Armor_German" } else { "Support_Armor" };
    private _defLabel = if (_isGerman) then { "Armor Section / Assault Guns (StuG III)" } else { "Armor Section (2x M4A1 Sherman)" };
    private _idx = _cMobile lbAdd _defLabel;
    _cMobile lbSetData [_idx, _defFile];
};

_cFixed lbSetCurSel 0;
_cMobile lbSetCurSel 0;

FTCS_Deploy_SelectedFixedFile  = _cFixed lbData 0;
FTCS_Deploy_SelectedMobileFile = _cMobile lbData 0;
