/*
    File: fn_syncGroupNames.sqf
    Module: Ctrl_Groups
    Author: FTCS Team
    Description: Abstracts engine-specific group naming calls (setGroupId for Arma 3) 
                 to ensure clean architecture and effortless portability to Arma 4 (Enfusion).
*/

FTCS_fnc_setEngineGroupName = {
    params ["_group", "_name", ["_iconType", "inf"], ["_sizeIcon", "group_0"]];
            
    if (isNull _group) exitWith {};
            
    // Arma 3 Engine Implementation (Ready to be swapped for Enfusion API in Arma 4)
    _group setGroupId [_name];

    // Native 2D Map NATO Group Icons (Functional independently of High Command mode)
    // Clears any previously attached icons on this group to prevent duplication on re-sync
    clearGroupIcons _group;
            
    // User Requirement: Friendly doctrine groups displayed to the player ALWAYS use BLUFOR style ("b_")
    // regardless of the actual underlying engine faction (e.g., resistance/independent).
    private _fullIcon = "b_" + _iconType;
            
    // Main NATO Role Icon (center)
    _group addGroupIcon [_fullIcon, [0, 0]];

    // NATO Echelon/Size Modifier Icon placed directly above the main icon (e.g. group_0 = fireteam, group_1 = squad)
    if (_sizeIcon != "") then {
        _group addGroupIcon [_sizeIcon, [0, -12]];
    };

    // Group Name Label: High-visibility Golden tactical tint [1.0, 0.75, 0.0, 1.0] instead of dull white
    _group setGroupIconParams [[1.0, 0.75, 0.0, 1.0], _name, 1.0, true];
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
                [ _teamGroup, format ["Company HQ (%1) - %2", _companyLetter, _teamType], "hq", "group_2" ] call FTCS_fnc_setEngineGroupName;
            } forEach _coTacticalTeams;
        } else {
            [ _hqGroup, format ["Company HQ (%1)", _companyLetter], "hq", "group_3" ] call FTCS_fnc_setEngineGroupName;
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
                        [ _teamGroup, format ["HQ - %1 (%2)", _pltName, _teamType], "hq", "group_0" ] call FTCS_fnc_setEngineGroupName;
                    } forEach _tacticalTeams;
                } else {
                    private _pltHqGroup = _sqdData getOrDefault ["group", grpNull];
                    [ _pltHqGroup, format ["HQ - %1", _pltName], "hq", "group_1" ] call FTCS_fnc_setEngineGroupName;
                };
            } else {
                if (_isUnified) then {
                    // Unified squads (e.g. Mortar Section) -> squad echelon modifier (group_1)
                    private _sqdGroup = _sqdData getOrDefault ["group", grpNull];
                    private _mortarIcon = if ((toLower _sqdName) find "mortar" >= 0 || (toLower _sqdName) find "mortero" >= 0) then { "mortar" } else { "art" };
                    [ _sqdGroup, format ["%1 - %2", _pltName, _sqdName], _mortarIcon, "group_1" ] call FTCS_fnc_setEngineGroupName;
                } else {
                    // Tactical teams (Fireteams) -> fireteam echelon modifier (group_0)
                    private _tacticalTeams = _sqdData getOrDefault ["tacticalTeams", createHashMap];
                    {
                        private _teamId = _x;
                        private _teamData = _y;
                        private _teamType = _teamData getOrDefault ["type", "TEAM"];
                        private _teamGroup = _teamData getOrDefault ["group", grpNull];
                        private _teamRole = _teamData getOrDefault ["tacticalRole", "ASSAULT"];
                        private _icon = if (_teamRole == "SUPPORT") then { "support" } else { "inf" };
                        
                        [ _teamGroup, format ["%1 - %2 (%3)", _sqdName, _teamType, _pltName], _icon, "group_0" ] call FTCS_fnc_setEngineGroupName;
                    } forEach _tacticalTeams;
                };
            };
        } forEach _parsedSquads;

    } forEach _platoonsMap;

    diag_log "FTCS: Visual group names successfully synchronized via engine abstraction layer.";
    true;
