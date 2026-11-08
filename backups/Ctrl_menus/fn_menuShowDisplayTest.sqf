

private _displayID = findDisplay 46 createDisplay "RscDisplayTest";//create display test

uiNamespace setVariable ["_displayID", _displayID];


//Event handler button next formation
 
(_displayID displayCtrl 1100) ctrlSetText "OTRA FORMATION";

private _control_Tree = (_displayID displayCtrl 4000);

uiNamespace setVariable ["_control_Tree", _control_Tree];

//Init menus for all the elements in the formation
//the last to digits refer to the formation position 1200 ==> postion 0 / 1212 ==> position 12

for "_i" from 1200 to 1212 do 

{
	
	_control = (_displayID displayCtrl _i);

	//Picture of elements in the formation

	_control ctrlSetText "ca\ui\data\markers\b_inf.paa";


	//Enable cursor fly over detection

	_control ctrlEnable true;

	//event handlers mouse enter / exit of elements in the formation

	_control ctrlAddEventHandler ["MouseEnter", 
			
			{
				params ["_control_EH"];
				private _displayID = uiNamespace getVariable "_displayID";
				systemchat str ctrlIDC _control_EH;
				_control_EH ctrlSetTextColor [1,0.5,0,1];
				[_control_EH, 1.35, 0] call BIS_fnc_ctrlSetScale;
				 
			}];

	_control ctrlAddEventHandler ["MouseExit", 
			
			{
				params ["_control_EH"];
				private _displayID = uiNamespace getVariable "_displayID";
				systemchat "salgo ctrl area";
				[_control_EH, 1, 0] call BIS_fnc_ctrlSetScale;
				private _index = (ctrlIDC _control_EH) - 1200;
				private _IDC_text = (ctrlIDC _control_EH) - 200;

				if (count (MPG_Formation_Structure_List select _index) > 0) then 
					{
						_control_EH ctrlSetTextColor [1, 1, 1, 1];
						(_displayID displayCtrl _IDC_text ) ctrlSetTextColor [1, 1, 1, 1];

					}
				else 
					{
						_control_EH ctrlSetTextColor [1, 1, 1, 0.35];
						(_displayID displayCtrl _IDC_text ) ctrlSetTextColor [1, 1, 1, 0.35];

					};	
							 
			}];


	_control ctrlAddEventHandler ["MouseButtonUp", 
			
			{

				params ["_control_EH"];
				private _displayID = uiNamespace getVariable "_displayID";
				private _control_Tree = uiNamespace getVariable "_control_Tree";
				private _array_selected = tvCurSel _control_Tree;
				private _first_element = (_array_selected select 0);
				private _second_element = (_array_selected select 1);
				private _aux_IDC_control = (ctrlIDC _control_EH) - 200;
				private _clicked_formation_pos = _aux_IDC_control - 1000;
				private _new_group_array = []; 
				private _old_group_array = []; 

				systemchat str _array_selected;

				//gets the OLD array of groups  in the position if not present ==> _old_group_array remains empty 
				//as the leader is always in position 0 in the formation structure but not in the menus ==> + 1
				
				_old_group_array = (MPG_Formation_Structure_List select _clicked_formation_pos + 1);
						
				
				if (count (_old_group_array) == 1) then 
					
					{

						//if old group array  is just one group element it means that it is a subordinated unit and it is needed to attach it again in the formation under the new leader
						//So we need to find which element it belong in the ORBAT and attach it to that element in the formation
						
						//_main_position retrieve the first array position where the group is in
						//_subordinated_position retrieve the second array postion where the group is in

						private _main_position = -1;
						private _subordinated_position = -1;

						{
							_main_position = _foreachindex;
							_subordinated_position = (_x find (_old_group_array select 0));

							if (_subordinated_position != -1) then 

								{
									
									//Once the element has been find in the ORBAT structure it is added in the 
									//same postion to the Formation structure (+1 position 0 is  commander)

									private _group_leader = ((MPG_ORBAT_Structure_List select _main_position) select 0);
									private _index_to_attach = -1;

									{_index_to_attach = (_x find _group_leader)} foreach MPG_Formation_Structure_List;

									(MPG_Formation_Structure_List select _index_to_attach + 1) insert [_subordinated_position, (_old_group_array select 0)];

									//out of the loop

									break;
								
								};
						
						} foreach MPG_ORBAT_Structure_List;


					
					};

				if ((count _old_group_array) > 1) then 
					
					{
						//if old group array is more than one element it means that it is a main group (squad) and it is enough to remove from the list.
						//This operation will be done when adding the new group in the position
						//But probably we will need to add some flag in the menus, so this "if" could be useful

					};




				// gets the NEW group  in the formation position selected from the Tree it depends of the type array returned in the Tree

				if (count _array_selected == 1) then 

					{
						// gets the new array in the formation position selected from the Tree
						//as _array selected is 1 it measn that it is a main elemnt ==> Squad we take all the array					
						
						_new_group_array = (MPG_ORBAT_Structure_List select _first_element);
				
					};

				if (count _array_selected == 2) then 

					{	
						// gets the new element in the formation position position selected from the Tree "select (second_element + 1)" first element (0) is the squad leader	
						// and add to the array
						_new_group_array set [0, (MPG_ORBAT_Structure_List select _first_element) select (_second_element + 1)];			
					
					};


				//If the new group exist in other position, it is removed from the old position with an empty array

				{
							
					private _index_find = -1;

					_index_find = (_x find (_new_group_array select 0));

					if (_index_find != -1) then 

						{
							//if it is in postion 0 means that is a main group or a group alone, so remove all the array in the position
							// if is in another postion (not 0) it means it is a subgroup an is remove just that group.
							if (_index_find == 0) then {MPG_Formation_Structure_List deleteAt _foreachindex}
							else {(MPG_Formation_Structure_List select _foreachindex) deleteAt _index_find};

							

						};
						
				} foreach MPG_Formation_Structure_List;
				
				// Sets the new element in the formation position clicked as an array
				//as the leader is always in position 0 in the formation structure but not in the menus ==> + 1

				MPG_Formation_Structure_List set [_clicked_formation_pos + 1, _new_group_array];

				//Actualize the name in the menus Attention is not this control is the text control
				//As they have same termination ==> 1200 -200 = 1000 / 1201 - 200 = 1001

				private _name = Groups_Names_Table get (groupId (_new_group_array select 0));
				private _aux_IDC_control = (ctrlIDC _control_EH) - 200;
				systemchat str _name;
				systemchat str _aux_IDC_control;
				(_displayID displayCtrl _aux_IDC_control) ctrlSetText  _name;
				
						 
			}];

			

};

//Picture of platoon leader

(_displayID displayCtrl 1250) ctrlSetText "\A3\ui_f\data\map\mapcontrol\Chapel_CA.paa";

(_displayID displayCtrl 1250) ctrlSetTextColor [0, 0, 0, 1];


//Add the name of the Squad to each of the tree elements in the menus,

{
	 private _main_index = _foreachindex;

	{
			
		private _name = "";

		if (_foreachindex == 0) then 
			{
				_name = format ["%1", Groups_Names_Table get (groupId _x)];
				_control_Tree  tvAdd [[], _name];
				_control_Tree  tvSetPicture [[_main_index], "ca\ui\data\markers\b_inf.paa"];
			}
		else 
			{
				_name = format ["%1", Groups_Names_Table get (groupId _x)];
				_control_Tree  tvAdd [[_main_index], _name];
				
				_control_Tree  tvSetPicture [[_main_index , _foreachindex - 1], "ca\ui\data\markers\b_inf.paa"];
				
			};

		
	} foreach (MPG_ORBAT_Structure_List select _foreachindex);

} foreach MPG_ORBAT_Structure_List;

tvExpandAll _control_Tree ;
_control_Tree  tvSetCurSel [0];



{

	private _name = "";
	private _IDC_text = 1000 + _foreachindex;
	private _IDC_picture = 1200 + _foreachindex;

	//Check if the position in the formation is not an array nil

	if ((count (Platoon_Formation_Position_List select _foreachindex)) > 0) then 

		{		
			private _group = (Platoon_Formation_Position_List select _foreachindex) select 2;
			_name = Groups_Names_Table get (groupId _group);
		
		}

	else

		{
			_name = "x";
			(_displayID displayCtrl _IDC_text) ctrlSetTextColor [1, 1, 1, 0.35];
			(_displayID displayCtrl _IDC_picture) ctrlSetTextColor [1, 1, 1, 0.35];		
		};
	
	(_displayID displayCtrl _IDC_text) ctrlSetText _name;

} foreach Platoon_Formation_Position_List;

//When using the event names via GUI scripting commands (e.g ctrlAddEventHandler, displayAddEventHandler), 
//the prefix "on" in the name must be removed (e.g. ButtonDown instead of onButtonDown)!


//Event handler button next formation

private _id_1 = (_displayID displayCtrl 2480) ctrlAddEventHandler ["ButtonClick", 
			
			{
				private _displayID = uiNamespace getVariable "_displayID";
				 (_displayID displayCtrl 1100) ctrlSetText "NEXT FORMATION";				 
			}];

//Event handler button Back formation

private _id_2 = (_displayID displayCtrl 2481) ctrlAddEventHandler ["ButtonClick", 
			
			{
				private _displayID = uiNamespace getVariable "_displayID";
				 (_displayID displayCtrl 1100) ctrlSetText "PREVIOUS FORMATION";			 
			}];



