
/*
	Author: Manel P.

	Description:
		
		Make the group to follow commander 

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_distance", "_direction"];

	private _first_able_time = 120; //Time to check if group is able to get in postion first time
	private _not_able_time = _first_able_time;  //Variable to check if group is able to get in postion ones with commander
	private _max_aware_time = 3; //Value to check if group is able to get in postion ones with commander
	private _timer = time;
	private _spd = Speed  player;
	private _last_spd = 10;
	_last_player_dir = getDir Player;

	
	Groups_MovingMode_Table set [groupId _group,"WITH_COMMANDER"];

	//Enable movement in case coming from a HALT------!!??? if from a STOP CHECK CHECK

	(leader _group) enableAI "PATH";

	//move first time do move with default values (set & later on get)

	(Groups_With_Commander_Position_Table get (groupId _group)) set [0, _distance];
	(Groups_With_Commander_Position_Table get (groupId _group)) set [1, _direction];

	_group Move (player getRelPos [(Groups_With_Commander_Position_Table get (groupId _group)) select 0,
	 			(Groups_With_Commander_Position_Table get (groupId _group)) select 1]);

	if ((Groups_Stance_Table get (groupId _group)) != "FOLLOW_COMMANDER_STANCE") then 
	{
		[_group, "FOLLOW_COMMANDER_STANCE"] spawn MPG_fnc_groupSetStance;
	};
	
	while {((Groups_MovingMode_Table get groupId _group) == "WITH_COMMANDER")} do

			{
				
				_spd = Speed  player;

				//if player is near static do nothing & get the last speed of the player

				if (_spd  > 2) then 
				
				{
					
					_last_spd = _spd;

					{_x limitSpeed _spd} foreach units _group;
								
					_timer = time + _not_able_time;

					waituntil {time > _timer || unitReady leader _group || lifeState leader _group == "DEAD" || lifeState leader _group == "INCAPACITATED"};

					//do the move command silent

					{_x disableAI "RADIOPROTOCOL"} foreach units _group;			

					_group Move (player getRelPos [(Groups_With_Commander_Position_Table get (groupId _group)) select 0,
	 							(Groups_With_Commander_Position_Table get (groupId _group)) select 1]);

					units _group doFollow leader _group;	
						
					//if out of the while not for timer, then arrive set formation as the commander direction
					
					if (time < _timer) then {_group setFormDir (getDir player)}
					else {};

					_last_player_dir = getDir Player;

					//Check if it is first timeto get in position and ajust the _max_aware_time

					if (_not_able_time == _first_able_time) then {_not_able_time = _max_aware_time};

				
				}

				else 
				
					{
						
						{_x limitSpeed _last_spd;} foreach units _group;
						//restart AI comments
						{_x enableAI "RADIOPROTOCOL"} foreach units _group;
						
					};			
			
			};

	//remove speed limit if not moving with commander & recover last stance mode

	[_group, Groups_Last_Stance_Table get (groupId _group)] spawn MPG_fnc_groupSetStance;
	{_x limitSpeed -10} foreach units _group;	
			
	
				