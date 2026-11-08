
/*
	Author: Manel P.

	Description:
		
		Set the ROE for vehicles
	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			_ROE -rule to apply at group
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_list", "_type"];

private _number_selected = count _list;
private _group_leader = (_list select 0);
private _vehicle_command = ((assignedVehicles _group_leader) select 0);
private _time_to_wait = 180; // wait 3 min to form the column
private _timer = time;
private _default_speed = missionNamespace getVariable "MPG_Convoy_Speed";



if (Type_Selected == "VEHICLE") then
		
	{	

	
		//First stage : ONLY if not in column mode yet,  move all vehicles except command vehicle (_vehicle_command) close to the leader vehicle for column ready 
		
			if (MPG_Group_Column_Status == "NO_EXIST") then

			{
				
				{(assignedVehicles _x select 0) limitSpeed _default_speed}foreach _list;
				[_list, "SAFE"] call MPG_fnc_listSetAwareMode;


				//Sets command vehicle to Convoy mode & save the last 
		
				Group_Vehicle_Last_MovingMode_Table set [groupId _group_leader, Group_Vehicle_MovingMode_Table get groupId _Vehicle_command];
				Group_Vehicle_MovingMode_Table set [groupId _group_leader, "CONVOY"];
				
				
				{
					
					
					//move each vehicle first 20 m second 40 ......just back to the leader vehicle
					
					_rel_pos = _vehicle_command getRelpos [(_forEachIndex + 1) * 20, 180];
					
					[_x, "MOVE_TO_POSITION", grpNull, _rel_pos, _list,-1] spawn MPG_fnc_vehicleDoMoveInFormation;
					sleep 5;
			
			
				}
				
				foreach (_list - [_group_leader]);

			};

			_timer = time + _time_to_wait;

			//Wait for all the vehicles in position for convoy

			waituntil 
				{
					(time > _timer) ||
					(({((Group_Vehicle_MovingMode_Table get (groupId _x)) == "CONVOY")} count _list) == _number_selected)		
				
				};

			MPG_Group_Column setFormDir (getDir leader MPG_Group_Column);


		//Second stage :

		//if out of the while not for timer then move in column ==> if all units in position
	
			
		if (time < _timer) then 
				
			{
				
				//Only if is first time we make the column

				if (MPG_Group_Column_Status == "NO_EXIST") then
					{

				 		[_list, "SET_IN_COLUMN"] call MPG_fnc_listSetFormation;
					
						//Is needed actualize the selected list to the new groups  

						_list =	+Selected_Vehicle_list;
						sleep 1;
						["GUNNERS_FRONT"] call MPG_fnc_ColumnMoveCtrl; 
					
					};

				//delete markers each time move convoy is issued

				[MPG_Group_Column, "CONVOY"] call MPG_fnc_mapDeleteWaypointMarkers;

				MPG_Group_Column_Status = "READY";

				//Ones ready activate the otion in the menus to go, and wait until cancel or point inmap issued
				hint "entro wait";
				waitUntil {sleep 1; (missionNamespace getVariable "MPG_Convoy_Go" == true) || 
									(MPG_Group_Column_Status == "NO_EXIST") ||
									(MPG_Group_Column_Status == "STOP")};
				
				//if it is out of the waituntil by command issued to go ...the execute code ..if group NO_EXIST group column ==> desmantled convoy
				hint "salgo wait";
				if ((missionNamespace getVariable "MPG_Convoy_Go") == true) then
				
					{
					
					showCommandingMenu ""; //close the control menu for no interfering with the map zoom
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
							[_variable_vehicle, "CONVOY"] call MPG_fnc_mapDeleteWaypointMarkers; 
							[_variable_vehicle, "CONVOY"] spawn MPG_fnc_groupDeleteAllWaypoints;
						}
						onMapSingleClick "";
						removeMissionEventHandler ["Map", _thisEventHandler];
					}
					
					];
	
					//delete all waypoint & markers each time move onmap is issued			
						
					[MPG_Group_Column,"CONVOY"] call MPG_fnc_mapDeleteWaypointMarkers; 
					[MPG_Group_Column, "CONVOY"] spawn MPG_fnc_groupDeleteAllWaypoints;
					
					[_list, MPG_Group_Column] onMapSingleClick 

						{	

							_list = _this select 0;
							_Convoy_Group = _this select 1;
							private _max = 4;


							if (_shift) then

								{
									hint "Starting route"; //click + shift start planed route

									//Create the codeto be executed ones
									private _array_waypoints = waypoints MPG_Group_Column;
									_last_index = count _array_waypoints;
									_wp_temp =  _array_waypoints  select (_last_index - 1); 
										
									_wp_temp setWaypointStatements ["true", "deleteWaypoint [group this, currentWaypoint group this]; ['STOP'] Spawn MPG_fnc_columnMoveCtrl;"];

									(driver (vehicle leader MPG_Group_Column)) enableAI "PATH";

									MPG_Group_Column_Status = "MOVING";
						
									[_Convoy_Group, "CONTROL_COLUMN", grpNull, -1, _list,-1] spawn MPG_fnc_vehicleDoMoveInFormation;
											
									_out_map_with_route_vehicle = true;
									//make varibles public to access in the eventhandler
									missionNamespace setVariable ["out_ok_vehicle",_out_map_with_route_vehicle];
									
								}

							else 

								{
									hint "SHIFT + LEFT CLICK TO START";

									//look for number of waypoints to be limited for max

									//Only valid for a list of one element, no sense at this point wapoints for multiple selected.

									if (count (waypoints _Convoy_Group) <= _max) then 

									{

										(driver (vehicle leader MPG_Group_Column)) disableAI "PATH";
										
										[_Convoy_Group, _pos, "CONVOY"] call MPG_fnc_mapCreateWaypoints;
									};
									
									if (count (waypoints _Convoy_Group) == _max) then 

									{
										hint "Max waypoints, Starting route"; // start planed route max waypoints reached
			
										//aqui actualñizar que elultimo waypoint ejecute unstop ??!!

										
										_wp_temp = ((waypoints MPG_Group_Column) select (_max - 1)); 
										
										_wp_temp setWaypointStatements ["true", "deleteWaypoint [group this, currentWaypoint group this]; ['STOP'] Spawn MPG_fnc_columnMoveCtrl;"];


										(driver (vehicle leader MPG_Group_Column)) enableAI "PATH";

										MPG_Group_Column_Status = "MOVING";
						
										[_Convoy_Group, "CONTROL_COLUMN", grpNull, -1, _list,-1] spawn MPG_fnc_vehicleDoMoveInFormation;
										
										_out_map_with_route_vehicle = true;

										//make varibles public to access in the eventhandler

										missionNamespace setVariable ["out_ok_vehicle",_out_map_with_route_vehicle];
										
									};

								};
														
						};
					
					};


				
			}

		else 

			{

				commander _vehicle_command commandchat "Not able to form a column";
				Group_Vehicle_MovingMode_Table set [groupId _Vehicle_command, Group_Vehicle_Last_MovingMode_Table get groupId _Vehicle_command];

			}


	};
	




if (Type_Selected == "INFANTRY") then

	{
					//
	};		
				
			
