
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_mode"];

					
		if (Type_Selected == "INFANTRY") then

				{
					{[_x, _mode] call MPG_fnc_groupSetAwareMode;} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
					{[_x, _mode] call MPG_fnc_vehicleSetAwareMode;} foreach _list;
					
				
					
					//int str (_list select 0);
					//hint str combatBehaviour (Selected_Vehicle_list select 0);
					//hint str (Selected_Vehicle_list select 0);
					
				};