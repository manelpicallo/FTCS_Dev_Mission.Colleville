
/*
	Author: Manel P.

	Description:
		
		Make the group to Stop 

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered
			_ROE -rule to apply at group
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_formation"];


	
switch (_formation) do 

	{

		case "FILE":
			
			{

				_group setFormation "FILE";	
			
			};

		case "COLUMN":
			
			{

				_group setFormation "COLUMN";	
			
			};

		case "STAG COLUMN":
			
			{

				_group setFormation "STAG COLUMN";	
			
			};

		case "LINE":
			
			{

				_group setFormation "LINE";	
			
			};

		case "ECH LEFT":
			
			{

				_group  setFormation "ECH LEFT";	
			
			};

		case "ECH RIGHT":
			
			{

				_group setFormation "ECH RIGHT";	
			
			};

		case "VEE":
			
			{

				_group  setFormation "VEE";	
			
			};

		case "WEDGE":
			
			{

				_group setFormation "WEDGE";	
			
			};

		case "DIAMOND":
			
			{

				_group setFormation "DIAMOND";	
			
			};


		default { hint "No Formation Description" };

	};
	
				
				
				
			