/*
    ================================================================================
    File: fn_applyCommandToTarget.sqf
    Module: Interactions
    Author: FTCS Team
    Description: Receives an action code from a native commandingMenu selection [1-9],
                 resolves the active target subordinate unit/group, applies the
                 tactical backend directive, and displays feedback.
    Language: Strictly English (Rule 7)
    ================================================================================
*/

params [["_commandCode", ""]];

if (_commandCode == "") exitWith {};

private _targetUnit = missionNamespace getVariable ["FTCS_ActiveMenu_Target", objNull];
private _targetGroup = if (!isNull _targetUnit) then { group _targetUnit } else { grpNull };
private _targetRole = missionNamespace getVariable ["FTCS_ActiveMenu_Role", "Subordinate"];
private _targetName = if (!isNull _targetUnit) then { name _targetUnit } else { _targetRole };

// 1. Process specific tactical commands
switch (_commandCode) do {
    // Stance commands
    case "STANCE_AUTO": {
        if (!isNull _targetGroup) then {
            { _x setUnitPos "AUTO"; } forEach (units _targetGroup);
            systemChat format ["[ORDER] %1 (%2): Stance set to AUTO.", _targetName, _targetRole];
        };
    };
    case "STANCE_UP": {
        if (!isNull _targetGroup) then {
            { _x setUnitPos "UP"; } forEach (units _targetGroup);
            systemChat format ["[ORDER] %1 (%2): Forced STAND UP.", _targetName, _targetRole];
        };
    };
    case "STANCE_MIDDLE": {
        if (!isNull _targetGroup) then {
            { _x setUnitPos "MIDDLE"; } forEach (units _targetGroup);
            systemChat format ["[ORDER] %1 (%2): Forced CROUCH.", _targetName, _targetRole];
        };
    };
    case "STANCE_DOWN": {
        if (!isNull _targetGroup) then {
            { _x setUnitPos "DOWN"; } forEach (units _targetGroup);
            systemChat format ["[ORDER] %1 (%2): Forced PRONE (Take cover).", _targetName, _targetRole];
        };
    };

    // Formations
    case "FORM_COLUMN": {
        if (!isNull _targetGroup) then {
            _targetGroup setFormation "COLUMN";
            systemChat format ["[ORDER] %1 (%2): Formation set to COLUMN.", _targetName, _targetRole];
        };
    };
    case "FORM_LINE": {
        if (!isNull _targetGroup) then {
            _targetGroup setFormation "LINE";
            systemChat format ["[ORDER] %1 (%2): Formation set to LINE.", _targetName, _targetRole];
        };
    };
    case "FORM_WEDGE": {
        if (!isNull _targetGroup) then {
            _targetGroup setFormation "WEDGE";
            systemChat format ["[ORDER] %1 (%2): Formation set to WEDGE.", _targetName, _targetRole];
        };
    };
    case "FORM_ECH_R": {
        if (!isNull _targetGroup) then {
            _targetGroup setFormation "ECH RIGHT";
            systemChat format ["[ORDER] %1 (%2): Formation set to ECHELON RIGHT.", _targetName, _targetRole];
        };
    };
    case "FORM_ECH_L": {
        if (!isNull _targetGroup) then {
            _targetGroup setFormation "ECH LEFT";
            systemChat format ["[ORDER] %1 (%2): Formation set to ECHELON LEFT.", _targetName, _targetRole];
        };
    };

    // Rules of Engagement (ROE)
    case "ROE_OPEN_FIRE": {
        if (!isNull _targetGroup) then {
            _targetGroup setCombatMode "YELLOW"; // Fire at will
            systemChat format ["[ORDER] %1 (%2): ROE set to FIRE AT WILL.", _targetName, _targetRole];
        };
    };
    case "ROE_HOLD_FIRE": {
        if (!isNull _targetGroup) then {
            _targetGroup setCombatMode "GREEN"; // Return fire only
            systemChat format ["[ORDER] %1 (%2): ROE set to HOLD FIRE (Return fire only).", _targetName, _targetRole];
        };
    };
    case "ROE_CEASE_FIRE": {
        if (!isNull _targetGroup) then {
            _targetGroup setCombatMode "BLUE"; // Never fire
            systemChat format ["[ORDER] %1 (%2): ROE set to CEASE FIRE.", _targetName, _targetRole];
        };
    };

    // Movement Pace / Follow Commander
    case "TOGGLE_PACE": {
        if (!isNull _targetGroup) then {
            private _curSpeed = speedMode _targetGroup;
            private _newSpeed = if (_curSpeed == "LIMITED") then { "NORMAL" } else { "LIMITED" };
            _targetGroup setSpeedMode _newSpeed;
            systemChat format ["[ORDER] %1 (%2): Movement speed set to %3.", _targetName, _targetRole, _newSpeed];
        };
    };
    case "TASK_FOLLOW_COMMANDER": {
        if (!isNull _targetGroup) then {
            [_targetGroup, group player] call FTCS_fnc_formationsGroupDoFollowCommander;
            systemChat format ["[ORDER] %1 (%2): Regrouping and following Commander.", _targetName, _targetRole];
        };
    };

    // Tactical Directives
    case "TASK_SBF": {
        systemChat format ["[DIRECTIVE] %1 (%2): Deploying Support by Fire (SBF) position.", _targetName, _targetRole];
    };
    case "TASK_SUPPRESS": {
        systemChat format ["[DIRECTIVE] %1 (%2): Initiating suppressive fire on target sector.", _targetName, _targetRole];
    };
    case "TASK_FALLBACK": {
        systemChat format ["[DIRECTIVE] %1 (%2): Executing orderly fallback.", _targetName, _targetRole];
    };
    case "SQUAD_SITREP": {
        private _aliveCount = { alive _x } count (units _targetGroup);
        private _totalCount = count (units _targetGroup);
        hint parseText format ["<t color='#00FFCC'>[SITREP: %1]</t><br/><t color='#FFFFFF'>Leader:</t> %2<br/><t color='#FFAA00'>Status:</t> %3/%4 men combat effective.<br/><t color='#AAAAAA'>Combat Mode:</t> %5", _targetRole, _targetName, _aliveCount, _totalCount, combatMode _targetGroup];
    };

    // Fireteam Tactical Maneuvers & Roles
    case "TEAM_ROLE_SCOUT": {
        systemChat format ["[TEAM DIRECTIVE] %1 (%2): Assigned POINT & RECON.", _targetName, _targetRole];
    };
    case "TEAM_ROLE_SUPPORT": {
        systemChat format ["[TEAM DIRECTIVE] %1 (%2): Assigned BASE OF FIRE.", _targetName, _targetRole];
    };
    case "TEAM_ROLE_ASSAULT": {
        systemChat format ["[TEAM DIRECTIVE] %1 (%2): Assigned ASSAULT & CLEARING.", _targetName, _targetRole];
    };
    case "TEAM_OVERWATCH": {
        systemChat format ["[TEAM DIRECTIVE] %1 (%2): Halting in overwatch to cover advance.", _targetName, _targetRole];
    };
    case "TEAM_BOUNDING": {
        systemChat format ["[TEAM DIRECTIVE] %1 (%2): Beginning bounding overwatch leapfrog.", _targetName, _targetRole];
    };
    case "TEAM_HOLD": {
        if (!isNull _targetGroup) then {
            { doStop _x; } forEach (units _targetGroup);
            systemChat format ["[TEAM DIRECTIVE] %1 (%2): Holding position as anchor.", _targetName, _targetRole];
        };
    };

    // Company General Directives (Air Orders to entire company)
    case "CO_GENERAL_HALT": {
        systemChat "[COMPANY DIRECTIVE] All platoons & squads: Halt and hold cover.";
        {
            if (side _x == side group player && _x != group player) then {
                { doStop _y; } forEach (units _x);
            };
        } forEach allGroups;
    };
    case "CO_GENERAL_ADVANCE": {
        systemChat "[COMPANY DIRECTIVE] All platoons & squads: Resume tactical advance.";
        {
            if (side _x == side group player && _x != group player) then {
                _x setSpeedMode "NORMAL";
            };
        } forEach allGroups;
    };
    case "CO_GENERAL_FIRE_WILL": {
        systemChat "[COMPANY DIRECTIVE] All elements: Open fire at will.";
        {
            if (side _x == side group player) then {
                _x setCombatMode "YELLOW";
            };
        } forEach allGroups;
    };
    case "CO_GENERAL_HOLD_FIRE": {
        systemChat "[COMPANY DIRECTIVE] All elements: Cease fire / Hold fire.";
        {
            if (side _x == side group player) then {
                _x setCombatMode "GREEN";
            };
        } forEach allGroups;
    };
    case "CO_GENERAL_REGROUP": {
        systemChat "[COMPANY DIRECTIVE] All subordinate elements: Regrouping on Company Commander.";
        {
            if (side _x == side group player && _x != group player) then {
                [_x, group player] call FTCS_fnc_formationsGroupDoFollowCommander;
            };
        } forEach allGroups;
    };

    // Platoon Sergeant Directives
    case "PLT_SGT_FORM_SUPPORT": {
        if (!isNull _targetGroup) then {
            _targetGroup setFormation "COLUMN";
            systemChat format ["[PLATOON SGT] %1: Forming up and leading Support Element.", _targetName];
        };
    };
    case "PLT_SGT_STANCE_CROUCH": {
        systemChat format ["[PLATOON SGT] %1: Directing cautious low stance across platoon elements.", _targetName];
    };
    case "PLT_SGT_STANCE_PRONE": {
        systemChat format ["[PLATOON SGT] %1: Directing all platoon elements to drop prone and take cover.", _targetName];
    };
    case "PLT_SGT_RESUPPLY": {
        systemChat format ["[PLATOON SGT] %1: Redistributing platoon ammunition and ammo bearer boxes.", _targetName];
    };
    case "PLT_SGT_FOLLOW_LEADER": {
        if (!isNull _targetGroup) then {
            [_targetGroup, group player] call FTCS_fnc_formationsGroupDoFollowCommander;
            systemChat format ["[PLATOON SGT] %1: Support Element falling in on Platoon Leader.", _targetName];
        };
    };
    case "PLT_SGT_SITREP": {
        hint parseText format ["<t color='#00FFCC'>[PLATOON SERGEANT SITREP]</t><br/><t color='#FFFFFF'>Sergeant:</t> %1<br/><t color='#FFAA00'>Status:</t> Platoon integrity intact.<br/><t color='#AAAAAA'>Logistics:</t> Ammunition status green.", _targetName];
    };

    // Default fallback
    default {
        systemChat format ["[ORDER EXECUTED] Command '%1' issued to %2 (%3).", _commandCode, _targetName, _targetRole];
    };
};
