
/*
	Author: Manel P.

	Description:
		
		Make the group to Stop 

	Parameter(s):
		0: can be one of:
			_unit- Group who is ordered
			_type-  type of movement
			_distance - distance to move in meters
			_direction - direction to move in meters
			


	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_unit", "_type", "_distance", "_direction"]; 

	
private _relpos = [];


switch (_type) do 

	{

		case "WITH_ME":
			
			{
				private _Initial_Group = group _unit;
				private _temp_Group = createGroup [PlayerSide, true];
				[_unit] joinSilent _temp_Group;
				[_temp_Group, "FIRE_IF_FIRED_UPON"] call MPG_fnc_groupSetROE;

				While {(group _unit) == _temp_Group } do 
				
					{
					
					if (((position player) distance (position _unit)) > 2 ) then {_unit doMove (position player)};
					
					if (stance player == "STAND")   then {_unit setUnitPos "UP"};
					if (stance player == "CROUCH")  then {_unit setUnitPos "MIDDLE"};
					if (stance player == "PRONE")   then {_unit setUnitPos "DOWN"};
					
					sleep 1; 
					
					};

				//the group of the unit has changed here due RETURN SQUAD isued, so use (group _unit) insted

				[(group _unit), Groups_ROEMode_Table get (groupId (_Initial_Group))] call MPG_fnc_groupSetROE;
				[(group _unit), Groups_Stance_Table get (groupId _Initial_Group)] call MPG_fnc_groupSetStance;
				[(group _unit), Groups_AwareMode_Table get (groupId _Initial_Group)] call MPG_fnc_groupSetAwareMode; 		
				//_unit setUnitPos "AUTO";
				[_unit] joinSilent _Initial_Group;
				deleteGroup _temp_Group;


			};
			
		case "RETURN_SQUAD":
		
			{
				
				//create a new temporal group to go out of the loop 
				private _temp_Group = createGroup [PlayerSide, true];
				[_unit] joinSilent _temp_Group;
				sleep 1.5;
				deleteGroup _temp_Group;
			
			};

		

		default { hint "No Action Description" };

	};
	
					