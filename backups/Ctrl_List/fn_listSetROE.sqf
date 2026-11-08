
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_ROE"];

		
			if (Type_Selected == "INFANTRY") then

				{
					{[_x, _ROE] call MPG_fnc_groupSetROE;} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
					{[_x, _ROE] call MPG_fnc_vehicleSetROE;} foreach _list;
				};
			

		
	

	
