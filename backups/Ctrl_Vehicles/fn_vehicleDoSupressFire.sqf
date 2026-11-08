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

params ["_crew_group", "_type"]; 

private _vehicle = (assignedVehicles _crew_group) select 0;
private _target = cursorObject;


//Internal function****************************

INT_fnc_InitSupressFire = 

{

	Groups_Vehicle_Last_Task_Table set [groupId _crew_group, Groups_Vehicle_Task_Table get groupId _crew_group];
	Groups_Vehicle_Last_Target_Table set [groupId _crew_group, _target];
	Groups_Vehicle_Task_Table set [groupId _crew_group,"SUPRESSING"];

};


//Select the secondari turret in the main turret
private _weapon = (_vehicle weaponsTurret [0]) select 1;
private _muzzle = (weaponState [_vehicle, [0], _weapon]) select 1;
private _fire_mode = (weaponState [_vehicle, [0], _weapon]) select 2;

//Select the unit in the secondari turret 
private _unit_in_turret = (_vehicle turretUnit [0]);

private _timer = time;
private _max_time_to_dowatch = 10;

private _current_aim = 0;
private _precision = 0.05;

private _fire_modes_array = (getArray (configFile >> "CfgWeapons" >> _weapon >> "modes"));
private _fire_mode_auto = (weaponState [_vehicle, [0], _weapon]) select 2;


	switch (_type) do 

	{
		
		player directSay "SentConfirmAttack";
		

		case "SHORT":
		
		{

			call INT_fnc_InitSupressFire;
					
			_i = 0;
			for [{_i = 0}, {_i < 40}, {_i = _i + 1}] do 
	
				{
					
					_unit_in_turret doWatch _target;

					_timer = time + _max_time_to_dowatch;

					//Wait until looking to target
					
					waituntil {sleep 0.1;(_vehicle aimedAtTarget [_target, _weapon] > 0.5) || (time > _timer)};

					if (_timer > time) then 

					{
						
						
						waituntil {_current_aim = (_vehicle aimedAtTarget [_target, _weapon]); abs ((_vehicle aimedAtTarget [_target, _weapon]) - _current_aim) <= _precision};
						
						//_current_aim = (_vehicle aimedAtTarget [_target, _weapon]);

						if (_current_aim > 0.65) then {_unit_in_turret forceWeaponFire [_weapon, _fire_mode_auto]}
						
						else {leader _crew_group commandchat "We have no enought precision to shot"};
			
						hint str _current_aim;
				
					
					}

					else {leader _crew_group commandchat "We cant align to target"};
			
				};	

				

			Groups_Vehicle_Task_Table set [groupId _crew_group, Groups_Vehicle_Last_Task_Table get groupId _crew_group];	

		};





		case "MEDIUM":
		
		{

			call INT_fnc_InitSupressFire;

			for [{_z = 0}, {_z < 4}, {_z = _z + 1}] do 
	
			{
				if ((Groups_Vehicle_Task_Table get groupId _crew_group) != "SUPRESSING")	then {break};
				
				
				_i = 0;
				for [{_i = 0}, {_i < 30}, {_i = _i + 1}] do 
	
				{
					
					_unit_in_turret doWatch _target;

					_timer = time + _max_time_to_dowatch;

					//Wait until looking to target
					
					waituntil {sleep 0.1;(_vehicle aimedAtTarget [_target, _weapon] > 0.5) || (time > _timer)};

					if (_timer > time) then 

					{
						
						
						waituntil {_current_aim = (_vehicle aimedAtTarget [_target, _weapon]); abs ((_vehicle aimedAtTarget [_target, _weapon]) - _current_aim) <= _precision};
						
						//_current_aim = (_vehicle aimedAtTarget [_target, _weapon]);

						if (_current_aim > 0.65) then {_unit_in_turret forceWeaponFire [_weapon, _fire_mode_auto]}
						
						else {leader _crew_group commandchat "We have no enought precision to shot"};
			
						hint str _current_aim;
				
					
					}

					else {leader _crew_group commandchat "We cant align to target"};
			
				};	

				sleep 4;
			};	

			Groups_Vehicle_Task_Table set [groupId _crew_group, Groups_Vehicle_Last_Task_Table get groupId _crew_group];
			
		
		};




		case "LONG":
		
		{

			call INT_fnc_InitSupressFire;
		
			for [{_z = 0}, {_z < 15}, {_z = _z + 1}] do 
	
				{
					if ((Groups_Vehicle_Task_Table get groupId _crew_group) != "SUPRESSING")	then {break};
					_i = 0;
					for [{_i = 0}, {_i < 10}, {_i = _i + 1}] do 
	
						{

						_unit_in_turret doWatch _target;

						_timer = time + _max_time_to_dowatch;

						//Wait until looking to target
					
						waituntil {sleep 0.1;(_vehicle aimedAtTarget [_target, _weapon] > 0.5) || (time > _timer)};

						if (_timer > time) then 

						{
						
						
						waituntil {_current_aim = (_vehicle aimedAtTarget [_target, _weapon]); abs ((_vehicle aimedAtTarget [_target, _weapon]) - _current_aim) <= _precision};
						
						//_current_aim = (_vehicle aimedAtTarget [_target, _weapon]);

						if (_current_aim > 0.65) then {_unit_in_turret forceWeaponFire [_weapon, _fire_mode_auto]}
						
						else {leader _crew_group commandchat "We have no enought precision to shot"};
			
						hint str _current_aim;
				
						}

						else {leader _crew_group commandchat "We cant align to target"};
						
						};

						sleep 3;
				};	

			Groups_Vehicle_Task_Table set [groupId _crew_group, Groups_Vehicle_Last_Task_Table get groupId _crew_group];	

		};

		case "STOP":
		
		{
			if ((Groups_Vehicle_Last_Task_Table get groupId _crew_group) != "SUPRESSING") then 

				{
					 Groups_Vehicle_Task_Table set [groupId _crew_group, Groups_Vehicle_Last_Task_Table get groupId _crew_group];	
				};

			if ((Groups_Vehicle_Last_Task_Table get groupId _crew_group) == "SUPRESSING") then 

				{
					 Groups_Vehicle_Task_Table set [groupId _crew_group, "AT_WILL"];	
				};
		};
		
		default { hint "No supress type" };

	};

hint str damage _target;					