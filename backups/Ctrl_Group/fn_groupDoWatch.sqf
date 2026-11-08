
/*
	Author: Manel P.

	Description:
		
		Make the group to Watch

	Parameter(s):
		0: can be one of:
			Group - Group who is ordered

			_type:

					REL_DIRECTION degree from current dir of leader (back = 180 ,Right = 90 , etc...)
					ABS_DIRECTION degree from cardinal space 0 north 180 south
					MY_DIRECTION player direction ==> poinitng a direction to watch
			
			
	Returns:
		Nothing

	Examples:
		<example>
*/

params ["_group", "_type", "_direction"];

	Private _Watch_Direction = 0;
	private _relpos = [];

	Groups_Task_Table set [groupId _group,"WATCHING"];


switch (_Type) do 

	{

		
		case "REL_DIRECTION":

			{
				
				_Watch_Direction = (_direction ) - (getDir (leader _group));
				_relpos = (leader _group) getRelPos [400,_Watch_Direction];
				units _group lookat (_relpos);
				

			};

		case "ABS_DIRECTION":

			{

			_Watch_Direction = _direction;
			_relpos = (leader _group) getRelPos [400,_Watch_Direction];
			units _group lookat (_relpos);	

			};




		case "MY_DIRECTION":

			{

			player playAction "gestureGo";

			_Watch_Direction = (getDir player) - (getDir (leader _group));
			_relpos = (leader _group) getRelPos [400,_Watch_Direction];
			units _group lookat (_relpos);	

			};



		default { hint "No Action Description" };

	};
	
				
				
				
			