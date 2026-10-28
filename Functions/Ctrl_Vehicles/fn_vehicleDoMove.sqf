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

params ["_group", "_type", "_pos", "_speed"]; 

	
private _relpos = [];
private _vehicle = (assignedVehicles _group) select 0;
private _time_to_pos = 120; //2 min to get in position
	

if (_speed > 0) then {(_vehicle ) forceSpeed _speed}; //is speed is positive, adjust speed of vehicle
	

switch (_type) do 

	{

		case "MOVE_THERE":
			
			{
				(driver _vehicle) enableAI "PATH";	
				_relpos = screenToWorld [0.5,0.5];
				_group move (_relpos);		
			
			};

		case "ON_MAP":
			
			{	
				(driver _vehicle) enableAI "PATH";								
			};

		case "CONTINUE":
		
			{				
				(driver _vehicle) enableAI "PATH";	
				Group_Vehicle_MovingMode_Table set [groupId _group, Group_Vehicle_Last_MovingMode_Table get groupId _group];						
				
			};


		case "FORWARD":
		
			{				
				(driver _vehicle) enableAI "PATH";
				_vehicle limitspeed _speed;
				_vehicle setDriveOnPath [position _vehicle, _vehicle getRelPos  [_pos + 15, 0]];

			};

		case "RIGHT":
		
			{				
				(driver _vehicle) enableAI "PATH";
				_vehicle limitspeed _speed;
				_vehicle setDriveOnPath [position _vehicle, _vehicle getRelPos  [_pos + 15, 45]];

			};

		case "LEFT":
		
			{				
				(driver _vehicle) enableAI "PATH";
				_vehicle limitspeed _speed;
				_vehicle setDriveOnPath [position _vehicle, _vehicle getRelPos  [_pos + 15, 315]];

			};

		case "BACK_RIGHT":
		
			{				
				(driver _vehicle) enableAI "PATH";
				_vehicle forceSpeed  _speed;
				_vehicle setDriveOnPath [position _vehicle, _vehicle getRelPos  [_pos + 15, 190]];

			};
		case "BACK_LEFT":
		
			{				
				(driver _vehicle) enableAI "PATH";
				_vehicle forceSpeed  _speed;
				_vehicle setDriveOnPath [position _vehicle, _vehicle getRelPos  [_pos + 15, 170]];

			};


		default {hint "No Action Description move vehicle"};

	};