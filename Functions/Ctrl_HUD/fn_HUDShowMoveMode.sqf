("my_layer_2" call BIS_fnc_rscLayer) cutRsc ["RscMoveMode", "PLAIN"];//create HUD to show Mode Move

private _display = (uiNamespace getVariable ["RscMoveMode", displayNull]);

private _title_1 = formatText ["Mode: %1", "No Init"];
private _title_2 = formatText ["Distance: %1 m", "No Init"];
private _title_3 = formatText ["Smoke: %1", "No Init"];
private _title_4 = formatText ["Aware: %1", "No Init"];

if (count Selected_list == 1) then 

	{
		private _mode = ((MPG_Groups_AdvanceMode_Table get (groupId (Selected_list select 0))) select 0);
		private _distance = ((MPG_Groups_AdvanceMode_Table get (groupId (Selected_list select 0))) select 1);
		private _smoke = ((MPG_Groups_AdvanceMode_Table get (groupId (Selected_list select 0))) select 2);

		_title_1 = formatText ["Mode: %1", _mode];
		_title_2 = formatText ["Distance: %1 m", _distance];
		_title_3 = formatText ["Smoke: %1", _smoke];

		private _Aware_Status = Groups_AwareMode_Table get (groupId (Selected_list select 0));

		switch (_Aware_Status) do 

			{

				case "SAFE":
				
				{_title_4 = formatText ["Aware: %1", "Safe"]};

				case "AWARE":

				{_title_4 = formatText ["Aware: %1", "Aware"]};

				case "SHARP":

				{_title_4 = formatText ["Aware: %1", "Sharp"]};

				case "COMBAT":

				{_title_4 = formatText ["Aware: %1", "Combat"]};

				case "STEALTH":

				{_title_4 = formatText ["Aware: %1", "Stealth"]};

				case "CARELESS":

				{_title_4 = formatText ["Aware: %1", "Relax"]};

				case "AWARE_RIFLE_DOWN":

				{_title_4 = formatText ["Aware: %1", "Relax"]};

				case "FOLLOWING_VEHICLE_NORMAL":

				{_title_4 = formatText ["Aware: %1", "Vehicle ????"]};

				case "FOLLOWING_VEHICLE_SLOW":

				{_title_4 = formatText ["Aware: %1", "Vehicle ????"]};

				case "FOLLOWING_VEHICLE_FAST":

				{_title_4 = formatText ["Aware: %1", "Vehicle ????"]};

				case "ASSAULT_ADVANCE":

				{_title_4 = formatText ["Aware: %1", "COMBAT"]};

				case "FAST_RETREAT":

				{_title_4 = formatText ["Aware: %1", "COMBAT"]};
				
			
				default {_title_4 = formatText ["Aware: %1", "Unknow"]};
			
			};
	}
	
	else 
	
	{ 
		_title_1 = formatText ["Mode: %1", "N/A"];
		_title_2 = formatText ["Distance: %1 m", "N/A"];
		_title_3 = formatText ["Smoke: %1", "N/A"];
		_title_4 = formatText ["Aware: %1", "N/A"];		
	};


(_display displayCtrl 1201) ctrlSetStructuredText _title_1;
(_display displayCtrl 1202) ctrlSetStructuredText _title_2;
(_display displayCtrl 1203) ctrlSetStructuredText _title_3;
(_display displayCtrl 1204) ctrlSetStructuredText _title_4;




