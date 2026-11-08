
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_type", "_activate"];


			if (Type_Selected == "INFANTRY") then

				{
					{[_x, _type, _activate] call MPG_fnc_groupSetAdvanceMode} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
					//Not implemente yet
				};

		

			
			

	
