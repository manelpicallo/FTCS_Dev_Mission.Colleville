
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

params ["_unit", "_type", "_weapon"];

		
	switch (_type) do 

	{
		
		case "CURSOR_TARGET":
			
			{
				
				private _Shot_Target = cursorTarget;
				player directSay "SentConfirmAttack";
				sleep 1;
				_unit directSay "SentConfirmAttack";
				[group _unit,  "FIRE_AT_WILL_KF"] call MPG_fnc_groupSetROE;
				_unit doFire _Shot_Target;
				sleep 15;
				_unit dowatch objNull;
					
			};

		default { hint "No Action Description" };

	};
				
				
				
			