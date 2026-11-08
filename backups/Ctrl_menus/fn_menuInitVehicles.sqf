
/*
	Author: Manel P.

	Description:
	
*/

params ["_list"];



		
{
		
	private _group_crew_name = format ["<t color = ""#FFFF00"">Select %1</t>", Groups_Vehicle_Names_Table get (groupID _x)];
	private _vehicle = (assignedVehicles _x) select 0;

	_vehicle addAction [_group_crew_name, {Type_Selected = "VEHICLE";  Selected_Vehicle_list = [group (_this select 0)]; call MPG_fnc_menuShowMain;}, nil,1.8,
				true,false,"","MPG_Group_Column_Status == ""NO_EXIST""", 50, false,"",""];


	_vehicle addAction ["Column", {Type_Selected = "VEHICLE";  Selected_Vehicle_list = [group (_this select 0)]; call MPG_fnc_menuShowMain;}, nil,1.8,
				true,false,"","MPG_Group_Column_Status != ""NO_EXIST""", 50, false,"",""];


} foreach _list;