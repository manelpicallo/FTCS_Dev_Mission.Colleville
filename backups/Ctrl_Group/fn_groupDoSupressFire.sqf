
/*
	Author: Manel P.

	Description:
		
		Make the group to Supress

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_type", "_duration"];

private _target = cursorTarget;


	switch (_type) do 

	{

		player directSay "SentCmdSuppress";
		sleep 1;
		(leader _group) directSay "SentConfirmAttack";
		
		case "IND_TIME":
			
			{			
					
				Groups_Last_Task_Table set [groupId _group, Groups_Task_Table get groupId _group];
				Groups_Last_Target_Table set [groupId _group, _target];
				Groups_Task_Table set [groupId _group,"SUPRESSING"];
				
				{
					_x doSuppressiveFire _target;
					sleep _duration;
					if ((Groups_Task_Table get groupId _group) != "SUPRESSING")	then {break};
				
				} foreach units _group; 		
				
				if ((Groups_Task_Table get groupId _group) == "SUPRESSING")	then {Groups_Task_Table set [groupId _group, Groups_Last_Task_Table get groupId _group];};
			};


		case "AT_WILL":
			
			{

				

			};



		case "STOP":
		
			{
				Groups_Task_Table set [groupId _group, Groups_Last_Task_Table get groupId _group];

			};


		default { hint "No Action Description" };

	};