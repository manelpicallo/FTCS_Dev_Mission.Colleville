
/*
	Author: Manel P.

	Description:
		
		init the group

	Parameter(s):
		0: can be one of:
			Group - Group to be init
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_group_leader"];


//Hash table to keep the formation type of each array of groups ==> Elements on the platoon ,not groups itself, which can be retrived with ==> 
//The group in this table are the  leader groups of each array of groups

Elements_Formation_Type_Table set [groupId _group, "COLUMN"];

//Hash table to keep the present relative position from commander  of each group in the organization 

//Values: hash table [groupId, [distance, direction, group of the leader]]

Groups_Rel_Position_Table set [groupId _group, [-1, -1, _group_leader]];

//Hash table to keep the formation relative position from commander  of each group in the organization

//Values: hash table [groupId, [distance, direction, group of the leader]]

Groups_Formation_Position_Table set [groupId _group, [-1, -1, _group_leader]];

//When a group is following the commander to BE CHECKED

Groups_With_Commander_Position_Table set [groupId _group, [2, 180]];

//Hash table to keep the  Advance mode, distance & smoke use of each group in the organization
//It is the way that they move from point to point

//Values select 0: SAME_MODE_ADVANCE /FAST_ADVANCE / ASSAULT_ADVANCE / STEALTH_ADVANCE / 
//		           FAST_RETREAT / STEALTH_RETREAT / 

//Values select 1: Int distance in meters to advance

//Values select 2: Bolean to check use of smoke granades

MPG_Groups_AdvanceMode_Table set [groupId _group, ["SAME_MODE_ADVANCE", 20, false]];

//Hash table to keep the  stances of each group in the organization

//Values: AUTO / FOLLOWING_COMMANDER_STANCE / FORCE_UP / FORCE_MIDDLE / FORCE_DOWN


Groups_Stance_Table set [groupId _group,"AT_WILL"];


Groups_Last_Stance_Table set [groupId _group,"AT_WILL"]; 

//Hash table to keep the moving status of each group in the organization

//STOP ==> stoped need a continue order stop task and move

//HALT == > stoped, no needa continue, a new move command does not cancel other tasks

//Values: 	/ AT_WILL / FOLLOWING_COMMANDER_REL/ FOLLOWING_COMMANDER_ABS / HALT 
//			/ FOLLOWING_VEHICLE / IN_VEHICLE / EMBARKING / DISEMBARKING / WITH_COMMANDER


Groups_MovingMode_Table set [groupId _group,"AT_WILL"]; 



Groups_Last_MovingMode_Table set [groupId _group,"AT_WILL"]; 


//Hash table to keep the Aware status of each group in the organization

//Values: 	/ AWARE / SHARP / SAFE / COMBAT / STEALTH / CARELESS /FOLLOWING_VEHICLE_SLOW
//			/ FOLLOWING_VEHICLE_FAST / FOLLOWING_VEHICLE_NORMAL / AWARE_RIFLE_DOWN / FAST_RETREAT
//			/ ASSAULT_ADVANCE



Groups_AwareMode_Table set [groupId _group, "SAFE"]; 



Groups_Last_AwareMode_Table set [groupId _group, "SAFE"]; 


//Hash table to keep the Speed status of each group in the organization

//Values: 	/ FULL / NORMAL / LIMITED


Groups_SpeedMode_Table set [groupId _group, "NORMAL"]; 



Groups_Last_SpeedMode_Table set [groupId _group, "NORMAL"]; 


//Hash table to keep the ROE status of each group in the organization

//Values: 	/ HOLD_FIRE / FIRE_AT_WILL / FIRE_IF_FIRED_UPON / HOLD_FIRE_COVER / FIRE_AT_WILL_COVER


Groups_ROEMode_Table set [groupId _group, "FIRE_IF_FIRED_UPON"]; 


Groups_Last_ROEMode_Table set [groupId _group, "FIRE_IF_FIRED_UPON"]; 


//Hash table to keep the status & vehicle of  groups moving with vehicles

//Values: 
//	Select 0==> _vehicle the group is following at
//	Select 1==>  SLOW / NORMAL / FAST

Groups_With_Vehicle_Table set [groupId _group, [grpNull, "NORMAL"]]; 


//Hash table to keep the tasking status of each group in the organization

//Values: AT_WILL / SUPRESSING / ATTACKING / WATCHING / MOVING / WAITING


Groups_Task_Table set [groupId _group, "AT_WILL"]; 


//Hash table to keep the tasking last status of each group in the organization NO the current task

//Values: AT_WILL / SUPRESSING / ATTACKING / WATCHING / MOVING / WAITING


Groups_Last_Task_Table set [groupId _group, "AT_WILL"]; 


//Hash table to keep the target object

Groups_Last_Target_Table set [groupId _group,objNull]; 





















	
