/*
    ================================================================================
    File: fn_movementBoundTeams.sqf
    Module: Movement
    Author: FTCS Team
    Description: Shared Movement-class utility. Returns the team groups of a
                 squad that are BOUND to the squad and therefore follow a squad
                 movement order. Filtering is driven EXCLUSIVELY by the explicit
                 "teamAttachment" registry field (single source of truth):
                     "SQUAD_BOUND"   -> included (default for ordinary teams)
                     "DETACHED_HOLD" -> excluded (MG emplaced, ordered hold)
                     "DETACHED_FREE" -> excluded (deployed scouts, autonomous)
                 The optional exclusion list lets callers extend the filter with
                 runtime conditions (e.g. a fireteam currently suppressing).
                 Teams lacking a registry entry are treated as SQUAD_BOUND
                 (defensive default: never silently drop a normal team).
    Params:
        0: GROUP - Squad group whose doctrinal data resolves its teams.
                   (Alternatively: 0: STRING - doctrinal squad key "SQD_X_Y".)
        1: STRING - Attachment requirement filter (default "SQUAD_BOUND").
    Returns:
        ARRAY - Bound GROUP objects (may be empty).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_squadRef", grpNull], ["_require", "SQUAD_BOUND"]];

// Resolve the doctrinal squad key from either a group object or a raw key
private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
private _sqdKey = "";
if (_squadRef isEqualType grpNull && { !isNull _squadRef }) then {
    // Walk the parsed platoon data to find which squad owns this group
    private _pltKey = format ["PLT_%1", _pltId];
    private _platoonsMap = (missionNamespace getVariable ["FTCS_Company_Data", createHashMap]) getOrDefault ["platoons", createHashMap];
    private _parsedSquads = (_platoonsMap getOrDefault [_pltKey, createHashMap]) getOrDefault ["parsedSquads", createHashMap];
    {
        private _key = _x;
        private _data = _y;
        private _match = false;
        private _teams = _data getOrDefault ["tacticalTeams", createHashMap];
        if (count _teams == 0) then { _teams = _data getOrDefault ["teams", createHashMap]; };
        { if (((_y) getOrDefault ["group", grpNull]) == _squadRef) exitWith { _match = true; }; } forEach _teams;
        if (!_match && { (_data getOrDefault ["group", grpNull]) == _squadRef }) then { _match = true; };
        if (_match) exitWith { _sqdKey = _key; };
    } forEach _parsedSquads;
} else {
    _sqdKey = _squadRef;
};

if (_sqdKey == "") exitWith { [] };

// Gather every team group of the doctrinal squad (tacticalTeams or teams)
private _pltKey = format ["PLT_%1", _pltId];
private _platoonsMap = (missionNamespace getVariable ["FTCS_Company_Data", createHashMap]) getOrDefault ["platoons", createHashMap];
private _parsedSquads = (_platoonsMap getOrDefault [_pltKey, createHashMap]) getOrDefault ["parsedSquads", createHashMap];
private _sqdData = _parsedSquads getOrDefault [_sqdKey, createHashMap];

private _boundTeams = [];
private _teams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
if (count _teams == 0) then { _teams = _sqdData getOrDefault ["teams", createHashMap]; };

{
    private _grp = (_y) getOrDefault ["group", grpNull];
    if (!isNull _grp) then {
        private _entry = FTCS_Groups_Registry_Table getOrDefault [groupId _grp, createHashMap];
        private _attach = _entry getOrDefault ["teamAttachment", "SQUAD_BOUND"];
        if (_attach == _require) then { _boundTeams pushBack _grp; };
    };
} forEach _teams;

// Fallback: squad-level group when no sub-teams resolved
if (count _boundTeams == 0) then {
    private _sqdGrp = _sqdData getOrDefault ["group", grpNull];
    if (!isNull _sqdGrp) then {
        private _entry = FTCS_Groups_Registry_Table getOrDefault [groupId _sqdGrp, createHashMap];
        if ((_entry getOrDefault ["teamAttachment", "SQUAD_BOUND"]) == _require) then {
            _boundTeams pushBack _sqdGrp;
        };
    };
};

_boundTeams
