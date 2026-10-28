
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_stance"];



if (Type_Selected == "INFANTRY") then 

	{
		if (_stance == "FOLLOW_COMMANDER_STANCE") then 

			{

				{

					if (typeName _x == "GROUP") then {[_x, _stance] spawn MPG_fnc_groupSetStance};
		
				} foreach _list;
			}

		else

			{
				{

					if (typeName _x == "GROUP") then {[_x, _stance] call MPG_fnc_groupSetStance};
			

				} foreach _list;

			};

	};		


if (Type_Selected == "VEHICLE") then 

	{
		hint "ERROR not stances for vehicles";
	};
