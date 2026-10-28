
/*
	Author: Manel P.

	Description:
		
	

	Parameter(s):
		0: can be one of:
			unit - unit who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_unit", "_radio", "_gesture", "_say", "_message", "_action", "_channel"];

		
//Only send a message if the group of the unit is directly attached to the main group

private _group_leader = ((Groups_Rel_Position_Table get (groupId (group _unit))) select 2);

//Check if the group of the unit is attached to the main group
						
if (_group_leader == MPG_Group_Commander) then 

		{

		if _radio then {_unit commandRadio _message};

		if _say then {_unit	directSay _message};

		if _gesture then {_unit	playAction _action};

	};


			
				
				
				
			