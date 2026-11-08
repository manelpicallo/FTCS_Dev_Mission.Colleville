
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

params ["_group", "_type"];


//delete all the waypoint 

	for "_i" from 0 to (count (waypoints  _group) - 1) do

		{
				deleteWaypoint [_group, 0];
		};

//create a dummy waypoint to stop the group from the present waypoint
	
	if (_type == "INFANTRY") then

		{
			_wp = _group addWaypoint [(leader _group) getRelPos [2, 0], 0];
		};


	if (_type == "VEHICLE") then

		{
			_wp = _group addWaypoint [((assignedVehicles _group) select 0) getRelPos [3, 0], 0];
		};
		
	if (_type == "CONVOY") then

		{
			private _vehicle =  vehicle (leader _group);
			_wp = _group addWaypoint [_vehicle getRelPos [3, 0], 0];
		};

	sleep 0.25;			
	deleteWaypoint [_group, 0];
	
	
					
	
				
				
				
			