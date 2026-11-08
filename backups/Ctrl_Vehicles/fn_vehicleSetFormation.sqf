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

params ["_group", "_type", "_Convoy_Group",  "_sep_distance", "_pos", "_speed", "_list", "_index"]; 

	
private _relpos = [];
private _vehicle = (assignedVehicles _group) select 0;
private _time_to_pos = 120; //2 min to get in position
private _vehicle_to_assign =  Vehicle_Assigned_Table  get groupId _group; 

	

//if (_speed > 0) then {(_vehicle) forceSpeed _speed}; //is speed is positive, adjust speed of vehicle
	

switch (_type) do 

	{


		case "SET_IN_COLUMN":
		
			{		


			_vehicle forceSpeed _speed;
			_vehicle setConvoySeparation _sep_distance;
			_vehicle setBehaviour "CARELESS";
			private _temp_GroupID = groupId _group;
			(units _group) joinSilent _Convoy_Group;
			waituntil {(count units _group) == 0;};
			deleteGroup _group;
			_temp_group = createGroup [PlayerSide, false];
			waituntil {_temp_group != grpNull};
			_temp_group setGroupId [_temp_GroupID];

			_temp_group addVehicle _vehicle;

			Selected_Vehicle_list set [_index, _temp_group];

			};


		case "SET_OUT_COLUMN":
		
			{		

			private _temp_commander = assignedCommander _vehicle_to_assign;
			private _temp_driver = assignedDriver _vehicle_to_assign;
			private _temp_gunner = assignedGunner _vehicle_to_assign;

			
			if ((!isNull _temp_commander) && 
				((MPG_Group_Crew_Mode_Table get (groupId (assignedGroup _vehicle_to_assign))) select 0 == false)) then 
			
			{
			[_temp_commander] joinSilent _group;
			waituntil {sleep 0.5; (_group == group _temp_commander)};
			_temp_commander assignAsCommander _vehicle_to_assign;
			};

			if ((!isNull _temp_gunner)  && 
				((MPG_Group_Crew_Mode_Table get (groupId (assignedGroup _vehicle_to_assign))) select 1 == false)) then 
			
			{
			[_temp_gunner] joinSilent _group; 
			waituntil {sleep 0.5; (_group == group _temp_gunner)};
			_temp_gunner assignAsGunner _vehicle_to_assign;
			};

			if (!isNull _temp_driver) then 
			{
			[_temp_driver] joinSilent _group;
			waituntil {sleep 0.5; (_group == group _temp_driver)};
			_temp_driver assignAsDriver _vehicle_to_assign;
			//prevent driver to disembark
			[_temp_driver] AllowGetIn true;
			[_temp_driver] orderGetIn true;
			}
			else {hint "ERROR:No driver found"};


			_group AddGroupIcon ["b_motor_inf",[0,0]];
			_group SetGroupIconParams [[1,1,1,1], Groups_Vehicle_Names_Table get groupId _group, 1, true];

			Group_Vehicle_Last_MovingMode_Table set [groupId _group, "AT_WILL"];
			Group_Vehicle_MovingMode_Table set [groupId _group, "AT_WILL"];
		
			};



		case "NORMAL_SEP":
			
			{
				_vehicle_to_assign setConvoySeparation _sep_distance;
			};	

		case "OPEN_SEP":
			
			{	
				_vehicle_to_assign setConvoySeparation _sep_distance * 2;
			};	

		default { hint "No Action Description Vehicle Formations " };

	};