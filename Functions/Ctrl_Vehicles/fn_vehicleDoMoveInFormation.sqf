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

params ["_group", "_type", "_Convoy_Group", "_pos", "_list", "_index"]; 

	
private _relpos = [];
private _vehicle = (assignedVehicles _group) select 0;
private _time_to_pos = 120; //2 min to get in position
	
switch (_type) do 

	{

		case "MOVE_TO_POSITION":
		
			{				
			
				Group_Vehicle_Last_MovingMode_Table set [groupId _group, Group_Vehicle_MovingMode_Table get groupId _group];
				Group_Vehicle_MovingMode_Table set [groupId _group, "MOVING_TO_POSITION"]; 
				
				private _leader_vehicle = Vehicle_Assigned_Table get groupId (_list select 0);

				_vehicle move _pos;
				private _timer = time + _time_to_pos;

				waituntil {time > _timer || unitReady _vehicle}; //check if destroyed or damaged MIRAR!!!
				
				//Set direction of vehicle same of vehicle in command 

				(driver _vehicle) setFormDir (getDir leader MPG_Group_Column);
			
				//if out of the while not for timer, then arrive set formation facing the vehicle in direction & change status

				if (time < _timer) then 
				
					{
						
						Group_Vehicle_MovingMode_Table set [groupId _group, "CONVOY"];
						leader _group commandchat "in postion for Convoy";
							
					}
				
				else 
				
					{

					 leader _group commandchat "Can t get postion for Convoy";
					 Group_Vehicle_MovingMode_Table set [groupId _group, Group_Vehicle_Last_MovingMode_Table get groupId _group];

					}; 
			};		


		case "CONTROL_COLUMN":
		
			{		
				private _last_vehicle = count _list;
				private _leader_vehicle = Vehicle_Assigned_Table get groupId (_list select 0);
				private _follow_vehicle = Vehicle_Assigned_Table get groupId (_list select (_last_vehicle - 1));
				private _speed = missionNamespace getVariable "MPG_Convoy_Speed";
				private _sep_distance = missionNamespace getVariable "MPG_Convoy_Separation";
	
				while {(MPG_Group_Column_Status != "NO_EXIST") && (MPG_Group_Column_Status != "STOP")} do

				{
					    
						//Get the cariable asigned to the column could be modify 
						
						//check if distance is separation desired * number of vehicle + margin
						
						//hint str (getPosASL (_leader_vehicle) vectorDistance getPosASL (_follow_vehicle));



							if	(((_leader_vehicle) distance2D (_follow_vehicle)) < (_sep_distance * _last_vehicle * 1.4)) then 
						
							{
			
								_leader_vehicle forceSpeed  (_speed / 3.6);//3.6 ==> km/h to m/s				
								hint "Reagrupados";	

							};
					
							if	((((_leader_vehicle) distance2D (_follow_vehicle) > (_sep_distance * _last_vehicle * 1.4))) &&
								(((_leader_vehicle) distance2D (_follow_vehicle)) < (_sep_distance * _last_vehicle * 1.8))) then 
						
							{
		
								_leader_vehicle forceSpeed  (_speed * 0.8 / 3.6);//3.6 ==> km/h to m/s
										
								{
								
									driver (Vehicle_Assigned_Table get groupId _x) doFollow _leader_vehicle		
							
								}foreach _list - [_list select 0];

								hint "lejos";

							};


							if	((((_leader_vehicle) distance2D (_follow_vehicle) > (_sep_distance * _last_vehicle * 1.8))) &&
								(((_leader_vehicle) distance2D (_follow_vehicle)) < (_sep_distance * _last_vehicle * 2.2))) then 
						
							{
	
								_leader_vehicle forceSpeed  (_speed * 0.5 / 3.6);//3.6 ==> km/h to m/s
										
								{
								
									driver (Vehicle_Assigned_Table get groupId _x) doFollow _leader_vehicle		
							
								}foreach _list - [_list select 0];

								hint " muy lejos";

							};


							if	(((_leader_vehicle) distance2D (_follow_vehicle)) > (_sep_distance * _last_vehicle * 2.2)) then 
						
							{
		
								_leader_vehicle forceSpeed  (_speed * 0.1 / 3.6);//3.6 ==> km/h to m/s
										
								{
								
									driver (Vehicle_Assigned_Table get groupId _x) doFollow _leader_vehicle		
							
								}foreach _list - [_list select 0];

								hint " super lejos";	

							};




					//Get the speed of the column just in case it has changed

					_Convoy_Group setSpeedMode "LIMITED";	
					_speed = missionNamespace getVariable "MPG_Convoy_Speed";

					//check also if the separation distance from the vehicles has changed
					
					_sep_distance = missionNamespace getVariable "MPG_Convoy_Separation";

					// gunners look at front ==> future select where to lookfor each unit & where
					// Also check what happend when in combat.......!!???

					["GUNNERS_FRONT"] call MPG_fnc_ColumnMoveCtrl; 

					sleep 4;

					//hint str _speed;

				};

			if (MPG_Group_Column_Status == "STOP") then 

				{
			
					onMapSingleClick "";
					missionNamespace setVariable ["MPG_Convoy_Go", false];

					//Call again to move but this time no create column and no move to position

					[Selected_Vehicle_list," "] spawn MPG_fnc_listDoMoveInFormation;

					player commandchat "salgo de control de columna STOP";
					

				};
				
			player commandchat "salgo de control de columna dismantle";

			//Release the gunners to look at direction just if not in stop mode
			
			if (MPG_Group_Column_Status != "STOP") then  {["GUNNERS_FREE_LOOK"] call MPG_fnc_ColumnMoveCtrl}; 

			missionNamespace setVariable ["MPG_Convoy_Go", false];

			};


		default { hint "No Action Description move vehicle " };

	};
