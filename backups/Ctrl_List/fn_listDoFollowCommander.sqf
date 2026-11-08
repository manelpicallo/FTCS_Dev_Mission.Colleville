
/*
	Author: Manel P.

	Description:
	
*/

params ["_list", "_mode"];

			
	if (Type_Selected == "INFANTRY") then

		{
	
	

			//Gets the main commander, at present dev, he is the player

			private _commander = leader MPG_Group_Commander;
			
			//Stop last formation loop spawned

			{Groups_MovingMode_Table set [groupId _x, "STOP"];} foreach _list;

			sleep 0.2;					
					
			// if ABS get postions to ABS value or if REL to REL positions
					
			if (_mode == "FOLLOWING_COMMANDER_ABS") then 

				{
							
					{
						
						private _group_leader = ((Groups_Rel_Position_Table get (groupId _x)) select 2);

						//Check if the group leader of the formation for the present group is in the selection ==> if true ==> not move because move with the leader
						
						if ((_list find _group_leader) == -1) then 
						
						{
						
							//Gets the leader which this group is attached (it could be the player group, so leader the player)

							private _leader_formation = leader _group_leader;

							[_x, _mode, _leader_formation] spawn MPG_fnc_groupDoFollowCommander;

							Groups_MovingMode_Table set [groupId _x, _mode];
						
						};
					
					
					} foreach _list;
						
				};

			if (_mode == "FOLLOWING_COMMANDER_REL") then 

				{
							
					{
						
						//Gets the leader which this group is attached (it could be the player group, so leader the player)

						private _leader_formation = leader ((Groups_Rel_Position_Table get (groupId _x)) select 2);
						
						[_x, _mode, _leader_formation] spawn MPG_fnc_groupDoFollowCommander;

						Groups_MovingMode_Table set [groupId _x, _mode];
					
					} foreach _list;

				};

						

			if (_mode == "NO_FOLLOW") then 

				{

					{Groups_MovingMode_Table set [groupId _x, "AT_WILL"];} foreach _list;
							
				};

					

	
		};


	if (Type_Selected == "VEHICLE") then

		{
			//
		};
			
	

	
	

	
			
	
				
				
				
			