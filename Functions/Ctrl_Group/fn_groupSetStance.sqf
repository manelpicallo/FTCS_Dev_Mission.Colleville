
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

params ["_group", "_stance"];


private _aware_time = 0.5;
private _leader = leader _group;

switch (_stance) do 

{
	case "GO_UP":

		{
			
			[_leader, false, true, true, "SentUnitPosUp", "gestureUp", 0] call MPG_fnc_unitSendMessage;
			
			{

				if (stance _x == "CROUCH") then 
				{
					_x setUnitPos "UP"; 
					Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
					Groups_Stance_Table set [groupid _group,"FORCE_UP"];
				};

				if (stance _x == "PRONE") then 
				{
					_x setUnitPos "MIDDLE"; 
					Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
					Groups_Stance_Table set [groupid _group,"FORCE_MIDDLE"];
				};

			} forEach units _group;
				
		};			
				
	case "GO_DOWN":

		{

			[_leader, false, true, true, "SentUnitPosDown", "gestureCover", 0] call MPG_fnc_unitSendMessage;

			{

				if (stance _x == "STAND") then 
				{
					_x setUnitPos "MIDDLE"; 
					Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
					Groups_Stance_Table set [groupid _group,"FORCE_MIDDLE"];
				};
	 			
				if (stance _x == "CROUCH") then 
				{
					_x setUnitPos "DOWN"; 
					Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
					Groups_Stance_Table set [groupid _group,"FORCE_DOWN"];	
				};

			} forEach units _group;	

		};


	case "AUTO":

		{
			{_x setUnitPos "AUTO";} forEach units _group;
			Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
			Groups_Stance_Table set [groupid _group,"AUTO"];

		};


	case "FORCE_LOW":

		{

			{_x setUnitPos "DOWN";} forEach units _group;
			Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
			Groups_Stance_Table set [groupid _group,"FORCE_LOW"];

		};


	case "FORCE_MIDDLE":

		{
			
			{_x setUnitPos "MIDDLE";} forEach units _group;
			Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
			Groups_Stance_Table set [groupid _group,"FORCE_MIDDLE"];

		};


	case "FORCE_UP":

		{
			
			{_x setUnitPos "UP";} forEach units _group;
			Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
			Groups_Stance_Table set [groupid _group,"FORCE_UP"];
			
		};



	case "FOLLOW_COMMANDER_STANCE":

			
		{


			Groups_Last_Stance_Table set [groupid _group, Groups_Stance_Table get (groupId _group)];
			Groups_Stance_Table set [groupid _group,"FOLLOW_COMMANDER_STANCE"];

			_player_change_stance = true;
			_player_last_estance = stance player;

			while {(Groups_Stance_Table get groupid _group) == "FOLLOW_COMMANDER_STANCE" } do

				{
				 if (_player_change_stance) then 
				 
				 	{
						if (stance player == "STAND")  then 
						{

							{if (stance _x != "STAND") then{_x setUnitPos "UP";};}foreach units _group;
							
							if ((Groups_AwareMode_Table get (groupId _group)) == "AWARE_RIFLE_DOWN") then 
							{
								[_group, "AWARE_RIFLE_DOWN"] call MPG_fnc_groupSetAwareMode;
							};
							
						};
						
						if (stance player == "CROUCH")  then {{if (stance _x != "CROUCH") then {_x setUnitPos "MIDDLE"}}foreach units _group};
						if (stance player == "PRONE")  then {{if (stance _x != "PRONE") then {_x setUnitPos "DOWN"}}foreach units _group}; 
					    _player_last_estance = stance player;
						_player_change_stance = false;
						
					};	

				if (_player_last_estance != stance player) then {_player_change_stance = true};

					Sleep _aware_time;
				};
		};		

	default { hint "No Action Description" };

};