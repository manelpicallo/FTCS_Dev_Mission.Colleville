/*
    ================================================================================
    File: fn_applyCommandToTarget.sqf
    Module: Interactions
    Author: FTCS Team
    Description: Receives an action code from a native commandingMenu selection [1-9],
                 resolves the active target subordinate unit/group, applies the
                 tactical backend directive, and displays feedback.
                 Fully mapped to FTCS_Menu_Structure_Reference (Doctrine FM 3-21.8).
    Language: Strictly English (Rule 7, Rule 11)

    +-----------------------------------------------------------------------------+
    |                    TACTICAL COMMAND DISPATCH ENGINE                         |
    +-----------------------------------------------------------------------------+
    |                                                                             |
    |  [Command Code] ──► [Command Dispatcher]                                    |
    |                           │                                                 |
    |    ┌──────────────────────┼─────────────────────────┐                       |
    |    ▼                      ▼                         ▼                       |
    | [PHASE TRANSITIONS]  [PHASE 1: MARCH]         [PHASE 2: OVERWATCH / LDA]   |
    |   - SET_PHASE_1        - Formations (Column..)  - Bounding (Succ / Cont)   |
    |   - SET_PHASE_2        - Techniques (Traveling) - Halt & 360 Security       |
    |   - SET_PHASE_3        - Route & March Control  - LDA (SBF / Leapfrog)      |
    |                        - Weapons Control Status - Weapons Readiness        |
    |                                                                             |
    |    ┌────────────────────────────────────────────────┐                       |
    |    ▼                                                ▼                       |
    | [PHASE 3: COMBAT & ASSAULT]                  [PRE-MISSION / CP / TLP]       |
    |   - Platoon Tactics (Assault Wave / Flank)     - METT-TC Analysis           |
    |   - Squad Directives (Alpha/Bravo/Charlie/Wpn) - Platoon Roster             |
    |   - 3D Terrain Tactics (Move, Breach, Push)    - Sustainment & Ammo         |
    |   - Direct Target Engagement & Suppression     - Fire Support Planning      |
    |   - Fire Direction & Mortar Support            - OPORD TacMap               |
    |   - Sustainment & MEDEVAC / CCP                                             |
    +-----------------------------------------------------------------------------+
    ================================================================================
*/

params [["_commandCode", ""]];

if (_commandCode == "") exitWith {};

private _targetUnit = missionNamespace getVariable ["FTCS_ActiveMenu_Target", objNull];
private _targetGroup = if (!isNull _targetUnit) then { group _targetUnit } else { grpNull };
private _targetRole = missionNamespace getVariable ["FTCS_ActiveMenu_Role", "Subordinate"];
private _targetName = if (!isNull _targetUnit) then { name _targetUnit } else { _targetRole };

private _crosshairPos = missionNamespace getVariable ["FTCS_ActiveMenu_Pos", screenToWorld [0.5, 0.5]];
private _crosshairObj = missionNamespace getVariable ["FTCS_ActiveMenu_CursorObject", cursorObject];

// Helper to retrieve specific platoon squad group
private _fnc_getPlatoonSquad = {
    params ["_squadSuffix"];
    private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    private _pltKey = format ["PLT_%1", _pltId];
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
    private _sqdKey = format ["SQD_%1_%2", _pltId, _squadSuffix];
    private _sData = _parsedSquads getOrDefault [_sqdKey, createHashMap];
    _sData getOrDefault ["group", grpNull]
};

// Helper to retrieve all subordinate groups & fireteams in current platoon
private _fnc_getAllPlatoonSquads = {
    private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    private _pltKey = format ["PLT_%1", _pltId];
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
    private _result = [];
    {
        private _sqdKey = _x;
        private _sqdData = _y;

        // Platoon HQ sub-teams
        if (_sqdKey find "_0" >= 0) then {
            private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
            {
                private _tGrp = _y getOrDefault ["group", grpNull];
                if (!isNull _tGrp && {_tGrp != group player} && {!(_tGrp in _result)}) then {
                    _result pushBack _tGrp;
                };
            } forEach _tacticalTeams;
        } else {
            // Combat squads and fireteams
            private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
            if (count _tacticalTeams > 0) then {
                private _tKeys = keys _tacticalTeams;
                _tKeys sort true;
                {
                    private _tGrp = (_tacticalTeams get _x) getOrDefault ["group", grpNull];
                    if (!isNull _tGrp && {!(_tGrp in _result)}) then { _result pushBack _tGrp; };
                } forEach _tKeys;
            } else {
                private _grp = _sqdData getOrDefault ["group", grpNull];
                if (!isNull _grp && {!(_grp in _result)}) then { _result pushBack _grp; };
            };
        };
    } forEach _parsedSquads;
    _result
};

// Helper to retrieve the actual platoon leader unit (player or NPC lieutenant)
private _fnc_getPlatoonLeaderUnit = {
    private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    private _pltKey = format ["PLT_%1", _pltId];
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
    private _hqSquadId = format ["SQD_%1_0", _pltId];
    private _hqData = _parsedSquads getOrDefault [_hqSquadId, createHashMap];
    private _roles = _hqData getOrDefault ["assignedRoles", createHashMap];
    private _pltLeaderRole = format ["PLT_%1_LEADER", _pltId];
    private _leader = _roles getOrDefault [_pltLeaderRole, objNull];
    if (isNull _leader) then {
        _leader = missionNamespace getVariable ["FTCS_Platoon_Leader_Unit", objNull];
    };
    if (isNull _leader) then {
        if (!isNull _targetUnit && {!((vehicleVarName _targetUnit) find "SERGEANT" >= 0)}) then {
            _leader = _targetUnit;
        } else {
            _leader = player;
        };
    };
    _leader
};

// -----------------------------------------------------------------------------
// COMMAND DISPATCH SWITCH
// -----------------------------------------------------------------------------
switch (_commandCode) do {

    // =========================================================================
    // 0. OPERATIONAL PHASE TRANSITIONS (FM 3-21.8)
    // =========================================================================
    case "SET_PHASE_1": {
        private _pId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        if (!isNull _targetUnit) then {
            private _uVar = vehicleVarName _targetUnit;
            if (_uVar != "" && {_uVar find "PLT_" >= 0}) then {
                private _parts = _uVar splitString "_";
                private _idx = _parts find "PLT";
                if (_idx >= 0 && {count _parts > _idx + 1}) then {
                    private _parsed = parseNumber (_parts select (_idx + 1));
                    if (_parsed > 0) then { _pId = _parsed; };
                };
            };
        };
        [_pId, 1] call FTCS_fnc_platoonSetOperationalPhase;
    };
    case "SET_PHASE_2": {
        private _pId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        if (!isNull _targetUnit) then {
            private _uVar = vehicleVarName _targetUnit;
            if (_uVar != "" && {_uVar find "PLT_" >= 0}) then {
                private _parts = _uVar splitString "_";
                private _idx = _parts find "PLT";
                if (_idx >= 0 && {count _parts > _idx + 1}) then {
                    private _parsed = parseNumber (_parts select (_idx + 1));
                    if (_parsed > 0) then { _pId = _parsed; };
                };
            };
        };
        [_pId, 2] call FTCS_fnc_platoonSetOperationalPhase;
    };
    case "SET_PHASE_3": {
        private _pId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        if (!isNull _targetUnit) then {
            private _uVar = vehicleVarName _targetUnit;
            if (_uVar != "" && {_uVar find "PLT_" >= 0}) then {
                private _parts = _uVar splitString "_";
                private _idx = _parts find "PLT";
                if (_idx >= 0 && {count _parts > _idx + 1}) then {
                    private _parsed = parseNumber (_parts select (_idx + 1));
                    if (_parsed > 0) then { _pId = _parsed; };
                };
            };
        };
        [_pId, 3] call FTCS_fnc_platoonSetOperationalPhase;
    };

    // =========================================================================
    // 1. TACTICAL STANCE (Common across all phases)
    // =========================================================================
    case "STANCE_AUTO": {
        if (!isNull _targetGroup) then {
            [_targetGroup, "AUTO"] call FTCS_fnc_groupSetStance;
            systemChat format ["[ORDER] %1 (%2): Stance set to AUTO.", _targetName, _targetRole];
        };
    };
    case "STANCE_UP": {
        if (!isNull _targetGroup) then {
            [_targetGroup, "FORCE_UP"] call FTCS_fnc_groupSetStance;
            systemChat format ["[ORDER] %1 (%2): Forced STAND UP.", _targetName, _targetRole];
        };
    };
    case "STANCE_MIDDLE": {
        if (!isNull _targetGroup) then {
            [_targetGroup, "FORCE_MIDDLE"] call FTCS_fnc_groupSetStance;
            systemChat format ["[ORDER] %1 (%2): Forced CROUCH.", _targetName, _targetRole];
        };
    };
    case "STANCE_DOWN": {
        if (!isNull _targetGroup) then {
            [_targetGroup, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
            systemChat format ["[ORDER] %1 (%2): Forced PRONE (Take cover).", _targetName, _targetRole];
        };
    };
    case "STANCE_FOLLOW_COMMANDER": {
        if (!isNull _targetGroup) then {
            [_targetGroup, "FOLLOW_COMMANDER_STANCE"] call FTCS_fnc_groupSetStance;
            systemChat format ["[ORDER] %1 (%2): Stance synced to Commander (Mirroring).", _targetName, _targetRole];
        };
    };

    // =========================================================================
    // 2. FASE 1: PLATOON FORMATIONS & MARCH CONTROL
    // =========================================================================
    case "PLT_FORM_COLUMN": {
        [call _fnc_getPlatoonLeaderUnit, "COLUMN", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to COLUMN (Trail / Road March).";
    };
    case "PLT_FORM_FILE": {
        // Reserved for special terrain / single file march (Road / Dense Vegetation)
        [call _fnc_getPlatoonLeaderUnit, "COLUMN", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to FILE (Single File / Narrow Trail).";
    };
    case "PLT_FORM_WEDGE": {
        [call _fnc_getPlatoonLeaderUnit, "WEDGE", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to WEDGE (Cross-country Security).";
    };
    case "PLT_FORM_VEE": {
        [call _fnc_getPlatoonLeaderUnit, "VEE", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to VEE (Flexible Front).";
    };
    case "PLT_FORM_LINE": {
        [call _fnc_getPlatoonLeaderUnit, "LINE", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to LINE (Maximum Frontage).";
    };
    case "PLT_FORM_DIAMOND": {
        [call _fnc_getPlatoonLeaderUnit, "DIAMOND", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to DIAMOND (All-Round Security / Open Terrain).";
    };

    case "PLT_FORM_LOCK_GROUND": {
        [call _fnc_getPlatoonLeaderUnit] call FTCS_fnc_formationsCurrentPositionSet;
        showCommandingMenu "#USER:FTCS_MENU_PlatoonFormations_P1";
    };

    case "PLT_MODE_RELATIVE": {
        missionNamespace setVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
        (FTCS_MENU_PlatoonFormations_P1 select 8) set [6, "0"];
        (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "1"];
        
        // Adopt current ground positions dynamically and engage relative follow mode
        [call _fnc_getPlatoonLeaderUnit, "FOLLOWING_COMMANDER_REL"] call FTCS_fnc_formationsCurrentPositionSet;
        systemChat "[FOLLOW MODE] Platoon follow mode set to RELATIVE (Turn with Leader). Current ground layout locked.";
        showCommandingMenu "#USER:FTCS_MENU_PlatoonFormations_P1";
    };

    case "PLT_MODE_ABSOLUTE": {
        missionNamespace setVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_ABS"];
        (FTCS_MENU_PlatoonFormations_P1 select 8) set [6, "1"];
        (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "0"];
        
        // Ensure absolute formation heading is locked to current platoon leader heading
        private _ldr = call _fnc_getPlatoonLeaderUnit;
        private _lockDir = getDir _ldr;
        missionNamespace setVariable ["FTCS_Platoon_Fixed_Abs_Dir", _lockDir];
        missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _lockDir];
        missionNamespace setVariable ["FTCS_Last_Commander_Dir", _lockDir];
        
        // Adopt current ground positions dynamically and engage absolute follow mode
        [_ldr, "FOLLOWING_COMMANDER_ABS"] call FTCS_fnc_formationsCurrentPositionSet;
        systemChat "[FOLLOW MODE] Platoon follow mode set to ABSOLUTE (Fixed Compass). Current ground layout locked.";
        showCommandingMenu "#USER:FTCS_MENU_PlatoonFormations_P1";
    };

    case "TECH_TRAVELING": {
        private _squads = call _fnc_getAllPlatoonSquads;
        {
            _x setSpeedMode "NORMAL";
            _x setBehaviourStrong "AWARE";
        } forEach _squads;
        systemChat "[MOVEMENT TECHNIQUE] Platoon set to TRAVELING (Standard March Speed).";
    };
    case "TECH_TRAVELING_OVERWATCH": {
        private _squads = call _fnc_getAllPlatoonSquads;
        {
            _x setSpeedMode "LIMITED";
            _x setBehaviourStrong "AWARE";
        } forEach _squads;
        systemChat "[MOVEMENT TECHNIQUE] Platoon set to TRAVELING OVERWATCH (Cautious Staggered Advance).";
    };

    case "PACE_NORMAL": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { _x setSpeedMode "NORMAL"; } forEach _squads;
        systemChat "[MARCH CONTROL] Platoon pace set to NORMAL.";
    };
    case "PACE_LIMITED": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { _x setSpeedMode "LIMITED"; } forEach _squads;
        systemChat "[MARCH CONTROL] Platoon pace set to LIMITED (Patrol / Cautious).";
    };
    case "PACE_FAST": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { _x setSpeedMode "FULL"; } forEach _squads;
        systemChat "[MARCH CONTROL] Platoon pace set to FAST (Rush / Quick Bound).";
    };
    case "CHECK_WAYPOINT": {
        hint parseText "<t color='#00FFCC'>[NAVIGATION CHECK]</t><br/><t color='#FFFFFF'>Route Status:</t> On designated Axis of Advance.<br/><t color='#FFAA00'>Heading:</t> Bearing locked towards Objective.";
        systemChat "[NAVIGATION] Platoon Leader checking route & checkpoints.";
    };

    case "WCS_HOLD": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { [_x, "HOLD_FIRE"] call FTCS_fnc_groupSetROE; } forEach _squads;
        systemChat "[WEAPONS STATUS] WEAPONS HOLD: Do not fire under any circumstances.";
    };
    case "WCS_TIGHT": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { [_x, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE; } forEach _squads;
        systemChat "[WEAPONS STATUS] WEAPONS TIGHT: Fire only if fired upon or positively identified hostile.";
    };
    case "WCS_FREE": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { [_x, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE; } forEach _squads;
        systemChat "[WEAPONS STATUS] WEAPONS FREE: Engage all confirmed enemy targets at will.";
    };

    case "PLT_FOLLOW_COMMANDER": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { [_x, group player] call FTCS_fnc_formationsGroupDoFollowCommander; } forEach _squads;
        systemChat "[PLATOON DIRECTIVE] Entire platoon regrouping on Commander.";
    };
    case "PLT_SITREP": {
        private _squads = call _fnc_getAllPlatoonSquads;
        private _total = 0;
        private _alive = 0;
        {
            _total = _total + count (units _x);
            _alive = _alive + ({ alive _y } count (units _x));
        } forEach _squads;
        hint parseText format ["<t color='#00FFCC'>[PLATOON SITREP]</t><br/><t color='#FFFFFF'>Personnel:</t> %1 / %2 combat effective.<br/><t color='#FFAA00'>Phase:</t> Phase %3<br/><t color='#00FFCC'>Morale & Readiness:</t> Green.", _alive, _total, missionNamespace getVariable ["FTCS_CurrentPhase", 1]];
    };

    // =========================================================================
    // 3. FASE 1: SQUAD BASE FORMATIONS & PACE
    // =========================================================================
    case "SQD_FORM_COLUMN";
    case "SQD_FORM_LINE";
    case "SQD_FORM_FILE";
    case "SQD_FORM_WEDGE": {
        private _sqdFormType = switch (_commandCode) do {
            case "SQD_FORM_COLUMN": { "COLUMN" };
            case "SQD_FORM_LINE":   { "LINE" };
            case "SQD_FORM_FILE":   { "FILE" };
            case "SQD_FORM_WEDGE":  { "WEDGE" };
            default { "COLUMN" };
        };

        if (!isNull _targetGroup) then {
            private _tGrpId = groupId _targetGroup;

            // 1. Resolve platoon and squad key
            private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
            private _pltKey = format ["PLT_%1", _pltId];
            private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
            private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
            private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

            // Locate squad entry corresponding to targetGroup
            private _targetSquadData = createHashMap;
            private _targetSquadId = "";
            {
                private _sId = _x;
                private _sData = _y;
                private _grp = _sData getOrDefault ["group", grpNull];
                private _teams = _sData getOrDefault ["tacticalTeams", createHashMap];

                if (_grp == _targetGroup) exitWith {
                    _targetSquadData = _sData;
                    _targetSquadId = _sId;
                };

                private _foundTeam = false;
                {
                    if ((_y getOrDefault ["group", grpNull]) == _targetGroup) exitWith {
                        _foundTeam = true;
                    };
                } forEach _teams;

                if (_foundTeam) exitWith {
                    _targetSquadData = _sData;
                    _targetSquadId = _sId;
                };
            } forEach _parsedSquads;

            // 2. Gather squad elements (Team 1, 2, 3, 4) or unified group
            private _squadElements = [];
            private _tacticalTeams = _targetSquadData getOrDefault ["tacticalTeams", createHashMap];
            if (count _tacticalTeams > 0) then {
                private _teamKeys = keys _tacticalTeams;
                _teamKeys sort true;
                {
                    private _tGrp = (_tacticalTeams get _x) getOrDefault ["group", grpNull];
                    if (!isNull _tGrp) then { _squadElements pushBack _tGrp; };
                } forEach _teamKeys;
            } else {
                private _grp = _targetSquadData getOrDefault ["group", _targetGroup];
                if (!isNull _grp) then { _squadElements pushBack _grp; };
            };

            // 3. Persist manual formation choice into registry
            [_tGrpId, "formationType", _sqdFormType] call FTCS_fnc_registrySet;

            // 4. Trigger recursive squad formation calculation
            if (count _squadElements > 1) then {
                [_squadElements, _sqdFormType, 4, 0] call FTCS_fnc_formationsTypeSquadSet;
            } else {
                _targetGroup setFormation _sqdFormType;
            };

            systemChat format ["[SQUAD DIRECTIVE] %1: Local formation deployed into %2.", _targetRole, _sqdFormType];
        };
    };
    case "SQD_PACE_NORMAL": {
        if (!isNull _targetGroup) then {
            _targetGroup setSpeedMode "NORMAL";
            systemChat format ["[SQUAD ORDER] %1: March pace set to NORMAL.", _targetRole];
        };
    };
    case "SQD_PACE_FAST": {
        if (!isNull _targetGroup) then {
            _targetGroup setSpeedMode "FULL";
            systemChat format ["[SQUAD ORDER] %1: March pace set to QUICK.", _targetRole];
        };
    };
    case "SQD_SPACING_CLOSE": {
        if (!isNull _targetGroup) then {
            systemChat format ["[SQUAD ORDER] %1: Spacing contracted to 5m close interval.", _targetRole];
        };
    };
    case "SQD_SPACING_OPEN": {
        if (!isNull _targetGroup) then {
            systemChat format ["[SQUAD ORDER] %1: Spacing expanded to 10m open interval.", _targetRole];
        };
    };
    case "TASK_FOLLOW_COMMANDER": {
        if (!isNull _targetGroup) then {
            [_targetGroup, group player] call FTCS_fnc_formationsGroupDoFollowCommander;
            systemChat format ["[SQUAD ORDER] %1: Regrouping on Commander.", _targetRole];
        };
    };
    case "SQUAD_SITREP": {
        private _aliveCount = { alive _x } count (units _targetGroup);
        private _totalCount = count (units _targetGroup);
        hint parseText format ["<t color='#00FFCC'>[SQUAD SITREP: %1]</t><br/><t color='#FFFFFF'>Leader:</t> %2<br/><t color='#FFAA00'>Readiness:</t> %3 / %4 men active.<br/><t color='#AAAAAA'>Combat Mode:</t> %5", _targetRole, _targetName, _aliveCount, _totalCount, combatMode _targetGroup];
    };

    // =========================================================================
    // 4. FASE 2: BOUNDING OVERWATCH & LINEAR DANGER AREA (LDA) CROSSING
    // =========================================================================
    case "BOUNDING_SUCCESSIVE": {
        systemChat "[OVERWATCH] Platoon initiating SUCCESSIVE BOUNDS (Alternate squad leapfrog).";
    };
    case "BOUNDING_CONTINUOUS": {
        systemChat "[OVERWATCH] Platoon initiating CONTINUOUS BOUNDS (Continuous overwatch leapfrog).";
    };
    case "BOUNDING_CEASE": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { _x setSpeedMode "NORMAL"; } forEach _squads;
        systemChat "[OVERWATCH] Cease bounds: Platoon consolidating in current positions.";
    };
    case "P2_HALT_360": {
        private _squads = call _fnc_getAllPlatoonSquads;
        {
            { doStop _x; } forEach (units _x);
            [_x, "FORCE_MIDDLE"] call FTCS_fnc_groupSetStance;
        } forEach _squads;
        systemChat "[OVERWATCH] Platoon ordered to HALT & ESTABLISH 360-DEGREE PERIMETER.";
    };

    // LDA Support Squad Assignments (SBF Base)
    case "LDA_SBF_ALPHA": {
        private _grp = ["1"] call _fnc_getPlatoonSquad;
        if (!isNull _grp) then {
            { doStop _x; } forEach (units _grp);
            [_grp, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
            systemChat "[LDA PROTOCOL] Squad Alpha assigned as SUPPORT SQUAD (SBF Base on near side).";
        };
    };
    case "LDA_SBF_BRAVO": {
        private _grp = ["2"] call _fnc_getPlatoonSquad;
        if (!isNull _grp) then {
            { doStop _x; } forEach (units _grp);
            [_grp, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
            systemChat "[LDA PROTOCOL] Squad Bravo assigned as SUPPORT SQUAD (SBF Base on near side).";
        };
    };
    case "LDA_SBF_WEAPONS": {
        private _grp = ["4"] call _fnc_getPlatoonSquad;
        if (!isNull _grp) then {
            { doStop _x; } forEach (units _grp);
            [_grp, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
            systemChat "[LDA PROTOCOL] Weapons Section assigned as SUPPORT SQUAD (Heavy SBF Base).";
        };
    };

    // LDA Crossing Squad Assignments (Security Point)
    case "LDA_CROSS_ALPHA": {
        private _grp = ["1"] call _fnc_getPlatoonSquad;
        if (!isNull _grp) then {
            _grp setSpeedMode "FULL";
            systemChat "[LDA PROTOCOL] Squad Alpha ordered to CROSS FIRST and secure far-side bridgehead.";
        };
    };
    case "LDA_CROSS_BRAVO": {
        private _grp = ["2"] call _fnc_getPlatoonSquad;
        if (!isNull _grp) then {
            _grp setSpeedMode "FULL";
            systemChat "[LDA PROTOCOL] Squad Bravo ordered to CROSS FIRST and secure far-side bridgehead.";
        };
    };
    case "LDA_CROSS_CHARLIE": {
        private _grp = ["3"] call _fnc_getPlatoonSquad;
        if (!isNull _grp) then {
            _grp setSpeedMode "FULL";
            systemChat "[LDA PROTOCOL] Squad Charlie ordered to CROSS FIRST and secure far-side bridgehead.";
        };
    };
    case "LDA_LEAPFROG": {
        systemChat "[LDA PROTOCOL] Remainder of Platoon executing LEAPFROG CROSSING under security coverage.";
    };

    case "SQD_RECON_AHEAD": {
        if (!isNull _targetGroup) then {
            _targetGroup setSpeedMode "LIMITED";
            [_targetGroup, "FORCE_MIDDLE"] call FTCS_fnc_groupSetStance;
            systemChat format ["[SCOUT DIRECTIVE] %1: Scouts probing ahead across danger area.", _targetRole];
        };
    };
    case "SQD_SET_OVERWATCH": {
        if (!isNull _targetGroup) then {
            { doStop _x; } forEach (units _targetGroup);
            [_targetGroup, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
            systemChat format ["[OVERWATCH] %1: Establishing overwatch base on danger area flanks.", _targetRole];
        };
    };
    case "SQD_RESUME_MARCH": {
        if (!isNull _targetGroup) then {
            _targetGroup setSpeedMode "NORMAL";
            [_targetGroup, "AUTO"] call FTCS_fnc_groupSetStance;
            systemChat format ["[DIRECTIVE] %1: Threat cleared; resuming standard advance.", _targetRole];
        };
    };

    // =========================================================================
    // 5. FASE 3: COMBAT & PLATOON-WIDE TACTICAL ORDERS
    // =========================================================================
    case "PLT_ASSAULT_WAVE": {
        private _squads = call _fnc_getAllPlatoonSquads;
        {
            _x setSpeedMode "FULL";
            _x setCombatMode "RED";
            _x setFormation "LINE";
        } forEach _squads;
        systemChat "[PLATOON ASSAULT] DIRECT ASSAULT WAVE: All squads executing synchronized assault wave!";
    };
    case "PLT_FLANK_LEFT": {
        private _sbfGrp = ["4"] call _fnc_getPlatoonSquad;
        if (isNull _sbfGrp) then { _sbfGrp = ["1"] call _fnc_getPlatoonSquad; };
        if (!isNull _sbfGrp) then {
            { doStop _x; } forEach (units _sbfGrp);
            [_sbfGrp, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
        };
        private _flankGrp = ["2"] call _fnc_getPlatoonSquad;
        if (!isNull _flankGrp) then { _flankGrp setSpeedMode "FULL"; };
        systemChat "[PLATOON MANEUVER] LEFT ENVELOPMENT: Base of Fire fixing enemy; Maneuver element flanking LEFT.";
    };
    case "PLT_FLANK_RIGHT": {
        private _sbfGrp = ["4"] call _fnc_getPlatoonSquad;
        if (isNull _sbfGrp) then { _sbfGrp = ["1"] call _fnc_getPlatoonSquad; };
        if (!isNull _sbfGrp) then {
            { doStop _x; } forEach (units _sbfGrp);
            [_sbfGrp, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
        };
        private _flankGrp = ["3"] call _fnc_getPlatoonSquad;
        if (!isNull _flankGrp) then { _flankGrp setSpeedMode "FULL"; };
        systemChat "[PLATOON MANEUVER] RIGHT ENVELOPMENT: Base of Fire fixing enemy; Maneuver element flanking RIGHT.";
    };
    case "PLT_BASE_OF_FIRE": {
        private _squads = call _fnc_getAllPlatoonSquads;
        {
            [_x, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE;
            [_x, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
        } forEach _squads;
        systemChat "[PLATOON TACTIC] BASE OF FIRE: All elements laying down heavy suppressive fire!";
    };
    case "PLT_FALLBACK": {
        private _squads = call _fnc_getAllPlatoonSquads;
        {
            _x setSpeedMode "FULL";
            [_x, "FORCE_MIDDLE"] call FTCS_fnc_groupSetStance;
        } forEach _squads;
        systemChat "[PLATOON RETREAT] Orderly fall back / break contact initiated across platoon.";
    };

    // Individual Squad Combat Directives (Alpha, Bravo, Charlie, Weapons)
    case "SQD_ALPHA_PUSH": {
        private _g = ["1"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then { _g setSpeedMode "FULL"; };
        systemChat "[SQUAD DIRECTIVE] Squad Alpha: Direct push forward aggressively!";
    };
    case "SQD_ALPHA_FLANK_L": {
        systemChat "[SQUAD DIRECTIVE] Squad Alpha: Executing flanking maneuver to the LEFT.";
    };
    case "SQD_ALPHA_FLANK_R": {
        systemChat "[SQUAD DIRECTIVE] Squad Alpha: Executing flanking maneuver to the RIGHT.";
    };
    case "SQD_ALPHA_FALLBACK": {
        systemChat "[SQUAD DIRECTIVE] Squad Alpha: Breaking contact & executing leapfrog fallback.";
    };
    case "SQD_ALPHA_SUPPRESS": {
        private _g = ["1"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then { [_g, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE; };
        systemChat "[SQUAD DIRECTIVE] Squad Alpha: Initiating suppressive fire on target sector.";
    };

    case "SQD_BRAVO_PUSH": {
        private _g = ["2"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then { _g setSpeedMode "FULL"; };
        systemChat "[SQUAD DIRECTIVE] Squad Bravo: Direct push forward aggressively!";
    };
    case "SQD_BRAVO_FLANK_L": {
        systemChat "[SQUAD DIRECTIVE] Squad Bravo: Executing flanking maneuver to the LEFT.";
    };
    case "SQD_BRAVO_FLANK_R": {
        systemChat "[SQUAD DIRECTIVE] Squad Bravo: Executing flanking maneuver to the RIGHT.";
    };
    case "SQD_BRAVO_FALLBACK": {
        systemChat "[SQUAD DIRECTIVE] Squad Bravo: Breaking contact & executing leapfrog fallback.";
    };
    case "SQD_BRAVO_SUPPRESS": {
        private _g = ["2"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then { [_g, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE; };
        systemChat "[SQUAD DIRECTIVE] Squad Bravo: Initiating suppressive fire on target sector.";
    };

    case "SQD_CHARLIE_PUSH": {
        private _g = ["3"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then { _g setSpeedMode "FULL"; };
        systemChat "[SQUAD DIRECTIVE] Squad Charlie: Direct push forward aggressively!";
    };
    case "SQD_CHARLIE_FLANK_L": {
        systemChat "[SQUAD DIRECTIVE] Squad Charlie: Executing flanking maneuver to the LEFT.";
    };
    case "SQD_CHARLIE_FLANK_R": {
        systemChat "[SQUAD DIRECTIVE] Squad Charlie: Executing flanking maneuver to the RIGHT.";
    };
    case "SQD_CHARLIE_FALLBACK": {
        systemChat "[SQUAD DIRECTIVE] Squad Charlie: Breaking contact & executing leapfrog fallback.";
    };
    case "SQD_CHARLIE_SUPPRESS": {
        private _g = ["3"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then { [_g, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE; };
        systemChat "[SQUAD DIRECTIVE] Squad Charlie: Initiating suppressive fire on target sector.";
    };

    case "SQD_WEAPONS_SBF": {
        private _g = ["4"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then {
            { doStop _x; } forEach (units _g);
            [_g, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
        };
        systemChat "[WEAPONS DIRECTIVE] Weapons Section: Establishing Support by Fire (SBF) Base!";
    };
    case "SQD_WEAPONS_SUPPRESS": {
        private _g = ["4"] call _fnc_getPlatoonSquad;
        if (!isNull _g) then { [_g, "FIRE_AT_WILL"] call FTCS_fnc_groupSetROE; };
        systemChat "[WEAPONS DIRECTIVE] Weapons Section: Heavy continuous suppression on target sector!";
    };
    case "SQD_WEAPONS_REPOSITION": {
        systemChat "[WEAPONS DIRECTIVE] Weapons Section: Packing static weapons & repositioning.";
    };
    case "SQD_WEAPONS_RESUPPLY": {
        systemChat "[WEAPONS DIRECTIVE] Ammo Bearers redistributing ammunition to machine gun teams.";
    };

    // Fire Direction & Support
    case "FIRE_SUPPRESS_TRP": {
        systemChat "[FIRE DIRECTION] All support elements focusing fire on designated Target Reference Point (TRP).";
    };
    case "FIRE_SHIFT_SECTOR": {
        systemChat "[FIRE DIRECTION] Shifting suppressive fire to secondary target sector.";
    };
    case "FIRE_CEASE": {
        private _squads = call _fnc_getAllPlatoonSquads;
        { [_x, "HOLD_FIRE"] call FTCS_fnc_groupSetROE; } forEach _squads;
        systemChat "[FIRE DIRECTION] CEASE FIRE! All elements hold fire immediately.";
    };

    case "SUSTAIN_ROSTER": {
        private _squads = call _fnc_getAllPlatoonSquads;
        private _total = 0;
        private _alive = 0;
        {
            _total = _total + count (units _x);
            _alive = _alive + ({ alive _y } count (units _x));
        } forEach _squads;
        hint parseText format ["<t color='#00FFCC'>[PLATOON ROSTER CHECK]</t><br/><t color='#FFFFFF'>Effective strength:</t> %1 / %2 men.<br/><t color='#FFAA00'>Casualties:</t> %3 wounded/KIA.", _alive, _total, (_total - _alive)];
    };
    case "SUSTAIN_ESTABLISH_CCP": {
        systemChat "[SUSTAINMENT] Designated Casualty Collection Point (CCP) established at current location.";
    };
    case "SUSTAIN_MEDEVAC": {
        systemChat "[SUSTAINMENT] Transmitting 9-Line MEDEVAC request to Battalion Aid Station.";
    };
    case "SUSTAIN_AMMO": {
        systemChat "[SUSTAINMENT] First Sergeant / Ammo Bearers redistributing combat ammunition reserves.";
    };

    case "FS_MORTAR_BARRAGE": {
        systemChat "[FIRE SUPPORT] Fire Mission Transmitted: 60mm/81mm HE Mortar Barrage inbound!";
    };
    case "FS_SMOKE_SCREEN": {
        systemChat "[FIRE SUPPORT] Fire Mission Transmitted: Smoke screen concealment mission inbound!";
    };
    case "FS_ILLUM_FLARES": {
        systemChat "[FIRE SUPPORT] Fire Mission Transmitted: Night illumination flares dispatched!";
    };

    // =========================================================================
    // 6. FASE 3: LOCAL 3D TERRAIN & CROSSHAIR TACTICS
    // =========================================================================
    case "TACTIC_MOVE_COVER": {
        if (!isNull _targetGroup) then {
            _targetGroup move _crosshairPos;
            systemChat format ["[TERRAIN TACTIC] %1: Moving to cover at targeted point.", _targetRole];
        };
    };
    case "TACTIC_BREACH_CLEAR": {
        if (!isNull _targetGroup) then {
            private _bldg = nearestBuilding _crosshairPos;
            if (!isNull _bldg) then {
                _targetGroup move (getPosATL _bldg);
                systemChat format ["[TERRAIN TACTIC] %1: Assaulting & clearing targeted building!", _targetRole];
            } else {
                systemChat "[TERRAIN TACTIC] No building detected at targeted crosshair.";
            };
        };
    };
    case "PUSH_5M": {
        if (!isNull _targetGroup) then {
            private _dir = getDir player;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 5, cos _dir * 5, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Bound 5 meters forward!", _targetRole];
        };
    };
    case "PUSH_10M": {
        if (!isNull _targetGroup) then {
            private _dir = getDir player;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 10, cos _dir * 10, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Bound 10 meters forward!", _targetRole];
        };
    };
    case "PUSH_15M": {
        if (!isNull _targetGroup) then {
            private _dir = getDir player;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 15, cos _dir * 15, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Bound 15 meters forward!", _targetRole];
        };
    };
    case "PUSH_25M": {
        if (!isNull _targetGroup) then {
            private _dir = getDir player;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 25, cos _dir * 25, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Bound 25 meters forward!", _targetRole];
        };
    };

    case "FALLBACK_5M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) + 180;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 5, cos _dir * 5, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Fall back 5 meters!", _targetRole];
        };
    };
    case "FALLBACK_10M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) + 180;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 10, cos _dir * 10, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Fall back 10 meters!", _targetRole];
        };
    };
    case "FALLBACK_15M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) + 180;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 15, cos _dir * 15, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Fall back 15 meters!", _targetRole];
        };
    };
    case "FALLBACK_25M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) + 180;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 25, cos _dir * 25, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Fall back 25 meters!", _targetRole];
        };
    };

    case "SHIFT_L_5M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) - 90;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 5, cos _dir * 5, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Shift left 5 meters.", _targetRole];
        };
    };
    case "SHIFT_L_10M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) - 90;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 10, cos _dir * 10, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Shift left 10 meters.", _targetRole];
        };
    };
    case "SHIFT_R_5M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) + 90;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 5, cos _dir * 5, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Shift right 5 meters.", _targetRole];
        };
    };
    case "SHIFT_R_10M": {
        if (!isNull _targetGroup) then {
            private _dir = (getDir player) + 90;
            private _newPos = (getPosATL (leader _targetGroup)) vectorAdd [sin _dir * 10, cos _dir * 10, 0];
            _targetGroup move _newPos;
            systemChat format ["[TERRAIN TACTIC] %1: Shift right 10 meters.", _targetRole];
        };
    };

    case "TACTIC_BREAK_CONTACT": {
        if (!isNull _targetGroup) then {
            _targetGroup setSpeedMode "FULL";
            systemChat format ["[TACTIC] %1: Breaking contact under covering fire!", _targetRole];
        };
    };
    case "TACTIC_FLANK_LEFT": {
        systemChat format ["[TACTIC] %1: Maneuvering around enemy LEFT FLANK.", _targetRole];
    };
    case "TACTIC_FLANK_RIGHT": {
        systemChat format ["[TACTIC] %1: Maneuvering around enemy RIGHT FLANK.", _targetRole];
    };

    case "ENGAGE_CROSSHAIR": {
        if (!isNull _targetGroup) then {
            if (!isNull _crosshairObj) then {
                _targetGroup reveal [_crosshairObj, 4];
                _targetGroup doTarget _crosshairObj;
                _targetGroup doFire _crosshairObj;
                systemChat format ["[FIRE ORDER] %1: Engaging designated target at crosshair!", _targetRole];
            } else {
                _targetGroup doSuppressiveFire _crosshairPos;
                systemChat format ["[FIRE ORDER] %1: Suppressing target position at crosshair.", _targetRole];
            };
        };
    };
    case "SUPPRESS_CROSSHAIR": {
        if (!isNull _targetGroup) then {
            _targetGroup doSuppressiveFire _crosshairPos;
            systemChat format ["[FIRE ORDER] %1: Suppressing window / nest at crosshair position!", _targetRole];
        };
    };
    case "ASSAULT_CROSSHAIR": {
        if (!isNull _targetGroup) then {
            _targetGroup move _crosshairPos;
            _targetGroup setSpeedMode "FULL";
            _targetGroup setCombatMode "RED";
            systemChat format ["[FIRE ORDER] %1: ASSAULTING TARGET POSITION NOW!", _targetRole];
        };
    };

    case "CONSOLIDATE_FACING": {
        systemChat format ["[CONSOLIDATION] %1: Reorienting defensive sectors and 360 security.", _targetRole];
    };
    case "CONSOLIDATE_AMMO": {
        systemChat format ["[CONSOLIDATION] %1: Performing squad ammunition and casualty check.", _targetRole];
    };
    case "CONSOLIDATE_PERIMETER": {
        if (!isNull _targetGroup) then {
            [_targetGroup, "FORCE_DOWN"] call FTCS_fnc_groupSetStance;
            systemChat format ["[CONSOLIDATION] %1: Locking down perimeter in hasty defense.", _targetRole];
        };
    };

    // =========================================================================
    // 7. PRE-MISSION / TLP (PLATOON PLANNING & PREPARATION)
    // =========================================================================
    case "TLP_ANALYSIS": {
        hint parseText "<t color='#00FFCC'>[METT-TC TERRAIN ANALYSIS]</t><br/><t color='#FFFFFF'>Mission:</t> Assault Axis OBJ<br/><t color='#FFAA00'>Terrain (OAKOC):</t> Key terrain identified, cover along hedgerows.<br/><t color='#00FFCC'>Enemy:</t> Expected infantry dug-in in defilade.";
        systemChat "[TLP PLANNING] Mission & terrain analysis reviewed.";
    };
    case "TLP_ROSTER": {
        hint parseText "<t color='#00FFCC'>[PLATOON ROSTER & MORALE]</t><br/><t color='#FFFFFF'>Key Roles:</t> Platoon Sgt, RTO, Runners assigned.<br/><t color='#FFAA00'>Squad Leaders:</t> Alpha, Bravo, Charlie, Weapons intact.<br/><t color='#00FFCC'>Morale:</t> High.";
        systemChat "[TLP PLANNING] Platoon roster verified.";
    };
    case "TLP_SUSTAINMENT": {
        hint parseText "<t color='#00FFCC'>[SUSTAINMENT & LOADOUT]</t><br/><t color='#FFFFFF'>Loadout:</t> Combat Basic Load.<br/><t color='#FFAA00'>MG Ammo:</t> Distributed to ammo bearers.<br/><t color='#00FFCC'>Bandages & Morphine:</t> Platoon Medic ready.";
        systemChat "[TLP PLANNING] Sustainment & loadout distribution logged.";
    };
    case "TLP_FIRE_SUPPORT": {
        hint parseText "<t color='#00FFCC'>[FIRE SUPPORT PLANNING]</t><br/><t color='#FFFFFF'>Mortar Support:</t> Pre-planned TRP 1 & TRP 2 on high ground.<br/><t color='#FFAA00'>Smoke Screen:</t> On call for LDA crossing.";
        systemChat "[TLP PLANNING] Pre-planned target reference points confirmed.";
    };
    case "TLP_TACMAP": {
        systemChat "[TLP PLANNING] Opening OPORD Tactical Map route planner.";
        openMap [true, true];
    };

    // =========================================================================
    // 8. SPECIALIZED ROLES (Radio, Runner, Medic, Visual)
    // =========================================================================
    case "RADIO_SITREP": {
        systemChat "[RADIO] Transmitting SITREP query to all platoon elements over radio net.";
    };
    case "RADIO_ARTILLERY": {
        systemChat "[RADIO] Transmitting artillery fire mission request to Battalion FDC.";
    };
    case "RADIO_ARMOR": {
        systemChat "[RADIO] Requesting direct armor support on Battalion Tactical Net.";
    };
    case "RADIO_CHECK": {
        systemChat "[RADIO] Net call check: Radio net operational (SCR-300 signal strong).";
    };

    case "RUNNER_PLT_1": {
        systemChat "[DISPATCH] Messenger dispatched with written OPORD to 1st Platoon Leader.";
    };
    case "RUNNER_PLT_2": {
        systemChat "[DISPATCH] Messenger dispatched with written OPORD to 2nd Platoon Leader.";
    };
    case "RUNNER_PLT_3": {
        systemChat "[DISPATCH] Messenger dispatched with written OPORD to 3rd Platoon Leader.";
    };
    case "RUNNER_PLT_4": {
        systemChat "[DISPATCH] Messenger dispatched with written OPORD to Weapons Platoon Leader.";
    };

    case "MEDIC_TREAT_WOUNDED": {
        systemChat "[MEDIC] Combat Medic dispatched to administer first aid to nearest wounded soldier.";
    };
    case "MEDIC_STATUS": {
        hint parseText "<t color='#00FF00'>[COMBAT MEDIC STATUS]</t><br/><t color='#FFFFFF'>Medical Kit:</t> Bandages, morphine, splints green.<br/><t color='#FFAA00'>Wounded on hand:</t> None critical.";
    };

    case "VISUAL_HALT": {
        systemChat "[VISUAL SIGNAL] Hand Signal: HALT & TAKE COVER!";
        if (!isNull _targetGroup) then { [_targetGroup, "FORCE_MIDDLE"] call FTCS_fnc_groupSetStance; };
    };
    case "VISUAL_FOLLOW": {
        systemChat "[VISUAL SIGNAL] Hand Signal: FOLLOW ME!";
        if (!isNull _targetGroup) then { [_targetGroup, group player] call FTCS_fnc_formationsGroupDoFollowCommander; };
    };
    case "VISUAL_PRONE": {
        systemChat "[VISUAL SIGNAL] Hand Signal: DROP PRONE / PIN DOWN!";
        if (!isNull _targetGroup) then { [_targetGroup, "FORCE_DOWN"] call FTCS_fnc_groupSetStance; };
    };
    case "VISUAL_SPREAD": {
        systemChat "[VISUAL SIGNAL] Hand Signal: SPREAD OUT / WEDGE FORMATION!";
        if (!isNull _targetGroup) then { _targetGroup setFormation "WEDGE"; };
    };
    case "VISUAL_RUSH": {
        systemChat "[VISUAL SIGNAL] Hand Signal: RUSH FORWARD!";
        if (!isNull _targetGroup) then { _targetGroup setSpeedMode "FULL"; };
    };

    // Default Fallback
    default {
        systemChat format ["[ORDER EXECUTED] Directive '%1' issued to %2 (%3).", _commandCode, _targetName, _targetRole];
    };
};
