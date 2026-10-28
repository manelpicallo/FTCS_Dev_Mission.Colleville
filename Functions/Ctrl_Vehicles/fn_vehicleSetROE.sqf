
/*
	Author: Manel P.

	Description:
		
		Set the ROE for vehicles
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

		case "HOLD_FIRE_KF":
			
			{

			_group  setCombatMode "GREEN";	
			//{_x disableAI "AUTOTARGET";_x disableAI "TARGET"; _x disableAI "AUTOCOMBAT"} foreach units _group;
			{_x disableAI "AUTOTARGET";_x disableAI "TARGET";} foreach units _group;
					
			};

		case "FIRE_AT_WILL_KF":
			
			{

			_group setCombatMode "YELLOW";
			//{_x disableAI "AUTOTARGET";_x disableAI "TARGET"; _x disableAI "AUTOCOMBAT"} foreach units _group;	
			{_x disableAI "TARGET";} foreach units _group;	
						
			};

		case "HOLD_FIRE_LF":
			
			{

			_group setCombatMode "WHITE";
			{_x enableAI "TARGET";} foreach units _group;
			//{_x enableAI "AUTOCOMBAT"} foreach units _group;		
			
			};

		case "FIRE_AT_WILL_LF":
			
			{

			_group setCombatMode "RED";
			{_x enableAI "AUTOTARGET"; _x enableAI "TARGET";} foreach units _group;
			//{_x enableAI "AUTOCOMBAT"} foreach units _group;
					
			};		

		default { hint "No Action Description" };

	};
	
				
				
				
			