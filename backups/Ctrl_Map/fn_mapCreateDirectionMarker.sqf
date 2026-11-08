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
			//deleteMarkerLocal format ["DIR_marker_%1", groupId _group];			
		
			//Create a new marker solid color
			_marker = createMarkerLocal [_marker_Name, _pos];
			_marker SetMarkerType "hd_objective_noShadow";
			_marker setMarkerText "ADVANCE DIRECTION";
			_marker setMarkerDir _dir;
			

			MPG_Arrow_Advance_Dir = [_pos, _pos getPos [200, _dir], [0,0,0,0.7], [3,1/5,4]] call BIS_fnc_drawArrow;

		};


	if (_type == "VEHICLE") then

		{
			
		


		};


	




											
			
		