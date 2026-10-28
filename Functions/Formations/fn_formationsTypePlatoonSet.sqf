params ["_formation_elements_in", "_formation_type", "_separate_dis"];

// Copy input array by value to prevent reference mutation
private _formation_elements = +_formation_elements_in;

// Check if platoon leader element and group are present
if (count (_formation_elements select 0) == 0) exitWith { hint "FTCS Error: No Platoon leader Element present"; };
if (isNull ((_formation_elements select 0) select 0)) exitWith { hint "FTCS Error: No Platoon leader Group present"; };

private _group_leader = ((_formation_elements select 0) select 0);
private _leader = leader _group_leader;

// Remove commander group from subordinate processing list
_formation_elements deleteAt 0;

private _number_elements = count _formation_elements;

if ((_number_elements <= 0) || (_number_elements > FTCS_Platoon_MAX_Infantry_Groups)) exitWith { 
    hint str _formation_elements; 
};

private _separate_dis_0 = 0;
private _separate_dis_1 = 0;
private _separate_dis_2 = 0;
private _separate_dis_3 = 0;
private _separate_dis_4 = 0;
private _separate_dis_5 = 0;
private _separate_dis_6 = 0;
private _separate_dis_7 = 0;
private _separate_dis_8 = 0;
private _separate_dis_9 = 0;
private _separate_dis_10 = 0;
private _separate_dis_11 = 0;

private _direction_0 = 0;
private _direction_1 = 0;
private _direction_2 = 0;
private _direction_3 = 0;
private _direction_4 = 0;
private _direction_5 = 0;
private _direction_6 = 0;
private _direction_7 = 0;
private _direction_8 = 0;
private _direction_9 = 0;
private _direction_10 = 0;
private _direction_11 = 0;

private _local_elements_separation = 4;
private _Advance_dir = missionNamespace getVariable "FTCS_Platoon_Advance_Direction";            

// Helper arrays to store dynamic paces fetched from squad elements (slots 0 to 11 capacity)
private _paces_front = [0,0,0,0,0,0,0,0,0,0,0,0];
private _paces_rear = [0,0,0,0,0,0,0,0,0,0,0,0];
private _paces_right = [0,0,0,0,0,0,0,0,0,0,0,0];
private _paces_left = [0,0,0,0,0,0,0,0,0,0,0,0];

{
    if (count _x > 0) then {
        private _type_form = [groupId (_x select 0), "formationType"] call FTCS_fnc_registryGet;
        if (isNil "_type_form") then { _type_form = "COLUMN"; };
        private _paces = [_x, _type_form, _local_elements_separation] call FTCS_fnc_formationsPaceSquadGet;
        _paces_front set [_forEachIndex, _paces select 0];
        _paces_rear set [_forEachIndex, _paces select 1];
        _paces_right set [_forEachIndex, _paces select 2];
        _paces_left set [_forEachIndex, _paces select 3];
    };
} forEach _formation_elements;

switch (_formation_type) do {

    case "COLUMN": {
        /*
            COLUMN Layout (Platoon Level):
            [X] = Platoon Leader / Commander (Anchor point)
            0-4 = Main Body Column
            5   = Forward Advanced Element
            6,7 = Front Flank Scouts / Security
            8,9 = Close Rear Protection to Leader
            10,11 = Mid-Flank Security

                      6 ----- 5 ----- 7
                              |
                              0
                              |
                             [X]
                           8 -|- 9
                              1
                              |
                     10 ----- 2 ----- 11
                              |
                              3
                              |
                              4
        */
        private _paces_rear_0 = _paces_rear select 0;
        private _paces_front_0 = _paces_front select 0;
        private _paces_rear_1 = _paces_rear select 1;
        private _paces_front_1 = _paces_front select 1;
        private _paces_front_2 = _paces_front select 2;
        private _paces_rear_2 = _paces_rear select 2;
        private _paces_front_3 = _paces_front select 3;
        private _paces_rear_3 = _paces_rear select 3;
        private _paces_front_4 = _paces_front select 4;
        private _paces_rear_5 = 4;

        _separate_dis_0 = _separate_dis + _paces_rear_0;
        _direction_0 = 0;

        if ((_paces_rear_0 > 0) || (_paces_front_0 > 0)) then {
            _separate_dis_5 = _separate_dis * 2 + _paces_rear_5 + _separate_dis_0 + _paces_front_0;
        } else {
            _separate_dis_5 = _separate_dis + _paces_rear_5;
        };
        _direction_5 = 0;

        private _separate_lat_6 = _separate_dis * 3;
        private _separate_long_6 = _separate_dis_5;
        _direction_6 = (_leader getRelDir ((_leader getRelPos [_separate_lat_6, 270]) getPos [_separate_long_6, getDir _leader]));
        _separate_dis_6 = _leader distance2D ((_leader getRelPos [_separate_lat_6, 270]) getpos [_separate_long_6, getDir _leader]);

        private _separate_lat_7 = _separate_dis * 3;
        private _separate_long_7 = _separate_dis_5;
        _direction_7 = (_leader getRelDir ((_leader getRelPos [_separate_lat_7, 90]) getPos [_separate_long_7, getDir _leader]));
        _separate_dis_7 = _leader distance2D ((_leader getRelPos [_separate_lat_7, 90]) getpos [_separate_long_7, getDir _leader]);

        private _separate_lat_9 = 2;
        private _separate_long_9 = 2;
        _direction_9 = (_leader getRelDir ((_leader getRelPos [_separate_lat_9, 90]) getPos [_separate_long_9, (getDir _leader) - 180]));
        _separate_dis_9 = _leader distance2D ((_leader getRelPos [_separate_lat_9, 90]) getpos [_separate_long_9, (getDir _leader) - 180]);

        private _separate_lat_8 = 2;
        private _separate_long_8 = 2;
        _direction_8 = (_leader getRelDir ((_leader getRelPos [_separate_lat_8, 270]) getPos [_separate_long_8, (getDir _leader) - 180]));
        _separate_dis_8 = _leader distance2D ((_leader getRelPos [_separate_lat_8, 270]) getpos [_separate_long_8, getDir _leader]);

        _separate_dis_1 = (_separate_dis / 2) + _paces_front_1;
        _direction_1 = 180;

        if ((_paces_front_1 > 0) || (_paces_rear_1 > 0)) then {
            _separate_dis_2 = _separate_dis_1 + _paces_rear_1 + _paces_front_2 + _separate_dis;
        } else {
            _separate_dis_2 = _separate_dis_1;
        };
        _direction_2 = 180;

        private _separate_lat_10 = _separate_dis * 3;
        private _separate_long_10 = _separate_dis_2;
        _direction_10 = (_leader getRelDir ((_leader getRelPos [_separate_lat_10, 270]) getPos [_separate_long_10, getDir _leader - 180]));
        _separate_dis_10 = _leader distance2D ((_leader getRelPos [_separate_lat_10, 270]) getpos [_separate_long_10, getDir _leader - 180]);

        private _separate_lat_11 = _separate_dis * 3;
        private _separate_long_11 = _separate_dis_2;
        _direction_11 = (_leader getRelDir ((_leader getRelPos [_separate_lat_11, 90]) getPos [_separate_long_11, getDir _leader - 180]));
        _separate_dis_11 = _leader distance2D ((_leader getRelPos [_separate_lat_11, 90]) getpos [_separate_long_11, getDir _leader - 180]);

        if ((_paces_front_2 > 0) || (_paces_rear_2 > 0)) then {
            _separate_dis_3 = _separate_dis_2 + _paces_rear_2 + _paces_front_3 + _separate_dis;
        } else {
            _separate_dis_3 = _separate_dis_2;
        };
        _direction_3 = 180;

        if ((_paces_front_3 > 0) || (_paces_rear_3 > 0)) then {
            _separate_dis_4 = _separate_dis_3 + _paces_rear_3 + _paces_front_4 + _separate_dis;
        } else {
            _separate_dis_4 = _separate_dis_3;
        };
        _direction_4 = 180;
    };

    case "LINE": {
        /*
            LINE Layout (Platoon Level):
            [X]   = Platoon Leader / Commander (Anchor point)
            0,3,4 = Main Assault Line
            2     = Center Pivot Marker
            1     = Rear Reserve Line
            5,6,7 = Front Security / Advanced Scouts
            8,9   = Close Rear Protection to Leader
            10,11 = Outer Wings / Flank Protection

                      6       5       7
                      |       |       |
                0 ----+---- 3 ----+---- 4
                              |
                             [X]
                           8 -|- 9
                10 -----------+----------- 11
                              |
                              1
                              |
                              2
        */
        private _sep_lat_0 = _separate_dis + (_paces_right select 0);
        private _sep_long_0 = _separate_dis;
        _direction_0 = (_leader getRelDir ((_leader getRelPos [_sep_lat_0, 270]) getPos [_sep_long_0, getDir _leader]));
        _separate_dis_0 = _leader distance2D ((_leader getRelPos [_sep_lat_0, 270]) getpos [_sep_long_0, getDir _leader]);

        private _sep_lat_3 = _separate_dis + (_paces_left select 3);
        private _sep_long_3 = _separate_dis;
        _direction_3 = (_leader getRelDir ((_leader getRelPos [_sep_lat_3, 90]) getPos [_sep_long_3, getDir _leader]));
        _separate_dis_3 = _leader distance2D ((_leader getRelPos [_sep_lat_3, 90]) getpos [_sep_long_3, getDir _leader]);

        private _sep_lat_4 = (_separate_dis * 2) + _sep_lat_3 + (_paces_right select 3) + (_paces_left select 4);
        private _sep_long_4 = _separate_dis;
        _direction_4 = (_leader getRelDir ((_leader getRelPos [_sep_lat_4, 90]) getPos [_sep_long_4, getDir _leader]));
        _separate_dis_4 = _leader distance2D ((_leader getRelPos [_sep_lat_4, 90]) getpos [_sep_long_4, getDir _leader]);

        _separate_dis_2 = _sep_lat_3 + ((_sep_lat_4 - _sep_lat_3) / 2);
        _direction_2 = 90;

        private _separate_lat_8 = 2;
        private _separate_long_8 = 2;
        _direction_8 = (_leader getRelDir ((_leader getRelPos [_separate_lat_8, 270]) getPos [_separate_long_8, getDir _leader]));
        _separate_dis_8 = _leader distance2D ((_leader getRelPos [_separate_lat_8, 270]) getpos [_separate_long_8, getDir _leader]);

        private _separate_lat_9 = 2;
        private _separate_long_9 = 2;
        _direction_9 = (_leader getRelDir ((_leader getRelPos [_separate_lat_9, 90]) getPos [_separate_long_9, (getDir _leader) - 180]));
        _separate_dis_9 = _leader distance2D ((_leader getRelPos [_separate_lat_9, 90]) getpos [_separate_long_9, (getDir _leader) - 180]);

        _separate_dis_1 = _sep_lat_3;
        _direction_1 = 180;

        _separate_dis_5 = _separate_dis * 2;
        _direction_5 = 0;
        _separate_dis_6 = _separate_dis * 3;
        _direction_6 = 315;
        _separate_dis_7 = _separate_dis * 3;
        _direction_7 = 45;
        _separate_dis_10 = _separate_dis * 4;
        _direction_10 = 270;
        _separate_dis_11 = _separate_dis * 4;
        _direction_11 = 90;
    };

    case "WEDGE": {
        /*
            WEDGE Layout (Platoon Level):
            [X]   = Platoon Leader / Commander (Anchor point & Center Axis)
            0     = Vanguard / Point Squad
            1,2   = Left / Right Flank Forward Squads
            3     = Right Rear Support Squad
            4     = Tail / Reserve Security Squad
            5     = Forward Advanced Element (Scout)
            6, 7  = Front Flank Scouts / Security Screen
            8, 9  = Close Rear Protection to Leader
            10,11 = Extended Outer Flank Guards (Central Axis Screen)

                      6 ----------- 5 ----------- 7
                                   |
                                  (0)
                               .       .
                             (1)         (2)
                           .               .
            10 -----------+-------[X]------+----------- 11
                                 8-|-9
                                  (3)
                                   |
                                  (4)
        */
        _separate_dis_0 = _separate_dis * 2;
        _direction_0 = 0;

        _separate_dis_1 = _separate_dis * 1.5;
        _direction_1 = 315;

        _separate_dis_2 = _separate_dis * 1.5;
        _direction_2 = 45;

        _separate_dis_3 = _separate_dis;
        _direction_3 = 90;

        _separate_dis_4 = _separate_dis * 2;
        _direction_4 = 180;

        _separate_dis_5 = _separate_dis * 3;
        _direction_5 = 0;
        _separate_dis_6 = _separate_dis * 3;
        _direction_6 = 315;
        _separate_dis_7 = _separate_dis * 3;
        _direction_7 = 45;
        _separate_dis_8 = 2;
        _direction_8 = 270;
        _separate_dis_9 = 2;
        _direction_9 = 90;
        _separate_dis_10 = _separate_dis * 4;
        _direction_10 = 270;
        _separate_dis_11 = _separate_dis * 4;
        _direction_11 = 90;
    };

    case "VEE": {
        /*
            VEE Layout (Platoon Level):
            [X]   = Platoon Leader / Commander (Anchor point & Center Axis)
            1,2   = Leading Spearheads (Left/Right)
            0,3   = Center Core Elements
            4     = Tail Security
            5     = Forward Advanced Scout
            6, 7  = Front Flank Screens
            8, 9  = Close Core Guards
            10,11 = Extended Outer Flank Guards (Central Axis Screen)

                      6 ----------- 5 ----------- 7
                                   |
                        (1)        |        (2)
                           .      [X]      .
            10 -----------+--------+--------+----------- 11
                             .    8|-9   .
                               (0)---(3)
                                   |
                                  (4)
        */
        _separate_dis_1 = _separate_dis * 2;
        _direction_1 = 330;

        _separate_dis_2 = _separate_dis * 2;
        _direction_2 = 30;

        _separate_dis_0 = _separate_dis;
        _direction_0 = 180;

        _separate_dis_3 = _separate_dis;
        _direction_3 = 180;

        _separate_dis_4 = _separate_dis * 2.5;
        _direction_4 = 180;

        _separate_dis_5 = _separate_dis * 3;
        _direction_5 = 0;
        _separate_dis_6 = _separate_dis * 3;
        _direction_6 = 315;
        _separate_dis_7 = _separate_dis * 3;
        _direction_7 = 45;
        _separate_dis_8 = 2;
        _direction_8 = 270;
        _separate_dis_9 = 2;
        _direction_9 = 90;
        _separate_dis_10 = _separate_dis * 4;
        _direction_10 = 270;
        _separate_dis_11 = _separate_dis * 4;
        _direction_11 = 90;
    };

    case "DIAMOND": {
        /*
            DIAMOND Layout (Platoon Level):
            [X]   = Platoon Leader / Commander (Anchor point & Center Axis)
            1     = Vanguard Point
            2,3   = Left / Right Flank Guards
            0     = Rear Guard
            4     = Command Reserve / Tail
            5     = Forward Advanced Scout
            6, 7  = Outer Forward Screen
            8, 9  = Close Guards to Leader
            10,11 = Extended Outer Flank Guards (Central Axis Screen)

                      6 ----------- 5 ----------- 7
                                   |
                                  (1)
                               .       .
                        (2)       [X]       (3)
            10 -----------+--------+--------+----------- 11
                                 8-|-9
                                  (0)
                                   |
                                  (4)
        */
        _separate_dis_1 = _separate_dis * 2;
        _direction_1 = 0;

        _separate_dis_2 = _separate_dis * 1.5;
        _direction_2 = 270;

        _separate_dis_3 = _separate_dis * 1.5;
        _direction_3 = 90;

        _separate_dis_0 = _separate_dis * 1.5;
        _direction_0 = 180;

        _separate_dis_4 = _separate_dis * 2.5;
        _direction_4 = 180;

        _separate_dis_5 = _separate_dis * 3;
        _direction_5 = 0;
        _separate_dis_6 = _separate_dis * 3;
        _direction_6 = 315;
        _separate_dis_7 = _separate_dis * 3;
        _direction_7 = 45;
        _separate_dis_8 = 2;
        _direction_8 = 270;
        _separate_dis_9 = 2;
        _direction_9 = 90;
        _separate_dis_10 = _separate_dis * 4;
        _direction_10 = 270;
        _separate_dis_11 = _separate_dis * 4;
        _direction_11 = 90;
    };

    default { 
        hint "FTCS Warning: Unknown platoon formation type"; 
    };
};

// Update Platoon Formation Position List global registry (0 to 11 slots)
{
    private _dist = switch (_forEachIndex) do {
        case 0: { _separate_dis_0 }; case 1: { _separate_dis_1 }; case 2: { _separate_dis_2 };
        case 3: { _separate_dis_3 }; case 4: { _separate_dis_4 }; case 5: { _separate_dis_5 };
        case 6: { _separate_dis_6 }; case 7: { _separate_dis_7 }; case 8: { _separate_dis_8 };
        case 9: { _separate_dis_9 }; case 10: { _separate_dis_10 }; case 11: { _separate_dis_11 };
        default { 0 };
    };

    private _dir = switch (_forEachIndex) do {
        case 0: { _direction_0 }; case 1: { _direction_1 }; case 2: { _direction_2 };
        case 3: { _direction_3 }; case 4: { _direction_4 }; case 5: { _direction_5 };
        case 6: { _direction_6 }; case 7: { _direction_7 }; case 8: { _direction_8 };
        case 9: { _direction_9 }; case 10: { _direction_10 }; case 11: { _direction_11 };
        default { 0 };
    };

    if (_forEachIndex < count _formation_elements && {count (_formation_elements select _forEachIndex) > 0}) then {
        Platoon_Formation_Position_List set [_forEachIndex, [_dist, _dir + _Advance_dir, ((_formation_elements select _forEachIndex) select 0)]];
    };
} forEach Platoon_Formation_Position_List;

// Register relative positions in the master registry and trigger recursive squad formation
private _list = [];

{
    if ((count _x) > 0) then {
        private _elementID = groupId (_x select 0);

        // Update encapsulated registry entry (geometry slots in one place)
        private _entry = FTCS_Groups_Registry_Table getOrDefault [_elementID, createHashMap];
        private _formPos = _entry getOrDefault ["formationPosition", [-1, -1, objNull]];
        private _relPos = _entry getOrDefault ["relPosition", [-1, -1, objNull]];
        _formPos set [0, (Platoon_Formation_Position_List select _forEachIndex) select 0];
        _formPos set [1, (Platoon_Formation_Position_List select _forEachIndex) select 1];
        _formPos set [2, _group_leader];
        _relPos set [0, (Platoon_Formation_Position_List select _forEachIndex) select 0];
        _relPos set [1, (Platoon_Formation_Position_List select _forEachIndex) select 1];
        _relPos set [2, _group_leader];
        _entry set ["formationPosition", _formPos];
        _entry set ["relPosition", _relPos];
        _entry set ["allocationSlot", _forEachIndex];
        FTCS_Groups_Registry_Table set [_elementID, _entry];

        _list pushBack (_x select 0);

        private _type_formation = _entry getOrDefault ["formationType", "COLUMN"];

        // Recursive call to squad formation function for internal team deployment
        if ((count _x) > 1) then {
            [_x, _type_formation, _local_elements_separation, missionNamespace getVariable "FTCS_Platoon_Advance_Direction"] call FTCS_fnc_formationsTypeSquadSet;
        };
    };
} forEach _formation_elements;

// Return follower list for external command execution
_list