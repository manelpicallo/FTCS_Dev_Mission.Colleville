

#include "\a3\ui_f\hpp\definedikcodes.inc"
hint "entro wait";
{
	waitUntil { !isNull findDisplay 46 };
};

(findDisplay 46) displayAddEventHandler 
	["KeyDown",
		{
			params ["_displayOrControl", "_key", "_shift", "_ctrl", "_alt"];
			hint "key pressed";
			if (_key isEqualTo DIK_TAB) then {call MPG_fnc_Main; hint "TAB"};	

		}
	];

