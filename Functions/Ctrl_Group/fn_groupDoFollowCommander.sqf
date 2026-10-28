
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

params ["_group","_mode", "_leader"];

	private _groupID = groupId _group;
	private _not_able_time = 1;  //time to check if group is able to get in postion
	private _timer = time;
	private _spd = Speed _leader;
	private _last_spd = 10;
	
	//check if the leader of the formation is the player

	if (isPlayer _leader) then

		{
			_last_commander_dir = getDir Player;
		
			//make variables public to access in for the directions in formation;
			
			missionNamespace setVariable ["MPG_Last_Commander_Dir", _last_commander_dir];
		
		}

	else 

		{
			_last_commander_dir = getDir Player;
			/*_leader doWatch _last_commander_dir;
			waituntil {unitReady _leader};
			_leader doWatch objNull;*/

		};

	
	Groups_MovingMode_Table set [_groupID, _mode];

	//Enable movement in case coming from a HALT------!!??? if from a STOP CHECK CHECK

	(leader _group) enableAI "PATH";

	// first time moving to initial positions diferent if ABS or REL

	if (_mode == "FOLLOWING_COMMANDER_REL") then 
	{
		_group Move (_leader getRelPos [(Groups_Rel_Position_Table get (_groupID) select 0),
				(Groups_Rel_Position_Table get (_groupID) select 1)]);
		units _group doFollow leader _group;
	};


	if (_mode == "FOLLOWING_COMMANDER_ABS") then 
	{
		_group Move (_leader getPos [(Groups_Rel_Position_Table get (_groupID) select 0),
				(Groups_Rel_Position_Table get (_groupID) select 1)]);
		units _group doFollow leader _group;
	};
	
	
	while {((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_REL") ||
			((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_ABS") || 
			((Groups_MovingMode_Table get _groupID) == "HALT")} do

			{
				
				_spd = Speed  _leader;

				//if commander is near static do nothing & get the last speed of the player

				if (_spd  > 2) then 
				
				{
					
					_last_spd = _spd;
					{_x limitSpeed _spd ;} foreach units _group;
				

					//player commandChat str (Groups_MovingMode_Table get _groupID);

					if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_REL") then 

						{

							{_x disableAI "RADIOPROTOCOL"} foreach units _group;//do the move command silent
									
							_timer = time + _not_able_time;

							waituntil {time > _timer || unitReady leader _group || lifeState leader _group == "DEAD" || lifeState leader _group == "INCAPACITATED"};
							{_x disableAI "RADIOPROTOCOL"} foreach units _group;//do the move command silent
							_group Move (_leader getRelPos [(Groups_Rel_Position_Table get (_groupID) select 0),
								(Groups_Rel_Position_Table get (_groupID) select 1)]);
							units _group doFollow leader _group;	
								
							//if out of the while not for timer, then arrive set formation facing the advance direction

							if (time < _timer) then {_group setFormDir (missionNamespace getVariable "MPG_Last_Commander_Dir")}
							else {}; 
	

						};
			
							


					if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_ABS") then 

						{									

							//get the new position as new formation & do a getpos not relative...is relative to north 0-360
							//only first time entering in ABS adjusting formation to absolute postions
							

							{_x disableAI "RADIOPROTOCOL"} foreach units _group;//do the move command silent
								
							_timer = time + _not_able_time;

							waituntil {time > _timer || unitReady leader _group || lifeState leader _group == "DEAD" || lifeState leader _group == "INCAPACITATED"};
							{_x disableAI "RADIOPROTOCOL"} foreach units _group;//do the move command silent
							_group Move (_leader getPos [(Groups_Rel_Position_Table get (_groupID) select 0),
								(Groups_Rel_Position_Table get (_groupID) select 1)]);
							units _group doFollow leader _group;	
							
							//if out of the while not for timer, then arrive set formation facing the advance direction

							if (time < _timer) then {_group setFormDir (missionNamespace getVariable "MPG_Platoon_Advance_Direction")}
							else {}; 

							
						
						};


					//sleep _aware_time;

					{_x enableAI "RADIOPROTOCOL"} foreach units _group;//restart AI comments

					_last_commander_dir = getDir _leader;
					missionNamespace setVariable ["MPG_Last_Commander_Dir", _last_commander_dir];// gets the last direction player when moving to know where the platoon was heading
				
				}

				else {{_x limitSpeed _last_spd;} foreach units _group;};			
			
			};	

		//player commandChat "Salgo formaciones!";				
	
				