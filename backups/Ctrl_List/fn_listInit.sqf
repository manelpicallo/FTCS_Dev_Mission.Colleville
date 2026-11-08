
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_init_type"];


if (_init_type == "INFANTRY") then 

	{

		Type_Selected = "INFANTRY";

		[_list, "FIRE_IF_FIRED_UPON"] call MPG_fnc_listSetFireMode;

		[_list, "SHARP"] call MPG_fnc_listSetAwareMode;

		[_list, "NORMAL", -1] call MPG_fnc_listSetSpeed;

		//Not allow to get in the vehicles by their own

		{(units _x)  AllowGetIn false;} foreach _list;



		{

			{[_x] call MPG_fnc_unitInit} foreach units _x;

		}foreach _list; 

	};


if (_init_type == "VEHICLE") then 

	{



	};
			

		