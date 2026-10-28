




params [];



_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


			{
				
				private _number_selected = count Selected_list;

				MENU_Orders_Group_Infantry_Var = +MENU_Orders_Group_Infantry;


				if ({((Groups_MovingMode_Table get groupId _x) == "IN_VEHICLE")} count Selected_list == _number_selected)  then 
					
					{

						(MENU_Orders_Group_Infantry_Var select 5) set [6,"0"];
						(MENU_Orders_Group_Infantry_Var select 6) set [6,"1"];

						(MENU_Orders_Group_Infantry_Var select 1) set [6,"0"];
						(MENU_Orders_Group_Infantry_Var select 2) set [6,"0"];
						(MENU_Orders_Group_Infantry_Var select 3) set [6,"0"];
						//(MENU_Orders_Group_Infantry_Var select 4) set [6,"0"];


					};

				if ({((Groups_MovingMode_Table get groupId _x) == "IN_VEHICLE")} count Selected_list == 0) then
				
					{

						(MENU_Orders_Group_Infantry_Var select 5) set [6,"1"];
						(MENU_Orders_Group_Infantry_Var select 6) set [6,"0"];

					};


				if (({(Groups_MovingMode_Table get groupId _x) == "EMBARKING"} count Selected_list != 0) ||
				({(Groups_MovingMode_Table get groupId _x) == "DISEMBARKING"} count Selected_list != 0)) then 

					{

						(MENU_Orders_Group_Infantry_Var select 5) set [6,"1"];
						(MENU_Orders_Group_Infantry_Var select 6) set [6,"1"];

						(MENU_Orders_Group_Infantry_Var select 1) set [6,"0"];
						(MENU_Orders_Group_Infantry_Var select 2) set [6,"0"];
						(MENU_Orders_Group_Infantry_Var select 3) set [6,"0"];
						//(MENU_Orders_Group_Infantry_Var select 4) set [6,"0"];

					};
				


				showCommandingMenu "#USER:MENU_Orders_Group_Infantry_Var";				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}];
		

