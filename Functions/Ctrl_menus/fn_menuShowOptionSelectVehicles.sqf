



//params ["_menutoreturn"];

 //hint _menutoreturn;

_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


			{
				showCommandingMenu "#USER:MENU_Options_Select_Vehicle";				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}];
		

