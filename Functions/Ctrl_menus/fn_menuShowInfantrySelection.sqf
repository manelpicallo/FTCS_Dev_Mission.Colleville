

_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


	{

//Now, just check if one vehicle is in convoy mode.... & supose all are in the same mode, so no check for alive vehicle needed.

 		if (({(Group_Vehicle_MovingMode_Table get (groupId _x)) == "CONVOY"} count Selected_Vehicle_list) == 0) then

			{
				showCommandingMenu "#USER:MENU_Select_Infantry";				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}

		else
		
			{

				showCommandingMenu "#USER:MENU_Main_Convoy";
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];

			}

	}];
		

