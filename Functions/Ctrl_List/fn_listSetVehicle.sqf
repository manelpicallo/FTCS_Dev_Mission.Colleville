
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_mode"];

	
	
			
			if (Type_Selected == "INFANTRY") then

				{
					
					if (_mode == "ASSIGN") then

					{
					
						{[_x, Groups_Assigned_Vehicle_Table get (groupId _x), _mode] call MPG_fnc_groupSetVehicle;} foreach _list;

					}

					else 

					{

						{[_x, Groups_Assigned_Vehicle_Table get (groupId _x), _mode] spawn MPG_fnc_groupSetVehicle;} foreach _list;

					};
				
				}; 


			if (Type_Selected == "VEHICLE") then

				{
					//
				};

			if (Type_Selected == "SOLDIER") then

				{
					//
				};
			

		