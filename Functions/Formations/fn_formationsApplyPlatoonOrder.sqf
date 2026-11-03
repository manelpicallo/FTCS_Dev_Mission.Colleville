/*
    ================================================================================
    File: fn_formationsApplyPlatoonOrder.sqf
    Module: Formations
    Author: FTCS Team
    Description: Resolves all subordinate squads and fireteams of a tactical platoon,
                 validates operational phase readiness, executes two-tier formation
                 geometry (Platoon layout + internal Squad team layout via
                 FTCS_fnc_formationsTypeSquadSet), updates the registry, and launches
                 the concurrent follow-commander movement threads.
                 AI behavior, awakening and ROE are strictly governed by operational
                 phase functions (SRP compliance).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)

    +-----------------------------------------------------------------------------+
    |                    PLATOON FORMATION EXECUTION ENGINE                       |
    +-----------------------------------------------------------------------------+
    |                                                                             |
    |  Params: [_platoonLeaderUnit, _formationType, _separationDistance]          |
    |               │                                                             |
    |               ▼                                                             |
    |     [Resolve Platoon & Phase Check]                                         |
    |     (If Phase 0: DEPLOYMENT/INSPECTION -> Abort, troops remain frozen)      |
    |               │                                                             |
    |               ▼                                                             |
    |     [Build Hierarchical Formation Elements]                                 |
    |     Slot 0: Platoon Leader Anchor                                           |
    |     Slot 1+: Platoon HQ Support Teams (Command / Support)                   |
    |     Slot 2+: Subordinate Combat Squads & Fireteams (Able, Baker, Charlie)   |
    |               │                                                             |
    |               ▼                                                             |
    |     [Two-Tier Formation Geometry Calculation]                               |
    |     -> FTCS_fnc_formationsTypePlatoonSet (Macro slots 0-11)                 |
    |        -> FTCS_fnc_formationsTypeSquadSet (Internal squad teams)            |
    |               │                                                             |
    |               ▼                                                             |
    |     [Launch Follow-Commander Threads]                                       |
    |     -> FTCS_fnc_formationsGroupListFollowCommander                          |
    |        (Natively tracks leader while marching; static when leader stops)    |
    |               │                                                             |
    |               ▼                                                             |
    |     [Draw Tactical Map Arrow Marker]                                        |
    +-----------------------------------------------------------------------------+
    ================================================================================
*/

params [
    ["_platoonLeaderUnit", objNull],
    ["_formationType", "FILE"],
    ["_separationDistance", 15]
];

if (isNull _platoonLeaderUnit) exitWith { false };

// 1. Resolve platoon key from target or global context
private _pltKey = missionNamespace getVariable ["FTCS_SelectedPlatoonKey", ""];
if (_pltKey == "") then {
    private _pId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    _pltKey = format ["PLT_%1", _pId];
};
private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

if (count _parsedSquads == 0) exitWith {
    systemChat format ["[FTCS Formations] Error: No parsed squads found for %1.", _pltKey];
    false;
};

// 2. Validate operational phase: Troops in Phase 0 (DEPLOYMENT / INSPECTION) remain frozen
private _currentPhase = _pltData getOrDefault ["currentPhase", 0];
if (_currentPhase == 0) exitWith {
    systemChat format ["[FTCS Formations] %1 is in DEPLOYMENT / INSPECTION phase (Troops Frozen). Set Operational Phase (Approach/Combat) first.", _pltData getOrDefault ["name", _pltKey]];
    hint parseText format ["<t color='#FFAA00'>[FORMATION BLOCKED]</t><br/><t color='#FFFFFF'>%1</t> is in inspection mode.<br/><t color='#00FFCC'>Action required:</t> Set Operational Phase (Approach / Combat) via Platoon Sergeant before ordering formation march.", _pltData getOrDefault ["name", _pltKey]];
    false;
};

// 3. Identify the Platoon Leader's group as the formation anchor (Slot 0)
private _leaderGroup = group _platoonLeaderUnit;

// Gather Platoon HQ sub-teams (Team 1: Command Element / RTO, Team 2: Support Element / Sergeant, Runner, Medic)
private _hqSquadId = format ["SQD_%1_0", parseNumber ((_pltKey splitString "_") select 1)];
private _hqSquadData = _parsedSquads getOrDefault [_hqSquadId, createHashMap];
private _hqTeams = _hqSquadData getOrDefault ["tacticalTeams", createHashMap];
private _hqSubordinateGroups = [];

{
    private _tKey = _x;
    private _hGrp = (_y) getOrDefault ["group", grpNull];
    if (!isNull _hGrp && {_hGrp != _leaderGroup}) then {
        if !(_hGrp in _hqSubordinateGroups) then {
            _hqSubordinateGroups pushBack _hGrp;
        };
    };
} forEach _hqTeams;

// Check if base HQ squad group is distinct from the leader's group
private _baseHqGroup = _hqSquadData getOrDefault ["group", grpNull];
if (!isNull _baseHqGroup && {_baseHqGroup != _leaderGroup} && {!(_baseHqGroup in _hqSubordinateGroups)}) then {
    _hqSubordinateGroups pushBack _baseHqGroup;
};

private _formationElements = [[_leaderGroup]];

// 4. Structure subordinate squads and their nested fireteams
private _squadKeys = keys _parsedSquads;
_squadKeys sort true;

private _allSubordinateGroups = [];

// Attach Platoon HQ remaining sub-teams (Command Element & Support Element) right behind the Leader
{
    _formationElements pushBack [_x];
    _allSubordinateGroups pushBack _x;
} forEach _hqSubordinateGroups;

{
    private _sqdKey = _x;
    // Exclude the Platoon HQ itself from the subordinate squad slots
    if (_sqdKey find "_0" < 0) then {
        private _sqdData = _parsedSquads get _sqdKey;
        private _squadGroup = _sqdData getOrDefault ["group", grpNull];
        private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];

        private _elementGroups = [];

        if (count _tacticalTeams > 0) then {
            // Sort teams so Team 1 (Squad Leader / Point) is at index 0, followed by Team 2, 3, 4
            private _teamKeys = keys _tacticalTeams;
            _teamKeys sort true;

            {
                private _tGrp = (_tacticalTeams get _x) getOrDefault ["group", grpNull];
                if (!isNull _tGrp) then {
                    _elementGroups pushBack _tGrp;
                    _allSubordinateGroups pushBack _tGrp;
                };
            } forEach _teamKeys;
        } else {
            if (!isNull _squadGroup) then {
                _elementGroups pushBack _squadGroup;
                _allSubordinateGroups pushBack _squadGroup;
            };
        };

        if (count _elementGroups > 0) then {
            _formationElements pushBack _elementGroups;
        };
    };
} forEach _squadKeys;
// 5. Two-tier formation geometry calculation:
// Set platoon advance direction strictly to the leader's current heading at the moment the formation order is issued
private _advanceDir = getDir _platoonLeaderUnit;
missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _advanceDir];
missionNamespace setVariable ["FTCS_Last_Commander_Dir", _advanceDir];

// Debug feedback: display slot 0 anchor info for Platoon Leader and update NATO icon
systemChat format ["[FORMATION ANCHOR SLOT 0] %1 -> (Heading %2° | Leader: %3)", groupId _leaderGroup, round _advanceDir, name (leader _leaderGroup)];
_leaderGroup setGroupIconParams [[0.55, 0.55, 0.55, 1.0], format ["[Slot 0 Anchor] %1", groupId _leaderGroup], 1.0, true];

// FTCS_fnc_formationsTypePlatoonSet calculates macro platoon slots (0 to 11)
// and recursively calls FTCS_fnc_formationsTypeSquadSet for internal squad teams
private _followerGroups = [_formationElements, _formationType, _separationDistance] call FTCS_fnc_formationsTypePlatoonSet;

// 6. Launch concurrent follow-commander movement threads for all subordinate groups
if (count _allSubordinateGroups > 0) then {
    private _followMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
    [_allSubordinateGroups, _followMode] spawn FTCS_fnc_formationsGroupListFollowCommander;
    systemChat format ["[PLATOON DIRECTIVE] %1 deployed into %2 formation (Heading %3°). Moving to positions...", _pltData getOrDefault ["name", _pltKey], _formationType, round _advanceDir];
};

// 7. Clean up any previous formation arrows and debug slot markers
{
    if (_x find "FTCS_MAP_FORMATION_ARROW" == 0 || _x find "FTCS_FORMATION_MARKER" == 0 || _x find "FTCS_DEBUG_SLOT_" == 0) then {
        deleteMarkerLocal _x;
    };
} forEach allMapMarkers;

private _anchorPos = getPosATL _platoonLeaderUnit;
private _arrowMarkerName = format ["FTCS_MAP_FORMATION_ARROW_%1", round time];
private _arrowMarker = createMarkerLocal [_arrowMarkerName, _anchorPos];
_arrowMarker setMarkerTypeLocal "mil_arrow2";
_arrowMarker setMarkerColorLocal "ColorGreen";
_arrowMarker setMarkerDirLocal _advanceDir;
_arrowMarker setMarkerSizeLocal [1.2, 1.8];
_arrowMarker setMarkerTextLocal format [" %1 (%2 - %3°)", _pltData getOrDefault ["name", _pltKey], _formationType, round _advanceDir];

// 8. Debug slot markers on map (Active when FTCS_Debug_Mode is true)
private _isDebug = missionNamespace getVariable ["FTCS_Debug_Mode", false];
if (_isDebug) then {
    {
        private _slotDist = _x select 0;
        private _slotBearing = _x select 1;
        private _slotGrp = if (count _x > 2) then { _x select 2 } else { grpNull };
        private _slotPos = _anchorPos getPos [_slotDist, _advanceDir + _slotBearing];

        private _dotName = format ["FTCS_DEBUG_SLOT_%1_%2", _forEachIndex, round time];
        private _dot = createMarkerLocal [_dotName, _slotPos];
        _dot setMarkerTypeLocal "mil_dot";
        if (!isNull _slotGrp) then {
            _dot setMarkerColorLocal "ColorOrange";
            _dot setMarkerSizeLocal [0.8, 0.8];
            _dot setMarkerTextLocal format [" (Slot %1)", _forEachIndex];
        } else {
            // Theoretical unassigned slot position
            _dot setMarkerColorLocal "ColorYellow";
            _dot setMarkerSizeLocal [0.5, 0.5];
            _dot setMarkerTextLocal format [" (Slot %1)", _forEachIndex];
        };
    } forEach Platoon_Formation_Position_List;
};

true;
