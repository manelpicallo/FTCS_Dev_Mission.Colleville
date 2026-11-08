
/*
	Author: Manel P.

	Description:
		
		Make the group to Stop 

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			_ROE -rule to apply at group
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_ROE"];

	

switch (_ROE) do 

	{

		case "HOLD_FIRE":
			
			{

			_group  setCombatMode "BLUE";

			Groups_Last_ROEMode_Table set [groupID _group, Groups_ROEMode_Table get (groupID _group)];
			Groups_ROEMode_Table set [groupID _group, "HOLD_FIRE"];	
			
			};

			
		case "FIRE_IF_FIRED_UPON":
			
			{

			_group  setCombatMode "GREEN";	

			Groups_Last_ROEMode_Table set [groupID _group, Groups_ROEMode_Table get (groupID _group)];
			Groups_ROEMode_Table set [groupID _group, "FIRE_IF_FIRED_UPON"];	
			
			};

		case "FIRE_AT_WILL":
			
			{

			_group  setCombatMode "YELLOW";

			Groups_Last_ROEMode_Table set [groupID _group, Groups_ROEMode_Table get (groupID _group)];
			Groups_ROEMode_Table set [groupID _group, "FIRE_AT_WILL"];	
			
			};

		case "HOLD_FIRE_COVER":
			
			{

			_group  setCombatMode "WHITE";

			Groups_Last_ROEMode_Table set [groupID _group, Groups_ROEMode_Table get (groupID _group)];
			Groups_ROEMode_Table set [groupID _group, "HOLD_FIRE_COVER"];		
			
			};

		case "FIRE_AT_WILL_COVER":
			
			{

			_group  setCombatMode "RED";

			
			Groups_Last_ROEMode_Table set [groupID _group, Groups_ROEMode_Table get (groupID _group)];
			Groups_ROEMode_Table set [groupID _group, "FIRE_AT_WILL_COVER"];	
			
			};

		default { hint "No Action Description" };

	};
	
				
				
				
			