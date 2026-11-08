

call MPG_fnc_HUDShowMoveMode;

_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


	{
				
		if (Type_Selected == "INFANTRY") then

			{
				private _mode = Groups_MovingMode_Table get (groupid (Selected_list select 0));
					
				switch (_mode) do 

				{


				case "FOLLOWING_VEHICLE":
					
					{

						//Eliminate options allready selected from the menu

						MENU_Move_With_Vehicle_Infantry_Var = +MENU_Move_With_Vehicle_Infantry;

						if ((Groups_With_Vehicle_Table get groupid (Selected_list select 0)) select 1 == "SLOW")  then 
						{

							(MENU_Move_With_Vehicle_Infantry_Var select 2) set [6,"0"]; 

						};

						if ((Groups_With_Vehicle_Table get groupid (Selected_list select 0)) select 1 == "NORMAL") then 
						{

							(MENU_Move_With_Vehicle_Infantry_Var select 3) set [6, "0"]; 

						};

						if ((Groups_With_Vehicle_Table get groupid (Selected_list select 0)) select 1 == "FAST") then 
						{

							(MENU_Move_With_Vehicle_Infantry_Var select 4) set [6, "0"]; 

						};

						showCommandingMenu "#USER:MENU_Move_With_Vehicle_Infantry_Var";

					};

				case "WITH_COMMANDER":
			
					
					{	

						showCommandingMenu "#USER:MENU_Move_With_Commander_Infantry";

					};

				default

					{
						
						showCommandingMenu "#USER:MENU_Move_Infantry";

					 };



				};
				
				};


				if (Type_Selected == "VEHICLE") then

				{
					showCommandingMenu "#USER:MENU_Move_Vehicles";
				};
				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}];


		
		
	
			
	

