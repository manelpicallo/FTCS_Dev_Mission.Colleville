
/*
	Author: Manel P.

	Description:
	
*/

params ["_list"];

hint "FIRE!";

		{

			if (typeName _x == "GROUP") then {_x call MPG_fnc_VehicleGunnerDoWatch};
			if (typeName _x == "OBJECT") then {doStop _x}; //no full implemented ==> no table moving actualized

		} foreach _list;