/*
    ================================================================================
    File: fn_formationsLiveSlotsDebugWorker.sqf
    Module: Formations
    Author: FTCS Team
    Description: Real-time dynamic 2D map visualizer for platoon formation slots.
                 Active while FTCS_Debug_Mode is true.
                 Updates every 0.5 seconds on the 2D map:
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

                    // Theoretical formation destination slot position for ALL slots (occupied and unoccupied)
                    // Visualizes the true geometric slot anchors where squads are directed to form/march
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

        sleep 0.5;
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

    FTCS_LiveSlotsWorker_Active = false;
};

true;
