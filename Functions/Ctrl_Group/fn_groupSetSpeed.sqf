
/*
	Author: Manel P.

	Description:
		
		Make the group to  fire at will

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_type", "_factor"];


switch (_type) do 

	{

		case "FULL":
			
			{
				_group setSpeedMode "FULL";
				{_x forceSpeed (_x GetSpeed "FAST");} foreach units _group;

				Groups_Last_SpeedMode_Table set [groupID _group, Groups_SpeedMode_Table get (groupID _group)];
				Groups_SpeedMode_Table set [groupID _group, "FULL"];

			};	


		case "NORMAL":
			
			{
				_group setSpeedMode "NORMAL";
				{_x forceSpeed ((_x GetSpeed "NORMAL")/_factor);} foreach units _group;
				
				Groups_Last_SpeedMode_Table set [groupID _group, Groups_SpeedMode_Table get (groupID _group)];
				Groups_SpeedMode_Table set [groupID _group, "NORMAL"];
				
			};

		case "LIMITED":
			
			{
				_group setSpeedMode "LIMITED";	
				{_x forceSpeed (_x GetSpeed "SLOW");} foreach units _group;

				Groups_Last_SpeedMode_Table set [groupID _group, Groups_SpeedMode_Table get (groupID _group)];
				Groups_SpeedMode_Table set [groupID _group, "LIMITED"];

			};		

		default { hint "No Action Description" };
				
	};	
