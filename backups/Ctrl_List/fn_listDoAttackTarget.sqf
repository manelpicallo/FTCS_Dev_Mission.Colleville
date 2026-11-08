
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_type"];


			if (Type_Selected == "INFANTRY") then

				{
					//
				};


			if (Type_Selected == "VEHICLE") then

				{
					//
				};

			if (Type_Selected == "SOLDIER") then

				{
					{[_x, "CURSOR_TARGET" ,""] spawn MPG_fnc_unitDoAttackTarget;} foreach _list;
				};
  
		

		