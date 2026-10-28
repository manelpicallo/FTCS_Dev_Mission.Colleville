
/*
	Author: Manel P.

	Description:
		
		Make the vehicle  to  fire at will

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_type"];


switch (_type) do 

	{

		case "AT_WILL":
			
			{
				_group setCombatMode "YELLOW";
				player playAction "gestureCeaseFire";
			};	


		case "HOLD_FIRE":
			
			{
				_group setCombatMode "GREEN";
				player playAction "gestureCeaseFire";		
				
			};	

		default { hint "No Action Description" };
				
	};		