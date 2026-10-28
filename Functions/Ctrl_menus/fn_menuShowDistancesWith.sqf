



//params ["_menutoreturn"];

 //hint _menutoreturn;

_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


			{
				showCommandingMenu "#USER:MENU_Move_With_pos_Infantry";				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}];
		

