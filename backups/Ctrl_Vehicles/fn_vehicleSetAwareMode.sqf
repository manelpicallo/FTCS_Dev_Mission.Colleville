
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

params ["_group", "_mode"];

	

switch (_mode) do 

	{


		case "SAFE":
			
			{

			//_group setCombatBehaviour "SAFE";
			{_x  setBehaviour "SAFE"}foreach units _group;
										
			};

		case "AWARE":
			
			{
			//_group setCombatBehaviour "AWARE";
			{_x setBehaviour "AWARE"}foreach units _group;
					
			};

		case "COMBAT":
			
			{
		
				//_group setCombatBehaviour "COMBAT";
				{_x setBehaviour "COMBAT"}foreach units _group;
				
				
			};


		case "STEALTH":
			
			{
				//_group setCombatBehaviour "STEALTH";
				{_x setCombatBehaviour "STEALTH"}foreach units _group;
				
			};		

		default { hint "No Action Description" };
		

	};
//hint str combatBehaviour _group;
	

	
	
				
				
				
			