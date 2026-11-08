
/*
	Author: Manel P.

	Description:
	
*/

params ["_list_to_select", "_type_of_selection", "_type_count"];

 


			if (_type_of_selection == "INFANTRY") then

				{
					
					if (_type_count == "ALL") then

					{
						Selected_list = []; //empty array for the append
						{Selected_list append _x} foreach MPG_ORBAT_Structure_List; //Append all the array of groups in just one array
					};

					//ONLY the elements of the Military structure that are in direct controlby platoon leader
					
					if (_type_count == "PLATOON") then

					{

						Selected_list = []; //empty array for the append
						{Selected_list pushBack (_x select 0)} foreach MPG_ORBAT_Structure_List; //Insert  the  squad leaders groups  in the array								
					
					};


					if (_type_count == "ELEMENT") then

					{
						Selected_list = []; //empty array
						Selected_list = Elements_Members_Table get (groupId (_list_to_select select 0));
					};


					if (_type_count == "PARTIAL") then

					{
						Selected_list =  _list_to_select;
					};
				
				};


			if (_type_of_selection == "VEHICLE") then

				{
					Selected_Vehicle_list = _list_to_select;
				};

			if (_type_of_selection == "SOLDIER") then

				{
					Selected_Units_list = _list_to_select;
				};
  
		

		