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


    case "FILE": {
        /*
            FILE Layout (Platoon Level):
            [X] = Platoon Leader / Commander (Anchor point)
            0-4 = Main Body File
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
            1,0,2 = Main Assault Line (0 is centered directly ahead of Leader, 1 on left, 2 on right)
            3,4   = Center Axis Reserve Line (3 directly behind Leader, 4 deep reserve behind 3)
            5,6,7 = Front Security / Advanced Scouts (5 ahead of 0, 6 ahead of 1, 7 ahead of 2)
            8,9   = Close Protection to Leader (Left / Right)
            10,11 = Outer Wings / Flank Protection

                              6               5               7
                              |               |               |
                         1 (Squad Left) ----- 0 (Center) ----- 2 (Squad Right)
                                              |
                                             [X] (Leader Anchor)
                                           8 -|- 9 (Close Guards)
                 10 (Outer Left) -------------+------------- 11 (Outer Right)
                                              |
                                              3 (Rear Reserve)
                                              |
                                              4 (Deep Reserve)
        */
        // Slot 0: Center of the main assault line, directly forward of Platoon Leader [X]
        _direction_0 = 0;
        _separate_dis_0 = _separate_dis + (_paces_rear select 0);

        // Slot 1: Left wing of the assault line (Squad Left), abreast with Slot 0
        private _sep_lat_1 = _separate_dis + (_paces_left select 0) + (_paces_right select 1);
        private _sep_long_1 = _separate_dis_0;
        private _pos1 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_sep_long_1, getDir _leader]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        // Slot 2: Right wing of the assault line (Squad Right), abreast with Slot 0
        private _sep_lat_2 = _separate_dis + (_paces_right select 0) + (_paces_left select 2);
        private _sep_long_2 = _separate_dis_0;
        private _pos2 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_sep_long_2, getDir _leader]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slot 3: Rear Reserve Line, directly behind Platoon Leader [X]
        _direction_3 = 180;
        _separate_dis_3 = _separate_dis + (_paces_front select 3);

        // Slot 4: Deep Rear Reserve / Tail, directly behind Slot 3
        _direction_4 = 180;
        _separate_dis_4 = _separate_dis_3 + _separate_dis + (_paces_rear select 3) + (_paces_front select 4);

        // Slot 5: Center Forward Scout Screen, directly ahead of Slot 0
        _direction_5 = 0;
        _separate_dis_5 = _separate_dis_0 + _separate_dis + 4;

        // Slot 6: Left Forward Scout Screen, directly ahead of Slot 1
        private _pos6 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_5, getDir _leader]);
        _direction_6 = _leader getRelDir _pos6;
        _separate_dis_6 = _leader distance2D _pos6;

        // Slot 7: Right Forward Scout Screen, directly ahead of Slot 2
        private _pos7 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_5, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

        // Slot 8 & 9: Close flank protection to Platoon Leader [X]
        _direction_8 = 270;
        _separate_dis_8 = 2;
        _direction_9 = 90;
        _separate_dis_9 = 2;

        // Slot 10 & 11: Outer Wings / Flank Protection screens
        private _pos10 = ((_leader getRelPos [_sep_lat_1 + _separate_dis, 270]) getPos [_separate_dis_0 / 2, getDir _leader]);
        _direction_10 = _leader getRelDir _pos10;
        _separate_dis_10 = _leader distance2D _pos10;

        private _pos11 = ((_leader getRelPos [_sep_lat_2 + _separate_dis, 90]) getPos [_separate_dis_0 / 2, getDir _leader]);
        _direction_11 = _leader getRelDir _pos11;
        _separate_dis_11 = _leader distance2D _pos11;
    };

    case "WEDGE": {
        /*
            WEDGE Layout (Platoon Level - Arrowhead / V-Inverted):
            (0)   = Vanguard / Point Squad (Apex of Wedge, ahead of Leader)
            [X]   = Platoon Leader / Commander (Anchor point & Center Axis)
            (3)   = Center Rear Support Squad (Directly behind Leader)
            1,2   = Left / Right Flank Wings (Laterally flanking, between Slot 3 and 4 in distance)
            (4)   = Tail / Reserve Security Squad (Directly behind Slot 3, rearmost element)
            5,6,7 = Forward Scout Screens (Screening ahead of Point 0)
            8,9   = Close Rear Protection to Leader
            10,11 = Extended Outer Flank Guards (Central Axis Screen)

                      6 ----------- 5 ----------- 7  <-- Forward Scout Screen
                                   |
                                  (0)                <-- Point / Vanguard Squad
                                   |
                                  [X]                <-- Platoon Leader Anchor
                                 8-|-9
                                  (3)                <-- Center Support Squad
                               .       .
                             (1)         (2)         <-- Flank Wings (Between Slot 3 and 4)
                           .               .
            10 -----------+-----------------+----------- 11
                                   |
                                  (4)                <-- Tail Security Squad (Rearmost)
        */
        _separate_dis_0 = _separate_dis * 2 + (_paces_rear select 0);
        _direction_0 = 0;

        // Slot 3: Center Rear Support Squad, directly behind Leader [X]
        _direction_3 = 180;
        _separate_dis_3 = _separate_dis + (_paces_front select 3);

        // Slot 4: Tail / Reserve Security Squad, directly behind Slot 3
        _direction_4 = 180;
        _separate_dis_4 = _separate_dis_3 + _separate_dis + (_paces_rear select 3) + (_paces_front select 4);

        // Slots 1 & 2: Flank Wings of the Wedge, positioned laterally but longitudinally exactly 5m behind Slot 3
        private _long_dist_wings = _separate_dis_3 + 5;
        private _separate_lat_wings = _separate_dis * 2.5;

        private _pos1 = ((_leader getRelPos [_separate_lat_wings, 270]) getPos [_long_dist_wings, (getDir _leader) - 180]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        private _pos2 = ((_leader getRelPos [_separate_lat_wings, 90]) getPos [_long_dist_wings, (getDir _leader) - 180]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slots 5, 6 & 7: Forward Scout Screens, advanced 35m further forward (15m + 20m)
        _direction_5 = 0;
        _separate_dis_5 = (_separate_dis * 3) + 35;

        private _separate_lat_scouts = _separate_dis * 3;
        private _separate_long_scouts = _separate_dis_5;

        private _pos6 = ((_leader getRelPos [_separate_lat_scouts, 270]) getPos [_separate_long_scouts, getDir _leader]);
        _direction_6 = _leader getRelDir _pos6;
        _separate_dis_6 = _leader distance2D _pos6;

        private _pos7 = ((_leader getRelPos [_separate_lat_scouts, 90]) getPos [_separate_long_scouts, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;
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
            VEE Layout (Platoon Level - V Shape / Wings Forward):
            1,2   = Left / Right Forward Spearhead Wings (Ahead of Leader)
            [X]   = Platoon Leader / Commander (Center Pocket Axis)
            0     = Follow-up Squad (5m directly behind Leader)
            3     = Center Rear Support Squad (directly behind Slot 0)
            4     = Tail Security Squad (directly behind Slot 3)
            5     = Forward Advanced Scout Screen (35m forward)
            6, 7  = Front Flank Scouts / Security Screen (35m forward, ahead of 1 & 2)
            8, 9  = Close Rear Protection to Leader
            10,11 = Extended Outer Flank Guards (Central Axis Screen)

                      6 ----------- 5 ----------- 7  <-- Advanced Scout Screen (+35m)
                                   |
                             (1)       (2)           <-- Wings Forward
                                .     .
                                  [X]                <-- Leader in the Pocket
                                   |
                                  (0)                <-- Slot 0 (5m behind Leader)
                                 8-|-9
            10 -------------------(3)------------------- 11
                                   |
                                  (4)                <-- Tail Security
        */
        // Slot 0: Positioned 5m directly behind Platoon Leader [X]
        _direction_0 = 180;
        _separate_dis_0 = 5;

        // Slots 1 & 2: Forward Wings of the Vee, advanced forward on the flanks
        private _sep_lat_vee = (_separate_dis * 1.5 + 20) * 0.7071;
        private _sep_long_vee = ((_separate_dis * 1.5 + 20) * 0.7071) + 5;

        private _pos1 = ((_leader getRelPos [_sep_lat_vee, 270]) getPos [_sep_long_vee, getDir _leader]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        private _pos2 = ((_leader getRelPos [_sep_lat_vee, 90]) getPos [_sep_long_vee, getDir _leader]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slot 3: Center Rear Support Squad, directly behind Slot 0
        _direction_3 = 180;
        _separate_dis_3 = _separate_dis_0 + _separate_dis + (_paces_front select 3);

        // Slot 4: Tail / Reserve Security Squad, directly behind Slot 3
        _direction_4 = 180;
        _separate_dis_4 = _separate_dis_3 + _separate_dis + (_paces_rear select 3) + (_paces_front select 4);

        // Slots 5, 6 & 7: Forward Scout Screens, advanced 35m further forward (15m + 20m)
        _direction_5 = 0;
        _separate_dis_5 = (_separate_dis * 3) + 35;

        private _sep_lat_scouts = _separate_dis * 3;
        private _sep_long_scouts = _separate_dis_5;

        private _pos6 = ((_leader getRelPos [_sep_lat_scouts, 270]) getPos [_sep_long_scouts, getDir _leader]);
        _direction_6 = _leader getRelDir _pos6;
        _separate_dis_6 = _leader distance2D _pos6;

        private _pos7 = ((_leader getRelPos [_sep_lat_scouts, 90]) getPos [_sep_long_scouts, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

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
            0     = Vanguard Point (Ahead of Leader)
            1,2   = Left / Right Flank Guards (Flanking Leader)
            3     = Rear Guard (Directly behind Leader)
            4     = Command Reserve / Tail
            5     = Forward Advanced Scout
            6, 7  = Outer Forward Screen
            8, 9  = Close Guards to Leader
            10,11 = Extended Outer Flank Guards (Central Axis Screen)

                      6 ----------- 5 ----------- 7
                                   |
                                  (0)
                               .       .
                        (1)       [X]       (2)
            10 -----------+--------+--------+----------- 11
                                 8-|-9
                                  (3)
                                   |
                                  (4)
        */
        _separate_dis_0 = _separate_dis * 2;
        _direction_0 = 0;

        _separate_dis_1 = _separate_dis * 1.5;
        _direction_1 = 270;

        _separate_dis_2 = _separate_dis * 1.5;
        _direction_2 = 90;

        _separate_dis_3 = _separate_dis * 1.5;
        _direction_3 = 180;

        _separate_dis_4 = _separate_dis * 2.5;
        _direction_4 = 180;

        _separate_dis_5 = _separate_dis * 3;
        _direction_5 = 0;

        private _separate_lat_diamond = _separate_dis * 3;
        private _separate_long_diamond = _separate_dis_5;

        private _pos6 = ((_leader getRelPos [_separate_lat_diamond, 270]) getPos [_separate_long_diamond, getDir _leader]);
        _direction_6 = _leader getRelDir _pos6;
        _separate_dis_6 = _leader distance2D _pos6;

        private _pos7 = ((_leader getRelPos [_separate_lat_diamond, 90]) getPos [_separate_long_diamond, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;
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
// Every slot 0 to 11 always receives its theoretical template coordinates [_dist, _dir, _assignedGroup],
// allowing all 12 slots to be tracked / visualized on the map in debug mode, even if no group is currently assigned (grpNull).
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

    private _assignedGroup = if (_forEachIndex < count _formation_elements && {count (_formation_elements select _forEachIndex) > 0}) then {
        (_formation_elements select _forEachIndex) select 0
    } else {
        grpNull
    };

    // Store pure relative polar coordinates: distance and relative angle (0 to 360) from commander's heading
    Platoon_Formation_Position_List set [_forEachIndex, [_dist, _dir, _assignedGroup]];
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

        // Update 2D tactical map NATO icon text to display assigned formation slot (0-11)
        private _grpObj = (_x select 0);
        private _slotDist = (Platoon_Formation_Position_List select _forEachIndex) select 0;
        private _slotBearing = (Platoon_Formation_Position_List select _forEachIndex) select 1;

        private _isDebug = missionNamespace getVariable ["FTCS_Debug_Mode", false];
        if (_isDebug) then {
            _grpObj setGroupIconParams [[0.55, 0.55, 0.55, 1.0], format ["[Slot %1] %2", _forEachIndex, groupId _grpObj], 1.0, true];
            systemChat format ["[FORMATION SLOT %1] %2 -> %3m at %4° (Leader: %5)", _forEachIndex, _elementID, round _slotDist, round _slotBearing, name (leader (_x select 0))];
        } else {
            _grpObj setGroupIconParams [[0.55, 0.55, 0.55, 1.0], groupId _grpObj, 1.0, true];
        };

        _list pushBack (_x select 0);

        // Resolve squad formation according to operational phase & macro platoon geometry:
        // PHASE 1 (APPROACH / CARELESS): Squads adapt marching file/column geometry.
        // In WEDGE / VEE formations, squads on the right flank adopt ECHELON_RIGHT,
        // squads on the left flank adopt ECHELON_LEFT, and centerline squads use COLUMN.
        // PHASE 2 & 3 (CONTACT LIKELY / COMBAT / AWARE): Squads retain authentic tactical
        // formations (WEDGE, LINE, etc.) allowing soldiers to fan out with 360 security.
        private _slotBearing = (Platoon_Formation_Position_List select _forEachIndex) select 1;
        private _entryFormation = _entry getOrDefault ["formationType", ""];
        
        // Resolve platoon operational phase (1: Approach, 2: Overwatch, 3: Combat)
        private _platoonPhase = missionNamespace getVariable ["FTCS_CurrentPhase", 1];
        if (!isNull _leader) then {
            private _uVar = vehicleVarName _leader;
            if (_uVar != "" && {_uVar find "PLT_" >= 0}) then {
                private _parts = _uVar splitString "_";
                private _pIdx = _parts find "PLT";
                if (_pIdx >= 0 && {count _parts > _pIdx + 1}) then {
                    private _parsedPlt = parseNumber (_parts select (_pIdx + 1));
                    if (_parsedPlt > 0) then {
                        _platoonPhase = missionNamespace getVariable [format ["FTCS_Platoon_Phase_%1", _parsedPlt], _platoonPhase];
                    };
                };
            };
        };

        private _type_formation = if (_platoonPhase == 1) then {
            // PHASE 1: APPROACH -> Adaptive Echelon / Column for non-combat march
            switch (_formation_type) do {
                case "WEDGE": {
                    if (_slotBearing > 0 && _slotBearing < 180) then { "ECHELON_RIGHT" }
                    else { if (_slotBearing > 180 && _slotBearing < 360) then { "ECHELON_LEFT" } else { "COLUMN" } };
                };
                case "VEE": {
                    if (_slotBearing > 0 && _slotBearing < 180) then { "ECHELON_RIGHT" }
                    else { if (_slotBearing > 180 && _slotBearing < 360) then { "ECHELON_LEFT" } else { "COLUMN" } };
                };
                case "LINE": { "COLUMN" };
                default { "COLUMN" };
            };
        } else {
            // PHASE 2 & 3: CONTACT LIKELY / OVERWATCH & COMBAT -> Standard Tactical Squad Formations
            if (_entryFormation != "") then {
                _entryFormation
            } else {
                switch (_formation_type) do {
                    case "LINE": { "LINE" };
                    default { "WEDGE" };
                };
            };
        };

        // Recursive call to squad formation function for internal team deployment
        // In relative mode, fireteams align relative to their Squad Leader's heading
        if ((count _x) > 1) then {
            [_x, _type_formation, _local_elements_separation, 0] call FTCS_fnc_formationsTypeSquadSet;
        };
    };
} forEach _formation_elements;

// Return follower list for external command execution
_list