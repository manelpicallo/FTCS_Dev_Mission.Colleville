
/*
	Author: Manel P.

	Description:
		
		Make the group to Stop 

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			_type-  type of movement
			_distance - distance to move in meters
			_direction - direction to move in meters
			_relativetodirection - direction from witch is the _direction relative  == used to be PLATOON_DIR


	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_group_vehicle", "_type", "_distance", "_position"]; 

	
private _relpos = [];
private _vehicle = (assignedVehicles _group_vehicle) select 0;
private _aware_time = 5;  //time to wait is unit not ready
private _advance_speed = 10; //speed for adjust the vehicle speed
//private _advance_distance = 5; //distance from the vehicle for the troops

switch (_type) do 

	{

		case "START":
			
			{
				
				[_group_vehicle, "CONTINUE", [0,0],0] call MPG_fnc_vehicleDoMove;
				
				//sets de vehicle wich the group is moving with & the default mode to advance
				
				(Groups_With_Vehicle_Table get groupid _group) set [0, _group_vehicle];
				(Groups_With_Vehicle_Table get groupid _group) set [1, "NORMAL"];

				_group setFormation "STAG COLUMN";
				
				//Sets  ROE, aware % speed mode by default
				
				[_group, "FIRE_IF_FIRED_UPON"] call MPG_fnc_groupSetROE;
				[_group, "FOLLOWING_VEHICLE_NORMAL"] call MPG_fnc_groupSetAwareMode;
				[_group, "NORMAL", 1.2] call MPG_fnc_groupSetSpeed;

				//Check type vehicle is being followed is tracked and ajust distance from troops in +5m
				
				if (_vehicle isKindof "tank") then 
					{
						_distance =	_distance + 5;				
					};

				//Sets the tables  of movingmode & lastmoving mode of the group && vehicle
	
				Groups_MovingMode_Table set [groupId _group,"FOLLOWING_VEHICLE"];
				//group last moving table not implemented ==> CARE CARE 

				Group_Vehicle_Last_MovingMode_Table set [groupId _group_vehicle, Group_Vehicle_MovingMode_Table get groupId _group_vehicle];
				Group_Vehicle_MovingMode_Table set [groupId _group_vehicle,"COVERING_INFANTRY"];

				//Main loop

				while {(((Groups_MovingMode_Table  get groupId _group) == "FOLLOWING_VEHICLE") &&
				((Group_Vehicle_MovingMode_Table get groupId _group_vehicle) == "COVERING_INFANTRY")) ||
				((Group_Vehicle_MovingMode_Table get groupId _group_vehicle) == "HALT")||
				((Group_Vehicle_MovingMode_Table get groupId _group_vehicle) == "STOP")} do



				//&& (lifeState leader _group != "DEAD" || lifeState leader _group != "INCAPACITATED") 
				// ==> out of the while loop cheking wath to do if INCAPACITATED, if dead is changed for other member

					{ 
				
  					if (unitReady leader _group) then {{_x enableAI "RADIOPROTOCOL"} foreach units _group};//restart AI comments

					//Chech if mode of advance has changed and set new parameters
					
					if ((Groups_With_Vehicle_Table get groupid _group) select 1 == "SLOW") then 
					{

						[_group, "FOLLOWING_VEHICLE_SLOW"] call MPG_fnc_groupSetAwareMode;
						[_group, "LIMITED", 1] call MPG_fnc_groupSetSpeed;			
						_advance_speed = 5;
						
					};

					if ((Groups_With_Vehicle_Table get groupid _group) select 1 == "NORMAL") then 
					
					{
						[_group, "FOLLOWING_VEHICLE_NORMAL"] call MPG_fnc_groupSetAwareMode;
						[_group, "NORMAL", 1.2] call MPG_fnc_groupSetSpeed;
						 _advance_speed = 8;
						 
					};
					

					
					if ((Groups_With_Vehicle_Table get groupid _group) select 1 == "FAST") then 
					
					{
						[_group, "FOLLOWING_VEHICLE_FAST"] call MPG_fnc_groupSetAwareMode;
						[_group, "FULL", 1] call MPG_fnc_groupSetSpeed;
						 _advance_speed = 11;
						 
					};


					_vehicle limitSpeed _advance_speed; //speed advance for vehicle = troops 
					
					//if in not in HALT nither in STOP then move 
					
					if (((Group_Vehicle_MovingMode_Table get groupId _group_vehicle) != "HALT") &&
					   ((Group_Vehicle_MovingMode_Table get groupId _group_vehicle) != "STOP")) then
 						
						{
						
						//check if vehicle is rear/left/right or front so  slow or accelerate ==> TOO SIMPLE IMPROVE NEEDED NOT WORKING AT THE MOMENT

						if (_position == 0) then 

							{
								if ((_vehicle distance leader _group) > (_distance * 2 )) then {_vehicle limitSpeed _advance_speed + 1};

								if ((_vehicle distance leader _group) > (_distance * 3 )) then {_vehicle limitSpeed _advance_speed + 3};
				
							}

						else 	
			
							{
								if ((_vehicle distance leader _group) > (_distance * 1.5)) then {
									driver _vehicle enableAI"PATH"; _vehicle limitSpeed _advance_speed / 1.1};

								if ((_vehicle distance leader _group) > (_distance * 2 )) then {
									driver _vehicle enableAI"PATH"; _vehicle limitSpeed _advance_speed / 1.3};

								if ((_vehicle distance leader _group) > (_distance * 2.5 )) then {
									driver _vehicle enableAI"PATH" ; _vehicle limitSpeed _advance_speed / 1.5};

								if ((_vehicle distance leader _group) > (_distance * 3 )) then {driver _vehicle disableAI "PATH";}; 
					
							};
				
								

							_relpos =  _vehicle getRelPos [_distance, _position];
				
							_timer = time + _aware_time;

							waituntil {time > _timer || unitReady leader _group || lifeState leader _group == "DEAD" || lifeState leader _group == "INCAPACITATED"};
							 {_x disableAI "RADIOPROTOCOL"} foreach units _group;//do the movecommand silent
							_group move (_relpos);
							units _group doFollow leader _group;	

						}

						else {sleep 0.5};		
					
					};	

			
					//PARAMETROS DE SALIDA SI NO SE FUERZA STOP==>POR DEFINIR
					
					
	
			};


		case "STOP":
			
			{
				
				//change status only of the group the vehicle only if it is not followed for any other group
				// in case is only group adjust speed & remove waypoint of the vehicle
				
				{_x enableAI "RADIOPROTOCOL"} foreach units _group;//restart AI comments
				
				private _count = 0; 	
				
				{if ((_y select 0) == ((Groups_With_Vehicle_Table get groupid _group) select 0) ) then {_count = _count + 1} } foreach Groups_With_Vehicle_Table;

				if (_count == 1) then
				
				{
					
					_vehicle  limitSpeed -20;
					
					[((Groups_With_Vehicle_Table get groupid _group) select 0), "VEHICLE"] spawn MPG_fnc_groupDeleteAllWaypoints;
							
				};	

				
				
				//remove speed limits of the group 				

				{_x limitSpeed -20; _x setSpeedMode "NORMAL";} foreach units _group;

				//Change movemode of the group moving with the  vehicle

				Groups_MovingMode_Table set [groupId _group,"AT_WILL"]; //group dostop !!????
				(Groups_With_Vehicle_Table get groupid _group) set [0, grpNull];			

			
			};	
		
		default { hint "No Action Description" };

	};
					