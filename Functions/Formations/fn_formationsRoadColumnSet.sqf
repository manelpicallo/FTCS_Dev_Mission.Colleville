/*
    ================================================================================
    File: fn_formationsRoadColumnSet.sqf
    Module: Formations
    Author: FTCS Team
    Description: Calculates and assigns staggered ditch positions along a road path for each
                 subordinate group in a platoon, alternating left and right road shoulders.
                 When road width < 2.0m, automatically transitions to single file center line.
                 Emits dynamic map debug telemetry markers for all assigned slots if
                 FTCS_Debug_Mode is active.
    Params:
        0: ARRAY of ARRAY - Formations elements list: [[leaderGroup], [slot0Groups], [slot1Groups]...]
        1: ARRAY of ARRAY - Sampled road path [[posATL, tangentDir, roadWidth], ...]
        2: NUMBER - Base inter-element separation distance in meters.
    Returns:
        ARRAY of GROUP - Follower groups list.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params ["_formation_elements_in", "_roadPath", ["_separate_dis", 8]];

if (count _formation_elements_in == 0 || count _roadPath == 0) exitWith { [] };

private _formation_elements = +_formation_elements_in;
private _group_leader = (_formation_elements select 0) select 0;
private _leader = leader _group_leader;
_formation_elements deleteAt 0;

private _leaderPos = getPosATL _leader;
private _leaderHeading = getDir _leader;

private _followerList = [];
private _isDebug = missionNamespace getVariable ["FTCS_Debug_Mode", false];

// Platoon sequence of slots along road column march:
// Slot 0 (Vanguard / 1st Squad) -> Slot 4 (Platoon Sergeant) -> Slot 1 (2nd Squad) ->
// Slot 2 (3rd Squad) -> Slot 3 (4th Squad / Mortars) -> Slot 10 (Platoon Guide) -> Slot 5 (Rear Reserve)
// Slots 6, 7, 8 (Scouts) advance 40m forward along road.
// Slots 9 (HQ escort) operates close behind Leader.
private _slotOrder = [0, 4, 1, 2, 3, 10, 5];

// Map slots to road progression distance and shoulder side:
// Side alternates: -1 = Left Shoulder (babor), +1 = Right Shoulder (estribor), 0 = Center
private _currentPathDistance = 6.0; // Starts 6m behind platoon leader
private _currentSide = -1; // Starts on left shoulder

private _roadSlotsMap = createHashMap; // slotIndex -> [worldPos, tangentDir, shoulderOffset]

// Sample position along road path at given distance from start
private _fnc_getPosAtDistance = {
    params ["_distTarget", "_path"];
    private _accum = 0;
    private _foundPt = _path select (count _path - 1); // fallback to end

    for "_i" from 0 to (count _path - 2) do {
        private _ptA = (_path select _i) select 0;
        private _ptB = (_path select (_i + 1)) select 0;
        private _d = _ptA distance2D _ptB;
        if ((_accum + _d) >= _distTarget) exitWith {
            private _frac = if (_d > 0) then { (_distTarget - _accum) / _d } else { 0 };
            private _dir = (_path select _i) select 1;
            private _width = (_path select _i) select 2;
            private _interpPos = [
                (_ptA select 0) + ((_ptB select 0) - (_ptA select 0)) * _frac,
                (_ptA select 1) + ((_ptB select 1) - (_ptA select 1)) * _frac,
                (_ptA select 2) + ((_ptB select 2) - (_ptA select 2)) * _frac
            ];
            _foundPt = [_interpPos, _dir, _width];
        };
        _accum = _accum + _d;
    };
    _foundPt
};

// Process macro march slots and their constituent sub-groups / teams individually
private _registeredGroupsCount = 0;

{
    private _slotIdx = _x;
    private _elemGroups = if (_slotIdx < count _formation_elements) then { _formation_elements select _slotIdx } else { [] };

    if (count _elemGroups > 0) then {
        // Iterate over each sub-team/group in this slot individually
        {
            private _grp = _x;
            if (!isNull _grp) then {
                private _elementID = groupId _grp;
                private _unitCount = count (units _grp);

                // Sample position along road path for THIS specific team
                private _pathSample = [_currentPathDistance, _roadPath] call _fnc_getPosAtDistance;
                _pathSample params ["_centerPos", "_tangentDir", "_roadWidth"];

                // Defensive type check: guarantee scalar road width across all terrain types
                private _effectiveWidth = if (_roadWidth isEqualType 0 && {_roadWidth > 0}) then { _roadWidth } else { 4.5 };

                // Staggered shoulder offset: if road is wide enough (> 1.5m), place on shoulder edge; if <= 1.5m, trail center
                private _isStaggered = (_effectiveWidth > 1.5);
                private _shoulderOffset = if (_isStaggered) then {
                    (_effectiveWidth / 2.0) * 0.85 * _currentSide
                } else {
                    0
                };

                // Calculate perpendicular offset from road center line (perpendicular to tangentDir)
                private _perpDir = (_tangentDir + 90) % 360;
                private _finalTeamPos = _centerPos getPos [abs _shoulderOffset, if (_shoulderOffset < 0) then { (_perpDir + 180) % 360 } else { _perpDir }];

                // Store relative polar coordinates
                private _polarDist = _leader distance2D _finalTeamPos;
                private _polarBearing = _leader getRelDir _finalTeamPos;

                // Update encapsulated group registry for this team
                private _entry = FTCS_Groups_Registry_Table getOrDefault [_elementID, createHashMap];
                _entry set ["formationPosition", [_polarDist, _polarBearing, _group_leader]];
                _entry set ["relPosition", [_polarDist, _polarBearing, _group_leader]];
                _entry set ["roadTargetPos", _finalTeamPos];
                _entry set ["roadTangentDir", _tangentDir];
                _entry set ["roadOffsetDist", _currentPathDistance];
                _entry set ["roadShoulderOffset", _shoulderOffset];
                _entry set ["roadTeamIndex", _forEachIndex + 1];
                _entry set ["allocationSlot", _slotIdx];
                _entry set ["formationType", "COLUMN"]; // Sub-teams march in single file column along shoulder
                FTCS_Groups_Registry_Table set [_elementID, _entry];

                if !(_grp in _followerList) then { _followerList pushBack _grp; };

                // If this is the first/lead group of the slot, register into Platoon_Formation_Position_List
                if (_forEachIndex == 0) then {
                    Platoon_Formation_Position_List set [_slotIdx, [_polarDist, _polarBearing, _grp]];
                };

                // Telemetry debug feedback for THIS team
                if (_isDebug) then {
                    _grp setGroupIconParams [[0.55, 0.55, 0.55, 1.0], format ["[Road S%1] %2", _slotIdx, _elementID], 1.0, true];
                    systemChat format ["[ROAD S%1-T%2] %3 (%4 men) -> %5m along road (Shoulder: %6m)", _slotIdx, _forEachIndex + 1, _elementID, _unitCount, round _currentPathDistance, round _shoulderOffset];

                    // Draw unique dynamic 2D map slot marker per group
                    private _mName = format ["FTCS_DEBUG_ROAD_SLOT_%1", _elementID];
                    if (getMarkerType _mName == "") then {
                        createMarkerLocal [_mName, _finalTeamPos];
                        _mName setMarkerTypeLocal "mil_dot";
                    };
                    _mName setMarkerPosLocal _finalTeamPos;
                    _mName setMarkerTextLocal format [" (S%1-T%2)", _slotIdx, _forEachIndex + 1];
                    _mName setMarkerColorLocal "ColorOrange";
                    _mName setMarkerSizeLocal [0.75, 0.75];
                };

                // Advance path distance by this team's footprint:
                // Number of soldiers * 2m pace, plus 3m tactical interval to next team
                private _teamPace = ((_unitCount max 1) * 2.0) + 3.0;
                _currentPathDistance = _currentPathDistance + _teamPace;

                // Alternate shoulder side for the next team within this squad or next squad
                if (_isStaggered) then {
                    _currentSide = _currentSide * -1;
                };

                _registeredGroupsCount = _registeredGroupsCount + 1;
            };
        } forEach _elemGroups;

        // Add additional inter-squad separation distance buffer between consecutive squads
        _currentPathDistance = _currentPathDistance + _separate_dis;
    };
} forEach _slotOrder;

// Slot 9 (HQ Command Group Attachments): placed 2.5m behind leader on road
private _sample9 = [2.5, _roadPath] call _fnc_getPosAtDistance;
private _pos9 = _sample9 select 0;
private _tangent9 = _sample9 select 1;
if (count _formation_elements > 9 && {count (_formation_elements select 9) > 0}) then {
    private _grp9 = (_formation_elements select 9) select 0;
    if (!isNull _grp9) then {
        private _eID9 = groupId _grp9;
        private _entry9 = FTCS_Groups_Registry_Table getOrDefault [_eID9, createHashMap];
        _entry9 set ["roadTargetPos", _pos9];
        _entry9 set ["roadTangentDir", _tangent9];
        _entry9 set ["roadOffsetDist", 2.5];
        _entry9 set ["roadShoulderOffset", -1.0];
        _entry9 set ["allocationSlot", 9];
        _entry9 set ["formationType", "COLUMN"];
        FTCS_Groups_Registry_Table set [_eID9, _entry9];
        if !(_grp9 in _followerList) then { _followerList pushBack _grp9; };
        Platoon_Formation_Position_List set [9, [_leader distance2D _pos9, _leader getRelDir _pos9, _grp9]];
    };
};

// Slots 6, 7, 8 (Forward Scouts Screen): advanced 40m forward along road
private _scoutForwardPos = _leaderPos getPos [40, _leaderHeading];
if (count _formation_elements > 6 && {count (_formation_elements select 6) > 0}) then {
    private _grp6 = (_formation_elements select 6) select 0;
    if (!isNull _grp6) then {
        private _eID6 = groupId _grp6;
        private _entry6 = FTCS_Groups_Registry_Table getOrDefault [_eID6, createHashMap];
        _entry6 set ["roadTargetPos", _scoutForwardPos];
        _entry6 set ["roadTangentDir", _leaderHeading];
        _entry6 set ["roadOffsetDist", -40];
        _entry6 set ["roadShoulderOffset", 0];
        _entry6 set ["allocationSlot", 6];
        _entry6 set ["formationType", "COLUMN"];
        FTCS_Groups_Registry_Table set [_eID6, _entry6];
        if !(_grp6 in _followerList) then { _followerList pushBack _grp6; };
        Platoon_Formation_Position_List set [6, [40, 0, _grp6]];
    };
};

_followerList
