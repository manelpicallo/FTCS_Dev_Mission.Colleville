

#include "\a3\ui_f\hpp\definedikcodes.inc"


{
	waitUntil { !isNull findDisplay 46 };
};


(findDisplay 46) displayAddEventHandler 
	["KeyDown",
		{
			params ["_displayOrControl", "_key", "_shift", "_ctrl", "_alt"];
			if (_key isEqualTo DIK_TAB) then {call MPG_fnc_menuShowMain;};	

		}
	];

[] spawn MPG_fnc_Main;


call MPG_fnc_menuShowMain;


