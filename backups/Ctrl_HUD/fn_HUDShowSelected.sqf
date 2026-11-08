

_title = "<t>No Selected</t>";

if (count Selected_list == 1) then 

	{
		_title = format ["%1",Groups_Names_Table get (groupid (Selected_list select 0))];
	}
	
	else { _title = "<t>All Squads</t>"};

(uiNamespace getVariable ["RscMainTitle", displayNull] displayCtrl 1101) ctrlSetStructuredText parseText _title;

