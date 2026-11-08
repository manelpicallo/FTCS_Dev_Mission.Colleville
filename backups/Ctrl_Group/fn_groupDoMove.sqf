
/*
	Author: Manel P.

	Description:
		
		Make the group to Stop 

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			_type-  type of movement
			_distance - distance to move in meters
			_direction - direction to move in meters
			_relativetodirection - direction from witch is the _direction relative  == used to be PLATOON_DIR


	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_type", "_distance", "_direction", "_relativetodirection"]; 


private _groupID = groupId _group;
private _relpos = [];
private _advance_mode = ((MPG_Groups_AdvanceMode_Table get (_groupID)) select 0);
private _leader_group = leader _group;

/*******************INTERNAL FUNCTIONS *******/

INT_fnc_WaitCompleteMove = 

{

	Groups_Task_Table set [_groupID,"MOVING"];
			
	//Wait until the group get the postion o a new order is issued and go out of this move command	
				
				
	waitUntil {(Groups_Task_Table get (_groupID)) != "MOVING" || (unitReady (_leader_group))};
		
		if ((Groups_Task_Table get (_groupID)) == "MOVING") then 
				
			{

				(_leader_group) commandChat "In position";
				Groups_Task_Table set [_groupID,"AT_WILL"];

				//get the last Aware & speed mode to return the status after the movement if not same movement
				
				if ((_advance_mode) != "SAME_MODE_ADVANCE") then 

				{

					Groups_SpeedMode_Table set [_groupID, Groups_Last_SpeedMode_Table get (_groupID)];
					Groups_AwareMode_Table set [_groupID, Groups_Last_AwareMode_Table get (_groupID)];
					Groups_ROEMode_Table set [_groupID, Groups_Last_ROEMode_Table get (_groupID)];
					Groups_Stance_Table set [_groupID, Groups_Last_Stance_Table get (_groupID)];


					[_group, Groups_AwareMode_Table get (_groupID)] spawn MPG_fnc_groupSetAwareMode;
					[_group, Groups_ROEMode_Table get (_groupID)] call MPG_fnc_groupSetROE;
					[_group, Groups_SpeedMode_Table get (_groupID), -1] call MPG_fnc_groupSetSpeed;
					[_group, Groups_Stance_Table get (_groupID)] spawn MPG_fnc_groupSetStance;

				};
					
			}
		else 
			
			{

				//nothing yet.......same mode advance

			};


};


INT_fnc_CheckHALTMode = 

{
	//check if HALT mode was activated for the group

	if (Groups_MovingMode_Table get (_groupID) == "HALT") then 
				
		{

			(_leader_group) enableAI "PATH";
			Groups_MovingMode_Table set [_groupID, Groups_Last_MovingMode_Table get (_groupID)];

		};

};


//*******************FUNCTION MAIN BODY***************************


//Gets the leader which this group is attached (it could be the player group, so leader the player)

private _leader_formation = leader ((Groups_Rel_Position_Table get _groupID) select 2);

//Gets the main commander, at present dev, he is the player

private _commander = leader MPG_Group_Commander;


switch (_type) do 

	{

		case "MOVE_THERE":
			
			{
				call INT_fnc_CheckHALTMode;

				[_group, _advance_mode, true] call MPG_fnc_groupSetAdvanceMode;

				_relpos = screenToWorld [0.5, 0.5];

				//Do the move

				_group move (_relpos);	

				//Actualize the following positions
				
				if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_ABS") then 

					{

						//The distance to keep is from the leader of the group of elements  which this group is attached

						Groups_Rel_Position_Table get (_groupID) set [0, _relpos distance2d _leader_formation];

						//The direction is from the postion  of the leader of the elements

						Groups_Rel_Position_Table get (_groupID) set [1, (_leader_formation getdir _relpos)];
					
					};

				if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_REL") then 

					{
						//Same as above but for REL
						Groups_Rel_Position_Table get (_groupID) set [0, _relpos distance2d _leader_formation];
						Groups_Rel_Position_Table get (_groupID) set [1, (_commander getReldir _relpos)];

					};

				if ((Groups_MovingMode_Table get _groupID) == "WITH_COMMANDER") then 

					{
						
						Groups_With_Commander_Position_Table get (_groupID) set [0, _relpos distance2d (getpos player)];
						Groups_With_Commander_Position_Table get (_groupID) set [1, (player getReldir _relpos)];
					
					};	


				call INT_fnc_WaitCompleteMove;
			
			};


		case "MOVE_POINTING_DIR":
			
			{
				

				//call to checkif in HALT mode ...idle

				call INT_fnc_CheckHALTMode;

				//Set the distance to move pre configured if it is -1

				if (_distance < 0) then { _distance = (MPG_Groups_AdvanceMode_Table get (_groupID) select 1)};

				//set advance mode pre configured

				[_group, _advance_mode, true] call MPG_fnc_groupSetAdvanceMode;

				//Do the move

				_relpos = _leader_group getRelPos [_distance, (getDir _commander) - (getDir (_leader_group))];
				units _group doMove (_relpos);
				
				//Actualize the following positions

				if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_ABS") then 

					{

						Groups_Rel_Position_Table get (_groupID) set [0, _relpos distance2d _leader_formation];
						Groups_Rel_Position_Table get (_groupID) set [1, (_leader_formation getdir _relpos)];

					};	


				if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_REL") then 

					{

						Groups_Rel_Position_Table get (_groupID) set [0, _relpos distance2d (getpos player)];
						Groups_Rel_Position_Table get (_groupID) set [1, (player getReldir _relpos)];

					};


					if ((Groups_MovingMode_Table get _groupID) == "WITH_COMMANDER") then 

					{
						
						Groups_With_Commander_Position_Table get (_groupID) set [0, _relpos distance2d (getpos player)];
						Groups_With_Commander_Position_Table get (_groupID) set [1, (player getReldir _relpos)];
					
					};	
			

				call INT_fnc_WaitCompleteMove;
			
			};
			
			

		case "MOVE_RELATIVE":
			
			{
				
				private _message = "";
				
				if (_relativetodirection == 0) then {_message = "front" };
				if (_relativetodirection == 90) then {_message = "right" };
				if (_relativetodirection == -90) then {_message = "left" };
				if (_relativetodirection == 180) then {_message = "back" };

				[_leader_group, false, true, true, _message, "gestureGo", 0] call MPG_fnc_unitSendMessage;

				call INT_fnc_CheckHALTMode;

				//Set the distance to move pre configured if it is -1

				if (_distance < 0) then { _distance = (MPG_Groups_AdvanceMode_Table get (_groupID) select 1)};


				[_group, _advance_mode, true] call MPG_fnc_groupSetAdvanceMode;

				if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_ABS") then 

					{
						
						if (_direction < 0) then {_direction = missionNamespace getVariable "MPG_Platoon_Advance_Direction"};
						
						//Do the move

						_relpos = (_leader_group) getPos [_distance, _direction + _relativetodirection];
						_group Move (_relpos);

						Groups_Rel_Position_Table get (_groupID) set [0, _relpos distance2d _leader_formation];
						Groups_Rel_Position_Table get (_groupID) set [1, (_leader_formation getdir _relpos)];
					
					};

				if ((Groups_MovingMode_Table get _groupID) == "FOLLOWING_COMMANDER_REL") then 

					{
	
						if (_direction < 0) then {_direction = missionNamespace getVariable "MPG_Last_Commander_Dir"};

						_relpos = (_leader_group) getPos [_distance, _direction + _relativetodirection];
						_group Move (_relpos);

						Groups_Rel_Position_Table get (_groupID) set [0, _relpos distance2d (getpos player)];
						Groups_Rel_Position_Table get (_groupID) set [1, (player getReldir _relpos)];
					
					};	


				if ((Groups_MovingMode_Table get _groupID) == "AT_WILL") then 

					{
	
						if (_direction < 0) then {_direction = getDir player};

						_relpos = (_leader_group) getPos [_distance, _direction + _relativetodirection];
						_group Move (_relpos);

					};

				if ((Groups_MovingMode_Table get _groupID) == "WITH_COMMANDER") then 

					{
						
						if (_direction < 0) then {_direction = getDir player};

						_relpos = (_leader_group) getPos [_distance, _direction + _relativetodirection];
						_group Move (_relpos);

						Groups_With_Commander_Position_Table get (_groupID) set [0, _relpos distance2d (getpos player)];
						Groups_With_Commander_Position_Table get (_groupID) set [1, (player getReldir _relpos)];
					
					};	

				call INT_fnc_WaitCompleteMove;

			};


		case "ON_MAP":
			
			{	
				_leader_group enableAI "PATH"; 								
			};


		case "CONTINUE":
			
			{	
				if (Groups_MovingMode_Table get (_groupID) == "HALT") then 
				
					{

						(_leader_group) enableAI "PATH";
						Groups_MovingMode_Table set [_groupID, Groups_Last_MovingMode_Table get _groupID];

					};

				if (Groups_MovingMode_Table get (_groupID) == "STOP") then 
				
					{

						(_leader_group) enableAI "PATH";
						Groups_MovingMode_Table set [_groupID, "AT_WILL"];
						{_x doFollow (_leader_group)} forEach (units _group);

					};


			};
		

		

		default { hint "No Action Description" };

	};
	
					