

/*
    Author: FTCS Framework
    Function: FTCS_fnc_formationsCurrentPositionSet
    Description: Captures current absolute map positions and orientations of groups 
                 to maintain organic deployment layouts without resetting to default templates.
*/

params ["_formation_elements", "_formation_type", "_separate_dis"];

private _number_elements = count _formation_elements;

// Check if number of groups is in range
if (_number_elements < 1) exitWith { hint "FTCS Error: Number of groups out of range"; };

// Gets the main commander using the standardized FTCS framework variable (AI-agnostic)
private _commander = leader FTCS_Group_Commander;

switch (_formation_type) do {

    case "ABS": {
        /*
            ABS (Absolute Snapshot Mode):
            Freezes the current map geometry by calculating direct distances and headings
            from leaders to their formation anchor, preventing accordion effects on movement.
        */
        {
            if (!isNull _x) then {
                
                private _groupID = groupId _x;

                // Gets the local leader of the group
                private _leader_group = leader _x;

                // Gets the leader to which this group is attached (from master registry)
                private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
                private _refGroup = if (!isNil "_relPos" && {_relPos isEqualType []} && {count _relPos > 2}) then {
                    _relPos select 2
                } else {
                    FTCS_Group_Commander
                };
                private _leader_formation = leader _refGroup;

                // Update encapsulated registry entry: absolute distance & direction
                private _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];
                _relPos set [0, _leader_group distance2D _leader_formation];
                _relPos set [1, _leader_formation getDir _leader_group];
                _entry set ["relPosition", _relPos];
                FTCS_Groups_Registry_Table set [_groupID, _entry];

            };

        } forEach _formation_elements;
    };

    default { 
        hint "FTCS Warning: Unknown formation position type"; 
    };
};