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

params ["_formation_elements_in", "_roadPath", ["_separate_dis", 8], ["_forcedSide", 0]];

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
// Slot 9 (HQ Escort) marches FIRST, attached closest behind the Leader, sized by
// its own manpower footprint; then Slot 0 (Vanguard / 1st Squad) -> Slot 4 (Platoon
// Sergeant) -> Slot 1 (2nd Squad) -> Slot 2 (3rd Squad) -> Slot 3 (4th Squad / Mortars)
// -> Slot 10 (Platoon Guide) -> Slot 5 (Rear Reserve).
// Slots 6, 7, 8 (Scouts) advance 40m forward along road.
private _slotOrder = [9, 0, 4, 1, 2, 3, 10, 5];

// Map slots to road progression distance and shoulder side:
// Side alternates: -1 = Left Shoulder (babor), +1 = Right Shoulder (estribor), 0 = Center
// Vanguard march order: HQ Escort (slot 9) travels first, attached closest behind
// the leader, consuming path distance by its own manpower footprint; following
// squads then alternate left/right shoulders exactly like slot 9 does.
// IMPORTANT: the rear path starts at the ROAD NODE nearest the leader, not at the
// leader himself. Slot distances must be anchored to the leader's arclength within
// the path, otherwise every slot appears shifted forward by that unaccounted gap.
private _leaderArc = 0;
private _bestLeaderDist = 1e10;
{
    private _d = (_x select 0) distance2D _leaderPos;
    if (_d < _bestLeaderDist) then { _bestLeaderDist = _d; _leaderArc = _forEachIndex; };
} forEach _roadPath;
// Convert the nearest sample INDEX into its cumulative arclength from path origin
private _leaderArcLen = 0;
for "_li" from 0 to (_leaderArc - 1) do {
    _leaderArcLen = _leaderArcLen + (((_roadPath select _li) select 0) distance2D ((_roadPath select (_li + 1)) select 0));
};
    private _currentPathDistance = _leaderArcLen + 2.0; // HQ Escort (slot 9) starts 2m behind the LEADER
// Forced side: 0 = alternating staggered shoulders (default); -1 = all LEFT; +1 = all RIGHT
private _forcedSide = _forcedSide;
private _currentSide = if (_forcedSide != 0) then { _forcedSide } else { -1 }; // Starts on left shoulder

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

                // Staggered shoulder offset: if road is wide enough (> 1.5m), place on shoulder edge; if <= 1.5m, trail center.
                // Stepped edge margin (edgeMarginSteps) shifts the offset (steps * 3m) beyond the asphalt edge.
                private _edgeStepsS = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", (missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1])], createHashMap] getOrDefault ["edgeMarginSteps", 0];
                private _edgeMarginS = _edgeStepsS * 3.0;
                private _isStaggered = (_effectiveWidth > 1.5);
                private _shoulderOffset = if (!_isStaggered) then {
                    0
                } else {
                    if (_edgeMarginS > 0) then {
                        ((_effectiveWidth / 2.0) + _edgeMarginS) * _currentSide
                    } else {
                        (_effectiveWidth / 2.0) * 0.85 * _currentSide
                    };
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
                _entry set ["roadColumnSide", _currentSide]; // informational: current shoulder side (-1 L / +1 R / 0 C)
                _entry set ["roadTeamIndex", _forEachIndex + 1];
                _entry set ["allocationSlot", _slotIdx];
                // NOTE: no doctrinal formation fields (platoonFormation/squadFormation/teamFormation)
                // are written here - road march owns its own geometry via the road* fields.
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
                // MEASURED team length: real distance from the group leader to his
                // rearmost soldier (engine formations do not spread linearly with
                // man count, so a formula underestimates for larger teams). Floor
                // at the nominal model (men * 3.5 + 3) to keep the column airy.
                private _rearmost = 0;
                { private _d = (leader _grp) distance2D _x; if (_d > _rearmost) then { _rearmost = _d; }; } forEach (units _grp);
                private _teamPace = (_rearmost max ((_unitCount max 1) * 3.5)) + 3.0;
                _currentPathDistance = _currentPathDistance + _teamPace;

                // Alternate shoulder side for the next team within this squad or next squad
                // (skipped entirely under a forced LEFT/RIGHT single-shoulder column)
                if (_isStaggered && { _forcedSide == 0 }) then {
                    _currentSide = _currentSide * -1;
                };

                _registeredGroupsCount = _registeredGroupsCount + 1;
            };
        } forEach _elemGroups;

        // Add additional inter-squad separation distance buffer between consecutive squads
        _currentPathDistance = _currentPathDistance + _separate_dis;
    };
} forEach _slotOrder;

// NOTE: Slot 9 (HQ Escort) is now processed FIRST inside the main _slotOrder loop
// (see slot order array), consuming path distance by its own manpower footprint
// and alternating shoulder sides like every other element. No special-case block.

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
        _entry6 set ["roadColumnSide", 0];
        _entry6 set ["allocationSlot", 6];
        FTCS_Groups_Registry_Table set [_eID6, _entry6];
        if !(_grp6 in _followerList) then { _followerList pushBack _grp6; };
        Platoon_Formation_Position_List set [6, [40, 0, _grp6]];
    };
};

_followerList
