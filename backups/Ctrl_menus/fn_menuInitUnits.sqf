
/*
	Author: Manel P.

	Description:
	
*/

params ["_list"];



		
{

 	{
 		private _unit_name = format ["<t color = ""#FFFF00"">Select %1</t>", name _x];
		private _group_name = format ["<t color = ""#FFFF00"">Select %1</t>", Groups_Names_Table get (groupID (group _x))];
		
		private _leader_group = (Groups_Rel_Position_Table get ((groupID (group _x)))) select 2;

		private _Element_name = format ["<t color = ""#FFFF00"">Select %1</t>", Groups_Names_Table get (groupID _leader_group)];

 		_x addAction [_unit_name, {Type_Selected = "SOLDIER"; Selected_Units_list set [0, _this select 0]; call MPG_fnc_menuShowUnits;}, nil,1.5,
				true,false,"","true", 30, false,"",""];

		_x addAction [_group_name, {Type_Selected = "INFANTRY";  Selected_list = [group (_this select 0)]; call MPG_fnc_menuShowMain;}, nil,1.8,
				true,false,"","true", 150, false,"",""];


		//Only create action to select the group leader of the present unit group if it is not the main commander group

		if (_leader_group != MPG_Group_Commander) then 

		{

			_x addAction [_Element_name, {Type_Selected = "INFANTRY"; [[(Groups_Rel_Position_Table get ((groupID (group (_this select 0))))) select 2], "INFANTRY", "ELEMENT"] call MPG_fnc_listSelect; call MPG_fnc_menuShowMain;}, nil,1.9,
				true,false,"","true", 150, false,"",""];

		};

	} foreach units _x;

} foreach _list;