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

params ["_group", "_type"]; 

	

// retieve all the name of the markers for waypoins of the group without the index

			
	if (_type == "INFANTRY") then

		{
			private _group_marker = format ["%1_pos_" , Groups_Names_Table get groupId  _group];
			{

				deleteMarker (format ["%1_pos_%2" , Groups_Names_Table get groupId _group, _forEachIndex + 1])	
			
			}
			foreach ([_group_marker] call BIS_fnc_getMarkers);
		};


	if (_type == "VEHICLE") then

		{
			
			private _group_marker = format ["%1_pos_" , Groups_Vehicle_Names_Table get groupId  _group];
			{
				deleteMarker (format ["%1_pos_%2" , Groups_Vehicle_Names_Table get groupId _group, _forEachIndex + 1])
			}
			foreach ([_group_marker] call BIS_fnc_getMarkers);

		};


	if (_type == "CONVOY") then

		{
							
			private _group_marker = "Column_";
			{
				deleteMarker (format ["Column_%1", _forEachIndex + 1])
			}
			foreach ([_group_marker] call BIS_fnc_getMarkers);
		
		};



					



											
			
		