/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_mode", "_speed", "_distance", "_direction", "_relativetodirection"]; 





//ACTION FOR INFANTRY**********************************


	if (Type_Selected == "INFANTRY") then

	{
		
		switch (_mode) do 

		{


			case "CONTINUE":
			
				{
					{[_x, "CONTINUE", _distance, _direction, _relativetodirection] call MPG_fnc_groupDoMove;} foreach _list;
				};
			
			
			case "MOVE_RELATIVE":
			
				{
					{
						
						private _group_leader = ((Groups_Rel_Position_Table get (groupId _x)) select 2);

						//Check if the group leader of the formation for the present group is in the selection ==> if true ==> not move because move with the leader
						
						if ((_list find _group_leader) == -1) then 
						
							{

								[_x, "MOVE_RELATIVE", _distance, _direction, _relativetodirection] spawn MPG_fnc_groupDoMove;
					
						
							};	
						
					} foreach _list;
				
				};


			case "MOVE_THERE":

				{			
					
					{
						
						private _group_leader = ((Groups_Rel_Position_Table get (groupId _x)) select 2);

						//Check if the group leader of the formation for the present group is in the selection ==> if true ==> not move because move with the leader
						
						if ((_list find _group_leader) == -1) then 
						
							{

								[_x, "MOVE_THERE", _distance, _direction, _relativetodirection] spawn MPG_fnc_groupDoMove;
								
						
							};	
						
					} foreach _list;
					
				};


			case "MOVE_POINTING_DIR":
			
				{

					{
						
						private _group_leader = ((Groups_Rel_Position_Table get (groupId _x)) select 2);

						//Check if the group leader of the formation for the present group is in the selection ==> if true ==> not move because move with the leader
						
						if ((_list find _group_leader) == -1) then 
						
							{

								[_x, "MOVE_POINTING_DIR", _distance, _direction, _relativetodirection] spawn MPG_fnc_groupDoMove;
								
						
							};	
						
					} foreach _list;	
					
				};
		
			case "ON_MAP":
			
				{
						
					showCommandingMenu ""; //close the control menu for no interfering with the map zoom
					openMap true;

					//make varibles public to access in the eventhandler

					missionNamespace setVariable ["group_infantry_onmap",_list select 0];

					//Create a eventhandler to remove everything if player close the map withou defining route

					addMissionEventHandler 
					[

					"Map",
					{
						//only delete waypoints & markers if not route selected
						if (!out_ok_inf) then 
						{
							_variable_inf = (missionNamespace getVariable "group_infantry_onmap");
							[_variable_inf, "INFANTRY"] call MPG_fnc_mapDeleteWaypointMarkers; 
							[_variable_inf, "INFANTRY"] spawn MPG_fnc_groupDeleteAllWaypoints;
						}
						onMapSingleClick "";
						removeMissionEventHandler ["Map", _thisEventHandler];
					}
					
					];
	
					//delete all waypoint & markers each time move onmap is issued

					{
						[_x, "INFANTRY"] call MPG_fnc_mapDeleteWaypointMarkers; [_x, "INFANTRY"] spawn MPG_fnc_groupDeleteAllWaypoints;
					
					}foreach _list;
	 				


					[_list, _mode, _speed] onMapSingleClick 

						{	
							_list = _this select 0;
							_mode = _this select 1;
							_speed = _this select 2;
							private _max = 4;


							if (_shift) then

								{
									hint "Starting route"; //click + shift start planed route
									{[_x, _mode, _pos, _speed] call MPG_fnc_groupDoMove;} foreach _list;
									_out_map_with_route_inf = true;
									//make variables public to access in the eventhandler
									missionNamespace setVariable ["out_ok_inf",_out_map_with_route_inf];
									
								}

							else 

								{
									hint "SHIFT + LEFT CLICK TO START";

									//look for number of waypoints to be limited for max

									//Only valid for a list of one element, no sense at this point wapoints for multiple selected.

									if (count (waypoints (_list select 0)) <= _max) then 

									{
										{(leader _x ) disableAI "PATH", 
										[_x, _pos, "INFANTRY"] call MPG_fnc_mapCreateWaypoints;} foreach _list;
									};
									
									if (count (waypoints (_list select 0)) == _max) then 

									{
										hint "Max waypoints, Starting route"; // start planed route max waypoints reached
										{[_x, _mode, _pos, _speed] call MPG_fnc_groupDoMove;} foreach _list;
										_out_map_with_route_inf = true;
										//make varibles public to access in the eventhandler
										missionNamespace setVariable ["out_ok_inf",_out_map_with_route_inf];
										
									};

								};
														
						};

				};
		

			default { hint "No Action Description domove list & vehicle " };

		};

	};


//ACTION FOR VEHICLES**********************************

	if (Type_Selected == "VEHICLE") then

	{
			
		switch (_mode) do 

		{

		
			case "ON_MAP":

				{
			
						
					showCommandingMenu ""; //close the control menu for no interferig¡ng with the map zoom
					openMap true;

					//make varibles public to access in the eventhandler

					missionNamespace setVariable ["group_onmap_vehicle",_list select 0];

					//Create a eventhandler to remove everything if player close the map withou defining route

					addMissionEventHandler 
					[

					"Map",
					{
						//only delete waypoints & markers if not route selected
						if (!out_ok_vehicle) then 
						{
							_variable_vehicle = (missionNamespace getVariable "group_onmap_vehicle");
							[_variable_vehicle, "VEHICLE"] call MPG_fnc_mapDeleteWaypointMarkers; 
							[_variable_vehicle, "VEHICLE"] spawn MPG_fnc_groupDeleteAllWaypoints;
						}
						onMapSingleClick "";
						removeMissionEventHandler ["Map", _thisEventHandler];
					}
					
					];
	
					//delete all waypoint & markers each time move onmap is issued

					{
						
						[_x,"VEHICLE"]call MPG_fnc_mapDeleteWaypointMarkers; [_x, "VEHICLE"] spawn MPG_fnc_groupDeleteAllWaypoints;
					
					}foreach _list;
	 				


					[_list, _mode, _speed] onMapSingleClick 

						{	
							_list = _this select 0;
							_mode = _this select 1;
							_speed = _this select 2;
							private _max = 4;


							if (_shift) then

								{
									hint "Starting route"; //click + shift start planed route
									{[_x, _mode, _pos, _speed] call MPG_fnc_vehicleDoMove;} foreach _list;
									_out_map_with_route_vehicle = true;
									//make varibles public to access in the eventhandler
									missionNamespace setVariable ["out_ok_vehicle",_out_map_with_route_vehicle];
									
								}

							else 

								{
									hint "SHIFT + LEFT CLICK TO START";

									//look for number of waypoints to be limited for max

									//Only valid for a list of one element, no sense at this point wapoints for multiple selected.

									if (count (waypoints (_list select 0)) <= _max) then 

									{
										{(driver (assignedVehicles _x select 0)) disableAI "PATH", 
										[_x, _pos,"VEHICLE"] call MPG_fnc_mapCreateWaypoints;} foreach _list;
									};
									
									if (count (waypoints (_list select 0)) == _max) then 

									{
										hint "Max waypoints, Starting route"; // start planed route max waypoints reached
										{[_x, _mode, _pos, _speed] call MPG_fnc_vehicleDoMove;} foreach _list;
										_out_map_with_route_vehicle = true;
										//make varibles public to access in the eventhandler
										missionNamespace setVariable ["out_ok_vehicle",_out_map_with_route_vehicle];
										
									};

								};
														
						};

				};

			case "MOVE_THERE":

				{
				
				{[_x, "MOVE_THERE", -1, -1]call MPG_fnc_vehicleDoMove;} foreach _list;
	
				};



			case "CONTINUE":

				{
				
				{[_x, "CONTINUE", -1, -1] call MPG_fnc_vehicleDoMove;} foreach _list;
	
				};

			default { hint "No Action Description domove list & vehicle " };

		};

	};


//ACTION FOR SOLDIERS**********************************


	if (Type_Selected == "SOLDIER") then

	{

		switch (_mode) do 

		{

		
			case "WITH_ME":
		
			{
			
				{[_x, "WITH_ME", -1, -1] spawn MPG_fnc_unitsDoMove;} foreach _list;

			};

			


			case "RETURN_SQUAD":
		
			{
			
				{[_x, "RETURN_SQUAD", -1, -1] spawn MPG_fnc_unitsDoMove;} foreach _list;

			};

			
			default { hint "No Action Description domove list & vehicle  & soldier" };
		
		};


	};

		
			

				
		
		