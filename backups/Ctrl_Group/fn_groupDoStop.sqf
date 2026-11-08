
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

private _groupID = groupID _group;
private _leader = leader _group;


	switch (_type) do 

	{

		case "HALT":
			
			{

			_leader disableAI "PATH";
			Groups_Last_MovingMode_Table set [ _groupID, Groups_MovingMode_Table get (_groupID)];
			Groups_MovingMode_Table set [_groupID, "HALT"];
			[_leader, false, true, true, "SentCmdStop", "gestureFreeze", 0] call MPG_fnc_unitSendMessage;
	
			};

			
		case "STOP":
			
			{

			{doStop _x;} forEach units _group;
			Groups_Last_MovingMode_Table set [_groupID,"AT_WILL"];
			Groups_MovingMode_Table set [_groupID, "STOP"];

			[_leader, false, true, true, "SentCmdStop", "gestureFreeze", 0] call MPG_fnc_unitSendMessage;
			
			};

		default { hint "No Action Description" };
				
	};	
				
				
				
			