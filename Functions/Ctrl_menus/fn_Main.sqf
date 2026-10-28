

while {true} do 

	{
	
		private _RscMainTitleON = missionNamespace getVariable "MPG_RscMainTitleON";

		if (commandingMenu != "") then 

		{

			if (_RscMainTitleON == false) then 

				{

					("my_layer_1" call BIS_fnc_rscLayer) cutRsc ["RscMainTitle", "PLAIN"];
					missionNamespace setVariable ["MPG_RscMainTitleON", true];

					if (Type_Selected == "INFANTRY") then {call MPG_fnc_HUDShowSelected;};

					if (Type_Selected == "VEHICLE") then {call MPG_fnc_HUDShowSelectedVehicle;};

					if (Type_Selected == "SOLDIER") then {call MPG_fnc_HUDShowSelectedUnit;};

				};
			
		}

		else 

		{
			if (_RscMainTitleON == true) then 
				{
					"my_layer_1" cutRsc ["Default", "PLAIN"];
					missionNamespace setVariable ["MPG_RscMainTitleON", false];
				};
			
		};

		sleep 0.25;
		
	};


