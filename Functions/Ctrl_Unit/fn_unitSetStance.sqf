
/*
	Author: Manel P.

	Description:
		
		Make the group be at a upper stance

	Parameter(s):
		0: can be one of:
			_group - Group who is ordered
			_Stance -type stance 
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_unit", "_stance"];


_aware_time = 0.5;

switch (_stance) do 

{
	case "GO_UP":

		{

			if (stance _unit == "CROUCH") then {_unit setUnitPos "UP"};
			if (stance _unit == "PRONE") then {_unit setUnitPos "MIDDLE"};
				
		};			
				
	case "GO_DOWN":

		{

			if (stance _unit == "STAND") then {_unit setUnitPos "MIDDLE"};
	 		if (stance _unit == "CROUCH") then {_unit setUnitPos "DOWN"};

		};


	case "AUTO":

		{
		 	_unit setUnitPos "AUTO";
		};


	case "LOW":

		{
			_unit setUnitPos "DOWN";
		};


	case "MIDDLE":

		{	
			_unit setUnitPos "MIDDLE";
		};


	case "UP":

		{		
			_unit setUnitPos "UP";
		};


	case "FOLLOW_COMMANDER_STANCE":

			
		{


			Units_Stance_Table set [name _unit,"FOLLOW_COMMANDER_STANCE"];

			while {(Units_Stance_Table get name _unit) == "FOLLOW_COMMANDER_STANCE" } do

				{
				
					if (stance player == "STAND")  then {_unit setUnitPos "UP"};
					if (stance player == "CROUCH")  then {_unit setUnitPos "MIDDLE"};
					if (stance player == "PRONE")  then {_unit setUnitPos "DOWN"}; 
					Sleep _aware_time;

				};
		};

	default { hint "No Action Description" };

};