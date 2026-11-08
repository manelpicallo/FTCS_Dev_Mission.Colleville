
/*
	Author: Manel P.

	Description:
		
		Make the group to  fire at will

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_type"];

private _leader = leader _group;


switch (_type) do 

	{


		case "HOLD_FIRE":
			
			{

			_group  setCombatMode "BLUE";
			
			[_leader, false, true, true, "SentCeaseFire", "gestureCeaseFire", 0] call MPG_fnc_unitSendMessage;
				
			
			};

			
		case "FIRE_IF_FIRED_UPON":
			
			{

			_group  setCombatMode "GREEN";	
			
			};

		case "FIRE_AT_WILL":
			
			{

			_group  setCombatMode "YELLOW";

			[_leader, false, true, true, "SentOpenFire", "gestureYes", 0] call MPG_fnc_unitSendMessage;	
			
			};



		default { hint "No Action Description" };
				
	};		