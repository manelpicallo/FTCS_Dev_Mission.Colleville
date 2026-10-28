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
        private _relPos = [ groupId _x, "relPosition" ] call FTCS_fnc_registryGet;
        private _group_leader = if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos > 2}) then {
            _relPos select 2
        } else {
            FTCS_Group_Commander
        };

        if ((_list find _group_leader) == -1) then 
        {
            private _leader_formation = leader _group_leader;

            // Lanza la función de seguimiento individual para cada grupo
            [_x, _mode, _leader_formation] spawn FTCS_fnc_formationsGroupDoFollowCommander;

            [groupId _x, "movingMode", _mode] call FTCS_fnc_registrySet;
        };
    } forEach _list;
};

if (_mode == "FOLLOWING_COMMANDER_REL") then 
{
    {
        private _relPos = [ groupId _x, "relPosition" ] call FTCS_fnc_registryGet;
        private _refGroup = if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos > 2}) then {
            _relPos select 2
        } else {
            FTCS_Group_Commander
        };
        private _leader_formation = leader _refGroup;
        
        // Lanza la función de seguimiento individual para cada grupo
        [_x, _mode, _leader_formation] spawn FTCS_fnc_formationsGroupDoFollowCommander;

        [groupId _x, "movingMode", _mode] call FTCS_fnc_registrySet;
    } forEach _list;
};

if (_mode == "NO_FOLLOW") then 
{
    { [groupId _x, "movingMode", "AT_WILL"] call FTCS_fnc_registrySet; } forEach _list;
};