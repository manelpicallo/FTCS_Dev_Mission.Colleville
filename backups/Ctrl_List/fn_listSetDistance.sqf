
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_distance"];


			if (Type_Selected == "INFANTRY") then

				{
					{(MPG_Groups_AdvanceMode_Table get (groupId _x)) set [1, _distance]} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
				//	{[_x, _type] call MPG_fnc_vehicleSetSpeed} foreach _list;
				};

		

			
			

	
