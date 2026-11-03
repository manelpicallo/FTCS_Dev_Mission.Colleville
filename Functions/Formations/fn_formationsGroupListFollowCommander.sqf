/*
    Author: FTCS Framework / Manel P.
    Function: FTCS_fnc_formationsGroupListFollowCommander
    Description: Iterates over a list of groups to assign follow-commander behaviors in batch (AI-Agnostic).
*/

params ["_list", "_mode"];

// Detiene cualquier bucle previo en los grupos de la lista
{ [groupId _x, "movingMode", "STOP"] call FTCS_fnc_registrySet; } forEach _list;

sleep 0.2;                    

if (_mode == "FOLLOWING_COMMANDER_ABS") then 
{
    {
        private _curGroup = _x;
        private _curGroupId = groupId _curGroup;
        private _relPos = [ _curGroupId, "relPosition" ] call FTCS_fnc_registryGet;
        private _refGroup = if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos > 2}) then {
            _relPos select 2
        } else {
            FTCS_Group_Commander
        };

        // Prevent a group from trying to follow itself
        if (_refGroup != _curGroup) then 
        {
            private _leader_formation = leader _refGroup;
            if (!isNull _leader_formation) then 
            {
                // Retrieve original relative geometry from formationPosition
                private _formPos = [ _curGroupId, "formationPosition" ] call FTCS_fnc_registryGet;
                if (isNil "_formPos" || {!(_formPos isEqualType [])} || {count _formPos < 2}) then {
                    _formPos = _relPos;
                };

                private _dist = if (!isNil "_formPos" && {_formPos isEqualType []} && {count _formPos > 0}) then { _formPos select 0 } else { 15 };
                private _relAngle = if (!isNil "_formPos" && {_formPos isEqualType []} && {count _formPos > 1}) then { _formPos select 1 } else { 180 };

                // Freeze absolute compass bearing (0-360) based on leader's heading at this moment
                private _refDir = missionNamespace getVariable ["FTCS_Last_Commander_Dir", getDir _leader_formation];
                private _absBearing = (_refDir + _relAngle) % 360;
                if (_absBearing < 0) then { _absBearing = _absBearing + 360; };

                // Store fixed compass bearing in relPosition so ABS getPos anchors to map grid
                [ _curGroupId, "relPosition", [_dist, _absBearing, _refGroup] ] call FTCS_fnc_registrySet;

                // Launch individual follow loop in ABS mode
                [_curGroup, _mode, _leader_formation] spawn FTCS_fnc_formationsGroupDoFollowCommander;

                [ _curGroupId, "movingMode", _mode ] call FTCS_fnc_registrySet;
            };
        };
    } forEach _list;
};

if (_mode == "FOLLOWING_COMMANDER_REL") then 
{
    {
        private _curGroup = _x;
        private _curGroupId = groupId _curGroup;
        private _relPos = [ _curGroupId, "relPosition" ] call FTCS_fnc_registryGet;
        private _refGroup = if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos > 2}) then {
            _relPos select 2
        } else {
            FTCS_Group_Commander
        };
        
        // Prevent a group from trying to follow itself
        if (_refGroup != _curGroup) then {
            private _leader_formation = leader _refGroup;
            if (!isNull _leader_formation) then {
                // Lanza la función de seguimiento individual para cada grupo
                [_curGroup, _mode, _leader_formation] spawn FTCS_fnc_formationsGroupDoFollowCommander;
                [_curGroupId, "movingMode", _mode] call FTCS_fnc_registrySet;
            };
        };
    } forEach _list;
};

if (_mode == "NO_FOLLOW") then 
{
    { [groupId _x, "movingMode", "AT_WILL"] call FTCS_fnc_registrySet; } forEach _list;
};