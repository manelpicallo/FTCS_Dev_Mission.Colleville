
/*
	Author: Manel P.

	Description:
	
*/

params ["_unit"];

	
//Add AI Behaviour when fired close to him

_unit addEventHandler ["Suppressed", 

	{
		params ["_unit", "_distance", "_shooter", "_instigator", "_ammoObject", "_ammoClassName", "_ammoConfig"];

		private _group = group _unit ;

		if (_distance < 5) then 
		
		{
			
			if ((Groups_Stance_Table get (groupId _group)) != "AUTO") then 
			
			{
				
				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				(leader _group) commandchat "Activate own stance";
			
			};

			
			
		};



	}];
			

		