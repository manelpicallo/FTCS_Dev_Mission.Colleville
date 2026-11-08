



_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


	{
		if (Type_Selected == "INFANTRY") then

		{
			
			MENU_Main_Infantry_Var = +MENU_Main_Infantry;

			//Eliminate Stance allready selected from menu

			if (Groups_Stance_Table get (groupid (Selected_list select 0)) == "FOLLOW_COMMANDER_STANCE") then 
					
				{
				
				(MENU_Main_Infantry_Var select 7) set [5,"0"];
				(MENU_Main_Infantry_Var select 8) set [5,"1"]; 	 			

				}

			else 
			
				{

				(MENU_Main_Infantry_Var select 7) set [5,"1"];
				(MENU_Main_Infantry_Var select 8) set [5,"0"]; 		

				};

			//Eliminate platoon formations if not all squad selected

			if ((count Selected_list) == MPG_Total_Infantry_Groups) then 
					
				{
				
				(MENU_Main_Infantry_Var select 10) set [5,"1"]; 			

				}

			else 
			
				{

				(MENU_Main_Infantry_Var select 10) set [5,"0"]; 

				};

			//Eliminate squad with me if more than one selected

			if ((count Selected_list) == 1) then 
					
				{
				
				(MENU_Main_Infantry_Var select 11) set [5,"1"]; 			

				}

			else 
			
				{

				(MENU_Main_Infantry_Var select 11) set [5,"0"]; 

				};			
				
			showCommandingMenu "#USER:MENU_Main_Infantry_Var";

		};



		if (Type_Selected == "VEHICLE") then

		{
				
			MENU_Main_Vehicles_Var = +MENU_Main_Vehicles;

			if ((count Selected_Vehicle_list) != missionNamespace getVariable "MPG_max_vehicle_convoy") then


				{ 
					
					MENU_Main_Vehicles_Var = +MENU_Main_Vehicles;

					//Validate option to select convoy if selected all activated

					(MENU_Main_Vehicles_Var select 7) set [6,"0"]; 

				};


			if (({(Group_Vehicle_MovingMode_Table get (groupId _x)) == "CONVOY"} count Selected_Vehicle_list) == 0) then

				{ 
							
					showCommandingMenu "#USER:MENU_Main_Vehicles_Var";	

				}				

			else

				{	

					showCommandingMenu "#USER:MENU_Main_Convoy";
				
				};
				
		};


		if (Type_Selected == "SOLDIER") then

		{

			showCommandingMenu "#USER:MENU_Main_Units";

		};



		findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			
			
	}];
		
		
	
