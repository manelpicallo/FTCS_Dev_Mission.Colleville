
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_mode"];

	
		
			
			if (Type_Selected == "INFANTRY") then

				{
					{[_x, _mode] spawn MPG_fnc_groupSetFireMode;} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
					{[_x, _mode] call MPG_fnc_vehicleSetFireMode;} foreach _list;
				};
			

		