




params [];



_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


			{
				
				private _number_selected = count Selected_list;

				MENU_Set_Mode_Advance_Infantry_Var = +MENU_Set_Mode_Advance_Infantry;

				//Check the if vehicles in convoy mode and just one vehcile selected, so no following vehicle for groups allowed

				if ((({(Group_Vehicle_MovingMode_Table get (groupId _x)) == "CONVOY"} count Selected_Vehicle_list) == 0) && 
					((count Selected_list) == 1))  then 
					
					{

						(MENU_Set_Mode_Advance_Infantry_Var select 11) set [5,"1"];
					
					}

				else

				{	

					(MENU_Set_Mode_Advance_Infantry_Var select 11) set [5,"0"];
				
				};

				//Check the following mode to show the otionos following commander mode

				if ({((Groups_MovingMode_Table get groupId _x) == "FOLLOWING_COMMANDER_REL")} count Selected_list == _number_selected) then
				
					{

						(MENU_Set_Mode_Advance_Infantry_Var select 8) set [6,"0"];
						(MENU_Set_Mode_Advance_Infantry_Var select 9) set [6,"1"];

					};

				if ({((Groups_MovingMode_Table get groupId _x) == "FOLLOWING_COMMANDER_ABS")} count Selected_list == _number_selected) then
				
					{

						(MENU_Set_Mode_Advance_Infantry_Var select 8) set [6,"1"];
						(MENU_Set_Mode_Advance_Infantry_Var select 9) set [6,"0"];

					};

				//Check if all the groups are AT_WILL wich means NO Follow option is not needed	

				if ({((Groups_MovingMode_Table get groupId _x) == "AT_WILL")} count Selected_list == _number_selected) then
				
					{

						(MENU_Set_Mode_Advance_Infantry_Var select 10) set [5,"0"];

					};
				


				/*

				if (({(Groups_MovingMode_Table get groupId _x) == "EMBARKING"} count Selected_list != 0) ||
				({(Groups_MovingMode_Table get groupId _x) == "DISEMBARKING"} count Selected_list != 0)) then 

					{

						(MENU_Set_Mode_Advance_Infantry_Var select 5) set [6,"1"];
						(MENU_Set_Mode_Advance_Infantry_Var select 6) set [6,"1"];

						(MENU_Set_Mode_Advance_Infantry_Var select 1) set [6,"0"];
						(MENU_Set_Mode_Advance_Infantry_Var select 2) set [6,"0"];
						(MENU_Set_Mode_Advance_Infantry_Var select 3) set [6,"0"];
						

					};*/
				


				showCommandingMenu "#USER:MENU_Set_Mode_Advance_Infantry_Var";				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}];
		

