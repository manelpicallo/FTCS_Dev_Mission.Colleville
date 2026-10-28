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

params ["_group", "_pos", "_type", "_dir"]; 


	if (_type == "INFANTRY") then
	
	
		{
			//Next Marker name to be created
			private _marker_Name = format ["DIR_marker_%1", groupId _group];
			deleteMarkerLocal format ["DIR_marker_%1", groupId _group];
			MPG_Arrow_Advance_Dir call BIS_fnc_drawArrow;			

		};


	if (_type == "VEHICLE") then

		{
			
		


		};


	




											
			
		