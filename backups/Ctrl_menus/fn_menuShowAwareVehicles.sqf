




params [];


_myEH = findDisplay 46 displayAddEventHandler ["MouseButtonUp", 


			{
				
				//{_x commandChat str (Behaviour (_x))} foreach units (Selected_Vehicle_list select 0);
				//leader (Selected_Vehicle_list select 0) commandChat str combatBehaviour (Selected_Vehicle_list select 0);

				MENU_Aware_Vehicles_Var = +MENU_Aware_Vehicles;

				private _all_units = count units (Selected_Vehicle_list select 0); 

				if ((({Behaviour _x == "SAFE"} count units (Selected_Vehicle_list select 0))) == _all_units)  then 
					
					{

						(MENU_Aware_Vehicles_Var select 4) set [6,"0"]; 

					};

				if ((({Behaviour _x == "AWARE"} count units (Selected_Vehicle_list select 0))) == _all_units) then 
					{

						(MENU_Aware_Vehicles_Var select 5) set [6, "0"]; 

					};

				if ((({Behaviour _x == "COMBAT"} count units (Selected_Vehicle_list select 0))) == _all_units) then 
					{

						(MENU_Aware_Vehicles_Var select 6) set [6, "0"]; 

					};

				if ((({Behaviour _x == "STEALTH"} count units (Selected_Vehicle_list select 0))) == _all_units) then 
					{

						(MENU_Aware_Vehicles_Var select 7) set [6, "0"]; 

					};

				showCommandingMenu "#USER:MENU_Aware_Vehicles_Var";				
				findDisplay 46 displayRemoveEventHandler ["MouseButtonUp", _thisEventHandler];
			}];
		

