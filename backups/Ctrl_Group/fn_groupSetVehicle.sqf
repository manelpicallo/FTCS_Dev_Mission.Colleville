
/*
	Author: Manel P.

	Description:
		
		Make the group to Supress

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_vehicle", "_type"];


private _units = units _group;
private _number_units = count _units;
private _timer = time;
private _not_able_time_embark = 240; // 4 min to embark disembark
private _not_able_time_disembark = 90; // 1,5 min to embark disembark

	switch (_type) do 

	{

	
		case "ASSIGN":
			
			{		

				//check is enough sits available for the group in the vehicle

				//Count the sits type cargo free,for this check if ocupied ...==> select 5 of the returned array

				private _sits_cargo_free = ({isNull (_x select 5)} count fullCrew [_vehicle, "cargo", true]);

				//Count the sits type Person turret free,for this checkif ocupied ...==> select 5 & if it is person turret ==> select 4 of the returned array

				private _sits_turret_free = ({((_x select 4) == true) && (isNull (_x select 5))} count fullCrew [_vehicle, "turret", true]);
				
				private _no_commander = false;
				private _no_gunner = false;
				_sits_total_free = _sits_cargo_free + _sits_turret_free;

				//Check if commander & gunner are unassigned & if exist the position in the vehicle
				
				if (count fullCrew [_vehicle, "commander", true] == 1) then 
				
					{

						if (isNull (assignedCommander _vehicle)) then {_sits_total_free = _sits_total_free + 1; _no_commander = true;}
						else {_no_commander = false;};

					};


				if (count fullCrew [_vehicle, "gunner", true] == 1) then

					{

						if (isNull (assignedGunner _vehicle)) then {_sits_total_free = _sits_total_free + 1; _no_gunner = true;}
						else {_no_gunner = false;};

					};

				//Onces all sits free & non assigned caculated, proceed to assign the sits to the group

				if (_sits_total_free >= _number_units)  then
				
				{
					//check if commander & gunner sits available and assign it to the commander & second unit of the group

					if (_no_commander && _no_gunner) then 

					{
						hint str "NO & NO";
						leader _group assignAsCommander _vehicle;

						if (_number_units >= 2) then 

						{
							(_units select 1) assignAsGunner _vehicle;
							{_x assignAsCargo _vehicle} foreach (units _group - [leader _group, (_units select 1)]);
						};

						//If first time, commander & gunner are onboard then assign the last group for both
						//as the assigned group of the vehcile wich they are onboard

						(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [0, _group];
						(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [1, _group];
										
					};

					//check if commander free & NO gunner free sits available and assign  the commander sit to the leader group

					if (_no_commander && !_no_gunner) then 

					{
						hint str "SI & NO";			
						leader _group assignAsCommander _vehicle;

						if (_number_units >= 2) then 

						{
							{_x assignAsCargo _vehicle} foreach (units _group - [leader _group]);
						};

						//If first time, commander is onboard then assign the last group for commander
						//as the assigned group of the vehicle is  onboard

						(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [0, _group];
						
					};

					//check if NO commander free & gunner free sits available and assign  the gunner sit to the leader group
					
					if (!_no_commander && _no_gunner) then 

					{
									
						hint str "NO & SI";	
						leader _group assignAsGunner _vehicle;

						if (_number_units >= 2) then 

						{
							{_x assignAsCargo _vehicle} foreach (units _group - [leader _group]);
						};

						//If first time, gunner is onboard then assign the last group for gunner
						//as the assigned group of the vehicle is  onboard

						(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [1, _group];
						
					};

					//check if NO commander & NO gunner sits available and assign all the group as cargo ==> & by default as turret person.
				
					if (!_no_commander && !_no_gunner) then 

						

					{
						hint str "SI & SI";		
						{_x assignAsCargo _vehicle} foreach units _group;

						//If first time, commander & gunner are onboard then assign the last group for both
						//as the assigned group of the vehcile which they are onboard

						(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [0, _group];
						(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [1, _group];
					
					};
										
					
				}
				
				else 

				{
					
					(leader _group) commandchat "No sits available for all";

				};
				
			};


		case "EMBARK":
			
			{

				(units _group) AllowGetIn true;
				(units _group) orderGetIn true;

				//prevent auto dissembark, by now it is here

				_vehicle setUnloadInCombat [false, false];

				Groups_MovingMode_Table set [groupId _group, "EMBARKING"];

				_timer = time + _not_able_time_embark;		

				waitUntil {(time > _timer) || (({isNull objectParent _x} count units _group) == 0)};

				//if out of the waituntil not for timer, then get in OK, if not ==> not able to embark

				if (time < _timer) then 

				{

					(leader _group) commandchat "All boarded";
					Groups_MovingMode_Table set [groupId _group, "IN_VEHICLE"];

					//Store the group from the untis comes that will be assigned as crew, select 0 is the commander,select 1 is the gunner
					//first chech if there is a  units is in the position

					if (!isNull commander _vehicle) then 

						{	
							
							//check if the commander is already in the vehcile group, just to be sure we dont remove the original group,
							//it could happedn if 2 groups assigned to the same vehicle, or if the commander is already onboard.

							if ((group commander _vehicle != (assignedGroup _vehicle)) && (MPG_Group_Column_Status == "NO_EXIST")) then 

							{
								(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [0, group (commander _vehicle)];
							}; 
								
						};	
						

					if (!isNull gunner _vehicle) then 
					
						{	

							//check if the gunner is already in the vehcile group, just to be sure we dont remove the original group,
							//it could happedn if 2 groups assigned to the same vehicle, or if the gunner is already onboard.

							if ((group gunner _vehicle != (assignedGroup _vehicle)) && (MPG_Group_Column_Status == "NO_EXIST")) then 

							{
								(MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) set [1, group (gunner _vehicle)];
							};
					
						};


					//if is commander o gunner then .....joint the group of the vehicle crew or the complete column if it is formed
					
					If  (MPG_Group_Column_Status == "NO_EXIST") then 
					
						{
							if (!isNull commander _vehicle) then {[commander _vehicle] join (assignedGroup _vehicle)};
							if (!isNull gunner _vehicle) then {[gunner _vehicle] join (assignedGroup _vehicle)};  
						};

					If  (MPG_Group_Column_Status != "NO_EXIST") then 
					
						{
							if (!isNull commander _vehicle) then {[commander _vehicle] join MPG_Group_Column};
							if (!isNull gunner _vehicle) then {[gunner _vehicle] join MPG_Group_Column};  
						};

			
				}

				else 
				
				{

					(leader _group) commandchat "Not able to embark";
					Groups_MovingMode_Table set [groupId _group, "AT_WILL"];

				}; 
		

			};



		case "DISEMBARK":
		
			{

				

					//if he/she is commander o gunner then if is order to disembark crew then.....unjoint the group of the vehicle crew & joint the onfood group
					
					// check commander order to disembark vehicle 

					if ((MPG_Group_Crew_Mode_Table get (groupId (assignedGroup _vehicle))) select 0 == true) then

						{
							private _temp_group = (MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) select 0;
	
							if (!isNull commander _vehicle) then

							{
								[commander _vehicle] join _temp_group;
								waituntil {(group commander _vehicle) == _temp_group};
								[_temp_group, "AWARE"] call MPG_fnc_groupSetAwareMode;
								{_x doFollow leader _temp_group} foreach units _temp_group;					
							};


						}; 

					// check gunner order to disembark vehicle 

					if ((MPG_Group_Crew_Mode_Table get (groupId (assignedGroup _vehicle))) select 1 == true) then

						{
							private _temp_group = (MPG_Group_Crew_last_group_Table get (groupId (assignedGroup _vehicle))) select 1;
							
							if (!isNull gunner _vehicle) then 
							{

								[gunner _vehicle] join _temp_group;
								waituntil {(group gunner _vehicle) == _temp_group};
								[_temp_group, "AWARE"] call MPG_fnc_groupSetAwareMode;
								{_x doFollow leader _temp_group} foreach units _temp_group;

							};  
			
						}; 


					
					(units _group) orderGetIn false;
					(units _group) AllowGetIn false;
					Groups_MovingMode_Table set [groupId _group, "DISEMBARKING"];

					_timer = time + _not_able_time_disembark;

					waitUntil {(time > _timer) || (({isNull objectParent _x} count units _group) == _number_units)};

					//if out of the waituntil not for timer, then get in OK, if not ==> not able to disembark

					if (time < _timer) then 

					{

						(leader _group) commandchat "All on foot";
						Groups_MovingMode_Table set [groupId _group, "AT_WILL"];


					}

					else 
				
					{

						(leader _group) commandchat "Not able to disembark";
						Groups_MovingMode_Table set [groupId _group, "IN_VEHICLE"];

					}; 	

				

			};


		default { hint "No Action Description" };

	};