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
    |     -> FTCS_fnc_formationsTypePlatoonSet (Macro slots 0-12)                 |
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
    ["_formationType", "COLUMN"],
    ["_separationDistance", 15],
    ["_squadFormationsOverride", []]
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

// 3. Identify the Platoon Leader's group as the formation anchor [X]
private _pltIdx = parseNumber ((_pltKey splitString "_") select 1);
private _hqSquadId = format ["SQD_%1_0", _pltIdx];
private _hqSquadData = _parsedSquads getOrDefault [_hqSquadId, createHashMap];
private _hqTeams = _hqSquadData getOrDefault ["tacticalTeams", createHashMap];

// Ensure _platoonLeaderUnit is resolved to the actual Platoon Leader (Lieutenant), not the Sergeant
private _hqRoles = _hqSquadData getOrDefault ["assignedRoles", createHashMap];
private _resolvedLeader = _hqRoles getOrDefault [format ["PLT_%1_LEADER", _pltIdx], objNull];
if (!isNull _resolvedLeader) then {
    _platoonLeaderUnit = _resolvedLeader;
} else {
    if (isNull _platoonLeaderUnit || {(vehicleVarName _platoonLeaderUnit) find "SERGEANT" >= 0}) then {
        _platoonLeaderUnit = player;
    };
};
private _leaderGroup = group _platoonLeaderUnit;
missionNamespace setVariable ["FTCS_Platoon_Leader_Unit", _platoonLeaderUnit];

// Isolate HQ sub-teams distinctly:
// - Command Element remaining group (Team 1 without isolated Leader) -> Slot 9 (HQ Command Attachments)
// - Support Element group (Team 2: Platoon Sergeant, Runner, Medic) -> Slot 4 (Platoon Sergeant)
// - Guide / Security Element group (Team 3: Platoon Guide, Messenger / Security) -> Slot 10
// - Any secondary attached elements (e.g. attached Company messenger / liaison) -> Slot 10 fallback
private _team1Grp = grpNull;
private _team2Grp = grpNull;
private _team3Grp = grpNull;
private _extraHqGrps = [];

{
    private _tKey = toUpper _x;
    private _hGrp = (_y) getOrDefault ["group", grpNull];
    if (!isNull _hGrp && {_hGrp != _leaderGroup}) then {
        if (_tKey find "TEAM_1" >= 0 || _tKey find "COMMAND" >= 0) then {
            if (isNull _team1Grp) then { _team1Grp = _hGrp; } else { _extraHqGrps pushBack _hGrp; };
        } else {
            if (_tKey find "TEAM_2" >= 0 || _tKey find "SUPPORT" >= 0) then {
                if (isNull _team2Grp) then { _team2Grp = _hGrp; } else { _extraHqGrps pushBack _hGrp; };
            } else {
                if (_tKey find "TEAM_3" >= 0 || _tKey find "GUIDE" >= 0 || _tKey find "SECURITY" >= 0) then {
                    if (isNull _team3Grp) then { _team3Grp = _hGrp; } else { _extraHqGrps pushBack _hGrp; };
                } else {
                    _extraHqGrps pushBack _hGrp;
                };
            };
        };
    };
} forEach _hqTeams;

// Check if base HQ squad group is distinct from the leader's group
private _baseHqGroup = _hqSquadData getOrDefault ["group", grpNull];
if (!isNull _baseHqGroup && {_baseHqGroup != _leaderGroup}) then {
    if (isNull _team1Grp && isNull _team2Grp) then {
        _team2Grp = _baseHqGroup;
    } else {
        if !(_baseHqGroup in [_team1Grp, _team2Grp]) then {
            _extraHqGrps pushBack _baseHqGroup;
        };
    };
};

// 4. Resolve subordinate combat squads (Squad 1, Squad 2, Squad 3, Squad 4 / Mortars)
// and map Platoon HQ sub-teams to allow explicit doctrinal slot overrides (e.g. SQD_X_0_TEAM_1/2/3)
private _squadElementsMap = createHashMap; // Key: squad ID or team ID (e.g. "SQD_1_1", "SQD_1_0_TEAM_3") -> groups array
private _mortarElements = [];

// Register Platoon HQ sub-teams into _squadElementsMap so doctrine formationSlots overrides can target them
{
    private _tKey = _x;
    private _hGrp = (_y) getOrDefault ["group", grpNull];
    if (!isNull _hGrp && {_hGrp != _leaderGroup}) then {
        _squadElementsMap set [_tKey, [_hGrp]];
    };
} forEach _hqTeams;

{
    private _sqdKey = _x;
    if (_sqdKey find "_0" < 0) then {
        private _sqdData = _parsedSquads get _sqdKey;
        private _sqdName = _sqdData getOrDefault ["name", ""];
        private _squadGroup = _sqdData getOrDefault ["group", grpNull];
        private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];

        private _elementGroups = [];
        if (count _tacticalTeams > 0) then {
            private _teamKeys = keys _tacticalTeams;
            _teamKeys sort true;
            {
                private _tGrp = (_tacticalTeams get _x) getOrDefault ["group", grpNull];
                if (!isNull _tGrp) then {
                    _elementGroups pushBack _tGrp;
                    // Register individual team key as well for sub-team detachment (e.g. "SQD_1_1_TEAM_2")
                    _squadElementsMap set [_x, [_tGrp]];
                };
            } forEach _teamKeys;
        } else {
            if (!isNull _squadGroup) then { _elementGroups pushBack _squadGroup; };
        };

        if (count _elementGroups > 0) then {
            private _isMortar = (toLower _sqdName) find "mortar" >= 0 || (toLower _sqdName) find "mortero" >= 0;
            if (_isMortar && count _mortarElements == 0) then {
                _mortarElements = _elementGroups;
            };
            _squadElementsMap set [_sqdKey, _elementGroups];
        };
    };
} forEach (keys _parsedSquads);

// Initialize 13 macro formation slots (Slots 0 to 12)
private _slottedElements = [[], [], [], [], [], [], [], [], [], [], [], [], []];

// Query active doctrine custom slot overrides (Method 2 data template hook)
// Checks platoon-level pre-resolved formationSlots (from fn_applyDoctrine) or raw doctrine data.
// DOCTRINE: scout detachment mappings (outer slots 5,6,7,8,11,12 → team keys) are
// EPHEMERAL per formation order - a new cross-country order wipes them, so detached
// scouts re-join their doctrinal slot instead of resurrecting the old detachment.
private _formationSlotsMap = _pltData getOrDefault ["formationSlots", createHashMap];
private _detachedScoutKeys = [];
{
    private _sIdx = _x;
    if (_sIdx in [5, 6, 7, 8, 11, 12]) then {
        _detachedScoutKeys pushBack (_formationSlotsMap get _sIdx);
        _formationSlotsMap deleteAt _sIdx;
    };
} forEach (keys _formationSlotsMap);
_pltData set ["formationSlots", _formationSlotsMap];
if (count _formationSlotsMap == 0) then {
    private _activeDocData = FTCS_Company_Data getOrDefault ["activeDoctrineData", createHashMap];
    private _rawOverrides = _activeDocData getOrDefault ["platoonFormationSlots", createHashMap];
    {
        private _sIdx = _x;
        private _tPattern = _y;
        private _resolvedVal = if (_tPattern find "SQD_X_" == 0) then {
            format ["SQD_%1_%2", _pltIdx, _tPattern select [6]]
        } else {
            _tPattern
        };
        _formationSlotsMap set [_sIdx, _resolvedVal];
    } forEach _rawOverrides;
};

// Default deterministic assignment:
// Slot 0: 1st Rifle Squad (SQD_X_1)
private _sqd1Key = format ["SQD_%1_1", _pltIdx];
if (_sqd1Key in _squadElementsMap) then { _slottedElements set [0, _squadElementsMap get _sqd1Key]; };

// Slot 1: 2nd Rifle Squad (SQD_X_2)
private _sqd2Key = format ["SQD_%1_2", _pltIdx];
if (_sqd2Key in _squadElementsMap) then { _slottedElements set [1, _squadElementsMap get _sqd2Key]; };

// Slot 2: 3rd Rifle Squad (SQD_X_3)
private _sqd3Key = format ["SQD_%1_3", _pltIdx];
if (_sqd3Key in _squadElementsMap) then { _slottedElements set [2, _squadElementsMap get _sqd3Key]; };

// Slot 3: 4th Squad (SQD_X_4) or Mortar / Heavy Weapons section
private _sqd4Key = format ["SQD_%1_4", _pltIdx];
if (_sqd4Key in _squadElementsMap) then {
    _slottedElements set [3, _squadElementsMap get _sqd4Key];
} else {
    if (count _mortarElements > 0) then {
        _slottedElements set [3, _mortarElements];
    };
};

// Slot 4: Platoon Sergeant & Support Element (Team 2)
if (!isNull _team2Grp) then { _slottedElements set [4, [_team2Grp]]; };

// Slot 9: Company HQ Command Group Attachments (Team 1 escort / runners / RTO)
if (!isNull _team1Grp) then { _slottedElements set [9, [_team1Grp]]; };

// Slot 10: Platoon Guide / Security Element (Team 3) or secondary HQ liaison attachments
if (!isNull _team3Grp) then {
    _slottedElements set [10, [_team3Grp]];
} else {
    if (count _extraHqGrps > 0) then { _slottedElements set [10, [_extraHqGrps select 0]]; };
};

// Apply pre-configured formation slots from doctrine if defined
{
    private _slotIdx = _x;
    private _resolvedKey = _y; // e.g. "SQD_1_1", "SQD_1_0_TEAM_2", "SQD_1_1_TEAM_2"
    if (_slotIdx >= 0 && _slotIdx < 13) then {
        if (_resolvedKey in _squadElementsMap) then {
            private _assignedGroups = _squadElementsMap get _resolvedKey;
            _slottedElements set [_slotIdx, _assignedGroups];

            // If a specific sub-team was detached to an outer/scout slot (e.g. Slot 11, 12, 6, 7, 8),
            // remove that detached sub-team from its parent squad element list so its parent squad leader
            // does not drag it in internal squad formation geometry
            if (_slotIdx in [5, 6, 7, 8, 11, 12] && {_resolvedKey find "_TEAM_" >= 0}) then {
                private _detachedGrp = _assignedGroups select 0;
                for "_sI" from 0 to 3 do {
                    private _parentSquadList = _slottedElements select _sI;
                    if (_detachedGrp in _parentSquadList && {count _parentSquadList > 1}) then {
                        _slottedElements set [_sI, _parentSquadList - [_detachedGrp]];
                    };
                };
            };
        };
    };
} forEach _formationSlotsMap;

// Gather all active subordinate groups participating in formation navigation
// Platoon operational phase resolves once and is shared by the leader-group sync
// block and the subordinate AI configuration block below.
private _platoonPhase = missionNamespace getVariable [format ["FTCS_Platoon_Phase_%1", _pltIdx], 1];

private _allSubordinateGroups = [];
{
    {
        if (!isNull _x && {!(_x in _allSubordinateGroups)}) then {
            _allSubordinateGroups pushBack _x;
        };
    } forEach _x;
} forEach _slottedElements;

// Build final formation elements list: Index 0 is strictly Leader Group [X], followed by Slots 0 to 12
private _formationElements = [[_leaderGroup]] + _slottedElements;

// Reset platoon movement technique to open cross-country formation (releasing road march mode cleanly)
_pltData set ["movementTechnique", "CROSS_COUNTRY"];
_pltData set ["roadPath", []];
_platoonsMap set [_pltKey, _pltData];

// Invalidate every squad's marked 3D target: a NEW platoon formation restarts
// the tactical picture - squad movement menus return to their "no marked point"
// state (point-movement orders gated disabled until a fresh target is marked).
[] call FTCS_fnc_targetClearAllSquads;

// 5. Two-tier formation geometry calculation:
// (legacy FTCS_Platoon_Formation_Type global removed: the platoon-level formation
// lives exclusively in the registry field "platoonFormation" per group)

// Set platoon advance direction strictly to the leader's current heading at the moment the formation order is issued
private _advanceDir = getDir _platoonLeaderUnit;
missionNamespace setVariable ["FTCS_Platoon_Fixed_Abs_Dir", _advanceDir];
missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _advanceDir];
missionNamespace setVariable ["FTCS_Last_Commander_Dir", _advanceDir];

// Debug feedback: display slot 0 anchor info for Platoon Leader and update NATO icon
systemChat format ["[FORMATION ANCHOR SLOT 0] %1 -> (Heading %2° | Leader: %3)", groupId _leaderGroup, round _advanceDir, name (leader _leaderGroup)];
_leaderGroup setGroupIconParams [[0.55, 0.55, 0.55, 1.0], format ["[Slot 0 Anchor] %1", groupId _leaderGroup], 1.0, true];

// -------------------------------------------------------------------------
// Doctrinal State & AI Synchronization for Platoon Leader Anchor Group (_leaderGroup / HQ)
// -------------------------------------------------------------------------
if (!isNull _leaderGroup) then {

    switch (_platoonPhase) do {
        case 1: {
            [_leaderGroup, "CARELESS"] call FTCS_fnc_groupSetAwareMode;
            [_leaderGroup, "NORMAL"] call FTCS_fnc_groupSetSpeed;
            [_leaderGroup, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE;
            [_leaderGroup, "AUTO"] call FTCS_fnc_groupSetStance;
        };
        case 2: {
            [_leaderGroup, "AWARE"] call FTCS_fnc_groupSetAwareMode;
            [_leaderGroup, "LIMITED"] call FTCS_fnc_groupSetSpeed;
            [_leaderGroup, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE;
            [_leaderGroup, "AUTO"] call FTCS_fnc_groupSetStance;
        };
        case 3: {
            [_leaderGroup, "COMBAT"] call FTCS_fnc_groupSetAwareMode;
            [_leaderGroup, "FULL"] call FTCS_fnc_groupSetSpeed;
            [_leaderGroup, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE;
            [_leaderGroup, "AUTO"] call FTCS_fnc_groupSetStance;
        };
    };

    if (_platoonPhase < 3) then {
        {
            if (_x != _platoonLeaderUnit) then {
                _x disableAI "AUTOCOMBAT";
                _x disableAI "COVER";
                _x enableAI "PATH";
                _x enableAI "MOVE";
                _x doFollow _platoonLeaderUnit;
            };
        } forEach (units _leaderGroup);
    };
};

// FTCS_fnc_formationsTypePlatoonSet calculates macro platoon slots (0 to 12)
// and recursively calls FTCS_fnc_formationsTypeSquadSet for internal squad teams
private _followerGroups = [_formationElements, _formationType, _separationDistance, _squadFormationsOverride] call FTCS_fnc_formationsTypePlatoonSet;

// Default AI configuration for every cross-country formation order, mirroring the
// road march entry pattern: stance ("Copy My Stance") plus doctrinal awareness,
// speed and ROE per operational phase, applied through the standardized group
// functions only. Phase profile mirrors the leader-group table above, except
// phase 2 uses AWARE (not SAFE) to keep vigilant spacing coherent for subordinates.
{
    private _grp = _x;
    if (!isNull _grp) then {
        [_grp, "FOLLOW_COMMANDER_STANCE"] call FTCS_fnc_groupSetStance;

        switch (_platoonPhase) do {
            case 1: {
                [_grp, "CARELESS"] call FTCS_fnc_groupSetAwareMode;
                [_grp, "NORMAL"] call FTCS_fnc_groupSetSpeed;
                [_grp, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE;
            };
            case 2: {
                [_grp, "AWARE"] call FTCS_fnc_groupSetAwareMode;
                [_grp, "LIMITED"] call FTCS_fnc_groupSetSpeed;
                [_grp, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE;
            };
            case 3: {
                [_grp, "COMBAT"] call FTCS_fnc_groupSetAwareMode;
                [_grp, "FULL"] call FTCS_fnc_groupSetSpeed;
                [_grp, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE;
            };
            default { };
        };
    };
} forEach _allSubordinateGroups;

// Straggler recovery supervisor (levels 1-2): cross-country orders share the
// same watchdog coverage as road/trail marches. Bumping the shared generation
// kills any previous march watchdog for this platoon and spawns a fresh one.
private _wdGen = (missionNamespace getVariable [format ["FTCS_March_Watchdog_Gen_PLT_%1", _pltIdx], 0]) + 1;
missionNamespace setVariable [format ["FTCS_March_Watchdog_Gen_PLT_%1", _pltIdx], _wdGen];
[_pltIdx, _wdGen] spawn FTCS_fnc_marchStuckWatchdog;

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

// 8. Launch real-time dynamic formation slots visualizer on map
missionNamespace setVariable ["FTCS_Debug_Mode", true];
[_platoonLeaderUnit] spawn FTCS_fnc_formationsLiveSlotsDebugWorker;

true;
