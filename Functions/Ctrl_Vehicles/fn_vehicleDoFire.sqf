/*
	Author: Manel P.

	Description:
		
		Make the Vehicle move to a position

	Parameter(s):
		0: can be one of:
			Vehicle - Vehicle who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_crew_group", "_type", "_fire_mode", "_type_target"]; 

private _vehicle = Vehicle_Assigned_Table get (groupId _crew_group);
private _gunner = gunner _vehicle;
private _target = cursorObject;

if  (_type_target == "SELECTED_TAGET") then {_target = cursorObject};

if  (_type_target == "LAST_TAGET") then {_target = Groups_Vehicle_Last_Target_Table get (groupId _crew_group)};

missionNamespace setVariable ["_PUB_gunner", _gunner];
missionNamespace setVariable ["_PUB_target", position _target];

//hint str (nearestTerrainObjects [position _target, [], 0]);

//_building = (nearestTerrainObjects [position _target, [], 0]);



switch (_type) do 

	{

	case "MAIN_GUN":
			
		{	

			private _VehicleID = Groups_Vehicle_Names_Table get (groupId _crew_group);		
			private _maingun_exist = MPG_Vehicles_MainGun_Table get _VehicleID;
			private _id = 0;
			//Check if there is some object in the cursor && main_gun exist

			if ((_maingun_exist) && (!isNull _target)) then 

			{

				//Select the main gun of the turret

				private _weapon = (_vehicle weaponsTurret [0]) select 0;

				if ((Groups_Vehicle_Task_Table get (groupId _crew_group) != "SHOOTING_MAINGUN") &&
				((weaponState [_vehicle, [0], _weapon]) select 5) == 0) then 
			
				{

					player directSay "SentConfirmAttack";

					//Check if firing to a buiding of the terrain not add with editor	
				
					_building = (nearestTerrainObjects [position _target, [], 0]);

					if (!isNil {_building select 0}) then 

						{

							_id = addMissionEventHandler ["BuildingChanged",
								{
									params ["_from", "_to", "_isRuin"];
									hint str _thisEventHandler;
									if _isRuin then 
									{
										hint str "edificio destruido";
										(missionNamespace getVariable "_PUB_gunner") dowatch (missionNamespace getVariable "_PUB_target");
									};

									removeMissionEventHandler ["BuildingChanged", _thisEventHandler];

								}];

							leader _crew_group commandchat "Firing that building";
	
						}

					else {leader _crew_group commandchat "Firing that target"};


					Groups_Vehicle_Last_Task_Table set [groupId _crew_group, Groups_Vehicle_Task_Table get groupId _crew_group];
					Groups_Vehicle_Last_Target_Table set [groupId _crew_group, _target];
					Groups_Vehicle_Task_Table set [groupId _crew_group,"SHOOTING_MAINGUN"];
				

					private _fire_modes_array = (getArray (configFile >> "CfgWeapons" >> _weapon >> "modes"));
					private _fire_mode_selected = "";

					//hint str _fire_modes_array;
				
					if  ( _fire_mode == "AUTO") then {_fire_mode_selected = (weaponState [_vehicle, [0], _weapon]) select 2};
					
					//_fire_mode_selected = _fire_modes_array select 1;

					//hint str _fire_mode_selected;

					//Make to realign if the target is already doing dowatch
				
					//_gunner doWatch ObjNull;
					//sleep 0.1;
					_gunner doWatch _target;
					
						
					private _current_aim = 0;
					private _precision = 0.001;
					private _max_time_to_dowatch = 5;
					private _max_time_to_aim = 2;

					private _timer = time + _max_time_to_dowatch;


					waituntil {sleep 0.1;(_vehicle aimedAtTarget [_target, _weapon] > 0.5) || (time > _timer)};

						if (_timer > time) then 

							{

								_timer = time + _max_time_to_aim;

								sleep 0.5;

								waituntil {_current_aim = (_vehicle aimedAtTarget [_target, _weapon]); sleep 0.25;
									 (abs ((_vehicle aimedAtTarget [_target, _weapon]) - _current_aim) <= _precision) || (time > _timer)};

								if (_timer > time) then 

								{	

									if (_current_aim > 0.65) then 
								
									{
									
								
										//_fire_mode_selected = (weaponState [_vehicle, [0], _weapon]) select 2;
										 sleep 0.1;
										_gunner forceWeaponFire [_weapon, _fire_mode_selected];
								
									}
						
									else {leader _crew_group commandchat "We have no enought precision to shoot"};
			
									//hint str _current_aim;
								}

								else {leader _crew_group commandchat "time exceed: We cant get precision aim to target"};
				
							}

						else {leader _crew_group commandchat "time exceed: We cant align to target"};

					sleep 2;
					//hint str (alive _target);
					if (!(alive _target)) then {_gunner doWatch (position _target)};

					Groups_Vehicle_Task_Table set [groupId _crew_group, Groups_Vehicle_Last_Task_Table get groupId _crew_group];
					
				}

				else 
				
				{

					if (((weaponState [_vehicle, [0], _weapon]) select 5) != 0) then {leader _crew_group commandchat "Reloading Ammo!"};
					sleep 0.2;
					if (Groups_Vehicle_Task_Table get (groupId _crew_group) == "SHOOTING_MAINGUN") then {leader _crew_group commandchat "Already doing Fire"};
					
				};

			}

			else {leader _crew_group commandchat "NO target identified"};

		//hint str _id;

		};


	case "FORGET":
			
		{

			_gunner doWatch ObjNull;
			leader _crew_group commandchat "Ok, ready for new targets";

		};

	default {hint "No Action Description for do fire"};

	};









		