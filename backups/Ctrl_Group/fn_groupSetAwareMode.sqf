
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

params ["_group", "_mode"];

private _temp_current_aware_mode = Groups_AwareMode_Table get (groupID _group); 

switch (_mode) do 

	{


		case "STAY_CALM":
			
			{

				{_x disableAI "TARGET";_x disableAI "AUTOCOMBAT"} foreach units _group;

			};

			
		case "STAY_READY":
			
			{

				{_x disableAI "TARGET"; _x enableAI "AUTOCOMBAT"} foreach units _group;

			};

		case "CARELESS":
			
			{
				
				{

					_x disableAI "TARGET";
					_x disableAI "AUTOCOMBAT";
					_x enableAI "AUTOTARGET";
					_x enableAI "SUPPRESSION";
					_x enableAI "COVER";
					
				} forEach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;
				
				_group setBehaviour "SAFE";	

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "CARELESS"];
				
			
			};

		case "SAFE":
			
			{
				
				{

					_x disableAI "TARGET";
					_x disableAI "AUTOCOMBAT";
					_x enableAI "AUTOTARGET";
					_x enableAI "SUPPRESSION";
					_x enableAI "COVER";
					
				} forEach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				_group setBehaviour "SAFE";

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "SAFE"];

			};
			

		case "AWARE_RIFLE_DOWN":
			
			{
	

				{

					_x disableAI "TARGET";
					_x disableAI "AUTOCOMBAT";
					_x enableAI "AUTOTARGET";
					_x enableAI "SUPPRESSION";
					_x enableAI "COVER";
					
				} forEach units _group;

				_group setBehaviour "SAFE";
				{_x setUnitPos "UP";} forEach units _group;
				{waituntil {(Unitpos _x) isEqualTo "Up"};} Foreach units _group;				
				{waituntil {weaponLowered _x};} Foreach units _group; //======>>> TARDA!!!!!no en el INI
				_group setBehaviour "AWARE";

				//[_group, "AUTO"] call MPG_fnc_groupSetStance;

				

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "AWARE_RIFLE_DOWN"];
			
			};



		case "SHARP":
			
			{
	
				{

					_x disableAI "TARGET";
					_x enableAI "AUTOCOMBAT";
					_x enableAI "AUTOTARGET";
					_x enableAI "SUPPRESSION";
					_x enableAI "COVER";
					
				} forEach units _group;

				[_group, "FOLLOW_COMMANDER_STANCE"] spawn MPG_fnc_groupSetStance;


				_group setBehaviour "AWARE";

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "SHARP"];
				
			};

		case "AWARE":
			
			{
	
				{

					_x disableAI "TARGET";
					_x disableAI "AUTOCOMBAT";
					_x enableAI "AUTOTARGET";
					_x enableAI "SUPPRESSION";
					_x enableAI "COVER";
					
				} forEach units _group;

				[_group, "FOLLOW_COMMANDER_STANCE"] spawn MPG_fnc_groupSetStance;

				_group setBehaviour "AWARE";

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "AWARE"];
				
			};
	

		case "COMBAT":
			
			{

				{
					_x disableAI "TARGET";
					_x enableAI "AUTOTARGET";
					_x enableAI "SUPPRESSION";
					_x enableAI "COVER";
				
				} forEach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				_group setBehaviourStrong "COMBAT";

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "COMBAT"];

			};


		case "STEALTH":
			
			{

				{
					_x disableAI "TARGET";
					_x enableAI "AUTOTARGET";
					_x enableAI "SUPPRESSION";
					_x enableAI "COVER";
				
				} forEach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				_group setBehaviourStrong "STEALTH";

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "STEALTH"];

			};	


		case "FAST_RETREAT":
			
			{
	
				{

					_x disableAI "TARGET";
					_x disableAI "AUTOTARGET";
					_x disableAI "SUPPRESSION";
					_x disableAI "COVER";
					_x disableAI "AUTOCOMBAT";

				} forEach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				_group setBehaviourStrong  "AWARE";

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "FAST_RETREAT"];
				
			};


		case "ASSAULT_ADVANCE":
			
			{
	
				{

					_x disableAI "TARGET";
					_x disableAI "SUPPRESSION";
					_x disableAI "COVER";
					_x disableAI "AUTOCOMBAT";

				} forEach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				_group setBehaviourStrong  "AWARE";

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "ASSAULT_ADVANCE"];
				
			};


		case "FOLLOWING_VEHICLE_SLOW":
			
			{

				{_x setUnitPos "MIDDLE"} forEach units _group;
				{waituntil {(Unitpos _x) isEqualTo "Middle"};} Foreach units _group;
				_group setCombatBehaviour "AWARE";
				_group setBehaviourStrong  "AWARE";

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				{ 
  				  _x disableAI "TARGET";
				} foreach units _group;

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "FOLLOWING_VEHICLE_SLOW"];

		
			};



		case "FOLLOWING_VEHICLE_NORMAL":
			
			{

				{_x setUnitPos "AUTO";
  				_x disableAI "TARGET";
 				_x disableAI "AUTOCOMBAT";
				} foreach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "FOLLOWING_VEHICLE_NORMAL"];
		
			};


			
		case "FOLLOWING_VEHICLE_FAST":
			
			{

				{_x setUnitPos "UP";
  				 _x disableAI "TARGET";
 				 _x disableAI "SUPPRESSION";
 				 _x disableAI "AUTOCOMBAT";
				} foreach units _group;

				[_group, "AUTO"] call MPG_fnc_groupSetStance;

				Groups_Last_AwareMode_Table set [groupID _group, Groups_AwareMode_Table get (groupID _group)];
				Groups_AwareMode_Table set [groupID _group, "FOLLOWING_VEHICLE_FAST"];			
		
			};

		default { hint "No Action Description" };

	};
	
				
				
				
			