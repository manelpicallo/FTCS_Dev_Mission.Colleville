
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

params ["_group", "_type", "_activate"];

//_activate is the boolean to exeute the command when moving or just set the new advance mode

hint str _activate;

switch (_type) do 

	{

		case "SAME_MODE_ADVANCE":
			
			{

				//Do nothing yet.......just here in case...
				(MPG_Groups_AdvanceMode_Table get groupID _group) set [0, "SAME_MODE_ADVANCE"];
			
			};

			
		case "FAST_ADVANCE":
			
			{

				if (_activate == true) then 

				{
				[_group, "AWARE"] call MPG_fnc_groupSetAwareMode;
				[_group, "FULL", -1] call MPG_fnc_groupSetSpeed;
				[_group, "HOLD_FIRE_COVER", -1] call MPG_fnc_groupSetROE;
				[_group, "AUTO"] call MPG_fnc_groupSetStance;
				}

				else {(MPG_Groups_AdvanceMode_Table get groupID _group) set [0, "FAST_ADVANCE"];};


			
			};

		case "ASSAULT_ADVANCE":
			
			{
				if (_activate) then 

				{
				[_group, "ASSAULT_ADVANCE"] call MPG_fnc_groupSetAwareMode;
				[_group, "FULL", -1] call MPG_fnc_groupSetSpeed;
				[_group, "FIRE_AT_WILL_COVER", -1] call MPG_fnc_groupSetROE;
				[_group, "UP"] call MPG_fnc_groupSetStance;
				}

				else {(MPG_Groups_AdvanceMode_Table get groupID _group) set [0, "ASSAULT_ADVANCE"];};
				
			
			};


		case "STEALTH_ADVANCE":
			
			{
				if (_activate) then 

				{
				[_group, "STEALTH"] call MPG_fnc_groupSetAwareMode;
				[_group, "LIMITED", -1] call MPG_fnc_groupSetSpeed;
				[_group, "HOLD_FIRE_COVER", -1] call MPG_fnc_groupSetROE;
				[_group, "AUTO"] call MPG_fnc_groupSetStance;
				}

				else {(MPG_Groups_AdvanceMode_Table get groupID _group) set [0,"STEALTH_ADVANCE"];};
					
			};


						
		case "FAST_RETREAT":
			
			{
				if (_activate) then 
				
				{
				[_group, "FAST_RETREAT"] call MPG_fnc_groupSetAwareMode;
				[_group, "FULL", -1] call MPG_fnc_groupSetSpeed;
				[_group, "HOLD_FIRE", -1] call MPG_fnc_groupSetROE;
				[_group, "MIDDLE"] call MPG_fnc_groupSetStance;
				}

				else {(MPG_Groups_AdvanceMode_Table get groupID _group) set [0,"FAST_RETREAT"];};

			};

		
		case "STEALTH_RETREAT":
			
			{

				if (_activate) then 
				
				{
				[_group, "STEALTH"] call MPG_fnc_groupSetAwareMode;
				[_group, "FULL", -1] call MPG_fnc_groupSetSpeed;
				[_group, "HOLD_FIRE_COVER", -1] call MPG_fnc_groupSetROE;
				[_group, "AUTO"] call MPG_fnc_groupSetStance;
				}

				else {(MPG_Groups_AdvanceMode_Table get groupID _group) set [0,"STEALTH_RETREAT"];};

			};

		default { hint "No Action Description" };

		
				
	};	

	(leader _group) commandchat str ((MPG_Groups_AdvanceMode_Table get groupID _group) select 0); 	