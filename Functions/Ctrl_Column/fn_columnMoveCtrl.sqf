
/*
	Author: Manel P.

	Description:
		
		Make the group to Stop 

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_type"];

	private _vehicle = vehicle leader MPG_Group_Column;
	


	switch (_type) do 

	{

		case "STOP":
			
			{

				// if is allready in STOP do not nothing
				if (MPG_Group_Column_Status != "STOP") then 
				
				{
					(driver _vehicle) disableAI "PATH";

					//Remove waypoints and markers in mapAnimAdd

					[MPG_Group_Column,"CONVOY"] call MPG_fnc_mapDeleteWaypointMarkers; 
					[MPG_Group_Column, "CONVOY"] spawn MPG_fnc_groupDeleteAllWaypoints;

					//The column is still formed, so only remove the waypoints to issue new ones

					MPG_Group_Column_Status = "STOP";

				
				};

				sleep 1; //this sleep is to be sure that the column is out of control separation
	
			};	

		case "HALT":
			
			{

				(driver _vehicle) disableAI"PATH";
				MPG_Group_Column_Last_Status = MPG_Group_Column_Status; 
				MPG_Group_Column_Status = "HALT";
				
			};	


		case "CONTINUE":
			
			{
				(driver _vehicle) enableAI"PATH";
				MPG_Group_Column_Status = MPG_Group_Column_Last_Status;
		
			};	

		case "REGROUP":
			
			{
			
				{
								
					driver (Vehicle_Assigned_Table get groupId _x) doFollow (leader _vehicle);		
							
				}foreach Selected_Vehicle_list - [Selected_Vehicle_list select 0];
				
		
			};


		case "FAST":
			
			{
			
				missionNamespace setVariable ["MPG_Convoy_Speed", FAST_COLUMN_SPEED];
		
			};	


		case "NORMAL":
			
			{
			
				missionNamespace setVariable ["MPG_Convoy_Speed", NORMAL_COLUMN_SPEED];
		
			};	



		case "SLOW":
			
			{
			
				missionNamespace setVariable ["MPG_Convoy_Speed", SLOW_COLUMN_SPEED];
		
			};	



		case "GUNNERS_FRONT":
			
			{
							
				{
				
					private _vehicle_to_assign =  Vehicle_Assigned_Table  get groupId _x; 
					 _relpos = (driver _vehicle_to_assign) getRelPos [400, 0];
					if (!IsNull gunner _vehicle_to_assign) then {(gunner _vehicle_to_assign) doWatch _relpos};			

				} foreach Selected_Vehicle_list;
		
			};	


		case "GUNNERS_FREE_LOOK":
			
			{
						
				{
					private _vehicle_to_assign =  Vehicle_Assigned_Table  get groupId _x; 
					 if (!IsNull gunner _vehicle_to_assign) then {(gunner _vehicle_to_assign) doWatch objNull};			

				} foreach Selected_Vehicle_list;
		
			};	

		

		default { hint "No Action Description" };
				
	};		
	

	
					
	
				
				
				
			