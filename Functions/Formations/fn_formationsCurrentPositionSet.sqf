/*
    ================================================================================
    File: fn_formationsCurrentPositionSet.sqf
    Module: Formations
    Author: FTCS Team
    Description: Captures current real-world ground positions and relative orientations
                 of all platoon squads and nested fireteams on the terrain, locking them
                 into the active formation registry without altering default templates.
                 Preserves two-tier hierarchy:
                 - Tier 1: Squad Leaders anchored relative to Platoon Leader.
                 - Tier 2: Fireteams anchored relative to their own Squad Leader.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)

    +-----------------------------------------------------------------------------+
    |                 CURRENT GROUND LAYOUT CAPTURE ENGINE                        |
    +-----------------------------------------------------------------------------+
    |                                                                             |
    |  Platoon Leader [Anchor] (Position P, Heading D)                            |
    |         │                                                                   |
    |         ├─► Squad 1 Leader (d1, bearing1 -> relDir to Commander)            |
    |         │        │                                                          |
    |         │        ├─► Fireteam 2 (dist, relDir to Squad 1 Leader)            |
    |         │        └─► Fireteam 3 (dist, relDir to Squad 1 Leader)            |
    |         │                                                                   |
    |         ├─► Squad 2 Leader (d2, bearing2 -> relDir to Commander)            |
    |         │        │                                                          |
    |         │        ├─► Fireteam 2 (dist, relDir to Squad 2 Leader)            |
    |         │        └─► Fireteam 3 (dist, relDir to Squad 2 Leader)            |
    |         │                                                                   |
    |         └─► Squad 3 Leader (d3, bearing3 -> relDir to Commander)            |
    +-----------------------------------------------------------------------------+
    ================================================================================
*/

params [
    ["_platoonLeaderUnit", objNull],
    ["_explicitMode", ""]
];

if (isNull _platoonLeaderUnit) then {
    private _commanderGroup = missionNamespace getVariable ["FTCS_Group_Commander", group player];
    _platoonLeaderUnit = if (!isNull _commanderGroup) then { leader _commanderGroup } else { player };
};

if (isNull _platoonLeaderUnit) exitWith { false };

// 1. Resolve platoon key and structure from FTCS_Company_Data
private _pltKey = missionNamespace getVariable ["FTCS_SelectedPlatoonKey", ""];
if (_pltKey == "") then {
    private _pId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    _pltKey = format ["PLT_%1", _pId];
};
private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
private _pltName = _pltData getOrDefault ["name", _pltKey];
private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

if (count _parsedSquads == 0) exitWith {
    systemChat format ["[FTCS Formations] Error: No parsed squads found for %1.", _pltKey];
    false;
};

// 2. Validate operational phase: Troops in Phase 0 (DEPLOYMENT / INSPECTION) remain frozen
private _currentPhase = _pltData getOrDefault ["currentPhase", 0];
if (_currentPhase == 0) exitWith {
    systemChat format ["[FTCS Formations] %1 is in DEPLOYMENT / INSPECTION phase (Troops Frozen). Set Operational Phase first.", _pltName];
    hint parseText format ["<t color='#FFAA00'>[FORMATION BLOCKED]</t><br/><t color='#FFFFFF'>%1</t> is in inspection mode.<br/><t color='#00FFCC'>Action required:</t> Set Operational Phase (Approach / Combat) via Platoon Sergeant before locking formation.", _pltName];
    false;
};

// 3. Resolve active follow mode (Relative vs Absolute)
private _followMode = if (_explicitMode != "") then {
    _explicitMode
} else {
    missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"]
};

private _isRelative = (_followMode == "FOLLOWING_COMMANDER_REL");
private _leaderGroup = group _platoonLeaderUnit;

// Update global advance direction strictly from leader's current heading
private _advanceDir = getDir _platoonLeaderUnit;
missionNamespace setVariable ["FTCS_Platoon_Fixed_Abs_Dir", _advanceDir];
missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _advanceDir];
missionNamespace setVariable ["FTCS_Last_Commander_Dir", _advanceDir];

private _allSubordinateGroups = [];

// 4. Capture Platoon HQ Sub-teams (Tier 1: anchored relative to Platoon Leader)
private _hqSquadId = format ["SQD_%1_0", parseNumber ((_pltKey splitString "_") select 1)];
private _hqSquadData = _parsedSquads getOrDefault [_hqSquadId, createHashMap];
private _hqTeams = _hqSquadData getOrDefault ["tacticalTeams", createHashMap];

{
    private _tGrp = (_y) getOrDefault ["group", grpNull];
    if (!isNull _tGrp && {_tGrp != _leaderGroup}) then {
        private _tLeader = leader _tGrp;
        if (!isNull _tLeader) then {
            private _tDist = _tLeader distance2D _platoonLeaderUnit;
            private _tAngle = if (_isRelative) then { _platoonLeaderUnit getRelDir _tLeader } else { _platoonLeaderUnit getDir _tLeader };
            private _gId = groupId _tGrp;

            [_gId, "formationPosition", [_tDist, _tAngle, _leaderGroup]] call FTCS_fnc_registrySet;
            [_gId, "relPosition", [_tDist, _tAngle, _leaderGroup]] call FTCS_fnc_registrySet;

            if !(_tGrp in _allSubordinateGroups) then { _allSubordinateGroups pushBack _tGrp; };
        };
    };
} forEach _hqTeams;

// 5. Capture Combat Squads & nested Fireteams (Two-tier hierarchy)
private _squadKeys = keys _parsedSquads;
_squadKeys sort true;

{
    private _sqdKey = _x;
    if (_sqdKey find "_0" < 0) then {
        private _sqdData = _parsedSquads get _sqdKey;
        private _squadGroup = _sqdData getOrDefault ["group", grpNull];
        private _squadLeader = _sqdData getOrDefault ["leader", objNull];
        private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];

        // Tier 1: Squad Leader anchored relative to Platoon Leader
        private _squadAnchorObj = if (!isNull _squadLeader) then { _squadLeader } else { if (!isNull _squadGroup) then { leader _squadGroup } else { objNull } };
        private _squadAnchorGrp = if (!isNull _squadGroup) then { _squadGroup } else { grpNull };

        if (!isNull _squadAnchorObj) then {
            private _sqdDist = _squadAnchorObj distance2D _platoonLeaderUnit;
            private _sqdAngle = if (_isRelative) then { _platoonLeaderUnit getRelDir _squadAnchorObj } else { _platoonLeaderUnit getDir _squadAnchorObj };

            // If unified squad (no multi-teams), anchor the base squad group to Platoon Leader
            if (count _tacticalTeams == 0 && {!isNull _squadGroup}) then {
                private _gId = groupId _squadGroup;
                [_gId, "formationPosition", [_sqdDist, _sqdAngle, _leaderGroup]] call FTCS_fnc_registrySet;
                [_gId, "relPosition", [_sqdDist, _sqdAngle, _leaderGroup]] call FTCS_fnc_registrySet;
                if !(_squadGroup in _allSubordinateGroups) then { _allSubordinateGroups pushBack _squadGroup; };
            };

            // If multi-team squad, Team 1 (Squad Leader Team) anchors to Platoon Leader
            if (count _tacticalTeams > 0) then {
                private _tKeys = keys _tacticalTeams;
                _tKeys sort true;

                // Team 1 = Squad Leader
                private _team1Key = _tKeys select 0;
                private _team1Data = _tacticalTeams get _team1Key;
                private _team1Grp = _team1Data getOrDefault ["group", grpNull];

                if (!isNull _team1Grp) then {
                    private _t1Leader = leader _team1Grp;
                    private _t1Dist = _t1Leader distance2D _platoonLeaderUnit;
                    private _t1Angle = if (_isRelative) then { _platoonLeaderUnit getRelDir _t1Leader } else { _platoonLeaderUnit getDir _t1Leader };
                    private _gId = groupId _team1Grp;

                    [_gId, "formationPosition", [_t1Dist, _t1Angle, _leaderGroup]] call FTCS_fnc_registrySet;
                    [_gId, "relPosition", [_t1Dist, _t1Angle, _leaderGroup]] call FTCS_fnc_registrySet;
                    if !(_team1Grp in _allSubordinateGroups) then { _allSubordinateGroups pushBack _team1Grp; };

                    // Tier 2: Sub-teams (Team 2, 3, 4) anchored relative to Team 1 (Squad Leader)
                    for "_idx" from 1 to ((count _tKeys) - 1) do {
                        private _subTeamKey = _tKeys select _idx;
                        private _subTeamData = _tacticalTeams get _subTeamKey;
                        private _subTeamGrp = _subTeamData getOrDefault ["group", grpNull];

                        if (!isNull _subTeamGrp) then {
                            private _subLeader = leader _subTeamGrp;
                            if (!isNull _subLeader) then {
                                private _subDist = _subLeader distance2D _t1Leader;
                                private _subAngle = if (_isRelative) then { _t1Leader getRelDir _subLeader } else { _t1Leader getDir _subLeader };
                                private _subGId = groupId _subTeamGrp;

                                [_subGId, "formationPosition", [_subDist, _subAngle, _team1Grp]] call FTCS_fnc_registrySet;
                                [_subGId, "relPosition", [_subDist, _subAngle, _team1Grp]] call FTCS_fnc_registrySet;
                                if !(_subTeamGrp in _allSubordinateGroups) then { _allSubordinateGroups pushBack _subTeamGrp; };
                            };
                        };
                    };
                };
            };
        };
    };
} forEach _squadKeys;

// 6. Launch concurrent follow-commander movement threads for all subordinate groups
if (count _allSubordinateGroups > 0) then {
    [_allSubordinateGroups, _followMode] spawn FTCS_fnc_formationsGroupListFollowCommander;
};

// 7. Update 2D tactical map formation arrow marker & debug slot points
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
_arrowMarker setMarkerTextLocal format [" %1 (Ground Locked - %2°)", _pltName, round _advanceDir];

// 8. Launch real-time dynamic formation slots visualizer on map
missionNamespace setVariable ["FTCS_Debug_Mode", true];
[_platoonLeaderUnit] spawn FTCS_fnc_formationsLiveSlotsDebugWorker;

// 9. Player feedback
private _modeLabel = if (_isRelative) then { "Relative" } else { "Absolute" };
systemChat format ["[FORMATION LOCKED] %1 formation geometry anchored to current real-world ground layout (%2 mode).", _pltName, _modeLabel];
hint parseText format ["<t color='#00FFCC'>[GROUND LAYOUT LOCKED]</t><br/><t color='#FFFFFF'>%1</t><br/><t color='#FFAA00'>Mode:</t> %2<br/><t color='#AAAAAA'>Positions and relative bearings captured from active terrain coordinates.", _pltName, _modeLabel];

true;
