

_title = formatText ["%1", "No Init"];


if (count Selected_Units_list == 1) then 

	{
		private _unit = (Selected_Units_list select 0);
		private _rank = rank _unit;
		private _name = text (name _unit); 

		switch (_rank) do 

			{

				case "PRIVATE":

				
				{_title = formatText ["%1 %2", image "a3\ui_f\data\gui\cfg\ranks\private_gs.paa", _name]};

				case "CORPORAL":

				{_title = formatText ["%1 %2", image "a3\ui_f\data\gui\cfg\ranks\corporal_gs.paa", _name]};
				
				case "SERGEANT":

				{_title = formatText ["%1 %2", image "a3\ui_f\data\gui\cfg\ranks\sergeant_gs.paa", _name]};
				
				case "LIEUTENANT":

				{_title = formatText ["%1 %2", image "a3\ui_f\data\gui\cfg\ranks\lieutenant_gs.paa", _name]};
				
				case "CAPTAIN":

				{_title = formatText ["%1 %2", image "a3\ui_f\data\gui\cfg\ranks\captain_gs.paa", _name]};
				
				case "MAJOR":

				{_title = formatText ["%1 %2", image "a3\ui_f\data\gui\cfg\ranks\major_gs.paa", _name]};
				
				case "COLONEL":

				{_title = formatText ["%1 %2", image "a3\ui_f\data\gui\cfg\ranks\colonel_gs.paa", _name]};
				
				default {_title = formatText ["  %1", _name]};
			
			};


	}
	
	else {_title = formatText ["%1", "No Selected"]};

(uiNamespace getVariable ["RscMainTitle", displayNull] displayCtrl 1101) ctrlSetStructuredText  _title;
