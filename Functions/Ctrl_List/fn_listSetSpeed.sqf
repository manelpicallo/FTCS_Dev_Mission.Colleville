
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_type", "_factor"];


			if (Type_Selected == "INFANTRY") then

				{
					{[_x, _type, _factor] call MPG_fnc_groupSetSpeed} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
				//	{[_x, _type] call MPG_fnc_vehicleSetSpeed} foreach _list;
				};

		

			
			

	
