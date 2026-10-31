/*
    File: fn_syncGroupNames.sqf
    Module: Ctrl_Groups
    Author: FTCS Team
    Description: Abstracts engine-specific group naming calls (setGroupId for Arma 3) 
                 to ensure clean architecture and effortless portability to Arma 4 (Enfusion).
*/

FTCS_fnc_setEngineGroupName = {
    params ["_group", "_name", ["_iconType", "b_inf"]];
        
    if (isNull _group) exitWith {};
        
    // Arma 3 Engine Implementation (Ready to be swapped for Enfusion API in Arma 4)
    _group setGroupId [_name];

    // Native 2D Map NATO Group Icons (Functional independently of High Command mode)
    // Clears any previously attached icons on this group to prevent duplication on re-sync
    clearGroupIcons _group;
        
    // Resolve appropriate NATO icon tag based on group role or faction side
    private _sidePrefix = switch (side _group) do {
        case east:        { "o_" };
        case resistance:  { "n_" };
        default           { "b_" };
    };
    private _fullIcon = _sidePrefix + _iconType;
        
    _group addGroupIcon [_fullIcon, [0, 0]];
    _group setGroupIconParams [[1, 1, 1, 0.85], _name, 1.0, true];
};

// Enable native engine group icons rendering on the 2D tactical map and HUD
setGroupIconsVisible [true, false];


    private _companyHQData = FTCS_Company_Data getOrDefault ["companyHQ", createHashMap];
    if (count _companyHQData > 0) then {
        private _hqGroup = _companyHQData getOrDefault ["group", grpNull];
        private _companyLetter = FTCS_Config getOrDefault ["companyLetter", "E"];
        private _coTacticalTeams = _companyHQData getOrDefault ["tacticalTeams", createHashMap];
        if (count _coTacticalTeams > 0) then {
            {
                private _teamData = _y;
                private _teamType = _teamData getOrDefault ["type", "TEAM"];
                private _teamGroup = _teamData getOrDefault ["group", grpNull];
                [ _teamGroup, format ["Company HQ (%1) - %2", _companyLetter, _teamType], "hq" ] call FTCS_fnc_setEngineGroupName;
            } forEach _coTacticalTeams;
        } else {
            [ _hqGroup, format ["Company HQ (%1)", _companyLetter], "hq" ] call FTCS_fnc_setEngineGroupName;
        };
    };

    private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
    
    {
        private _pltId = _x;
        private _pltData = _y;
        private _pltName = _pltData getOrDefault ["name", _pltId];
        private _parsedSquads = _pltData getOrDefault ["parsedSquads", createHashMap];

        {
            private _sqdId = _x;
            private _sqdData = _y;
            private _sqdName = _sqdData getOrDefault ["name", _sqdId];
            private _isUnified = _sqdData getOrDefault ["isUnified", false];

            // Handle Platoon HQ / Leadership Slot (SQD_X_0)
            if (_sqdId find "_0" >= 0) then {
                private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
                if (count _tacticalTeams > 0) then {
                    {
                        private _teamData = _y;
                        private _teamType = _teamData getOrDefault ["type", "TEAM"];
                        private _teamGroup = _teamData getOrDefault ["group", grpNull];
                        [ _teamGroup, format ["HQ - %1 (%2)", _pltName, _teamType], "hq" ] call FTCS_fnc_setEngineGroupName;
                    } forEach _tacticalTeams;
                } else {
                    private _pltHqGroup = _sqdData getOrDefault ["group", grpNull];
                    [ _pltHqGroup, format ["HQ - %1", _pltName], "hq" ] call FTCS_fnc_setEngineGroupName;
                };
            } else {
                if (_isUnified) then {
                    // Unified squads (e.g. Mortar Section)
                    private _sqdGroup = _sqdData getOrDefault ["group", grpNull];
                    private _mortarIcon = if ((toLower _sqdName) find "mortar" >= 0 || (toLower _sqdName) find "mortero" >= 0) then { "mortar" } else { "art" };
                    [ _sqdGroup, format ["%1 - %2", _pltName, _sqdName], _mortarIcon ] call FTCS_fnc_setEngineGroupName;
                } else {
                    // Dual-group tactical teams (Assault & Support)
                    private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
                    {
                        private _teamId = _x;
                        private _teamData = _y;
                        private _teamType = _teamData getOrDefault ["type", "TEAM"];
                        private _teamGroup = _teamData getOrDefault ["group", grpNull];
                        private _teamRole = _teamData getOrDefault ["tacticalRole", "ASSAULT"];
                        private _icon = if (_teamRole == "SUPPORT") then { "support" } else { "inf" };
                        
                        [ _teamGroup, format ["%1 - %2 (%3)", _sqdName, _teamType, _pltName], _icon ] call FTCS_fnc_setEngineGroupName;
                    } forEach _tacticalTeams;
                };
            };
        } forEach _parsedSquads;

    } forEach _platoonsMap;

    diag_log "FTCS: Visual group names successfully synchronized via engine abstraction layer.";
    true;
