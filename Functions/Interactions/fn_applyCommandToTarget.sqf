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

// Helper to retrieve specific platoon squad group and its actual leader unit
private _fnc_getPlatoonSquadInfo = {
    params ["_squadSuffix"];
    private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
    private _pltKey = format ["PLT_%1", _pltId];
    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
    private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
    private _sqdKey = format ["SQD_%1_%2", _pltId, _squadSuffix];
    private _sData = _parsedSquads getOrDefault [_sqdKey, createHashMap];

    private _sqdGroup = _sData getOrDefault ["group", grpNull];
    private _sqdLeader = _sData getOrDefault ["leader", objNull];
    private _sqdName = _sData getOrDefault ["name", format ["Squad %1", _squadSuffix]];

    // If multi-team squad, resolve Team 1 group and leader
    private _teams = _sData getOrDefault ["tacticalTeams", createHashMap];
    private _tKeys = keys _teams;
    _tKeys sort true;
    if (count _tKeys > 0) then {
        private _t1 = _teams get (_tKeys select 0);
        if (isNull _sqdLeader) then { _sqdLeader = _t1 getOrDefault ["leader", objNull]; };
        if (isNull _sqdGroup) then { _sqdGroup = _t1 getOrDefault ["group", grpNull]; };
    };

    if (isNull _sqdLeader && {!isNull _sqdGroup}) then {
        _sqdLeader = leader _sqdGroup;
    };

    [_sqdGroup, _sqdLeader, _sqdName, _sqdKey]
};

// Helper to retrieve specific platoon squad group (legacy compatibility)
private _fnc_getPlatoonSquad = {
    params ["_squadSuffix"];
    ([_squadSuffix] call _fnc_getPlatoonSquadInfo) select 0
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
    // 0.1 SQUAD CONTEXT SELECTION (Remote directives via Platoon Sergeant)
    // =========================================================================
    case "SELECT_SQUAD_1";
    case "SELECT_SQUAD_2";
    case "SELECT_SQUAD_3";
    case "SELECT_SQUAD_4": {
        private _sqdNum = switch (_commandCode) do {
            case "SELECT_SQUAD_1": { "1" };
            case "SELECT_SQUAD_2": { "2" };
            case "SELECT_SQUAD_3": { "3" };
            case "SELECT_SQUAD_4": { "4" };
            default { "1" };
        };

        private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltKey = format ["PLT_%1", _pltId];
        private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
        private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
        private _sqdKey = format ["SQD_%1_%2", _pltId, _sqdNum];
        private _sData = _parsedSquads getOrDefault [_sqdKey, createHashMap];

        private _targetSqdGroup = _sData getOrDefault ["group", grpNull];
        private _targetSqdLeader = _sData getOrDefault ["leader", objNull];
        private _targetSqdName = _sData getOrDefault ["name", format ["Squad %1", _sqdNum]];

        // Fallback to Team 1 leader if multi-team squad
        if (isNull _targetSqdLeader) then {
            private _teams = _sData getOrDefault ["tacticalTeams", createHashMap];
            private _tKeys = keys _teams;
            _tKeys sort true;
            if (count _tKeys > 0) then {
                private _t1 = _teams get (_tKeys select 0);
                _targetSqdLeader = _t1 getOrDefault ["leader", objNull];
                if (isNull _targetSqdGroup) then { _targetSqdGroup = _t1 getOrDefault ["group", grpNull]; };
            };
        };
        if (isNull _targetSqdLeader && {!isNull _targetSqdGroup}) then {
            _targetSqdLeader = leader _targetSqdGroup;
        };

        if (!isNull _targetSqdLeader) then {
            // Set active menu context to the selected squad leader and open its squad menu after commandingMenu closes
            systemChat format ["[SQUAD SELECTION] Direct command active for %1.", _targetSqdName];
            [_targetSqdLeader, _targetSqdName] spawn {
                params ["_ldr", "_name"];
                sleep 0.05;
                [_ldr, player, 0, ["SQUAD", _name, true]] call FTCS_fnc_openSubordinateMenu;
            };
        } else {
            systemChat format ["[SQUAD SELECTION] Warning: %1 not found or unavailable.", _targetSqdName];
        };
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
    // 1.1 PLATOON-WIDE TACTICAL STANCE (Directly from Platoon Sergeant)
    // =========================================================================
    case "PLT_STANCE_AUTO";
    case "PLT_STANCE_UP";
    case "PLT_STANCE_MIDDLE";
    case "PLT_STANCE_DOWN";
    case "PLT_STANCE_FOLLOW_COMMANDER": {
        private _stanceType = switch (_commandCode) do {
            case "PLT_STANCE_AUTO": { "AUTO" };
            case "PLT_STANCE_UP": { "FORCE_UP" };
            case "PLT_STANCE_MIDDLE": { "FORCE_MIDDLE" };
            case "PLT_STANCE_DOWN": { "FORCE_DOWN" };
            case "PLT_STANCE_FOLLOW_COMMANDER": { "FOLLOW_COMMANDER_STANCE" };
            default { "AUTO" };
        };

        private _squads = call _fnc_getAllPlatoonSquads;
        {
            [_x, _stanceType] call FTCS_fnc_groupSetStance;
        } forEach _squads;

        systemChat format ["[PLATOON DIRECTIVE] Entire platoon stance set to: %1.", _stanceType];
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
    case "PLT_FORM_ECHELON_RIGHT": {
        [call _fnc_getPlatoonLeaderUnit, "ECHELON_RIGHT", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to ECHELON RIGHT (Right Flank Refused / Screen).";
    };
    case "PLT_FORM_ECHELON_LEFT": {
        [call _fnc_getPlatoonLeaderUnit, "ECHELON_LEFT", 15] call FTCS_fnc_formationsApplyPlatoonOrder;
        systemChat "[PLATOON ORDER] Platoon Formation set to ECHELON LEFT (Left Flank Refused / Screen).";
    };
    case "PLT_FORM_LOCK_GROUND": {
        [call _fnc_getPlatoonLeaderUnit] call FTCS_fnc_formationsCurrentPositionSet;
        showCommandingMenu "#USER:FTCS_MENU_PlatoonFormations_P1";
    };

    case "PLT_MODE_RELATIVE": {
        missionNamespace setVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
        // Refresh the relative reference heading with the leader's CURRENT heading:
        // switching from ABS leaves FTCS_Platoon_Advance_Direction frozen at the old
        // absolute lock, which makes RELATIVE targets behave like fixed-compass ones
        // until the leader moves. Re-baseline the direction at mode switch time.
        private _ldrRel = call _fnc_getPlatoonLeaderUnit;
        missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", getDir _ldrRel];
        missionNamespace setVariable ["FTCS_Last_Commander_Dir", getDir _ldrRel];
        (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "0"];
        (FTCS_MENU_PlatoonFormations_P1 select 10) set [6, "1"];
        
        // Adopt current ground positions dynamically and engage relative follow mode
        [call _fnc_getPlatoonLeaderUnit, "FOLLOWING_COMMANDER_REL"] call FTCS_fnc_formationsCurrentPositionSet;

        // RELIABILITY SWEEP: re-launch follow threads for every subordinate group
        // of the platoon regardless of whether the capture above managed to collect
        // them. Stale ABS threads surviving a failed/aborted capture path would keep
        // steering by fixed compass while the mode variable already says RELATIVE.
        // Collection source: parsedSquads (authoritative "group" references), NOT the
        // registry (whose entries are keyed by groupId without the group object).
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
        private _relGroups = [];
        {
            private _sData = _y;
            private _tacticalTeams = _sData getOrDefault ["tacticalTeams", createHashMap];
            private _sqdGroup = _sData getOrDefault ["group", grpNull];
            if (count _tacticalTeams > 0) then {
                { private _g = (_tacticalTeams get _x) getOrDefault ["group", grpNull]; if (!isNull _g) then { _relGroups pushBack _g; }; } forEach _tacticalTeams;
            } else {
                if (!isNull _sqdGroup) then { _relGroups pushBack _sqdGroup; };
            };
        } forEach _parsedSquads;
        [_relGroups, "FOLLOWING_COMMANDER_REL"] spawn FTCS_fnc_formationsGroupListFollowCommander;

        systemChat "[FOLLOW MODE] Platoon follow mode set to RELATIVE (Turn with Leader). Current ground layout locked.";
        showCommandingMenu "#USER:FTCS_MENU_PlatoonFormations_P1";
    };

    case "PLT_MODE_ABSOLUTE": {
        missionNamespace setVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_ABS"];
        (FTCS_MENU_PlatoonFormations_P1 select 9) set [6, "1"];
        (FTCS_MENU_PlatoonFormations_P1 select 10) set [6, "0"];
        
        // Ensure absolute formation heading is locked to current platoon leader heading
        private _ldr = call _fnc_getPlatoonLeaderUnit;
        private _lockDir = getDir _ldr;
        missionNamespace setVariable ["FTCS_Platoon_Fixed_Abs_Dir", _lockDir];
        missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _lockDir];
        missionNamespace setVariable ["FTCS_Last_Commander_Dir", _lockDir];
        
        // Adopt current ground positions dynamically and engage absolute follow mode
        [_ldr, "FOLLOWING_COMMANDER_ABS"] call FTCS_fnc_formationsCurrentPositionSet;

        // RELIABILITY SWEEP: same guarantee as the RELATIVE switch (see above)
        private _absGroups = [];
        {
            private _sData = _y;
            private _tacticalTeams = _sData getOrDefault ["tacticalTeams", createHashMap];
            private _sqdGroup = _sData getOrDefault ["group", grpNull];
            if (count _tacticalTeams > 0) then {
                { private _g = (_tacticalTeams get _x) getOrDefault ["group", grpNull]; if (!isNull _g) then { _absGroups pushBack _g; }; } forEach _tacticalTeams;
            } else {
                if (!isNull _sqdGroup) then { _absGroups pushBack _sqdGroup; };
            };
        } forEach _parsedSquads;
        [_absGroups, "FOLLOWING_COMMANDER_ABS"] spawn FTCS_fnc_formationsGroupListFollowCommander;

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
    case "PLT_ROAD_COLUMN": {
        private _ldr = call _fnc_getPlatoonLeaderUnit;
        private _roadScan = [_ldr, 30] call FTCS_fnc_roadFindSegment;
        _roadScan params ["_roadSeg", "_roadWidth", "_roadDir", "_roadCategory"];

        if (isNull _roadSeg || _roadCategory == "NONE") exitWith {
            hint parseText "<t color='#FF5555'>[ROAD MARCH FAILED]</t><br/>No road or trail detected under crosshair or within 30m of Platoon Leader.<br/><t color='#AAAAAA'>Position leader on or look at a road segment.</t>";
            systemChat "[ROAD MARCH] Error: No road segment detected in proximity.";
        };

        // Build continuous rearward road path (200m depth for platoon)
        private _roadPath = [_roadSeg, 200, getDir _ldr, _roadWidth] call FTCS_fnc_roadBuildPath;
        if (count _roadPath == 0) exitWith {
            hint parseText "<t color='#FF5555'>[ROAD MARCH FAILED]</t><br/>Could not map connected road segments.";
            systemChat "[ROAD MARCH] Error: Could not construct road path.";
        };

        // Set platoon advance direction from road segment orientation to guarantee stable road tracking
        missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _roadDir];
        missionNamespace setVariable ["FTCS_Last_Commander_Dir", _roadDir];

        // Gather all subordinate platoon elements structured for macro slots
        private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltKey = format ["PLT_%1", _pltId];
        private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
        private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];
        private _leaderGroup = group _ldr;

        // Collect elements identical to macro slot hierarchy
        private _slottedElements = [[], [], [], [], [], [], [], [], [], [], [], [], []];
        private _allSubordinates = [];

        // Check if platoon or doctrine defines custom formation slots overrides
        private _formationSlotsMap = _pltData getOrDefault ["formationSlots", createHashMap];
        private _squadElementsMap = createHashMap;

        {
            private _sqdKey = _x;
            private _sData = _y;
            private _tacticalTeams = _sData getOrDefault ["tacticalTeams", createHashMap];
            private _sqdGroup = _sData getOrDefault ["group", grpNull];

            if (_sqdKey find "_0" >= 0) then {
                // HQ sub-teams
                {
                    private _tKey = toUpper _x;
                    private _hGrp = (_y) getOrDefault ["group", grpNull];
                    if (!isNull _hGrp && {_hGrp != _leaderGroup}) then {
                        _squadElementsMap set [_x, [_hGrp]];
                        if (_tKey find "TEAM_1" >= 0) then { _slottedElements set [9, [_hGrp]]; };
                        if (_tKey find "TEAM_2" >= 0) then { _slottedElements set [4, [_hGrp]]; };
                        if (_tKey find "TEAM_3" >= 0) then { _slottedElements set [10, [_hGrp]]; };
                    };
                } forEach _tacticalTeams;
            } else {
                // Combat squads
                private _elementGroups = [];
                if (count _tacticalTeams > 0) then {
                    private _tKeys = keys _tacticalTeams;
                    _tKeys sort true;
                    {
                        private _tGrp = (_tacticalTeams get _x) getOrDefault ["group", grpNull];
                        if (!isNull _tGrp) then {
                            _elementGroups pushBack _tGrp;
                            _squadElementsMap set [_x, [_tGrp]];
                        };
                    } forEach _tKeys;
                } else {
                    if (!isNull _sqdGroup) then { _elementGroups pushBack _sqdGroup; };
                };
                if (count _elementGroups > 0) then {
                    _squadElementsMap set [_sqdKey, _elementGroups];
                    // Default slot assignments: S1 -> Slot 0, S2 -> Slot 1, S3 -> Slot 2, S4 -> Slot 3
                    if (_sqdKey select [count _sqdKey - 2] == "_1") then { _slottedElements set [0, _elementGroups]; };
                    if (_sqdKey select [count _sqdKey - 2] == "_2") then { _slottedElements set [1, _elementGroups]; };
                    if (_sqdKey select [count _sqdKey - 2] == "_3") then { _slottedElements set [2, _elementGroups]; };
                    if (_sqdKey select [count _sqdKey - 2] == "_4") then { _slottedElements set [3, _elementGroups]; };
                };
            };
        } forEach _parsedSquads;

        // Apply pre-configured formation slots from doctrine if defined
        {
            private _slotIdx = _x;
            private _resolvedKey = _y;
            if (_slotIdx >= 0 && _slotIdx < 13) then {
                if (_resolvedKey in _squadElementsMap) then {
                    private _assignedGroups = _squadElementsMap get _resolvedKey;
                    _slottedElements set [_slotIdx, _assignedGroups];
                };
            };
        } forEach _formationSlotsMap;

        private _formationElements = [[_leaderGroup]] + _slottedElements;

        // Persist structured state into this platoon's Data-Driven model (encapsulated for multi-platoon)
        _pltData set ["movementTechnique", "ROAD_COLUMN"];
        _pltData set ["roadPath", _roadPath];
        _pltData set ["roadAnchor", _anchor];
        _platoonsMap set [_pltKey, _pltData];

        // Calculate staggered shoulder positions along road and launch debug visualizer if active
        // Forced side injection (ROAD_COLUMN_LEFT/RIGHT fresh orders): a pending
        // value (-1/+1) makes roadColumnSet deploy single-shoulder; 0 = staggered
        private _forcedSideRC = missionNamespace getVariable ["FTCS_Road_Column_ForcedSide", 0];
        missionNamespace setVariable ["FTCS_Road_Column_ForcedSide", 0]; // consume once
        private _followerGroups = [_formationElements, _roadPath, 8, _forcedSideRC] call FTCS_fnc_formationsRoadColumnSet;

        // Extend mapped path rearward if total column depth exceeds the initially mapped road distance
        private _maxAssignedDist = 0;
        {
            private _e = _y;
            private _od = _e getOrDefault ["roadOffsetDist", 0];
            if (_od > _maxAssignedDist) then { _maxAssignedDist = _od; };
        } forEach FTCS_Groups_Registry_Table;
        private _mappedDepth = 0;
        for "_pi" from 0 to (count _roadPath - 2) do {
            _mappedDepth = _mappedDepth + (((_roadPath select _pi) select 0) distance2D ((_roadPath select (_pi + 1)) select 0));
        };
        if (_maxAssignedDist + 40 > _mappedDepth) then {
            _roadPath = [_roadPath, (_maxAssignedDist + 40 - _mappedDepth)] call FTCS_fnc_roadPathExtend;
        };

        // Build the MARCH-ORIENTED anchor path (index 0 = rearmost, last = frontmost):
        // 1) reverse the rearward-mapped path so it runs from the column tail up to the leader
        //    (its tangents already point tail->leader, i.e. along the march sense: keep them),
        // 2) append a forward stretch ahead of the leader: roadGetPointsBehind traverses
        //    rearwards, so passing _dirOverride = (advanceDir + 180) flips its internal rear
        //    heading to map the road AHEAD in the march direction,
        // 3) the leader sits at arclength = rear length; slots sample at (headDist - offset).
        private _rearPath = +_roadPath;
        reverse _rearPath;

        // Forward stretch: map road ahead of the leader (rear heading inverted to march sense)
        private _frontPath = [_ldr, 200, (_roadDir + 180) % 360] call FTCS_fnc_roadGetPointsBehind;
        // Returned array runs leader -> forward with tangents pointing BACK at the leader:
        // order already matches march sense, flip tangents to march orientation
        { _x set [1, ((_x select 1) + 180) % 360]; } forEach _frontPath;
        // Drop the duplicated joint point near the leader and append the front stretch
        if (count _frontPath > 0) then { _frontPath deleteAt 0; };
        { _rearPath pushBack _x; } forEach _frontPath;
        _roadPath = _rearPath;

        // Leader's starting arclength: walk the path until the first point near the leader
        // (the joint between the rear stretch and the forward stretch) is reached
        private _headStart = 0;
        for "_pi" from 0 to (count _roadPath - 2) do {
            private _nextPos = (_roadPath select (_pi + 1)) select 0;
            if (_nextPos distance2D (getPosATL _ldr) < 12) exitWith {};
            _headStart = _headStart + (((_roadPath select _pi) select 0) distance2D _nextPos);
        };

        // Freeze road march anchor: direction sense is fixed at order time and never
        // re-decided at runtime (Option A). Anchor progression is owned exclusively by
        // a single dedicated thread; followers and debug worker only READ headDist.
        private _anchor = createHashMap;
        _anchor set ["anchorPos", getPosATL _ldr];
        _anchor set ["advanceDir", _roadDir];
        _anchor set ["roadPath", _roadPath];
        _anchor set ["headDist", _headStart];
        _anchor set ["lastAnchorMovePos", getPosATL _ldr];
        // Layout born: staggered by default, LEFT/RIGHT when deployed through the
        // single-shoulder fresh orders (forced side was injected and consumed above)
        private _bornLayout = switch (_forcedSideRC) do {
            case -1: { "LEFT" };
            case 1: { "RIGHT" };
            default { "STAGGERED" };
        };
        _anchor set ["columnLayout", _bornLayout];
        missionNamespace setVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltId], _anchor];

        // Generation counter: each new road march order invalidates previous anchor threads
        private _gen = (missionNamespace getVariable [format ["FTCS_Road_Anchor_Gen_PLT_%1", _pltId], 0]) + 1;
        missionNamespace setVariable [format ["FTCS_Road_Anchor_Gen_PLT_%1", _pltId], _gen];

        // Sole anchor progression thread: advances headDist once per second.
        // Exits when superseded by a newer order (generation change).
        [_ldr, _anchor, _pltId, _gen] spawn {
            params ["_ldr", "_anchor", "_pltId", "_gen"];
            while { !isNull _ldr &&
                    { (missionNamespace getVariable [format ["FTCS_Road_Anchor_Gen_PLT_%1", _pltId], 0]) == _gen } } do {
                [_ldr, _anchor, 2.0, 60] call FTCS_fnc_roadAdvanceAnchor;
                sleep 1.0;
            };
        };

        // Orphan marker sweep: wipe road and trail slot markers from previous
        // march worlds before issuing the fresh road chain
        { if (_x find "FTCS_DEBUG_TRAIL_SLOT_" == 0 || _x find "FTCS_DEBUG_ROAD_SLOT_" == 0) then { deleteMarkerLocal _x; }; } forEach allMapMarkers;

        // Awaken AI and configure standardized march posture and blind follow micro-AI features for ALL groups
        private _allGroupsToConfigure = +_followerGroups;
        if (!isNull _leaderGroup && {!(_leaderGroup in _allGroupsToConfigure)}) then {
            _allGroupsToConfigure pushBack _leaderGroup;
        };

        {
            if (!isNull _x) then {
                (leader _x) enableAI "PATH";
                (leader _x) enableAI "MOVE";
                (leader _x) disableAI "TARGET";
                (leader _x) disableAI "AUTOCOMBAT";
                (leader _x) disableAI "COVER";
                (leader _x) disableAI "RADIOPROTOCOL";

                {
                    _x enableAI "PATH";
                    _x enableAI "MOVE";
                    _x disableAI "TARGET";
                    _x disableAI "AUTOCOMBAT";
                    _x disableAI "COVER";
                    _x disableAI "RADIOPROTOCOL";
                } forEach (units _x);

                [_x, "ROAD_MARCH"] call FTCS_fnc_groupSetAwareMode; // disciplined march profile (no COVER/AUTOTARGET)
                [_x, "NORMAL"] call FTCS_fnc_groupSetSpeed;
                [_x, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE;
                [_x, "FOLLOW_COMMANDER_STANCE"] call FTCS_fnc_groupSetStance; // Copy My Stance (formation default)
            };
        } forEach _allGroupsToConfigure;

        // Straggler recovery supervisor: bumps the shared generation (kills any
        // previous march watchdog) and spawns the fresh one for this order
        private _wdGenR = (missionNamespace getVariable [format ["FTCS_March_Watchdog_Gen_PLT_%1", _pltId], 0]) + 1;
        missionNamespace setVariable [format ["FTCS_March_Watchdog_Gen_PLT_%1", _pltId], _wdGenR];
        [_pltId, _wdGenR] spawn FTCS_fnc_marchStuckWatchdog;

        // Launch dedicated road navigation thread for subordinate follower groups
        {
            if (!isNull _x) then {
                [_x, _ldr] spawn FTCS_fnc_formationsGroupFollowRoad;
            };
        } forEach _followerGroups;

        // Launch real-time dynamic formation slots visualizer on map
        missionNamespace setVariable ["FTCS_Debug_Mode", true];
        [_ldr] spawn FTCS_fnc_formationsLiveSlotsDebugWorker;

        private _modeStr = if (_roadCategory == "ROAD") then { "STAGGERED COLUMN (Dual Shoulder)" } else { "TRAIL COLUMN (Single File)" };
        systemChat format ["[ROAD MARCH] Platoon deployed in %1 along %2 (Width %3m).", _modeStr, _roadCategory, round _roadWidth];
        hint parseText format ["<t color='#00FFCC'>[ROAD MARCH ACTIVATED]</t><br/><t color='#FFFFFF'>Technique:</t> %1<br/><t color='#FFAA00'>Road Width:</t> %2m<br/><t color='#AAAAAA'>Troops staggered on shoulders and following route.</t>", _modeStr, round _roadWidth];
    };

    // =========================================================================
    // ROAD MARCH SUBMENU: LEADER TRAIL COLUMN (Follow My Track)
    // Column slot order identical to road march, but the master trajectory is
    // the leader's own recorded track: groups inherit the exact terrain line
    // he walked (ravines, defiles, tree lanes). No road graph involved.
    // =========================================================================
    case "PLT_TRAIL_COLUMN": {
        private _pltIdT = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _ldrT = call _fnc_getPlatoonLeaderUnit;

        // Invalidate any previous trail thread generation
        missionNamespace setVariable [format ["FTCS_Trail_Gen_PLT_%1", _pltIdT],
            (missionNamespace getVariable [format ["FTCS_Trail_Gen_PLT_%1", _pltIdT], 0]) + 1];

        // Collect subordinate groups identically to the road column order
        private _pltId = _pltIdT;
        private _pltKey = format ["PLT_%1", _pltId];
        private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
        private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

        private _trailGroups = [];
        {
            private _sData = _y;
            private _tacticalTeams = _sData getOrDefault ["tacticalTeams", createHashMap];
            private _sqdGroup = _sData getOrDefault ["group", grpNull];
            if (count _tacticalTeams > 0) then {
                { private _g = (_tacticalTeams get _x) getOrDefault ["group", grpNull]; if (!isNull _g) then { _trailGroups pushBack _g; }; } forEach _tacticalTeams;
            } else {
                if (!isNull _sqdGroup) then { _trailGroups pushBack _sqdGroup; };
            };
        } forEach _parsedSquads;

        // Freeze the trail anchor and assign chained offsets
        private _chainedCount = [_pltIdT, _trailGroups, _ldrT] call FTCS_fnc_trailColumnSet;
        if (_chainedCount == 0) exitWith {
            hint parseText "<t color='#FF5555'>[TRAIL COLUMN FAILED]</t><br/>No subordinate groups resolved for chaining.";
            systemChat "[TRAIL COLUMN] Error: no subordinate groups found.";
        };

        private _anchorT = missionNamespace getVariable [format ["FTCS_Trail_Anchor_PLT_%1", _pltIdT], createHashMap];

        // Persist in the platoon data-driven model
        _pltData set ["movementTechnique", "TRAIL_COLUMN"];
        _pltData set ["trailAnchor", _anchorT];
        _platoonsMap set [_pltKey, _pltData];

        // Awaken AI and configure the SAME doctrinal march profile as road march
        {
            if (!isNull _x) then {
                (leader _x) enableAI "PATH";
                (leader _x) enableAI "MOVE";
                (leader _x) disableAI "TARGET";
                (leader _x) disableAI "AUTOCOMBAT";
                (leader _x) disableAI "COVER";
                (leader _x) disableAI "RADIOPROTOCOL";
                { _x enableAI "PATH"; _x enableAI "MOVE"; _x disableAI "TARGET"; _x disableAI "AUTOCOMBAT"; _x disableAI "COVER"; _x disableAI "RADIOPROTOCOL"; } forEach (units _x);

                [_x, "ROAD_MARCH"] call FTCS_fnc_groupSetAwareMode;
                [_x, "NORMAL"] call FTCS_fnc_groupSetSpeed;
                [_x, "FIRE_IF_FIRED_UPON"] call FTCS_fnc_groupSetROE;
                [_x, "FOLLOW_COMMANDER_STANCE"] call FTCS_fnc_groupSetStance;
                _x setFormation "COLUMN"; // same native formation as road march (single file)
            };
        } forEach _trailGroups;

        // Sole trail recorder thread: records the leader's track every 0.5s
        private _gen = missionNamespace getVariable [format ["FTCS_Trail_Gen_PLT_%1", _pltIdT], 0];
        [_ldrT, _anchorT, _pltIdT, _gen] spawn {
            params ["_ldr", "_anchor", "_pltId", "_gen"];
            while { !isNull _ldr &&
                    { (missionNamespace getVariable [format ["FTCS_Trail_Gen_PLT_%1", _pltId], 0]) == _gen } } do {
                [_ldr, _anchor, 2.0, 60] call FTCS_fnc_trailAdvanceAnchor;
                sleep 0.5;
            };
        };

        // Orphan marker sweep: any leftover trail slot markers from a previous
        // march world (dead threads) are wiped before the new chain starts
        { if (_x find "FTCS_DEBUG_TRAIL_SLOT_" == 0) then { deleteMarkerLocal _x; }; } forEach allMapMarkers;

        // Straggler recovery supervisor: bumps the shared generation (kills any
        // previous march watchdog) and spawns the fresh one for this order
        private _wdGen = (missionNamespace getVariable [format ["FTCS_March_Watchdog_Gen_PLT_%1", _pltIdT], 0]) + 1;
        missionNamespace setVariable [format ["FTCS_March_Watchdog_Gen_PLT_%1", _pltIdT], _wdGen];
        [_pltIdT, _wdGen] spawn FTCS_fnc_marchStuckWatchdog;

        // Launch per-group trail follow threads
        { if (!isNull _x) then { [_x, _ldrT] spawn FTCS_fnc_formationsGroupFollowTrail; }; } forEach _trailGroups;

        missionNamespace setVariable ["FTCS_Debug_Mode", true];
        [_ldrT] spawn FTCS_fnc_formationsLiveSlotsDebugWorker;

        systemChat format ["[TRAIL COLUMN] Platoon chained on leader track (%1 teams).", _chainedCount];
        hint parseText "<t color='#00FFCC'>[TRAIL COLUMN ACTIVATED]</t><br/><t color='#FFFFFF'>Trajectory:</t> Leader's own track<br/><t color='#AAAAAA'>Every team inherits the exact terrain line the leader walked.</t>";
    };

    // =========================================================================
    // ROAD MARCH SUBMENU: COMPACT COLUMN (Close Ranks, no stagger stepping)
    // Requires an already-formed road march column (live anchor): validated here
    // at runtime, since commanding menus are static arrays built once at init.
    // =========================================================================
    case "PLT_ROAD_COMPACT": {
        private _pltIdC = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltKeyC = format ["PLT_%1", _pltIdC];
        private _platoonsMapC = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
        private _pltDataC = _platoonsMapC getOrDefault [_pltKeyC, createHashMap];
        private _techniqueC = _pltDataC getOrDefault ["movementTechnique", "CROSS_COUNTRY"];

        // Router: the same Compact command serves both march worlds.
        // TRAIL_COLUMN compacts into a staggered double lane over the leader track;
        // ROAD_COLUMN compacts onto matching shoulder distances over the road path.
        if (_techniqueC == "TRAIL_COLUMN") exitWith {
            private _anchorC = missionNamespace getVariable [format ["FTCS_Trail_Anchor_PLT_%1", _pltIdC], createHashMap];
            if (count (_anchorC getOrDefault ["trailPath", []]) < 2) exitWith {
                hint parseText "<t color='#FF5555'>[TRAIL COMPACT FAILED]</t><br/>No active trail column.<br/><t color='#AAAAAA'>Form the platoon in Leader Trail Column first.</t>";
                systemChat "[TRAIL COMPACT] Error: trail march not active.";
            };
            if ((_anchorC getOrDefault ["columnLayout", "STAGGERED"]) == "COMPACT") exitWith {
                hint parseText "<t color='#FF5555'>[TRAIL COMPACT]</t><br/>Column already compacted.<br/><t color='#AAAAAA'>Re-order Leader Trail Column to restore single file.</t>";
            };
            [_pltIdC] call FTCS_fnc_formationsTrailCompactColumn;
            hint parseText "<t color='#00FFCC'>[TRAIL COMPACT]</t><br/><t color='#FFFFFF'>Staggered double lane engaged.</t><br/><t color='#AAAAAA'>Teams paired +/-0.75m off the leader's walked line.</t>";
        };

        private _anchorC = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltIdC], createHashMap];
        if (count (_anchorC getOrDefault ["roadPath", []]) < 2) exitWith {
            hint parseText "<t color='#FF5555'>[ROAD COMPACT FAILED]</t><br/>No active road march column.<br/><t color='#AAAAAA'>Form the platoon in Staggered Column first, then compact.</t>";
            systemChat "[ROAD COMPACT] Error: road march not active. Form the column first.";
        };

        // Single-shoulder columns are already single-file: compacting is meaningless
        if ((_anchorC getOrDefault ["columnLayout", "STAGGERED"]) in ["LEFT", "RIGHT"]) exitWith {
            hint parseText "<t color='#FF5555'>[ROAD COMPACT]</t><br/>Column is already a single-shoulder file.<br/><t color='#AAAAAA'>Re-order Staggered Column to restore dual shoulders first.</t>";
            systemChat "[ROAD COMPACT] Blocked: layout is already LEFT/RIGHT single-shoulder.";
        };

        [_pltIdC, "BOTH"] call FTCS_fnc_formationsRoadCompactColumn;
        hint parseText "<t color='#00FFCC'>[ROAD COMPACT]</t><br/><t color='#FFFFFF'>Staggering removed.</t><br/><t color='#AAAAAA'>Left and right shoulder teams march at matching distances (pace + 2m gap).</t>";
    };

    // =========================================================================
    // ROAD MARCH SUBMENU: SINGLE-SHOULDER COLUMNS (all teams to ONE side)
    // Two entry paths:
    // 1) No road column active: orders a FRESH road march directly into the
    //    requested single-shoulder layout (same full pipeline as PLT_ROAD_COLUMN
    //    with a forced side - no staggered pre-order needed).
    // 2) Road column active: re-chains the current column onto the requested
    //    shoulder via the compact resolver (push-out/push-in keeps working).
    // =========================================================================
    case "ROAD_COLUMN_LEFT";
    case "ROAD_COLUMN_RIGHT": {
        private _pltIdS = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _forcedSide = if (_commandCode == "ROAD_COLUMN_LEFT") then { -1 } else { 1 };
        private _sideStr = if (_forcedSide == -1) then { "LEFT" } else { "RIGHT" };
        private _anchorS = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltIdS], createHashMap];

        if (count (_anchorS getOrDefault ["roadPath", []]) >= 2) then {
            // PATH 1 - column already active: re-chain onto the requested shoulder
            private _scope = if (_forcedSide == -1) then { "LEFT" } else { "RIGHT" };
            [_pltIdS, _scope] call FTCS_fnc_formationsRoadCompactColumn;
            hint parseText format ["<t color='#00FFCC'>[ROAD COLUMN: %1]</t><br/><t color='#FFFFFF'>Single-shoulder column re-chained.</t><br/><t color='#AAAAAA'>All teams moved to the %2 shoulder (standard pacing).</t>", _sideStr, toLower _sideStr];
        } else {
            // PATH 2 - fresh order: route through PLT_ROAD_COLUMN with the forced side
            // injected, so the full pipeline (path, anchor, AI, threads, watchdog) runs
            missionNamespace setVariable ["FTCS_Road_Column_ForcedSide", _forcedSide];
            "PLT_ROAD_COLUMN" call FTCS_fnc_applyCommandToTarget;
            hint parseText format ["<t color='#00FFCC'>[ROAD COLUMN: %1]</t><br/><t color='#FFFFFF'>Road march deployed single-shoulder.</t><br/><t color='#AAAAAA'>All teams chained down the %2 shoulder from the start.</t>", _sideStr, toLower _sideStr];
        };
    };

    // =========================================================================
    // ROAD MARCH SUBMENU: STEPPED EDGE MARGIN CONTROL (margins 2m per level)
    // Requires an active road march column (staggered or compact layout).
    // PUSH_OUT / PULL_IN move the column 2m at a time; EDGE_RESET returns it
    // immediately onto the asphalt shoulders.
    // =========================================================================
    case "ROAD_EDGE_PUSH": {
        private _pltIdE = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _anchorE = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltIdE], createHashMap];
        if (count (_anchorE getOrDefault ["roadPath", []]) < 2) exitWith {
            hint parseText "<t color='#FF5555'>[ROAD EDGE FAILED]</t><br/>No active road march column.<br/><t color='#AAAAAA'>Form the platoon in a road column first.</t>";
            systemChat "[ROAD EDGE] Error: road march not active.";
        };

        [_pltIdE, 1] call FTCS_fnc_roadEdgeModeToggle;
    };

    case "ROAD_EDGE_PULL": {
        private _pltIdE = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _anchorE = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltIdE], createHashMap];
        if (count (_anchorE getOrDefault ["roadPath", []]) < 2) exitWith {
            hint parseText "<t color='#FF5555'>[ROAD EDGE FAILED]</t><br/>No active road march column.<br/><t color='#AAAAAA'>Form the platoon in a road column first.</t>";
            systemChat "[ROAD EDGE] Error: road march not active.";
        };

        [_pltIdE, -1] call FTCS_fnc_roadEdgeModeToggle;
    };

    case "ROAD_EDGE_RESET": {
        private _pltIdE = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _anchorE = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltIdE], createHashMap];
        if (count (_anchorE getOrDefault ["roadPath", []]) < 2) exitWith {
            hint parseText "<t color='#FF5555'>[ROAD EDGE FAILED]</t><br/>No active road march column.<br/><t color='#AAAAAA'>Form the platoon in a road column first.</t>";
            systemChat "[ROAD EDGE] Error: road march not active.";
        };

        [_pltIdE, 0] call FTCS_fnc_roadEdgeModeToggle;
        hint parseText "<t color='#00FFCC'>[ROAD EDGE: RESET]</t><br/><t color='#FFFFFF'>Column returned onto the asphalt shoulders.</t>";
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
            private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
            private _pltKey = format ["PLT_%1", _pltId];
            private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
            private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
            private _formationSlotsMap = _pltData getOrDefault ["formationSlots", createHashMap];
            private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

            // 1. Identify which squad this targetGroup belongs to
            private _targetSquadData = createHashMap;
            private _targetSquadId = "";
            {
                private _sId = _x;
                private _sData = _y;
                private _grp = _sData getOrDefault ["group", grpNull];
                private _teams = _sData getOrDefault ["tacticalTeams", createHashMap];
                if (_grp == _targetGroup) exitWith { _targetSquadData = _sData; _targetSquadId = _sId; };
                {
                    if ((_y getOrDefault ["group", grpNull]) == _targetGroup) exitWith {
                        _targetSquadData = _sData;
                        _targetSquadId = _sId;
                    };
                } forEach _teams;
                if (_targetSquadId != "") exitWith {};
            } forEach _parsedSquads;

            // 2. Check if any detached outer slot (5, 6, 7, 8, 11, 12) belongs to this squad
            private _tacticalTeams = _targetSquadData getOrDefault ["tacticalTeams", createHashMap];
            private _slotsToRemove = [];
            {
                private _sIdx = _x;
                private _tKey = _y;
                if (_sIdx in [5, 6, 7, 8, 11, 12]) then {
                    if (_tKey in _tacticalTeams || (_targetSquadId != "" && {_tKey find _targetSquadId == 0})) then {
                        _slotsToRemove pushBack _sIdx;
                    };
                };
            } forEach _formationSlotsMap;

            if (count _slotsToRemove > 0) then {
                // Clear the detached scout slot assignments
                {
                    _formationSlotsMap deleteAt _x;
                    // Clear the dynamic debug marker for the vacated slot
                    deleteMarkerLocal format ["FTCS_DEBUG_DYNAMIC_SLOT_%1", _x];
                    if (!isNil "Platoon_Formation_Position_List" && {count Platoon_Formation_Position_List > _x}) then {
                        (Platoon_Formation_Position_List select _x) set [2, grpNull];
                    };
                } forEach _slotsToRemove;
                _pltData set ["formationSlots", _formationSlotsMap];

                // 3. Rejoin strictly at the squad's CURRENT real-world position without re-triggering platoon formation
                // Gather all fireteams of this squad
                private _teamKeys = keys _tacticalTeams;
                _teamKeys sort true;
                private _squadElements = [];
                {
                    private _tGrp = (_tacticalTeams get _x) getOrDefault ["group", grpNull];
                    if (!isNull _tGrp) then { _squadElements pushBack _tGrp; };
                } forEach _teamKeys;

                if (count _squadElements > 1) then {
                    private _leadTeamGrp = _squadElements select 0;
                    private _leadTeamLeader = leader _leadTeamGrp;
                    private _squadFormType = [_targetSquadId, "formationType"] call FTCS_fnc_registryGet;
                    if (isNil "_squadFormType" || {!(_squadFormType isEqualType "")}) then { _squadFormType = "WEDGE"; };

                    // Recalculate local squad formation relative to the Squad Leader's CURRENT heading
                    [_squadElements, _squadFormType, 4, 0] call FTCS_fnc_formationsTypeSquadSet;

                    // Re-launch follow-commander threads for the rejoined sub-teams to follow their Squad Leader
                    private _subTeamsToFollow = +_squadElements;
                    _subTeamsToFollow deleteAt 0; // Exclude Squad Leader team
                    private _followMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
                    {
                        if (!isNull _x) then {
                            [_x, _followMode, _leadTeamLeader] spawn FTCS_fnc_formationsGroupDoFollowCommander;
                        };
                    } forEach _subTeamsToFollow;
                };

                systemChat format ["[SCOUT REJOIN] %1: Scouts rejoined parent squad at current position.", _targetRole];
            } else {
                [_targetGroup, group player] call FTCS_fnc_formationsGroupDoFollowCommander;
                systemChat format ["[SQUAD ORDER] %1: Regrouping on Commander.", _targetRole];
            };
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

    case "SQD_RECON_AHEAD";
    case "SQD_SCOUT_FLANK";
    case "SQD_SCOUT_FRONT";
    case "SQD_SCOUT_REAR";
    case "SQD_SCOUT_SLOT_11";
    case "SQD_SCOUT_SLOT_12";
    case "SQD_SCOUT_SLOT_6";
    case "SQD_SCOUT_SLOT_7";
    case "SQD_SCOUT_SLOT_8";
    case "SQD_SCOUT_SLOT_5": {
        if (!isNull _targetGroup) then {
            private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
            private _pltKey = format ["PLT_%1", _pltId];
            private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
            private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
            private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

            // 1. Resolve target squad and its tactical teams
            private _targetSquadData = createHashMap;
            private _targetSquadId = "";
            {
                private _sId = _x;
                private _sData = _y;
                private _grp = _sData getOrDefault ["group", grpNull];
                private _teams = _sData getOrDefault ["tacticalTeams", createHashMap];
                if (_grp == _targetGroup) exitWith { _targetSquadData = _sData; _targetSquadId = _sId; };
                {
                    if ((_y getOrDefault ["group", grpNull]) == _targetGroup) exitWith {
                        _targetSquadData = _sData;
                        _targetSquadId = _sId;
                    };
                } forEach _teams;
                if (_targetSquadId != "") exitWith {};
            } forEach _parsedSquads;

            // 2. Identify the macro slot where the parent squad is assigned (Slot 0, 1, 2, 3...)
            private _parentMacroSlot = 0;
            private _formationSlotsMap = _pltData getOrDefault ["formationSlots", createHashMap];
            {
                private _sIdx = _x;
                private _mappedId = _y;
                if (_sIdx in [0, 1, 2, 3] && {_mappedId == _targetSquadId || (_mappedId find _targetSquadId == 0)}) exitWith {
                    _parentMacroSlot = _sIdx;
                };
            } forEach _formationSlotsMap;

            // Fallback: deduce macro slot from squad suffix if not explicitly mapped
            if (_parentMacroSlot == 0 && {_targetSquadId != ""}) then {
                if (_targetSquadId find "_1" >= 0) then { _parentMacroSlot = 0; };
                if (_targetSquadId find "_2" >= 0) then { _parentMacroSlot = 1; };
                if (_targetSquadId find "_3" >= 0) then { _parentMacroSlot = 2; };
                if (_targetSquadId find "_4" >= 0) then { _parentMacroSlot = 3; };
            };

            // 3. Determine which sub-team acts as scouts (prefer Team 2 / Scouts)
            private _tacticalTeams = _targetSquadData getOrDefault ["tacticalTeams", createHashMap];
            private _teamKeys = keys _tacticalTeams;
            _teamKeys sort true;

            private _scoutGroup = _targetGroup;
            private _scoutTeamKey = "";
            if (count _teamKeys > 1) then {
                _scoutTeamKey = _teamKeys select 1; // Team 2 (Scouts / Maneuver)
                _scoutGroup = (_tacticalTeams get _scoutTeamKey) getOrDefault ["group", _targetGroup];
            } else {
                if (count _teamKeys == 1) then {
                    _scoutTeamKey = _teamKeys select 0;
                    _scoutGroup = (_tacticalTeams get _scoutTeamKey) getOrDefault ["group", _targetGroup];
                };
            };

            if (_scoutTeamKey == "") exitWith {
                systemChat format ["[SCOUT DETACHMENT] Warning: %1 has no separate scout fireteam to detach.", _targetRole];
            };

            // 4. Determine destination slot strictly based on Parent Squad Slot or explicit slot command:
            private _destSlot = 6;
            switch (_commandCode) do {
                case "SQD_SCOUT_SLOT_11": { _destSlot = 11; };
                case "SQD_SCOUT_SLOT_12": { _destSlot = 12; };
                case "SQD_SCOUT_SLOT_6":  { _destSlot = 6; };
                case "SQD_SCOUT_SLOT_7":  { _destSlot = 7; };
                case "SQD_SCOUT_SLOT_8":  { _destSlot = 8; };
                case "SQD_SCOUT_SLOT_5":  { _destSlot = 5; };
                case "SQD_SCOUT_FRONT": {
                    _destSlot = switch (_parentMacroSlot) do {
                        case 1: { 7 };
                        case 0: { 6 };
                        case 2: { 8 };
                        default { 6 };
                    };
                };
                case "SQD_SCOUT_FLANK": {
                    _destSlot = switch (_parentMacroSlot) do {
                        case 1: { 11 };
                        case 2: { 12 };
                        default { 11 };
                    };
                };
                case "SQD_SCOUT_REAR": {
                    _destSlot = 5;
                };
                default {
                    // Default SQD_RECON_AHEAD
                    _destSlot = switch (_parentMacroSlot) do {
                        case 1: { 11 };
                        case 2: { 12 };
                        case 0: { 6 };
                        default { 6 };
                    };
                };
            };

            // 5. Dynamic hot-shift: Check if this scout team was already deployed in an outer slot
            // If already in another slot (e.g. was in 11, now moving to 7), free the old slot cleanly
            private _previousSlot = -1;
            {
                private _sIdx = _x;
                private _val = _y;
                if (_sIdx in [5, 6, 7, 8, 11, 12] && {_val == _scoutTeamKey}) exitWith {
                    _previousSlot = _sIdx;
                };
            } forEach _formationSlotsMap;

            if (_previousSlot >= 0 && {_previousSlot != _destSlot}) then {
                _formationSlotsMap deleteAt _previousSlot;
                deleteMarkerLocal format ["FTCS_DEBUG_DYNAMIC_SLOT_%1", _previousSlot];
                if (!isNil "Platoon_Formation_Position_List" && {count Platoon_Formation_Position_List > _previousSlot}) then {
                    (Platoon_Formation_Position_List select _previousSlot) set [2, grpNull];
                };
                systemChat format ["[SCOUT SHIFT] %1: Scouts dynamically reallocated from Slot %2 -> Slot %3.", _targetRole, _previousSlot, _destSlot];
            };

            // 6. Assign new slot mapping in platoon data
            _formationSlotsMap set [_destSlot, _scoutTeamKey];
            _pltData set ["formationSlots", _formationSlotsMap];

            // 7. Dispatch scouts LOCALLY to the target slot without recalculating or disturbing the rest of the platoon
            private _ldr = call _fnc_getPlatoonLeaderUnit;
            private _ldrGroup = group _ldr;

            if (!isNil "Platoon_Formation_Position_List" && {count Platoon_Formation_Position_List > _destSlot}) then {
                private _slotTemplate = Platoon_Formation_Position_List select _destSlot;
                if (count _slotTemplate >= 2) then {
                    private _slotDist = _slotTemplate select 0;
                    private _slotBearing = _slotTemplate select 1;

                    // Bind scout group object into the slot position buffer
                    Platoon_Formation_Position_List set [_destSlot, [_slotDist, _slotBearing, _scoutGroup]];

                    // Register coordinates in FTCS_Groups_Registry_Table anchored directly to Platoon Leader [X]
                    private _scoutGroupId = groupId _scoutGroup;
                    [_scoutGroupId, "allocationSlot", _destSlot] call FTCS_fnc_registrySet;
                    [_scoutGroupId, "formationPosition", [_slotDist, _slotBearing, _ldrGroup]] call FTCS_fnc_registrySet;
                    [_scoutGroupId, "relPosition", [_slotDist, _slotBearing, _ldrGroup]] call FTCS_fnc_registrySet;

                    // Launch follow-commander thread strictly for this scout group
                    private _followMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
                    [_scoutGroup, _followMode, _ldr] spawn FTCS_fnc_formationsGroupDoFollowCommander;
                };
            };

            // 8. Re-compact the parent squad's internal formation locally without the detached scouts
            // Preserve Squad Leader and remaining members in place without forward leaps
            private _parentRemainingTeams = [];
            {
                private _tKey = _x;
                if (_tKey != _scoutTeamKey) then {
                    private _tGrp = (_tacticalTeams get _tKey) getOrDefault ["group", grpNull];
                    if (!isNull _tGrp) then { _parentRemainingTeams pushBack _tGrp; };
                };
            } forEach _teamKeys;

            if (count _parentRemainingTeams > 1) then {
                private _leadParentGrp = _parentRemainingTeams select 0;
                private _squadFormType = [_targetSquadId, "formationType"] call FTCS_fnc_registryGet;
                if (isNil "_squadFormType" || {!(_squadFormType isEqualType "")}) then { _squadFormType = "WEDGE"; };
                [_parentRemainingTeams, _squadFormType, 4, 0] call FTCS_fnc_formationsTypeSquadSet;
            };

            systemChat format ["[SCOUT DIRECTIVE] %1: Scouts deployed to Platoon Slot %2. Screening under direct Platoon Leader [X] tracking.", _targetRole, _destSlot];
        };
    };

    // =========================================================================
    // 4.1 PLATOON-WIDE SCOUT SCREEN DIRECTIVES (Directly from Platoon Sergeant)
    // =========================================================================
    case "PLT_SCOUT_FLANK_L": {
        // Left Flank Screen: Automatically provided by Squad in Slot 1
        private _info = ["2"] call _fnc_getPlatoonSquadInfo; // SQD_X_2 is Slot 1
        if (isNull (_info select 1)) then { _info = ["1"] call _fnc_getPlatoonSquadInfo; };
        _info params ["_grp", "_ldr", "_name"];
        if (!isNull _ldr) then {
            missionNamespace setVariable ["FTCS_ActiveMenu_Target", _ldr];
            missionNamespace setVariable ["FTCS_ActiveMenu_Role", _name];
            ['SQD_SCOUT_SLOT_11'] call FTCS_fnc_applyCommandToTarget;
        };
    };
    case "PLT_SCOUT_FLANK_R": {
        // Right Flank Screen: Automatically provided by Squad in Slot 2
        private _info = ["3"] call _fnc_getPlatoonSquadInfo; // SQD_X_3 is Slot 2
        if (isNull (_info select 1)) then { _info = ["2"] call _fnc_getPlatoonSquadInfo; };
        _info params ["_grp", "_ldr", "_name"];
        if (!isNull _ldr) then {
            missionNamespace setVariable ["FTCS_ActiveMenu_Target", _ldr];
            missionNamespace setVariable ["FTCS_ActiveMenu_Role", _name];
            ['SQD_SCOUT_SLOT_12'] call FTCS_fnc_applyCommandToTarget;
        };
    };
    case "PLT_SCOUT_FRONT_L": {
        // Front Left Screen (Slot 7): Provided by Squad in Slot 1
        private _info = ["2"] call _fnc_getPlatoonSquadInfo;
        if (isNull (_info select 1)) then { _info = ["1"] call _fnc_getPlatoonSquadInfo; };
        _info params ["_grp", "_ldr", "_name"];
        if (!isNull _ldr) then {
            missionNamespace setVariable ["FTCS_ActiveMenu_Target", _ldr];
            missionNamespace setVariable ["FTCS_ActiveMenu_Role", _name];
            ['SQD_SCOUT_SLOT_7'] call FTCS_fnc_applyCommandToTarget;
        };
    };
    case "PLT_SCOUT_FRONT_C": {
        // Front Center Screen (Slot 6): Provided by Squad in Slot 0
        private _info = ["1"] call _fnc_getPlatoonSquadInfo;
        _info params ["_grp", "_ldr", "_name"];
        if (!isNull _ldr) then {
            missionNamespace setVariable ["FTCS_ActiveMenu_Target", _ldr];
            missionNamespace setVariable ["FTCS_ActiveMenu_Role", _name];
            ['SQD_SCOUT_SLOT_6'] call FTCS_fnc_applyCommandToTarget;
        };
    };
    case "PLT_SCOUT_FRONT_R": {
        // Front Right Screen (Slot 8): Provided by Squad in Slot 2
        private _info = ["3"] call _fnc_getPlatoonSquadInfo;
        _info params ["_grp", "_ldr", "_name"];
        if (!isNull _ldr) then {
            missionNamespace setVariable ["FTCS_ActiveMenu_Target", _ldr];
            missionNamespace setVariable ["FTCS_ActiveMenu_Role", _name];
            ['SQD_SCOUT_SLOT_8'] call FTCS_fnc_applyCommandToTarget;
        };
    };
    case "PLT_SCOUT_REAR": {
        // Rear Reserve Screen (Slot 5): Provided by Squad in Slot 0
        private _info = ["1"] call _fnc_getPlatoonSquadInfo;
        _info params ["_grp", "_ldr", "_name"];
        if (!isNull _ldr) then {
            missionNamespace setVariable ["FTCS_ActiveMenu_Target", _ldr];
            missionNamespace setVariable ["FTCS_ActiveMenu_Role", _name];
            ['SQD_SCOUT_SLOT_5'] call FTCS_fnc_applyCommandToTarget;
        };
    };
    case "PLT_SCOUT_REJOIN_ALL": {
        // Rejoin all detached scouts across all squads back to their parent elements
        private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltKey = format ["PLT_%1", _pltId];
        private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
        private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
        private _formationSlotsMap = _pltData getOrDefault ["formationSlots", createHashMap];
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

        private _detachedSlots = [5, 6, 7, 8, 11, 12];
        {
            if (_x in _formationSlotsMap) then {
                _formationSlotsMap deleteAt _x;
                deleteMarkerLocal format ["FTCS_DEBUG_DYNAMIC_SLOT_%1", _x];
                if (!isNil "Platoon_Formation_Position_List" && {count Platoon_Formation_Position_List > _x}) then {
                    (Platoon_Formation_Position_List select _x) set [2, grpNull];
                };
            };
        } forEach _detachedSlots;

        _pltData set ["formationSlots", _formationSlotsMap];

        // Trigger local rejoin for each squad
        {
            private _sqdKey = _x;
            if (_sqdKey find "_0" < 0) then {
                private _sData = _y;
                private _tacticalTeams = _sData getOrDefault ["tacticalTeams", createHashMap];
                private _teamKeys = keys _tacticalTeams;
                _teamKeys sort true;
                private _squadElements = [];
                {
                    private _tGrp = (_tacticalTeams get _x) getOrDefault ["group", grpNull];
                    if (!isNull _tGrp) then { _squadElements pushBack _tGrp; };
                } forEach _teamKeys;

                if (count _squadElements > 1) then {
                    private _leadTeamLeader = leader (_squadElements select 0);
                    private _squadFormType = [_sqdKey, "formationType"] call FTCS_fnc_registryGet;
                    if (isNil "_squadFormType" || {!(_squadFormType isEqualType "")}) then { _squadFormType = "WEDGE"; };
                    [_squadElements, _squadFormType, 4, 0] call FTCS_fnc_formationsTypeSquadSet;

                    private _subTeams = +_squadElements;
                    _subTeams deleteAt 0;
                    private _followMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
                    {
                        if (!isNull _x) then {
                            [_x, _followMode, _leadTeamLeader] spawn FTCS_fnc_formationsGroupDoFollowCommander;
                        };
                    } forEach _subTeams;
                };
            };
        } forEach _parsedSquads;

        systemChat "[SCOUT REJOIN] All detached platoon scouts recalled and rejoined with parent squads.";
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
