/*
	Author: Manel P.

	Description:
		
		Make the Vehicle move to a position

	Parameter(s):
		0: can be one of:
			Vehicle - Vehicle who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group"]; 

private _vehicle = assignedVehicles	_group;
//private _Watch_Direction;
private _relpos;

_Watch_Direction = (getDir player) - (getDir gunner (_vehicle select 0));
_relpos = (gunner (_vehicle select 0)) getRelPos [400,_Watch_Direction];
(gunner (_vehicle select 0)) doWatch _relpos;

					
				
