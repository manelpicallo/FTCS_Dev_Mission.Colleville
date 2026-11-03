/*
    ================================================================================
    File: fn_platoonSetOperationalPhase.sqf
    Module: Core / Groups
    Author: FTCS Team
    Description: Transitions a tactical platoon to a specified Operational Phase
                 (FM 3-21.8 Doctrine: Phase 1 APPROACH, Phase 2 OVERWATCH, Phase 3 COMBAT).
                 Maintains independent state per platoon (FTCS_Platoon_Phase_1..4)
                 and applies group awareness, speed, rules of engagement, and stance
                 across all subordinate squads and HQ teams via modular group functions.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)

    +-----------------------------------------------------------------------------+
    |               PLATOON OPERATIONAL PHASE TRANSITION ENGINE                   |
    +-----------------------------------------------------------------------------+
    |                                                                             |
    |  Params: [_platoonID, _targetPhase]                                         |
    |               │                                                             |
    |               ▼                                                             |
    |     [Resolve Platoon Groups] (HQ teams + Squads 1..4)                       |
    |               │                                                             |
    |    ┌──────────┼─────────────────────────┐                                   |
    |    ▼          ▼                         ▼                                   |
    | [PHASE 1]     [PHASE 2]                 [PHASE 3]                              |
    |  APPROACH      OVERWATCH / LDA           COMBAT & ASSAULT                      |
    |  Aware:CARELESS Aware: AWARE             Aware: COMBAT                         |
    |  Speed:NORM    Speed: LIMITED            Speed: FULL                           |
    |  ROE: GREEN    ROE:   GREEN              ROE:   YELLOW                         |
    |  Stance:AUTO   Stance: AUTO              Stance: AUTO                          |
    |    └──────────┬─────────────────────────┘                                   |
    |               ▼                                                             |
    |  [Update State]: FTCS_Platoon_Phase_X + FTCS_Company_Data                   |
    +-----------------------------------------------------------------------------+
    ================================================================================
*/

params [
    ["_arg1", 1],
    ["_arg2", 0]
];

// Flexible parameter resolution:
// Syntax A: [_platoonID, _targetPhase] (e.g. [1, 2] or ["PLT_1", 2])
// Syntax B: [_targetPhase] (defaults to player platoon ID)
private _pltIndex = 1;
private _targetPhase = 1;

if (_arg2 isEqualType 0 && {_arg2 > 0}) then {
    // Syntax A
    if (_arg1 isEqualType "") then {
        private _parts = _arg1 splitString "_";
        _pltIndex = if (count _parts > 1) then { parseNumber (_parts select 1) } else { parseNumber _arg1 };
    } else {
        _pltIndex = _arg1;
    };
    _targetPhase = _arg2;
} else {
    // Syntax B: single argument is _targetPhase
    _targetPhase = _arg1;
    _pltIndex = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
};

// Clamp phase value between 1 and 3
if (_targetPhase < 1) then { _targetPhase = 1; };
if (_targetPhase > 3) then { _targetPhase = 3; };

// Clamp platoon index between 1 and 4
if (_pltIndex < 1) then { _pltIndex = 1; };
if (_pltIndex > 4) then { _pltIndex = 4; };

// 1. Resolve platoon data and all constituent groups from FTCS_Company_Data
private _pltKey = format ["PLT_%1", _pltIndex];
private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
private _pltName = _pltData getOrDefault ["name", format ["%1 Platoon", _pltKey]];
private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

private _platoonGroups = [];

{
    private _sqdKey = _x;
    private _sqdData = _y;

    // Check base group of the squad
    private _baseGrp = _sqdData getOrDefault ["group", grpNull];
    if (!isNull _baseGrp && {!(_baseGrp in _platoonGroups)}) then {
        _platoonGroups pushBack _baseGrp;
    };

    // Check sub-teams (tacticalTeams for multi-team squads or HQ elements)
    private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
    {
        private _tData = _y;
        private _tGrp = _tData getOrDefault ["group", grpNull];
        if (!isNull _tGrp && {!(_tGrp in _platoonGroups)}) then {
            _platoonGroups pushBack _tGrp;
        };
    } forEach _tacticalTeams;

} forEach _parsedSquads;

// 2. Apply doctrinal phase state to all platoon groups using modular group functions
switch (_targetPhase) do {

    case 1: { // PHASE 1: APPROACH (Traveling & Security / Unalerted non-combat)
        {
            private _grp = _x;
            // Awaken movement if frozen in assembly area
            (leader _grp) enableAI "PATH";
            (leader _grp) enableAI "MOVE";
            { _x enableAI "PATH"; _x enableAI "MOVE"; } forEach (units _grp);

            // Behavior CARELESS: weapons lowered/at rest, unalerted non-combat posture
            [_grp, "CARELESS"] call FTCS_fnc_groupSetAwareMode;
            [_grp, "NORMAL"] call FTCS_fnc_groupSetSpeed;
            [_grp, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE; // Weapons Tight / Return fire only
            [_grp, "AUTO"] call FTCS_fnc_groupSetStance;
        } forEach _platoonGroups;

        systemChat format ["[DOCTRINE: %1] Operational Phase transitioned to: PHASE 1 (APPROACH & TRAVELING).", _pltName];
        hint parseText format ["<t color='#00FFCC'>[DOCTRINAL PHASE 1 ACTIVE: %1]</t><br/><t color='#FFFFFF'>Phase:</t> APPROACH & TRAVELING<br/><t color='#AAAAAA'>Posture:</t> CARELESS (Weapons lowered / unalerted), Normal March Pace, Weapons Tight.", _pltName];
    };

    case 2: { // PHASE 2: CONTACT LIKELY / OVERWATCH (Cautious / Linear Danger Area)
        {
            private _grp = _x;
            (leader _grp) enableAI "PATH";
            (leader _grp) enableAI "MOVE";
            { _x enableAI "PATH"; _x enableAI "MOVE"; } forEach (units _grp);

            // Behavior AWARE: scanning sectors, cautious traveling overwatch pace
            [_grp, "AWARE"] call FTCS_fnc_groupSetAwareMode;
            [_grp, "LIMITED"] call FTCS_fnc_groupSetSpeed;
            [_grp, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE;
            [_grp, "AUTO"] call FTCS_fnc_groupSetStance;
        } forEach _platoonGroups;

        systemChat format ["[DOCTRINE: %1] Operational Phase transitioned to: PHASE 2 (CONTACT LIKELY / OVERWATCH).", _pltName];
        hint parseText format ["<t color='#FFAA00'>[DOCTRINAL PHASE 2 ACTIVE: %1]</t><br/><t color='#FFFFFF'>Phase:</t> CONTACT LIKELY / OVERWATCH<br/><t color='#AAAAAA'>Posture:</t> AWARE (Weapons raised), Cautious Pace, Bounding / LDA Readiness.", _pltName];
    };

    case 3: { // PHASE 3: COMBAT, ASSAULT & CONSOLIDATION (Full combat readiness)
        {
            private _grp = _x;
            (leader _grp) enableAI "PATH";
            (leader _grp) enableAI "MOVE";
            { _x enableAI "PATH"; _x enableAI "MOVE"; } forEach (units _grp);

            // Behavior COMBAT: tactical bounding, dynamic cover, weapons free
            [_grp, "COMBAT"] call FTCS_fnc_groupSetAwareMode;
            [_grp, "FULL"] call FTCS_fnc_groupSetSpeed;
            [_grp, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE; // Weapons Free
            [_grp, "AUTO"] call FTCS_fnc_groupSetStance;
        } forEach _platoonGroups;

        systemChat format ["[DOCTRINE: %1] Operational Phase transitioned to: PHASE 3 (COMBAT & ASSAULT).", _pltName];
        hint parseText format ["<t color='#FF4500'>[DOCTRINAL PHASE 3 ACTIVE: %1]</t><br/><t color='#FFFFFF'>Phase:</t> COMBAT & ASSAULT<br/><t color='#AAAAAA'>Posture:</t> COMBAT (Full readiness), Assault Speed, Weapons Free.", _pltName];
    };
};

// 3. Persist state in platoon-specific global variable and FTCS_Company_Data
missionNamespace setVariable [format ["FTCS_Platoon_Phase_%1", _pltIndex], _targetPhase];
_pltData set ["currentPhase", _targetPhase];

// Synchronize FTCS_CurrentPhase if this is the player's active command platoon
private _playerPlatoonID = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
if (_pltIndex == _playerPlatoonID) then {
    FTCS_CurrentPhase = _targetPhase;
};

diag_log format ["FTCS: Platoon '%1' (Index %2) shifted to Operational Phase %3. %4 group(s) updated.", _pltName, _pltIndex, _targetPhase, count _platoonGroups];
true;
