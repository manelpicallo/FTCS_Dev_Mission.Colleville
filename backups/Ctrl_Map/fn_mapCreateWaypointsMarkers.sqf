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

private _index = count waypoints _group;


	if (_type == "INFANTRY") then

		{
			_marker_Name = format ["%1_pos_%2" , Groups_Names_Table get groupId  _group, _index + 1];
			_marker_Move = createMarkerLocal [_marker_Name, _pos];
			_marker_Move setMarkerType "Contact_pencilCircle1";
			_marker_Name setMarkerText _marker_Name;
			
		};


	if (_type == "VEHICLE") then

		{
			
			_marker_Name = format ["%1_pos_%2" , Groups_Vehicle_Names_Table get groupId  _group, _index + 1];
			_marker_Move = createMarkerLocal [_marker_Name, _pos];
			_marker_Move setMarkerType "Contact_pencilCircle1";
			_marker_Name setMarkerText _marker_Name;


		};

		if (_type == "CONVOY") then

		{
			
			_marker_Name = format ["Column_%1",  _index + 1];
			_marker_Move = createMarkerLocal [_marker_Name, _pos];
			_marker_Move setMarkerType "Contact_pencilCircle1";
			_marker_Name setMarkerText _marker_Name;


		};

	

					



											
			
		