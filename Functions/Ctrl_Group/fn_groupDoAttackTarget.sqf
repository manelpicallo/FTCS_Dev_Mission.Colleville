
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

params ["_group", "_target"];

	player directSay "SentConfirmAttack";
	sleep 1;
	(leader _Who_Group) directSay "SentConfirmAttack";

	Groups_Last_Target_Table set [groupId _group, _target];
	Groups_Task_Table set [groupId _group,"ATTACKING"];
	
	{_x doFire _target;} foreach units _group;
	sleep 15;
	{_x dowatch objNull;} foreach units _group;
				
				
				
			