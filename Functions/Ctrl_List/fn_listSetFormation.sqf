
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_type"];



private _number_selected = count _list;
private _group_leader = (_list select 0);
private _vehicle_command = ((assignedVehicles _group_leader) select 0);
private _default_speed = missionNamespace getVariable "MPG_Convoy_Speed";
private _sep_distance = missionNamespace getVariable "MPG_Convoy_Separation";


	if (Type_Selected == "INFANTRY") then

	{
		{[_x, _type] call MPG_fnc_groupSetFormations;} foreach _list;
	};


	if (Type_Selected == "VEHICLE") then

	{



		switch (_type) do 

			{

				case "SET_IN_COLUMN":

				{

					//create a convoy for all the vehicles and prepare the parameters for convoy no crazie

					// leader group first group to joint => apart 
				
					useAISteeringComponent true;
					_vehicle_command setBehaviour "CARELESS";
					_vehicle_command forceSpeed _default_speed;
					_vehicle_command setConvoySeparation _sep_distance;

					//create the column group & keep the old group ensure not deleted

					_Convoy_Group = createGroup [PlayerSide, true];

					_Convoy_Group AddGroupIcon ["b_motor_inf",[0,0]];
					_Convoy_Group SetGroupIconParams [[1,1,1,1], "Column", 1, true];

					/*
					ORBAT_Group_Vehicle_0 synchronizeObjectsRemove [commander ((assignedVehicles Group_Vehicle_0) select 0)];
					ORBAT_Group_Vehicle_1 synchronizeObjectsRemove [commander ((assignedVehicles Group_Vehicle_1) select 0)];
					ORBAT_Group_Vehicle_2 synchronizeObjectsRemove [commander ((assignedVehicles Group_Vehicle_2) select 0)];
					ORBAT_Group_Vehicle_3 synchronizeObjectsRemove [commander ((assignedVehicles Group_Vehicle_3) select 0)];
					*/

					private _temp_GroupID = groupId _group_leader;
					(units _group_leader) joinSilent _Convoy_Group;
					
					waituntil {((count units _group_leader) == 0)};
					
					_temp_group = createGroup [PlayerSide, false];
					waituntil {_temp_group != grpNull};
					_temp_group setGroupId [_temp_GroupID];

					_temp_group addVehicle _vehicle_command;

					Selected_Vehicle_list set [0, _temp_group];
					_list set [0, _temp_group];
				

					{	
						 
						[_x, "SET_IN_COLUMN", _Convoy_Group, _sep_distance, -1, -1, [], (_foreachindex + 1 )] call MPG_fnc_vehicleSetFormation; 
					
					}foreach (_list - [_temp_group]);

					MPG_Group_Column = _Convoy_Group; 

					//sleep 2;

					_Convoy_Group  setformation "COLUMN";

				};


				case "SET_OUT_COLUMN":

					{

					//Remove the onclik code in case it is still waiting to issue the command

					onMapSingleClick "";

					{	
						 
						[_x, "SET_OUT_COLUMN", MPG_Group_Column, 15, -1, -1, [], (_foreachindex + 1 )] call MPG_fnc_vehicleSetFormation; 
					
					}foreach (_list);

					MPG_Group_Column = objNull;
					MPG_Group_Column_Status = "NO_EXIST";

					//Reasign the new groups to the original variables fot the selects etc etc....
					//I need to check the order......

					 Group_Vehicle_0 = (Selected_Vehicle_list select 0);
					 Group_Vehicle_1 = (Selected_Vehicle_list select 1);
					 Group_Vehicle_2 = (Selected_Vehicle_list select 2);
					 Group_Vehicle_3 = (Selected_Vehicle_list select 3);

					 //sync the ORBAT logics modules to again to the vehicle groups

					/*ORBAT_Group_Vehicle_0 synchronizeObjectsAdd [commander ((assignedVehicles Group_Vehicle_0) select 0)];
					ORBAT_Group_Vehicle_1 synchronizeObjectsAdd [commander ((assignedVehicles Group_Vehicle_1) select 0)];
					ORBAT_Group_Vehicle_2 synchronizeObjectsAdd [commander ((assignedVehicles Group_Vehicle_2) select 0)];
					ORBAT_Group_Vehicle_3 synchronizeObjectsAdd [commander ((assignedVehicles Group_Vehicle_3) select 0)];
					*/


					};



			case "NORMAL_SEP":
			
				{
			
					{	
						 
						[_x, "NORMAL_SEP", grpNull, _sep_distance, -1, -1, [], -1] call MPG_fnc_vehicleSetFormation; 
					
					}foreach _list;
		
				};	

			case "OPEN_SEP":
			
				{
			
					{	
						 
						[_x, "OPEN_SEP", grpNull, _sep_distance, -1, -1, [], -1] call MPG_fnc_vehicleSetFormation; 
					
					}foreach _list;
		
				};	

			default { hint "No Action Description" };

		};

	};
					
	
			

		
	

	
