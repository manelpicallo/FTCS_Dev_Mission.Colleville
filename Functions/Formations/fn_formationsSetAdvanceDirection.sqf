



/*
    Author: FTCS Framework
    Function: FTCS_fnc_formationsSetAdvanceDirection
    Description: Sets the general advance direction for the platoon and updates tactical markers.
*/

params ["_commander"];

// Sets the direction of advance as the present direction of the commander
private _advanceDir = getDir _commander;
missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _advanceDir];							

// Delete old Direction marker & Create the new Direction marker (if marker functions exist)
if (!isNil "FTCS_fnc_mapDeleteDirectionMarker") then {
    [group _commander, getPos _commander, "INFANTRY", _advanceDir] call FTCS_fnc_mapDeleteDirectionMarker;
};
if (!isNil "FTCS_fnc_mapCreateDirectionMarker") then {
    [group _commander, getPos _commander, "INFANTRY", _advanceDir] call FTCS_fnc_mapCreateDirectionMarker;							
};

_advanceDir;							


