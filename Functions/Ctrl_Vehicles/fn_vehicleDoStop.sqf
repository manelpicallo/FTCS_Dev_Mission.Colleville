
/*
	Author: Manel P.

	Description:
		
		Make the group to Stop 

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_type"];

	private _vehicle = assignedVehicles	_group;
	


	switch (_type) do 

	{

		case "STOP":
			
			{

				// if is allready in STOP do not nothing
				if ((Group_Vehicle_MovingMode_Table get groupId _group) != "STOP") then 
				
				{
					(driver (assignedVehicles _group select 0)) disableAI "PATH";

					//more cancel things in case a stop vs halt?????????


					//if issued a STOP but is allready in HALT don t actualize last status
					if ((Group_Vehicle_MovingMode_Table get groupId _group) == "HALT") then 

					{

						Group_Vehicle_MovingMode_Table set [groupId _group, "STOP"];
					
					}

					else 

					{
						
						Group_Vehicle_Last_MovingMode_Table set [groupId _group, Group_Vehicle_MovingMode_Table get groupId _group]; 
						Group_Vehicle_MovingMode_Table set [groupId _group, "STOP"];


					};
				
				};

			};	

		case "HALT":
			
			{
				
				// if is allready in HALT or STOP do not nothing
				if ((Group_Vehicle_MovingMode_Table get groupId _group) != "STOP") then 
				
					{
				 	
					if ((Group_Vehicle_MovingMode_Table get groupId _group) != "HALT") then

						{

							(driver (assignedVehicles _group select 0)) disableAI"PATH";
							Group_Vehicle_Last_MovingMode_Table set [groupId _group, Group_Vehicle_MovingMode_Table get groupId _group];
							Group_Vehicle_MovingMode_Table set [groupId _group, "HALT"];

						};


					};


				
			};	


		/*case "CONTINUE":
			
			{
				(driver (assignedVehicles _group select 0)) enableAI "PATH";
				Group_Vehicle_MovingMode_Table set [groupId _group, Group_Vehicle_Last_MovingMode_Table get groupId _group];						
				
			};	*/

		default { hint "No Action Description" };
				
	};		
	

	
					
	
				
				
				
			