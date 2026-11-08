
_title = "<t>No Selected</t>";

if (count Selected_Vehicle_list == 1) then 

	{
		_title = format ["%1",Groups_Vehicle_Names_Table get (groupid (Selected_Vehicle_list select 0))];
	}
	
	else
	
	{ 
		
		if (({(Group_Vehicle_MovingMode_Table get (groupId _x)) == "CONVOY"} count Selected_Vehicle_list) == 0) then

		{ 

			_title = "<t>All Vehicles</t>"

		}

		else 
		
		{

			_title = "<t>Convoy</t>"

		};
		
		
	};

(uiNamespace getVariable ["RscMainTitle", displayNull] displayCtrl 1101) ctrlSetStructuredText parseText _title;

