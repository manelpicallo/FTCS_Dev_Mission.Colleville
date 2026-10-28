
/*
	Author: Manel P.

	Description:
		
		Set the ROE for vehicles
	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_list", "_type"];

private _number_selected = count _list;
private _group_leader = (_list select 0);
private _vehicle_command = ((assignedVehicles _group_leader) select 0);
private _default_speed = 40;



if (Type_Selected == "VEHICLE") then
		
	{	

		switch (_type) do 

		{

			case "SET_IN_COLUMN":

				{

				//create a convoy for all the vehicles and prepare the parameters for convoy no crazie

				// leader group first group to joint => apart 
				
				useAISteeringComponent true;
				_vehicle_command setBehaviour "CARELESS";
				_vehicle_command forceSpeed _default_speed;

				//create the column group & keep the old group ensure not deleted

				_Convoy_Group = createGroup [PlayerSide, true];

				_Convoy_Group AddGroupIcon ["b_motor_inf",[0,0]];
				_Convoy_Group SetGroupIconParams [[1,1,1,1], "Column", 1, true];

				private _temp_GroupID = groupId _group_leader;
				(units _group_leader) joinSilent _Convoy_Group;
				waituntil {(count units _group_leader) == 0;};
				deleteGroup _group_leader;
				_temp_group = createGroup [PlayerSide, true];
				_temp_group setGroupId [_temp_GroupID];
				Selected_Vehicle_list set [0, _temp_group];
				_group_leader = (_list select 0);

				{	
						 
					[_x, "SET_IN_COLUMN", _Convoy_Group, 15, -1, -1, [], (_foreachindex + 1 )] call MPG_fnc_vehicleSetConvoy; 
					
				}foreach (_list - [_group_leader]);

				sleep 2;

				_Convoy_Group  setformation "COLUMN";

			};


			case "SET_OUT_COLUMN":

				{


					
				{	
						 
					[_x, "SET_OUT_COLUMN", _Convoy_Group, 15, -1, -1, [], (_foreachindex + 1 )] call MPG_fnc_vehicleSetConvoy; 
					
				}foreach (_list - [_group_leader]);

				sleep 2;


				};

			default { hint "No Action Description" };

		};
	

	};
	


if (Type_Selected == "INFANTRY") then

	{
					//
	};		
				
			
