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

params ["_group", "_pos", "_type"]; 

private _radius = 2;


		if (_type == "INFANTRY") then

				{
					[_group, _pos, "INFANTRY"] call MPG_fnc_mapCreateWaypointsMarkers;
					 _radius = 1;
				};


		if (_type == "VEHICLE") then

				{
					[_group, _pos, "VEHICLE"] call MPG_fnc_mapCreateWaypointsMarkers;
					_radius = 8;
				};

		if (_type == "CONVOY") then

				{
					[_group, _pos, "CONVOY"] call MPG_fnc_mapCreateWaypointsMarkers;
					_radius = 8;
				};

	_last_Waypoint = _group addWaypoint [_pos, _radius];
	_last_Waypoint setWaypointVisible false;
	_last_Waypoint setWaypointCompletionRadius 1;
	_last_Waypoint setWaypointType "MOVE";

	//Autodelete the waypoint ones completed
	_last_Waypoint setWaypointStatements ["true", "deleteWaypoint [group this, currentWaypoint group this]"];

	



											
			
		