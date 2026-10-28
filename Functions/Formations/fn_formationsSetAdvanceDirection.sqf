



params ["_commander"];



//Sets the direction of advance as the present direction of the commander

missionNamespace setVariable ["MPG_Platoon_Advance_Direction", getDir _commander];							

//Delete old Direction marker & Create the new Direction maker

[group _commander, GetPos _commander ,"INFANTRY", missionNamespace getVariable  "MPG_Platoon_Advance_Direction"] call MPG_fnc_mapDeleteDirectionMarker;
[group _commander, GetPos _commander,"INFANTRY", missionNamespace getVariable  "MPG_Platoon_Advance_Direction"] call MPG_fnc_mapCreateDirectionMarker;							


