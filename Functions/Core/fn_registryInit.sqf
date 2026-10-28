/*
    File: fn_registryInit.sqf
    Module: Core
    Author: FTCS Team / Manel P.
    Description: Initializes the Master Encapsulated Group Registry (FTCS_Groups_Registry_Table)
                 from the parsed FTCS_Company_Data hierarchy. Creates one sub-HashMap per group
                 holding all real-time tactical state (state machine, geometry and ORBAT slot
                 allocation), replacing the old scattered per-property hash tables.

    Registry Sub-HashMap properties per group:
        * "movingMode"         : [String] ("AT_WILL", "FOLLOWING_COMMANDER_REL", "FOLLOWING_COMMANDER_ABS", "HALT", "STOP", "CONVOY").
        * "stance"             : [String] ("AT_WILL", "FORCE_UP", "FORCE_MIDDLE", "FORCE_DOWN").
        * "awareMode"          : [String] ("CARELESS", "SAFE", "AWARE", "COMBAT", "STEALTH").
        * "speed"              : [String] ("FULL", "NORMAL", "LIMITED").
        * "roe"                : [String] ("HOLD_FIRE", "FIRE_AT_WILL", "FIRE_IF_FIRED_UPON").
        * "task"               : [String] ("AT_WILL", "MOVING", "SUPPRESSING", "ATTACKING", "WATCHING", "WAITING").
        * "formationType"      : [String] Local element formation ("COLUMN", "WEDGE", "VEE", "LINE", "DIAMOND").
        * "allocationSlot"     : [Scalar] Numerical slot assignment in platoon formations (0, 1, 2, 3...).
        * "formationPosition"  : [Array]  Assigned geometric formation slot [Distance, Direction, Leader Object].
        * "relPosition"        : [Array]  Current relative position vector [Distance, Direction, Reference Leader].

    Also initializes the shared tactical constants and the platoon-level formation
    geometry buffer (Platoon_Formation_Position_List) used by the Formations module.
*/

// ---------------------------------------------------------------------------
// 1. Shared tactical constants (migrated from the legacy init block)
// ---------------------------------------------------------------------------

FTCS_Pace_Soldiers = 5;
FTCS_Platoon_MAX_Infantry_Groups = 13;
FTCS_Squad_MAX_Infantry_Groups = 5;

missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", 0];
missionNamespace setVariable ["FTCS_Last_Commander_Dir", getDir player];

// ---------------------------------------------------------------------------
// 2. Commander group reference (Company HQ group, fallback to player group)
// ---------------------------------------------------------------------------

private _companyHQ = FTCS_Company_Data getOrDefault ["companyHQ", createHashMap];
FTCS_Group_Commander = _companyHQ getOrDefault ["group", group player];

// ---------------------------------------------------------------------------
// 3. Registry access helper closures (global, engine-agnostic)
// ---------------------------------------------------------------------------

FTCS_fnc_registryGet = {
    params ["_groupID", "_key"];
    private _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];
    _entry getOrDefault [_key, nil];
};

FTCS_fnc_registrySet = {
    params ["_groupID", "_key", "_value"];
    private _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];
    _entry set [_key, _value];
    FTCS_Groups_Registry_Table set [_groupID, _entry];
    true;
};

// -------------------------------------------------------
// Registry geometry helper: updates formationPosition & relPosition slots together
// ---------------------------------------------------------------------------

FTCS_fnc_registryUpdatePos = {
    params ["_groupID", "_distance", "_direction"];
    private _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];
    private _formPos = _entry getOrDefault ["formationPosition", [-1, -1, objNull]];
    private _relPos = _entry getOrDefault ["relPosition", [-1, -1, objNull]];
    _formPos set [0, _distance]; _formPos set [1, _direction];
    _relPos set [0, _distance]; _relPos set [1, _direction];
    _entry set ["formationPosition", _formPos];
    _entry set ["relPosition", _relPos];
    FTCS_Groups_Registry_Table set [_groupID, _entry];
    true;
};

// ---------------------------------------------------------------------------
// 4. Build one encapsulated registry entry per parsed group
// ---------------------------------------------------------------------------

private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
private _registeredCount = 0;

{
    private _pltKey = _x;
    private _pltData = _y;
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

    // Platoon HQ group acts as the default formation leader reference for its squads
    private _pltHqSquadId = format ["SQD_%1_0", parseNumber ((_pltKey splitString "_") select 1)];
    private _pltHqGroup = grpNull;
    if (_parsedSquads get _pltHqSquadId isEqualType createHashMap) then {
        _pltHqGroup = (_parsedSquads get _pltHqSquadId) getOrDefault ["group", grpNull];
    };
    private _leaderRef = if (isNull _pltHqGroup) then { FTCS_Group_Commander } else { _pltHqGroup };

    private _slot = 0;

    {
        private _sqdId = _x;
        private _sqdData = _y;
        private _isUnified = _sqdData getOrDefault ["isUnified", false];

        // Collect every Arma 3 group belonging to this squad element (including HQ sub-teams)
        private _squadGroups = [];
        private _teamsContainer = _sqdData getOrDefault ["teams", _sqdData getOrDefault ["tacticalTeams", createHashMap]];

        if (count _teamsContainer > 0) then {
            {
                private _teamGroup = (_y) getOrDefault ["group", grpNull];
                if (!isNull _teamGroup) then { _squadGroups pushBack _teamGroup; };
            } forEach _teamsContainer;
        } else {
            private _grp = _sqdData getOrDefault ["group", grpNull];
            if (!isNull _grp) then { _squadGroups pushBack _grp; };
        };

        {
            private _group = _x;
            private _groupID = groupId _group;

            // Skip already registered groups (idempotent initialization)
            if !(_groupID in FTCS_Groups_Registry_Table) then {
                FTCS_Groups_Registry_Table set [_groupID, createHashMapFromArray [
                    ["movingMode", "AT_WILL"],
                    ["stance", "AT_WILL"],
                    ["awareMode", "SAFE"],
                    ["speed", "NORMAL"],
                    ["roe", "FIRE_IF_FIRED_UPON"],
                    ["task", "AT_WILL"],
                    ["formationType", "COLUMN"],
                    ["allocationSlot", _slot],
                    ["formationPosition", [-1, -1, _leaderRef]],
                    ["relPosition", [-1, -1, _leaderRef]]
                ]];
                _registeredCount = _registeredCount + 1;
            };
        } forEach _squadGroups;

        _slot = _slot + 1;

    } forEach _parsedSquads;

} forEach _platoonsMap;

// ---------------------------------------------------------------------------
// 5. Register ad-hoc teams and unassigned groups as well
// ---------------------------------------------------------------------------

{
    private _teamGroup = (_y) getOrDefault ["group", grpNull];
    if (!isNull _teamGroup) then {
        private _groupID = groupId _teamGroup;
        if !(_groupID in FTCS_Groups_Registry_Table) then {
            FTCS_Groups_Registry_Table set [_groupID, createHashMapFromArray [
                ["movingMode", "AT_WILL"],
                ["stance", "AT_WILL"],
                ["awareMode", "SAFE"],
                ["speed", "NORMAL"],
                ["roe", "FIRE_IF_FIRED_UPON"],
                ["task", "AT_WILL"],
                ["formationType", "COLUMN"],
                ["allocationSlot", -1],
                ["formationPosition", [-1, -1, FTCS_Group_Commander]],
                ["relPosition", [-1, -1, FTCS_Group_Commander]]
            ]];
            _registeredCount = _registeredCount + 1;
        };
    };
} forEach (FTCS_Company_Data getOrDefault ["teams", createHashMap]);

{
    private _groupID = groupId _x;
    if !(_groupID in FTCS_Groups_Registry_Table) then {
        FTCS_Groups_Registry_Table set [_groupID, createHashMapFromArray [
            ["movingMode", "AT_WILL"],
            ["stance", "AT_WILL"],
            ["awareMode", "SAFE"],
            ["speed", "NORMAL"],
            ["roe", "FIRE_IF_FIRED_UPON"],
            ["task", "AT_WILL"],
            ["formationType", "COLUMN"],
            ["allocationSlot", -1],
            ["formationPosition", [-1, -1, FTCS_Group_Commander]],
            ["relPosition", [-1, -1, FTCS_Group_Commander]]
        ]];
        _registeredCount = _registeredCount + 1;
    };
} forEach (FTCS_Company_Data getOrDefault ["unassignedGroups", []]);

// ---------------------------------------------------------------------------
// 6. Platoon-level formation geometry buffer (13 slots: commander + 0..11)
// ---------------------------------------------------------------------------

Platoon_Formation_Position_List = [[], [], [], [], [], [], [], [], [], [], [], [], []];

diag_log format ["FTCS: Master Group Registry initialized (%1 groups registered).", _registeredCount];
true;