



//call MPG_fnc_HUDShowSelectedUnit;

Type_Selected = "SOLDIER";


_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


			{
				showCommandingMenu "#USER:MENU_Main_Units";				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}];
		

