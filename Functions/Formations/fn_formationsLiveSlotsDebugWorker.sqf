/*
    ================================================================================
    File: fn_formationsLiveSlotsDebugWorker.sqf
    Module: Formations
    Author: FTCS Team
    Description: Real-time dynamic 2D map visualizer for platoon formation slots.
                 Active while FTCS_Debug_Mode is true.
                 Updates every 1 second on the 2D map:
                 - Assigned / Occupied slots: Drawn at the real-time physical position
                   that the assigned squad currently occupies on the terrain (Orange dot).
                 - Unassigned slots: Drawn at the theoretical formation position where that
                   slot would be relative to the platoon leader (Yellow dot).
                 - Text format: Strictly the slot index in parentheses, e.g. "(1)".
                 Zero marker flicker by updating marker positions in-place.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4)
    ================================================================================
*/

params [["_inputLeader", objNull]];

if (!isNull _inputLeader) then {
    missionNamespace setVariable ["FTCS_Formation_Visualizer_Leader", _inputLeader];
};

missionNamespace setVariable ["FTCS_Debug_Mode", true];

if (!isNil "FTCS_LiveSlotsWorker_Active" && {FTCS_LiveSlotsWorker_Active}) exitWith {};

FTCS_LiveSlotsWorker_Active = true;

[] spawn {
    while {missionNamespace getVariable ["FTCS_Debug_Mode", true]} do {
        private _leaderUnit = missionNamespace getVariable ["FTCS_Formation_Visualizer_Leader", objNull];
        if (isNull _leaderUnit) then {
            _leaderUnit = missionNamespace getVariable ["FTCS_Platoon_Leader_Unit", objNull];
        };
        if (isNull _leaderUnit) then {
            private _commanderGrp = missionNamespace getVariable ["FTCS_Group_Commander", grpNull];
            _leaderUnit = if (!isNull _commanderGrp) then { leader _commanderGrp } else { player };
        };
        if (isNull _leaderUnit) then { _leaderUnit = player; };

        private _leaderPos = getPosATL _leaderUnit;
        private _followMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];

        // Reference heading for formation slots:
        // In RELATIVE mode:
        //   - While marching (speed > 2 km/h): turns dynamically with leader march heading.
        //   - While stopped (speed <= 2 km/h): strictly locked to the consolidated platoon advance heading
        //     (FTCS_Platoon_Advance_Direction), NEVER rotating with mouse view or leader head rotation.
        // In ABSOLUTE mode: permanently locked to the fixed compass heading frozen when absolute was chosen.
        private _refHeading = if (_followMode == "FOLLOWING_COMMANDER_REL") then {
            if (speed _leaderUnit > 2) then {
                getDir _leaderUnit
            } else {
                missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", missionNamespace getVariable ["FTCS_Last_Commander_Dir", getDir _leaderUnit]]
            };
        } else {
            missionNamespace getVariable ["FTCS_Platoon_Fixed_Abs_Dir", missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", getDir _leaderUnit]]
        };

        // Check if platoon is currently marching along a road
        private _pId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltKey = format ["PLT_%1", _pId];
        private _platoonsMap = FTCS_Company_Data getOrDefault ["platoons", createHashMap];
        private _pltData = _platoonsMap getOrDefault [_pltKey, createHashMap];
        private _technique = _pltData getOrDefault ["movementTechnique", "CROSS_COUNTRY"];
        private _activePath = _pltData getOrDefault ["roadPath", []];
        private _isRoadMode = (_technique == "ROAD_COLUMN" && count _activePath >= 2);

        if (_isRoadMode && {!isNil "FTCS_Groups_Registry_Table"}) then {
            // In ROAD march mode: query live connected road segments backward from current leader position
            // Use locked advance direction if stopped to prevent road path jitter from player mouse view/look
            private _roadLookDir = if (speed _leaderUnit > 2) then { getDir _leaderUnit } else { _refHeading };
            private _livePath = [_leaderUnit, 250, _roadLookDir] call FTCS_fnc_roadGetPointsBehind;

            // Helper to calculate exact position along polyline at distance
            private _fnc_sampleRoadDist = {
                params ["_distTarget", "_path"];
                private _accum = 0;
                private _foundPt = _path select (count _path - 1);
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

            {
                private _gEntry = _y;
                private _offsetDist = _gEntry getOrDefault ["roadOffsetDist", nil];
                private _shoulderOffset = _gEntry getOrDefault ["roadShoulderOffset", nil];
                private _slotIdx = _gEntry getOrDefault ["allocationSlot", -1];
                private _teamIdx = _gEntry getOrDefault ["roadTeamIndex", -1];

                if (!isNil "_offsetDist" && {_slotIdx >= 0}) then {
                    private _gID = _x;
                    private _mName = format ["FTCS_DEBUG_ROAD_SLOT_%1", _gID];
                    private _slotPos = [0, 0, 0];

                    if (count _livePath >= 2) then {
                        private _roadSample = [_offsetDist, _livePath] call _fnc_sampleRoadDist;
                        private _roadCenter = _roadSample select 0;
                        private _tangent = _roadSample select 1;
                        private _sh = if (!isNil "_shoulderOffset") then { _shoulderOffset } else { 0 };
                        private _perp = (_tangent + 90) % 360;
                        _slotPos = _roadCenter getPos [abs _sh, if (_sh < 0) then { (_perp + 180) % 360 } else { _perp }];
                    } else {
                        _slotPos = _leaderPos getPos [_offsetDist, ((getDir _leaderUnit) + 180) % 360];
                    };

                    if (getMarkerType _mName == "") then {
                        createMarkerLocal [_mName, _slotPos];
                        _mName setMarkerTypeLocal "mil_dot";
                    };

                    _mName setMarkerPosLocal _slotPos;
                    private _label = if (_teamIdx > 0) then {
                        format [" (S%1-T%2)", _slotIdx, _teamIdx]
                    } else {
                        format [" (S%1)", _slotIdx]
                    };
                    _mName setMarkerTextLocal _label;
                    _mName setMarkerColorLocal "ColorOrange";
                    _mName setMarkerSizeLocal [0.75, 0.75];
                };
            } forEach FTCS_Groups_Registry_Table;

            // Hide normal off-road slot markers while on road
            for "_i" from 0 to 12 do {
                private _m = format ["FTCS_DEBUG_DYNAMIC_SLOT_%1", _i];
                if (getMarkerType _m != "") then { deleteMarkerLocal _m; };
            };
        } else {
            // Clean up road slot markers when off road
            {
                if (_x find "FTCS_DEBUG_ROAD_SLOT_" == 0) then { deleteMarkerLocal _x; };
            } forEach allMapMarkers;

            // Update all 13 macro slots (slots 0 to 12)
            if (!isNil "Platoon_Formation_Position_List" && {count Platoon_Formation_Position_List > 0}) then {
                {
                    if (_forEachIndex < 13 && {count _x >= 2}) then {
                        private _slotIdx = _forEachIndex;
                        private _slotDist = _x select 0;
                        private _slotBearing = _x select 1;
                        private _slotGrp = if (count _x > 2) then { _x select 2 } else { grpNull };

                        // Fallback lookup in registry if slotGrp was not cached directly
                        if (isNull _slotGrp && {!isNil "FTCS_Groups_Registry_Table"}) then {
                            {
                                private _gEntry = _y;
                                if ((_gEntry getOrDefault ["allocationSlot", -1]) == _slotIdx) exitWith {
                                    private _cand = missionNamespace getVariable [_x, grpNull];
                                    if (!isNull _cand) then { _slotGrp = _cand; };
                                };
                            } forEach FTCS_Groups_Registry_Table;
                        };

                        private _markerName = format ["FTCS_DEBUG_DYNAMIC_SLOT_%1", _slotIdx];
                        private _isOccupied = (!isNull _slotGrp && {count units _slotGrp > 0} && {!isNull (leader _slotGrp)});
                        private _slotPos = _leaderPos getPos [_slotDist, _refHeading + _slotBearing];

                        if (getMarkerType _markerName == "") then {
                            createMarkerLocal [_markerName, _slotPos];
                            _markerName setMarkerTypeLocal "mil_dot";
                        };

                        _markerName setMarkerPosLocal _slotPos;
                        _markerName setMarkerTextLocal format [" (%1)", _slotIdx];

                        if (_isOccupied) then {
                            _markerName setMarkerColorLocal "ColorOrange";
                            _markerName setMarkerSizeLocal [0.8, 0.8];
                        } else {
                            _markerName setMarkerColorLocal "ColorYellow";
                            _markerName setMarkerSizeLocal [0.5, 0.5];
                        };
                    };
                } forEach Platoon_Formation_Position_List;
            };
        };

        // Render / update solid red arrow indicator for the Platoon Leader / Player facing direction (+25% size)
        private _playerPos = getPosATL player;
        private _arrowMarkerName = "FTCS_DEBUG_PLAYER_DIR_ARROW";
        if (getMarkerType _arrowMarkerName == "") then {
            createMarkerLocal [_arrowMarkerName, _playerPos];
            _arrowMarkerName setMarkerTypeLocal "mil_arrow2";
            _arrowMarkerName setMarkerColorLocal "ColorRed";
            _arrowMarkerName setMarkerSizeLocal [0.625, 0.875];
        };
        _arrowMarkerName setMarkerPosLocal _playerPos;
        _arrowMarkerName setMarkerDirLocal (getDir player);

        sleep 1.0;
    };

    // Clean up dynamic slot markers and direction arrow when debug mode is deactivated
    if (getMarkerType "FTCS_DEBUG_PLAYER_DIR_ARROW" != "") then {
        deleteMarkerLocal "FTCS_DEBUG_PLAYER_DIR_ARROW";
    };

    for "_i" from 0 to 12 do {
        private _m = format ["FTCS_DEBUG_DYNAMIC_SLOT_%1", _i];
        if (getMarkerType _m != "") then {
            deleteMarkerLocal _m;
        };
    };

            {
                if (_x find "FTCS_DEBUG_ROAD_SLOT_" == 0) then { deleteMarkerLocal _x; };
            } forEach allMapMarkers;

    FTCS_LiveSlotsWorker_Active = false;
};

true;
