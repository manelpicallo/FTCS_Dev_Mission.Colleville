

#include "Menus\CommandingMenus.sqf"

// Mission variables **********************************




//Direction selected by the commander platton

missionNamespace setVariable ["MPG_Platoon_Advance_Direction", 0];

//Last Direction of the commanders platton

missionNamespace setVariable ["MPG_Last_Commander_Dir", getDir player];

//Size convoy,laterit will bemodify for less than 4 if needed

missionNamespace setVariable ["MPG_max_vehicle_convoy", 4];

//Variable to know  when  the convoy is accepted to go to destination

missionNamespace setVariable ["MPG_Convoy_Go", false];

//Variable to know  when  the RscMianTitleis visble

missionNamespace setVariable ["MPG_RscMainTitleON", false];



//INIT Variable & constant  to adjust the speed of the vehicles column

FAST_COLUMN_SPEED = 55;
NORMAL_COLUMN_SPEED = (FAST_COLUMN_SPEED * 0.75);
SLOW_COLUMN_SPEED = (FAST_COLUMN_SPEED * 0.2);

//keep the number of max number allowed of infantry groups attached directly to the platoon in the config

MPG_Platoon_MAX_Infantry_Groups = 13;

MPG_Squad_MAX_Infantry_Groups = 5;

//Variable to keep the pace between soldiers

MPG_Pace_Soldiers = 5;

//Variable to keep the number of infantry groups defined in the config

MPG_Total_Infantry_Groups = 0;

//Variable to keep the number of infantry groups attached directly to the platoon in the config
//Excluded the leaders platoon group ==> is player now

MPG_Platoon_Infantry_Groups = 0;

//Variable to keep the max number of infantry groups in the squads
//Included leader groups

MPG_Squad_Infantry_Groups = 0;

//Variable to adjust the speed of the vehicle s column 

missionNamespace setVariable ["MPG_Convoy_Speed", NORMAL_COLUMN_SPEED];


//Variable to adjust the separation the vehicle s column 

missionNamespace setVariable ["MPG_Convoy_Separation", 20];


//Advance direction platoon arrow in map

MPG_Arrow_Advance_Dir = [];

//Group Commander of the platoon

MPG_Group_Commander = group player;


//Type of element selected

//Variable to recognize for wich type of unit is selected

//Values: INFANTRY / VEHICLE / SOLDIER

Type_Selected = "INFANTRY";







//INIT INFANTRY *******************************************************************




//List of on food units selected to order commands

Selected_list = [];

//Hash table of allocation of each group in the formation  0/1/2/3/4/.......

Groups_Formation_Allocation_Table = createHashMap;


//Platoon_Formation_Position_List is a list of array of arrays, where the position in the first array is
//the position in the formation, and the second array is 
//an array of three elements ==> [distance from leader , direction relative from leader, group in that position]
// Platoon_Formation_Position_List ==> [[distance, direction, group], [distance, direction, group], [], [distance, direction, group],...........] 

Platoon_Formation_Position_List = [];

//Hash table to keep the formation type of each array of groups ==> Elements on the platoon ,not groups itself, which can be retrived with ==> 
//The group in this table are the  leader groups of each array of groups

Elements_Formation_Type_Table = createHashMap;

//Hash table to keep the groups inside each element,it is an array of groups 
//The groups does not include the leader groups

Elements_Members_Table = createHashMap;

//Hash table to keep the formation position of each group relative to their leader
//Values: hash table [groupId, [distance, direction, group leader]]

Groups_Formation_Position_Table = createHashMap;
					
//Hash table to keep the present relative position from the own commander  of each group in the organization

//Values: hash table [groupId, [distance, direction, group formation leader]]

Groups_Rel_Position_Table = createHashMap;

//When a group is following the commander to BE CHECKED

Groups_With_Commander_Position_Table = createHashMap;


//Hash table to keep the  Advance mode, distance & smoke use of each group in the organization
//It is the way that they move from point to point

//Values select 0: SAME_MODE_ADVANCE /FAST_ADVANCE / ASSAULT_ADVANCE / STEALTH_ADVANCE / 
//		  FAST_RETREAT / STEALTH_RETREAT / 

//Values select 1: Int distance in meters to advance

//Values select 2: Bolean to check use of smoke granades


MPG_Groups_AdvanceMode_Table = createHashMap;


//Hash table to keep the  stances of each group in the organization

//Values: AUTO / FOLLOWING_COMMANDER_STANCE / FORCE_UP / FORCE_MIDDLE / FORCE_DOWN


Groups_Stance_Table = createHashMap;


Groups_Last_Stance_Table = createHashMap;


//Hash table to keep the moving status of each group in the organization

//STOP ==> stoped need a continue order stop task and move

//HALT == > stoped, no needa continue, a new move command does not cancel other tasks

//Values: 	/ AT_WILL / FOLLOWING_COMMANDER_REL/ FOLLOWING_COMMANDER_ABS / HALT 
//			/ FOLLOWING_VEHICLE / IN_VEHICLE / EMBARKING / DISEMBARKING / WITH_COMMANDER

Groups_MovingMode_Table = createHashMap;

Groups_Last_MovingMode_Table = createHashMap; 


//Hash table to keep the Aware status of each group in the organization

//Values: 	/ AWARE / SHARP / SAFE / COMBAT / STEALTH / CARELESS /FOLLOWING_VEHICLE_SLOW
//			/ FOLLOWING_VEHICLE_FAST / FOLLOWING_VEHICLE_NORMAL / AWARE_RIFLE_DOWN / FAST_RETREAT
//			/ ASSAULT_ADVANCE


Groups_AwareMode_Table = createHashMap;

Groups_Last_AwareMode_Table = createHashMap; 


//Hash table to keep the Speed status of each group in the organization

//Values: 	/ FULL / NORMAL / LIMITED


Groups_SpeedMode_Table = createHashMap; 

Groups_Last_SpeedMode_Table = createHashMap;



//Hash table to keep the ROE status of each group in the organization

//Values: 	/ HOLD_FIRE / FIRE_AT_WILL / FIRE_IF_FIRED_UPON / HOLD_FIRE_COVER / FIRE_AT_WILL_COVER


Groups_ROEMode_Table = createHashMap;

Groups_Last_ROEMode_Table = createHashMap; 



//Hash table to keep the status & vehicle of  groups moving with vehicles

//Values: 
//	Select 0==> _vehicle the group is following at
//	Select 1==>  SLOW / NORMAL / FAST

Groups_With_Vehicle_Table = createHashMap;


//Hash table to keep the tasking status of each group in the organization

//Values: AT_WILL / SUPRESSING / ATTACKING / WATCHING / MOVING / WAITING

Groups_Task_Table = createHashMap;


Groups_Last_Task_Table = createHashMap;

								
//Hash table to keep the last target assigned for each group in the organization

//Values: [distance from commander, Direction from commander]

Groups_Last_Target_Table = createHashMap; 

//Hash table to keep the name for the menus to each group in the organization


Groups_Names_Table = createHashMap;


//Hash table to keep the assigned vehicle to each group in the organization
//now initialized by default it will be do using logic modules in EDEN


Groups_Assigned_Vehicle_Table = createHashMap; 




//define all the posible groups in the oragnization

ORBAT_Group_0 = missionNamespace getVariable ["ORBAT_Group_0",objNull];


ORBAT_Group_0_0 = missionNamespace getVariable ["ORBAT_Group_0_0",objNull];
ORBAT_Group_0_1 = missionNamespace getVariable ["ORBAT_Group_0_1",objNull];
ORBAT_Group_0_2 = missionNamespace getVariable ["ORBAT_Group_0_2",objNull];
ORBAT_Group_0_3 = missionNamespace getVariable ["ORBAT_Group_0_3",objNull];
ORBAT_Group_0_4 = missionNamespace getVariable ["ORBAT_Group_0_4",objNull];

//////////////////////////

ORBAT_Group_1 = missionNamespace getVariable ["ORBAT_Group_1",objNull];

ORBAT_Group_1_0 = missionNamespace getVariable ["ORBAT_Group_1_0",objNull];
ORBAT_Group_1_1 = missionNamespace getVariable ["ORBAT_Group_1_1",objNull];
ORBAT_Group_1_2 = missionNamespace getVariable ["ORBAT_Group_1_2",objNull];
ORBAT_Group_1_3 = missionNamespace getVariable ["ORBAT_Group_1_3",objNull];
ORBAT_Group_1_4 = missionNamespace getVariable ["ORBAT_Group_1_4",objNull];

//////////////////////////

ORBAT_Group_2 = missionNamespace getVariable ["ORBAT_Group_2",objNull];

ORBAT_Group_2_0 = missionNamespace getVariable ["ORBAT_Group_2_0",objNull];
ORBAT_Group_2_1 = missionNamespace getVariable ["ORBAT_Group_2_1",objNull];
ORBAT_Group_2_2 = missionNamespace getVariable ["ORBAT_Group_2_2",objNull];
ORBAT_Group_2_3 = missionNamespace getVariable ["ORBAT_Group_2_3",objNull];
ORBAT_Group_2_4 = missionNamespace getVariable ["ORBAT_Group_2_4",objNull];

//////////////////////////

ORBAT_Group_3 = missionNamespace getVariable ["ORBAT_Group_3",objNull];

ORBAT_Group_3_0 = missionNamespace getVariable ["ORBAT_Group_3_0",objNull];
ORBAT_Group_3_1 = missionNamespace getVariable ["ORBAT_Group_3_1",objNull];
ORBAT_Group_3_2 = missionNamespace getVariable ["ORBAT_Group_3_2",objNull];
ORBAT_Group_3_3 = missionNamespace getVariable ["ORBAT_Group_3_3",objNull];
ORBAT_Group_3_4 = missionNamespace getVariable ["ORBAT_Group_3_4",objNull];

//////////////////////////

ORBAT_Group_4 = missionNamespace getVariable ["ORBAT_Group_4",objNull];

ORBAT_Group_4_0 = missionNamespace getVariable ["ORBAT_Group_4_0",objNull];
ORBAT_Group_4_1 = missionNamespace getVariable ["ORBAT_Group_4_1",objNull];
ORBAT_Group_4_2 = missionNamespace getVariable ["ORBAT_Group_4_2",objNull];
ORBAT_Group_4_3 = missionNamespace getVariable ["ORBAT_Group_4_3",objNull];
ORBAT_Group_4_4 = missionNamespace getVariable ["ORBAT_Group_4_4",objNull];

//Create the oragization structure
//First Array of array of groups (each positions means a firts level group)
//Second Array of groups ==> [[group, group, ],[],[]]
//First group of second array is the group leader of the element

MPG_ORBAT_Structure_List = [];




//INIT ALL THE SYNCED GROUPS


//Synced object with the orbat modules are assigned to the internal varible groups


//Get the names for the groups (IDs) from the class defined in description.ext for the ORBAT classes, the groupId would be enought
// i prefer to use the function and the parameter is the 3rd value so ==> select 2


//Init Group_0

if (!isNull ORBAT_Group_0) then 

{

	private _temp_objects_sync = synchronizedObjects ORBAT_Group_0;
	private _temp_array = [];

	if (!isNull (_temp_objects_sync select 0)) then 

	{

		Group_0 = group (_temp_objects_sync select 0);
		
		_temp_array = [Group_0];
		MPG_ORBAT_Structure_List pushBack _temp_array;

		MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
		MPG_Platoon_Infantry_Groups = MPG_Platoon_Infantry_Groups + 1;

		Name_Infantry_Group_0 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "1squad"] call BIS_fnc_ORBATGetGroupParams) select 2);
		Group_0 setGroupId [Name_Infantry_Group_0];

		Groups_Formation_Allocation_Table set [groupId Group_0, 0];

		Groups_Names_Table set [groupId Group_0, Name_Infantry_Group_0];
		[Group_0, MPG_Group_Commander] call MPG_fnc_groupInit;

		(MENU_Select_Infantry select 2) set [0, Groups_Names_Table get groupId Group_0];

		//Init Group_0_0

		_temp_objects_sync = synchronizedObjects ORBAT_Group_0_0;

		private _last_element = (count MPG_ORBAT_Structure_List - 1);

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_0_0 = group (_temp_objects_sync select 0);
				Name_Infantry_Group_0_0 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "1squad" >> "11team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_0_0 setGroupId [Name_Infantry_Group_0_0];

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_0_0;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Groups_Formation_Allocation_Table set [groupId Group_0_0, 0];

				Groups_Names_Table set [groupId Group_0_0, Name_Infantry_Group_0_0];
				[Group_0_0, Group_0] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 0 0"};


		//Init Group_0_1

		_temp_objects_sync = synchronizedObjects ORBAT_Group_0_1;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_0_1 = group (_temp_objects_sync select 0);
				
				Name_Infantry_Group_0_1 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "1squad" >> "12team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_0_1 setGroupId [Name_Infantry_Group_0_1];

				_temp_array = MPG_ORBAT_Structure_List select _last_element;				
				_temp_array pushBack Group_0_1;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Groups_Formation_Allocation_Table set [groupId Group_0_1, 1];

				Groups_Names_Table set [groupId Group_0_1, Name_Infantry_Group_0_1];
				[Group_0_1, Group_0] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 0 1"};


		//Init Group_0_2

		_temp_objects_sync = synchronizedObjects ORBAT_Group_0_2;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_0_2 = group (_temp_objects_sync select 0);
				Name_Infantry_Group_0_2 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "1squad" >> "13team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_0_2 setGroupId [Name_Infantry_Group_0_2];

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_0_2;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
				
				Groups_Formation_Allocation_Table set [groupId Group_0_2, 2];

				Groups_Names_Table set [groupId Group_0_2, Name_Infantry_Group_0_2];
				[Group_0_2, Group_0] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 0 2"};

		//Init Group_0_3

		_temp_objects_sync = synchronizedObjects ORBAT_Group_0_3;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_0_3 = group (_temp_objects_sync select 0);
				Name_Infantry_Group_0_3 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "1squad" >> "14team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_0_3 setGroupId [Name_Infantry_Group_0_3];

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_0_3;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Groups_Formation_Allocation_Table set [groupId Group_0_3, 3];

				Groups_Names_Table set [groupId Group_0_3, Name_Infantry_Group_0_3];
				[Group_0_3, Group_0] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 0 3"};


		//Init Group_0_4

		_temp_objects_sync = synchronizedObjects ORBAT_Group_0_4;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_0_4 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_0_4;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_0_4 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "1squad" >> "15team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_0_4 setGroupId [Name_Infantry_Group_0_4];

				Groups_Formation_Allocation_Table set [groupId Group_0_4, 3];

				Groups_Names_Table set [groupId Group_0_4, Name_Infantry_Group_0_4];
				[Group_0_4, Group_0] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 0 4"};



	}

	else {hintc "ERROR NOT FOUND GROUP 0 0"};

//Initzialize the table of groups of the  element, it is an array of groups 6 hash table with ID group leader attached to the platoon

Elements_Members_Table set [groupId Group_0, _temp_array];

};


//Init Group_1

if (!isNull ORBAT_Group_1) then 

{

	private _temp_objects_sync = synchronizedObjects ORBAT_Group_1;
	private _temp_array = [];

	if (!isNull (_temp_objects_sync select 0)) then 
	{
		Group_1 = group (_temp_objects_sync select 0);

		_temp_array = [Group_1];
		MPG_ORBAT_Structure_List pushBack _temp_array;

		MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
		MPG_Platoon_Infantry_Groups = MPG_Platoon_Infantry_Groups + 1;
		
		Name_Infantry_Group_1 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "2squad"] call BIS_fnc_ORBATGetGroupParams) select 2);
		Group_1 setGroupId [Name_Infantry_Group_1];

		Groups_Formation_Allocation_Table set [groupId Group_1, 1];

		Groups_Names_Table set [groupId Group_1, Name_Infantry_Group_1];
		[Group_1, MPG_Group_Commander] call MPG_fnc_groupInit;
		(MENU_Select_Infantry select 3) set [0, Groups_Names_Table get groupId Group_1];

		//Init Group_1_0

		_temp_objects_sync = synchronizedObjects ORBAT_Group_1_0;
		private _last_element = (count MPG_ORBAT_Structure_List - 1);

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_1_0 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_1_0;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
				
				Name_Infantry_Group_1_0 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "2squad" >> "21team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_1_0 setGroupId [Name_Infantry_Group_1_0];

				Groups_Formation_Allocation_Table set [groupId Group_1_0, 0];

				Groups_Names_Table set [groupId Group_1_0, Name_Infantry_Group_1_0];
				[Group_1_0, Group_1] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 1 0"};


		//Init Group_1_1

		_temp_objects_sync = synchronizedObjects ORBAT_Group_1_1;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_1_1 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_1_1;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_1_1 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "2squad" >> "22team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_1_1 setGroupId [Name_Infantry_Group_1_1];

				Groups_Formation_Allocation_Table set [groupId Group_1_1, 1];

				Groups_Names_Table set [groupId Group_1_1, Name_Infantry_Group_1_1];
				[Group_1_1, Group_1] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 1 1"};


		//Init Group_1_2

		_temp_objects_sync = synchronizedObjects ORBAT_Group_1_2;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_1_2 = group (_temp_objects_sync select 0);
				

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_1_2;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_1_2 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "2squad" >> "23team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_1_2 setGroupId [Name_Infantry_Group_1_2];


				Groups_Formation_Allocation_Table set [groupId Group_1_2, 2];

				Groups_Names_Table set [groupId Group_1_2, Name_Infantry_Group_1_2];
				[Group_1_2, Group_1] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 1 2"};

		//Init Group_1_3

		_temp_objects_sync = synchronizedObjects ORBAT_Group_1_3;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_1_3 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_1_3;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_1_3 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "2squad" >> "24team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_1_3 setGroupId [Name_Infantry_Group_1_3];

				Groups_Formation_Allocation_Table set [groupId Group_1_3, 3];

				Groups_Names_Table set [groupId Group_1_3, Name_Infantry_Group_1_3];
				[Group_1_3, Group_1] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 1 3"};


		//Init Group_1_4

		_temp_objects_sync = synchronizedObjects ORBAT_Group_1_4;


		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_1_4 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_1_4;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_1_4 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "2squad" >> "25team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_1_4 setGroupId [Name_Infantry_Group_1_4];

				Groups_Formation_Allocation_Table set [groupId Group_1_4, 3];

				Groups_Names_Table set [groupId Group_1_4, Name_Infantry_Group_1_4];
				[Group_1_4, Group_1] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 1 4"};

	}
	else {hintc "ERROR NOT FOUND SYNC GROUP 1 0"};


//Initzialize the table of groups of the  element, it is an array of groups 6 hash table with ID group leader attached to the platoon

Elements_Members_Table set [groupId Group_1, _temp_array];

};

//Init Group_2

if (!isNull ORBAT_Group_2) then 

{

	private _temp_objects_sync = synchronizedObjects ORBAT_Group_2;
	private _temp_array = [];

	if (!isNull (_temp_objects_sync select 0)) then

	{
		Group_2 = group (_temp_objects_sync select 0);

		_temp_array = [Group_2];
		MPG_ORBAT_Structure_List pushBack _temp_array;

		MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
		MPG_Platoon_Infantry_Groups = MPG_Platoon_Infantry_Groups + 1;
		
		Name_Infantry_Group_2= (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "3squad"] call BIS_fnc_ORBATGetGroupParams) select 2);
		Group_2 setGroupId [Name_Infantry_Group_2];

		Groups_Formation_Allocation_Table set [groupId Group_2, 2];

		Groups_Names_Table set [groupId Group_2, Name_Infantry_Group_2];
		[Group_2, MPG_Group_Commander] call MPG_fnc_groupInit;
		(MENU_Select_Infantry select 4) set [0, Groups_Names_Table get groupId Group_2];

		//Init Group_2_0

		_temp_objects_sync = synchronizedObjects ORBAT_Group_2_0;
		private _last_element = (count MPG_ORBAT_Structure_List - 1);

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_2_0 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_2_0;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_2_0 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "3squad" >> "31team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_2_0 setGroupId [Name_Infantry_Group_2_0];

				Groups_Formation_Allocation_Table set [groupId Group_2_0, 0];

				Groups_Names_Table set [groupId Group_2_0, Name_Infantry_Group_2_0];
				[Group_2_0, Group_2] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 2 0"};


		//Init Group_2_1

		_temp_objects_sync = synchronizedObjects ORBAT_Group_2_1;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_2_1 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_2_1;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_2_1 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "3squad" >> "32team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_2_1 setGroupId [Name_Infantry_Group_2_1];

				Groups_Formation_Allocation_Table set [groupId Group_2_1, 1];

				Groups_Names_Table set [groupId Group_2_1, Name_Infantry_Group_2_1];
				[Group_2_1, Group_2] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 2 1"};


		//Init Group_2_2

		_temp_objects_sync = synchronizedObjects ORBAT_Group_2_2;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_2_2 = group (_temp_objects_sync select 0);
				

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_2_2;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_2_2 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "3squad" >> "33team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_2_2 setGroupId [Name_Infantry_Group_2_2];


				Groups_Formation_Allocation_Table set [groupId Group_2_2, 2];

				Groups_Names_Table set [groupId Group_2_2, Name_Infantry_Group_2_2];
				[Group_2_2, Group_2] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 2 2"};

		//Init Group_2_3

		_temp_objects_sync = synchronizedObjects ORBAT_Group_2_3;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_2_3 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_2_3;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_2_3 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "3squad" >> "34team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_2_3 setGroupId [Name_Infantry_Group_2_3];

				Groups_Formation_Allocation_Table set [groupId Group_2_3, 3];

				Groups_Names_Table set [groupId Group_2_3, Name_Infantry_Group_2_3];
				[Group_2_3, Group_2] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 2 3"};


		//Init Group_2_4

		_temp_objects_sync = synchronizedObjects ORBAT_Group_2_4;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_2_4 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_2_4;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_2_4 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "3squad" >> "35team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_2_4 setGroupId [Name_Infantry_Group_2_4];

				Groups_Formation_Allocation_Table set [groupId Group_2_4, 3];

				Groups_Names_Table set [groupId Group_2_4, Name_Infantry_Group_2_4];
				[Group_2_4, Group_2] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 2 4"};

	}
	else {hintc "ERROR NOT FOUND SYNC GROUP 2 0"};

//Initzialize the table of groups of the  element, it is an array of groups 6 hash table with ID group leader attached to the platoon

Elements_Members_Table set [groupId Group_2, _temp_array];

};

//Init Group_3

if (!isNull ORBAT_Group_3) then 

{

	private _temp_objects_sync = synchronizedObjects ORBAT_Group_3;
	private _temp_array = [];

	if (!isNull (_temp_objects_sync select 0)) then 
	{
		Group_3 = group (_temp_objects_sync select 0);

		_temp_array = [Group_3];
		MPG_ORBAT_Structure_List pushBack _temp_array;

		MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
		MPG_Platoon_Infantry_Groups = MPG_Platoon_Infantry_Groups + 1;
		
		Name_Infantry_Group_3 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "4squad"] call BIS_fnc_ORBATGetGroupParams) select 2);	
		Group_3 setGroupId [Name_Infantry_Group_3];

		Groups_Formation_Allocation_Table set [groupId Group_3, 3];

		Groups_Names_Table set [groupId Group_3, Name_Infantry_Group_3];
		[Group_3, MPG_Group_Commander] call MPG_fnc_groupInit;
		(MENU_Select_Infantry select 5) set [0, Groups_Names_Table get groupId Group_3];

		//Init Group_3_0

		_temp_objects_sync = synchronizedObjects ORBAT_Group_3_0;
		private _last_element = (count MPG_ORBAT_Structure_List - 1);

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_3_0 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_3_0;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_3_0 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "4squad" >> "41team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_3_0 setGroupId [Name_Infantry_Group_3_0];

				Groups_Formation_Allocation_Table set [groupId Group_3_0, 0];

				Groups_Names_Table set [groupId Group_3_0, Name_Infantry_Group_3_0];
				[Group_3_0, Group_3] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 3 0"};


		//Init Group_3_1

		_temp_objects_sync = synchronizedObjects ORBAT_Group_3_1;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_3_1 = group (_temp_objects_sync select 0);


				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_3_1;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_3_1 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "4squad" >> "42team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_3_1 setGroupId [Name_Infantry_Group_3_1];

				Groups_Formation_Allocation_Table set [groupId Group_3_1, 1];

				Groups_Names_Table set [groupId Group_3_1, Name_Infantry_Group_3_1];
				[Group_3_1, Group_3] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 3 1"};


		//Init Group_3_2

		_temp_objects_sync = synchronizedObjects ORBAT_Group_3_2;


		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_3_2 = group (_temp_objects_sync select 0);
				

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_3_2;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
				
				Name_Infantry_Group_3_2 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "4squad" >> "43team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_3_2 setGroupId [Name_Infantry_Group_3_2];


				Groups_Formation_Allocation_Table set [groupId Group_3_2, 2];

				Groups_Names_Table set [groupId Group_3_2, Name_Infantry_Group_3_2];
				[Group_3_2, Group_3] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 3 2"};

		//Init Group_3_3

		_temp_objects_sync = synchronizedObjects ORBAT_Group_3_3;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_3_3 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_3_3;
				
				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_3_3 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "4squad" >> "44team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_3_3 setGroupId [Name_Infantry_Group_3_3];

				Groups_Formation_Allocation_Table set [groupId Group_3_3, 3];

				Groups_Names_Table set [groupId Group_3_3, Name_Infantry_Group_3_3];
				[Group_3_3, Group_3] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 3 3"};


		//Init Group_2_4

		_temp_objects_sync = synchronizedObjects ORBAT_Group_3_4;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_3_4 = group (_temp_objects_sync select 0);

				_temp_array = MPG_ORBAT_Structure_List select _last_element;
				_temp_array pushBack Group_3_4;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_3_4 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "4squad" >> "45team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_3_4 setGroupId [Name_Infantry_Group_3_4];

				Groups_Formation_Allocation_Table set [groupId Group_3_4, 3];

				Groups_Names_Table set [groupId Group_3_4, Name_Infantry_Group_3_4];
				[Group_3_4, Group_3] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 3 4"};

	}
	else {hintc "ERROR NOT FOUND SYNC GROUP 3 0"};

//Initzialize the table of groups of the  element, it is an array of groups 6 hash table with ID group leader attached to the platoon

Elements_Members_Table set [groupId Group_3, _temp_array];

};


//Init Group_4

if (!isNull ORBAT_Group_4) then 

{

	private _temp_objects_sync = synchronizedObjects ORBAT_Group_4;
	private _temp_array = [];

	if (!isNull (_temp_objects_sync select 0)) then 
	{
		Group_4 = group (_temp_objects_sync select 0);

		_temp_array = [Group_4];
		MPG_ORBAT_Structure_List pushBack _temp_array;

		MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;
		MPG_Platoon_Infantry_Groups = MPG_Platoon_Infantry_Groups + 1;
		
		Name_Infantry_Group_4 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "5squad"] call BIS_fnc_ORBATGetGroupParams) select 2);
		Group_4 setGroupId [Name_Infantry_Group_4];

		Groups_Formation_Allocation_Table set [groupId Group_4, 4];

		Groups_Names_Table set [groupId Group_4, Name_Infantry_Group_4];
		[Group_4, MPG_Group_Commander] call MPG_fnc_groupInit;
		(MENU_Select_Infantry select 6) set [0, Groups_Names_Table get groupId Group_4];


		//Init Group_4_0

		_temp_objects_sync = synchronizedObjects ORBAT_Group_4_0;
		private _last_element = (count MPG_ORBAT_Structure_List - 1);

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_4_0 = group (_temp_objects_sync select 0);

				//_temp_array = MPG_ORBAT_Structure_List select _last_element;
				//_temp_array pushBack Group_4_0;

				(MPG_ORBAT_Structure_List select _last_element) pushBack Group_4_0;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_4_0 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "5squad" >> "51team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_4_0 setGroupId [Name_Infantry_Group_4_0];


				Groups_Formation_Allocation_Table set [groupId Group_4_0, 0];

				Groups_Names_Table set [groupId Group_4_0, Name_Infantry_Group_4_0];
				[Group_4_0, Group_4] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 4 0"};


		//Init Group_4_1

		_temp_objects_sync = synchronizedObjects ORBAT_Group_4_1;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_4_1 = group (_temp_objects_sync select 0);

				//_temp_array = MPG_ORBAT_Structure_List select _last_element;
				//_temp_array pushBack Group_4_1;

				(MPG_ORBAT_Structure_List select _last_element) pushBack Group_4_1;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_4_1 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "5squad" >> "52team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_4_1 setGroupId [Name_Infantry_Group_4_1];


				Groups_Formation_Allocation_Table set [groupId Group_4_1, 1];

				Groups_Names_Table set [groupId Group_4_1, Name_Infantry_Group_4_1];
				[Group_4_1, Group_4] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 4 1"};


		//Init Group_4_2

		_temp_objects_sync = synchronizedObjects ORBAT_Group_4_2;



		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_4_2 = group (_temp_objects_sync select 0);
				

				//_temp_array = MPG_ORBAT_Structure_List select _last_element;
				//_temp_array pushBack Group_4_2;

				(MPG_ORBAT_Structure_List select _last_element) pushBack Group_4_2;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_4_2 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "5squad" >> "53team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_4_2 setGroupId [Name_Infantry_Group_4_2];


				Groups_Formation_Allocation_Table set [groupId Group_4_2, 2];

				Groups_Names_Table set [groupId Group_4_2, Name_Infantry_Group_4_2];
				[Group_4_2, Group_4] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 4 2"};

		//Init Group_4_3

		_temp_objects_sync = synchronizedObjects ORBAT_Group_4_3;


		if (!isNull (_temp_objects_sync select 0)) then 

			{
				
				Group_4_3 = group (_temp_objects_sync select 0);

				//_temp_array = MPG_ORBAT_Structure_List select _last_element;
				//_temp_array pushBack Group_4_3;

				(MPG_ORBAT_Structure_List select _last_element) pushBack Group_4_3;


				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_4_3 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "5squad" >> "54team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_4_3 setGroupId [Name_Infantry_Group_4_3];

				Groups_Formation_Allocation_Table set [groupId Group_4_3, 3];

				Groups_Names_Table set [groupId Group_4_3, Name_Infantry_Group_4_3];
				[Group_4_3, Group_4] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 4 3"};


		//Init Group_4_4

		_temp_objects_sync = synchronizedObjects ORBAT_Group_4_4;

		if (!isNull (_temp_objects_sync select 0)) then 

			{

				Group_4_4 = group (_temp_objects_sync select 0);

				//_temp_array = MPG_ORBAT_Structure_List select _last_element;
				//_temp_array pushBack Group_4_4;

				(MPG_ORBAT_Structure_List select _last_element) pushBack Group_4_4;

				MPG_Total_Infantry_Groups = MPG_Total_Infantry_Groups + 1;

				Name_Infantry_Group_4_4 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "5squad" >> "55team"] call BIS_fnc_ORBATGetGroupParams) select 2);
				Group_4_4 setGroupId [Name_Infantry_Group_4_4];


				Groups_Formation_Allocation_Table set [groupId Group_4_4, 3];

				Groups_Names_Table set [groupId Group_4_4, Name_Infantry_Group_4_4];
				[Group_4_4, Group_4] call MPG_fnc_groupInit;

			}

		else {hintc "ERROR NOT FOUND GROUP 4 4"};

	}

	else {hintc "ERROR NOT FOUND SYNC GROUP 4 0"};

//Initzialize the table of groups of the  element, it is an array of groups 6 hash table with ID group leader attached to the platoon

Elements_Members_Table set [groupId Group_4, _temp_array];

};

//Initzialize the list of the position of each group in formation

//Add the commander 

MPG_Formation_Structure_List = [[MPG_Group_Commander]];

{MPG_Formation_Structure_List set [(_foreachindex + 1), +(MPG_ORBAT_Structure_List select _foreachindex)]} foreach MPG_ORBAT_Structure_List;

while {count MPG_Formation_Structure_List <= MPG_Platoon_MAX_Infantry_Groups} do {MPG_Formation_Structure_List pushBack []};

//Actualize name the main unit in the menus

(MENU_Select_Infantry select 1) set [0, "All Squads"];

//Actualize infantry names of the main unit ....commander unit

Name_commander_Group = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon"] call BIS_fnc_ORBATGetGroupParams) select 2);

//Select all the infantry groups on start mission

[[], "INFANTRY", "ALL"] call MPG_fnc_listSelect;





//////////////////////////////////////////////////////////////////////////////


//TEST for formation plus player
/*
TEST_FORMATION = [[group player]];

TEST_FORMATION append MPG_ORBAT_Structure_List;

while {count TEST_FORMATION <= MPG_Platoon_MAX_Infantry_Groups} do {TEST_FORMATION pushBack []};

//TEST all the groups in selected list

//{Selected_list append _x}foreach MPG_ORBAT_Structure_List;
*/

/////////////////////////////////////////////////////////////////////////////



















//INIT VEHICLES*******************************************************************






Group_Vehicle_0 = createGroup [PlayerSide, false];
Group_Vehicle_1 = createGroup [PlayerSide, false];
Group_Vehicle_2 = createGroup [PlayerSide, false];
Group_Vehicle_3 = createGroup [PlayerSide, false];

//Create group for Formation mode & status control & assign vehicles to this group too

MPG_Group_Column = grpNull;

//Create the lsitof the vehicles selected

Selected_Vehicle_list = [];

//Table of postions of each vehicle group in the formation  0/1/2/3/

Elements_Vehicle_Positions_Table = [];

//Hash Table to keep the main gun properties if selected vehicle has main gun
//Values select 0: true / false ==> has main gun


MPG_Vehicles_MainGun_Table = createHashMap;

//Synced object with the orbat modules are assigned to the internal varible vehicle groups

_temp_objects_sync = synchronizedObjects ORBAT_Group_Vehicle_0;

private _maingun_exist = 0;

if (!isNull (_temp_objects_sync select 0)) then 
{
	Group_Vehicle_0 = group (_temp_objects_sync select 0);
	Selected_Vehicle_list set [0, Group_Vehicle_0];
	Elements_Vehicle_Positions_Table set [0, Group_Vehicle_0];
	Name_Vehicle_Group_0 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "1vehicle"] call BIS_fnc_ORBATGetGroupParams) select 2);
	
	_maingun_exist = getNumber (missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "1vehicle" >> "maingun");
	if (_maingun_exist == 1) then {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_0, true]}
	else {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_0, false]};
	
	Group_Vehicle_0 setGroupId [Name_Vehicle_Group_0];
	MPG_Group_Column addVehicle ((assignedVehicles Group_Vehicle_0) select 0);
};



_temp_objects_sync = synchronizedObjects ORBAT_Group_Vehicle_1;

if (!isNull (_temp_objects_sync select 0)) then 
{
	Group_Vehicle_1 = group (_temp_objects_sync select 0);
	Selected_Vehicle_list set [1, Group_Vehicle_1];
	Elements_Vehicle_Positions_Table set [1, Group_Vehicle_1];
	Name_Vehicle_Group_1 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "2vehicle"] call BIS_fnc_ORBATGetGroupParams) select 2);
	
	_maingun_exist = getNumber (missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "2vehicle" >> "maingun");
	if (_maingun_exist == 1) then {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_1, true]}
	else {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_1, false]};
	
	Group_Vehicle_1 setGroupId [Name_Vehicle_Group_1];
	MPG_Group_Column addVehicle ((assignedVehicles Group_Vehicle_1) select 0);
};


_temp_objects_sync = synchronizedObjects ORBAT_Group_Vehicle_2;

if (!isNull (_temp_objects_sync select 0)) then 
{
	Group_Vehicle_2 = group (_temp_objects_sync select 0);
	Selected_Vehicle_list set [2, Group_Vehicle_2];
	Elements_Vehicle_Positions_Table set [2, Group_Vehicle_2];
	Name_Vehicle_Group_2 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "3vehicle"] call BIS_fnc_ORBATGetGroupParams) select 2);
	
	_maingun_exist = getNumber (missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "3vehicle" >> "maingun");
	if (_maingun_exist == 1) then {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_2, true]}
	else {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_2, false]};
	
	Group_Vehicle_2 setGroupId [Name_Vehicle_Group_2];
	MPG_Group_Column addVehicle ((assignedVehicles Group_Vehicle_2) select 0);
};


_temp_objects_sync = synchronizedObjects ORBAT_Group_Vehicle_3;

if (!isNull (_temp_objects_sync select 0)) then 
{
	Group_Vehicle_3 = group (_temp_objects_sync select 0);
	Selected_Vehicle_list set [3, Group_Vehicle_3];
	Elements_Vehicle_Positions_Table set [3, Group_Vehicle_3];
	Name_Vehicle_Group_3 = (([missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "4vehicle"] call BIS_fnc_ORBATGetGroupParams) select 2);
	
	_maingun_exist = getNumber (missionConfigFile >> "CfgORBAT" >> "1company" >> "1platoon" >> "vhsquad" >> "4vehicle" >> "maingun");
	if (_maingun_exist == 1) then {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_3, true]}
	else {MPG_Vehicles_MainGun_Table set [Name_Vehicle_Group_3, false]};
	
	Group_Vehicle_3 setGroupId [Name_Vehicle_Group_3];
	MPG_Group_Column addVehicle ((assignedVehicles Group_Vehicle_3) select 0);
};







[Selected_list, "INFANTRY"] call MPG_fnc_listInit;














//**************************VEHICLES*********************************************************

//Selected_Vehicle_list = [Group_Vehicle_0, Group_Vehicle_1, Group_Vehicle_2, Group_Vehicle_3];


//ONLY IF ALL VEHICLES EXISTS******************************************

if (count Selected_Vehicle_list == 4) then

{

//Values: NO_EXIST / HALT / STOP / MOVING

MPG_Group_Column_Status = "NO_EXIST";

MPG_Group_Column_Last_Status = "NO_EXIST";

//Table of postions of each vehicle group in the formation  0/1/2/3/

//Elements_Vehicle_Positions_Table = [Group_Vehicle_0, Group_Vehicle_1, Group_Vehicle_2, Group_Vehicle_3];


//Hash table to keep the assigned vehicle to each group in the organization
//now initialized by default it will be do using logic modules in EDEN

/*
Groups_Assigned_Vehicle_Table = createHashMapFromArray 

[	
	[groupId Group_0, (assignedVehicles Group_Vehicle_0) select 0],  
	[groupId Group_0_0, (assignedVehicles Group_Vehicle_1) select 0], 
	[groupId Group_0_1, (assignedVehicles Group_Vehicle_2) select 0],
	[groupId Group_0_2, (assignedVehicles Group_Vehicle_3) select 0],
	[groupId Group_0_3, (assignedVehicles Group_Vehicle_3) select 0] 
	
]; 	*/



//Hash table to keep the tasking status of each Vehicle in the organization

//Values: AT_WILL / SUPRESSING / ATTACKING / WATCHING / MOVING / SHOOTING_MAINGUN / CONVOY

Groups_Vehicle_Task_Table = createHashMap;

Groups_Vehicle_Task_Table = createHashMapFromArray 

[	
	[groupId Group_Vehicle_0,"AT_WILL"],  
	[groupId Group_Vehicle_1 ,"AT_WILL"], 
	[groupId Group_Vehicle_2 ,"AT_WILL"],
	[groupId Group_Vehicle_3 ,"AT_WILL"]
];


//Hash table to keep the last tasking status of each Vehicle in the organization NO the present task

//Values: AT_WILL / SUPRESSING / ATTACKING / WATCHING / MOVING / SHOOTING_MAINGUN / CONVOY

Groups_Vehicle_Last_Task_Table = createHashMap;

Groups_Vehicle_Last_Task_Table = createHashMapFromArray 

[	
	[groupId Group_Vehicle_0,"AT_WILL"],  
	[groupId Group_Vehicle_1 ,"AT_WILL"], 
	[groupId Group_Vehicle_2 ,"AT_WILL"],
	[groupId Group_Vehicle_3 ,"AT_WILL"]
	
	
];
	

//Hash table to keep the last target assigned for each Vehicle in the organization

//Values: [distance from commander, Direction from commander]



Groups_Vehicle_Last_Target_Table = createHashMapFromArray 

[	
	[groupId Group_Vehicle_0, objNull],  
	[groupId Group_Vehicle_1, objNull], 
	[groupId Group_Vehicle_2, objNull],
	[groupId Group_Vehicle_3, objNull]

	
]; 	


//Hash table to keep the moving status of each vehicle in the organization

//STOP ==> stoped by a direct command no remaing in formation?????

//HALT == > stoped by all elements stop remaing information??????

//Values: AT_WILL / STOP / HALT / CONVOY / COVERING_INFANTRY / MOVING_TO_POSITION



Group_Vehicle_MovingMode_Table = createHashMapFromArray 


[	

	[groupId Group_Vehicle_0,"AT_WILL"],  
	[groupId Group_Vehicle_1 ,"AT_WILL"], 
	[groupId Group_Vehicle_2 ,"AT_WILL"],
	[groupId Group_Vehicle_3 ,"AT_WILL"]
	
	
];



//Hash table to keep the last moving status of each vehicle in the organization after it changed

Group_Vehicle_Last_MovingMode_Table = createHashMapFromArray 


[	
	[groupId Group_Vehicle_0,"AT_WILL"],  
	[groupId Group_Vehicle_1 ,"AT_WILL"], 
	[groupId Group_Vehicle_2 ,"AT_WILL"],
	[groupId Group_Vehicle_3 ,"AT_WILL"]
	
	
];

//Hash table to keep the vehicles assigned initially to each group



Vehicle_Assigned_Table = createHashMapFromArray 


[	
	[groupId Group_Vehicle_0,(assignedVehicles Group_Vehicle_0) select 0],  
	[groupId Group_Vehicle_1 ,(assignedVehicles Group_Vehicle_1) select 0], 
	[groupId Group_Vehicle_2 ,(assignedVehicles Group_Vehicle_2) select 0],
	[groupId Group_Vehicle_3 ,(assignedVehicles Group_Vehicle_3) select 0]	
	
];


//Hash table to keep the crew dissembark mode ==> select 0 is commander, select 1 is gunner ==> [commander, gunner]

MPG_Group_Crew_Mode_Table = createHashMapFromArray 


[	
	[groupId Group_Vehicle_0 , [false, false]],  
	[groupId Group_Vehicle_1 , [false, false]], 
	[groupId Group_Vehicle_2 , [false, false]],
	[groupId Group_Vehicle_3 , [false, false]]	
];

//Hash table to keep the vehicle s crew original group ==> select 0 is commander, select 1 is gunner ==> [commander, gunner]


MPG_Group_Crew_last_group_Table = createHashMapFromArray 


[	
	[groupId Group_Vehicle_0, [grpNull, grpNull]],  
	[groupId Group_Vehicle_1, [grpNull, grpNull]], 
	[groupId Group_Vehicle_2, [grpNull, grpNull]], 
	[groupId Group_Vehicle_3, [grpNull, grpNull]]		
];



//**************************TEST STRUCTURES 


Type_Selected = "VEHICLE";

[Selected_Vehicle_list, "SAFE"] call MPG_fnc_listSetAwareMode;
[Selected_Vehicle_list, "FIRE_AT_WILL_KF"] call MPG_fnc_listSetROE;

Type_Selected = "INFANTRY";

/*
//Assign names for the vehicles

{
	if ((assignedVehicles _x) select 0 isKindof "tank") then 
	
		{
			Groups_Vehicle_Names_Table set [groupid _x, format ["Tank_%1",_forEachIndex + 1]] 
					
		};

	if ((assignedVehicles _x) select 0 isKindof "APC") then 
	
		{
			Groups_Vehicle_Names_Table set [groupid _x, format ["APC_%1",_forEachIndex + 1]] 
					
		};
	if ((assignedVehicles _x select 0) isKindof "car") then 
	
		{
			Groups_Vehicle_Names_Table set [groupid _x, format ["Car_%1",_forEachIndex + 1]] 
					
		};
	if ((assignedVehicles _x) select 0 isKindof "truck") then 
	
		{
			Groups_Vehicle_Names_Table set [groupid _x, format ["Truck_%1",_forEachIndex + 1]] 
					
		};

} foreach Selected_Vehicle_list;*/


//Hash table to keep the name for the menus & other tasks  to each vehicle group in the organization

Groups_Vehicle_Names_Table = createHashMapFromArray 

[	
	[groupId Group_Vehicle_0, Name_Vehicle_Group_0],  
	[groupId Group_Vehicle_1, Name_Vehicle_Group_1], 
	[groupId Group_Vehicle_2, Name_Vehicle_Group_2],
	[groupId Group_Vehicle_3, Name_Vehicle_Group_3]
	
]; 	
 	

//names for the variable vehicles in the main selection menu


(MENU_Select_Vehicles select 2) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_0];
(MENU_Select_Vehicles select 3) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_1];
(MENU_Select_Vehicles select 4) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_2];
(MENU_Select_Vehicles select 5) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_3];

//Actualize vehicles names in the  Option select menu

(MENU_Options_Select_Vehicle select 1) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_0];
(MENU_Options_Select_Vehicle select 2) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_1];
(MENU_Options_Select_Vehicle select 3) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_2];
(MENU_Options_Select_Vehicle select 4) set [0, Groups_Vehicle_Names_Table get groupId Group_Vehicle_3];


//**MARTA Military Symbols init*****************************************************



SetGroupIconsVisible [true,false];

/*

Group_0 AddGroupIcon ["b_inf",[0,0]];
Group_1 AddGroupIcon ["b_inf",[0,0]];
Group_2 AddGroupIcon ["b_inf",[0,0]];
Group_3 AddGroupIcon ["b_inf",[0,0]];
Group_4 AddGroupIcon ["b_hq",[0,0]];
Officer_Group AddGroupIcon ["b_hq",[0,0]];
 
 
Group_0 SetGroupIconParams [[1,1,1,1], Groups_Names_Table get groupId Group_0, 1, true];
Group_1 SetGroupIconParams [[1,1,1,1], Groups_Names_Table get groupId Group_1, 1, true];
Group_2 SetGroupIconParams [[1,1,1,1], Groups_Names_Table get groupId Group_2, 1, true];
Group_3 SetGroupIconParams [[1,1,1,1], Groups_Names_Table get groupId Group_3, 1, true];
Group_4 SetGroupIconParams [[1,1,1,1], Groups_Names_Table get groupId Group_4, 1, true];
Officer_Group SetGroupIconParams [[1,1,1,1], Name_commander_Group, 1, true];
*/

Group_Vehicle_0 AddGroupIcon ["b_motor_inf",[0,0]];
Group_Vehicle_1 AddGroupIcon ["b_motor_inf",[0,0]];
Group_Vehicle_2 AddGroupIcon ["b_motor_inf",[0,0]];
Group_Vehicle_3 AddGroupIcon ["b_motor_inf",[0,0]];

 
 
Group_Vehicle_0 SetGroupIconParams [[1,1,1,1], Groups_Vehicle_Names_Table get groupId Group_Vehicle_0, 1, true];
Group_Vehicle_1 SetGroupIconParams [[1,1,1,1], Groups_Vehicle_Names_Table get groupId Group_Vehicle_1, 1, true];
Group_Vehicle_2 SetGroupIconParams [[1,1,1,1], Groups_Vehicle_Names_Table get groupId Group_Vehicle_2, 1, true];
Group_Vehicle_3 SetGroupIconParams [[1,1,1,1], Groups_Vehicle_Names_Table get groupId Group_Vehicle_3, 1, true];


//**********DISABLE COLLITION AMONG VEHICLES AND INFANTRY IN THE PLATOON

{{(assignedVehicles Group_Vehicle_0) select 0 disableCollisionWith _x} foreach units _x} foreach Selected_list;
{{(assignedVehicles Group_Vehicle_1) select 0 disableCollisionWith _x} foreach units _x} foreach Selected_list;
{{(assignedVehicles Group_Vehicle_2) select 0 disableCollisionWith _x} foreach units _x} foreach Selected_list;
{{(assignedVehicles Group_Vehicle_3) select 0 disableCollisionWith _x} foreach units _x} foreach Selected_list;


//**********DISABLE COLLITION AMONG VEHICLES THEMSELF

{(assignedVehicles Group_Vehicle_0) select 0 disableCollisionWith ((assignedVehicles _x) select 0)} foreach Selected_Vehicle_list;
{(assignedVehicles Group_Vehicle_1) select 0 disableCollisionWith ((assignedVehicles _x) select 0)} foreach Selected_Vehicle_list;
{(assignedVehicles Group_Vehicle_2) select 0 disableCollisionWith ((assignedVehicles _x) select 0)} foreach Selected_Vehicle_list;
{(assignedVehicles Group_Vehicle_3) select 0 disableCollisionWith ((assignedVehicles _x) select 0)} foreach Selected_Vehicle_list;




//assign vehicle player by default

	if (((assignedVehicles Group_Vehicle_0) select 0 emptyPositions "Commander") == 1) then 

	{

		player assignAsCommander (assignedVehicles Group_Vehicle_0) select 0;
	
	}

	else 

	{

		//player assignAsCargo ((assignedVehicles Group_Vehicle_0) select 0);

	};


	//assign default vehicles

	[Selected_list, "ASSIGN"] call MPG_fnc_listSetVehicle;

	//Create menus for the vehicles addaction..

	[Selected_Vehicle_list] call MPG_fnc_vehicleInit;

	[Selected_Vehicle_list] call MPG_fnc_menuInitVehicles;


}; //END OF VEHICLES EXISTS**********************


//**************************UNITS*********************************************************




//Hash table to keep the  stance of each unit in the organization

//Values: AT_WILL / FOLLOW_COMMANDER_STANCE /

Units_Stance_Table = createHashMap;

{Units_Stance_Table set [name _x,"AT_WILL"]} forEach units group player; //to do for all groups to control




Selected_Units_list = [];

[Selected_list] call MPG_fnc_menuInitUnits;





//********************************* General init *************************/



			
//ADD ACTION MENU

player addAction 
		["Platoon CommandingMenu", {call MPG_fnc_menuShowMain;},
		nil,1.5,false,false,"","true", 50,false,"",""];

//call main menu open at start

call MPG_fnc_menuStartMain;




