
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_type"];


			if (Type_Selected == "INFANTRY") then

				{
					{[_x, _type] call MPG_fnc_groupDoStop} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
					{[_x, _type] call MPG_fnc_vehicleDoStop} foreach _list;
				};

		

			
			

	
