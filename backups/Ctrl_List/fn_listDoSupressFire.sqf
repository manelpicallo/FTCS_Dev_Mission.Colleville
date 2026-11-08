
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_type", "_duration"];

hint "SUPRESS FIRE!";


			if (Type_Selected == "INFANTRY") then

				{
					{[_x, _type, _duration] spawn MPG_fnc_GroupDoSupressFire;} foreach _list;
				};


			if (Type_Selected == "VEHICLE") then

				{
					{[_x, _type] spawn MPG_fnc_VehicleDoSupressFire;} foreach _list;
				};
  
		

		