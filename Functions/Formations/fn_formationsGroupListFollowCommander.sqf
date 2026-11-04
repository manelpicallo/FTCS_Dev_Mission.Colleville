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