
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_type", "_fire_mode", "_type_target"];

	if (Type_Selected == "INFANTRY") then

		{
			//
		};


	if (Type_Selected == "VEHICLE") then

		{

			{[_x, _type, _fire_mode, _type_target] spawn MPG_fnc_vehicleDoFire} foreach _list;

		};