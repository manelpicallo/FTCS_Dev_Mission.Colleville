/*
    ================================================================================
    File: fn_formationsTypePlatoonSet.sqf
    Module: Formations
    Author: M. Picallo
    Project: FTCS (First-Person Tactical Command Simulation)
    Description: Calculates and assigns relative spatial positions for each formation slot
                 within platoon-level combat formations. These positions are based on generic
                 tactical combat formations applicable to any military doctrine during
                 World War II.
                 
                 Macro Slot Allocation Overview:
                 - Slots 0, 1, 2: Dedicated to primary combat rifle squads.
                 - Slot 3: Dedicated to a 4th combat rifle squad (when present in certain
                   doctrines) or an additional weapons section (mortars or heavy machine guns).
                 - Slot 4: Dedicated to the Platoon Sergeant and accompanying support/escort troops
                   (mid-rear tactical position).
                 - Slot 5: Deep rear reserve and tail security element.
                 - Slots 6, 7, 8: Advanced scout screens.
                 - Slot 9: Dedicated to Company HQ Command Group Attachments (runners/messengers,
                   medical corpsmen, and direct-support specialists) operating in close proximity to Leader.
                 - Slot 10: Dedicated to Platoon Sergeant / Platoon Guide (Tactical Guide and rear/flank anchor).
                 - Slots 11, 12: Extended outer flank guards and peripheral security elements.
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) port.
    ================================================================================
*/

params ["_formation_elements_in", "_formation_type", "_separate_dis", ["_squad_formations_in", []]];

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
private _separate_dis_12 = 0;

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
private _direction_12 = 0;

private _local_elements_separation = 4;            

// Helper arrays to store dynamic paces fetched from squad elements (slots 0 to 12 capacity)
private _paces_front = [0,0,0,0,0,0,0,0,0,0,0,0,0];
private _paces_rear = [0,0,0,0,0,0,0,0,0,0,0,0,0];
private _paces_right = [0,0,0,0,0,0,0,0,0,0,0,0,0];
private _paces_left = [0,0,0,0,0,0,0,0,0,0,0,0,0];

{
    if (count _x > 0) then {
        // Formación específica pasada por parámetro o deducida
        private _type_form = if (_forEachIndex < count _squad_formations_in && {(_squad_formations_in select _forEachIndex) != ""}) then {
            _squad_formations_in select _forEachIndex
        } else {
            if (_formation_type in ["LINE", "ECHELON_RIGHT", "ECHELON_LEFT"]) then {
                if (_forEachIndex in [0, 1, 2]) then { "LINE" } else { "COLUMN" };
            } else {
                "COLUMN"
            };
        };
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
            Doctrinal Slot Allocation:
            - Slots 0, 1, 2: Dedicated to main combat rifle squads.
            - Slot 3: Dedicated to a 4th main rifle squad (when present in certain doctrines)
              or an additional weapons section (mortars or heavy machine guns).
            - Slot 4: Dedicated to the Platoon Sergeant and accompanying support/escort troops.
            - Slot 9: Dedicated to Company HQ Command Group Attachments (runners/messengers/medics).
            - Slot 10: Dedicated to Platoon Sergeant / Platoon Guide.

            COLUMN Layout (Platoon Level - WWII Road/Trail March):
            [X]   = Platoon Leader / Commander (Anchor point in vanguard)
            6,7,8 = Forward Advanced Scout Screen (50m ahead of Leader [X], standardized)
            9     = HQ Command Attachment Left
            0     = 1st Rifle Squad (Directly behind Leader [X] and 9)
            4     = Platoon Sergeant & Support (Directly behind Slot 0, between 0 and 1)
            1     = 2nd Rifle Squad (Following behind Platoon Sergeant)
            2     = 3rd Rifle Squad (Following behind 2nd Squad)
            3     = 4th Rifle Squad / Weapons Section (Following behind 3rd Squad)
            10    = Platoon Sergeant / Platoon Guide (3m behind Slot 3 after pace)
            5     = Deep Rear Reserve / Tail Security (Rearmost element)
            11,12 = Mid-Flank Security (Flanking 2nd Squad / Slot 1)

                      7 ----- 6 ----- 8  <-- Forward Scouts Screen
                              |
                             [X]         <-- Platoon Leader
                            9-|-         <-- 9: HQ Command Attachment Left
                              0          <-- 1st Rifle Squad
                              |
                              4          <-- Platoon Sergeant & Support
                              |
                     11 ----- 1 ----- 12 <-- 2nd Rifle Squad & Mid-Flank Guards
                              |
                              2          <-- 3rd Rifle Squad
                              |
                              3          <-- 4th Squad / Mortars
                              |
                             (10)        <-- Platoon Guide (3m after Slot 3 pace)
                              |
                              5          <-- Deep Rear Reserve / Tail Security
        */
        private _paces_rear_0 = _paces_rear select 0;
        private _paces_front_0 = _paces_front select 0;
        private _paces_rear_1 = _paces_rear select 1;
        private _paces_front_1 = _paces_front select 1;
        private _paces_rear_2 = _paces_rear select 2;
        private _paces_front_2 = _paces_front select 2;
        private _paces_rear_3 = _paces_rear select 3;
        private _paces_front_3 = _paces_front select 3;
        private _paces_rear_4 = _paces_rear select 4;
        private _paces_front_4 = _paces_front select 4;
        private _paces_front_5 = _paces_front select 5;

        // Slots 6, 7 & 8: Forward Scout Screens, advanced 50m forward ahead of Leader [X] (standardized)
        _direction_6 = 0;
        _separate_dis_6 = 50;

        // Slots 7 & 8: Flanking lateral spread matching standardized squad wings
        private _sep_lat_1 = _separate_dis + (_paces_left select 0) + (_paces_right select 1);
        private _pos7 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_6, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

        private _sep_lat_2 = _separate_dis + (_paces_right select 0) + (_paces_left select 2);
        private _pos8 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_6, getDir _leader]);
        _direction_8 = _leader getRelDir _pos8;
        _separate_dis_8 = _leader distance2D _pos8;

        // Slot 9: Company HQ Command Group Attachment (Messengers/Medical, 2m lateral, 3m behind Leader [X] - 1m further back)
        private _separate_lat_9 = 2;
        private _separate_long_9 = 3;
        _direction_9 = (_leader getRelDir ((_leader getRelPos [_separate_lat_9, 270]) getPos [_separate_long_9, (getDir _leader) - 180]));
        _separate_dis_9 = _leader distance2D ((_leader getRelPos [_separate_lat_9, 270]) getpos [_separate_long_9, getDir _leader]);

        // Slot 0: 1st Rifle Squad, positioned 5m further back behind Platoon Leader [X] and Slot 9
        _direction_0 = 180;
        _separate_dis_0 = (_separate_dis / 2) + 7 + _paces_front_0;

        // Slot 4: Platoon Sergeant & Support, directly behind Slot 0 (between Slot 0 and Slot 1)
        _direction_4 = 180;
        _separate_dis_4 = _separate_dis_0 + _paces_rear_0 + _paces_front_4 + (_separate_dis / 2);

        // Slot 1: 2nd Rifle Squad, directly behind Platoon Sergeant (Slot 4)
        _direction_1 = 180;
        _separate_dis_1 = _separate_dis_4 + _paces_rear_4 + _paces_front_1 + _separate_dis;

        // Slots 11 & 12: Mid-Flank Security, matching the exact lateral width of Scouts 7 & 8 from column center
        private _separate_lat_11 = _sep_lat_1;
        private _separate_long_11 = _separate_dis_1;
        _direction_11 = (_leader getRelDir ((_leader getRelPos [_separate_lat_11, 270]) getPos [_separate_long_11, getDir _leader - 180]));
        _separate_dis_11 = _leader distance2D ((_leader getRelPos [_separate_lat_11, 270]) getpos [_separate_long_11, getDir _leader - 180]);

        private _separate_lat_12 = _sep_lat_2;
        private _separate_long_12 = _separate_dis_1;
        _direction_12 = (_leader getRelDir ((_leader getRelPos [_separate_lat_12, 90]) getPos [_separate_long_12, getDir _leader - 180]));
        _separate_dis_12 = _leader distance2D ((_leader getRelPos [_separate_lat_12, 90]) getpos [_separate_long_12, getDir _leader - 180]);

        // Slot 2: 3rd Rifle Squad, following behind Slot 1
        _direction_2 = 180;
        _separate_dis_2 = _separate_dis_1 + _paces_rear_1 + _paces_front_2 + _separate_dis;

        // Slot 3: 4th Squad / Mortars, following behind Slot 2
        _direction_3 = 180;
        _separate_dis_3 = _separate_dis_2 + _paces_rear_2 + _paces_front_3 + _separate_dis;

        // Slot 10: Platoon Sergeant / Platoon Guide, following 3m behind Slot 3 after its rear pace
        _direction_10 = 180;
        _separate_dis_10 = _separate_dis_3 + _paces_rear_3 + (_paces_front select 10) + 3;

        // Slot 5: Deep Rear Reserve / Tail Security, following behind Slot 10
        _direction_5 = 180;
        _separate_dis_5 = _separate_dis_10 + (_paces_rear select 10) + _paces_front_5 + _separate_dis;
    };

    case "LINE": {
        /*
            Doctrinal Slot Allocation:
            - Slots 0, 1, 2: Dedicated to main combat rifle squads.
            - Slot 3: Dedicated to a 4th main rifle squad (when present in certain doctrines)
              or an additional weapons section (mortars or heavy machine guns).
            - Slot 4: Dedicated to the Platoon Sergeant and accompanying support/escort troops.
            - Slot 9: Dedicated to Company HQ Command Group Attachment Left.
            - Slot 10: Dedicated to Platoon Sergeant / Platoon Guide (Tactical Guide).

            LINE Layout (Platoon Level - Assault Line with Leader & Scouts in Vanguard):
            [X]     = Platoon Leader / Commander (Anchor point in vanguard, 10m ahead of Slot 0)
            9       = Company HQ Command Group Attachment Left (Flanking Leader [X])
            6,7,8   = Forward Advanced Scouts Screen (50m ahead of Leader [X], standardized)
            11,1,0,2,12 = Main Assault Line (0 center, 1 left, 2 right; 11 & 12 extended 50m outer wings after pace)
            4       = Platoon Sergeant & Support (Centered halfway between Slot 1 and Slot 0)
            10      = Platoon Sergeant / Platoon Guide (Centered halfway between Slot 0 and Slot 2, abreast with 4)
            3       = 4th Squad / Weapons Section (Aligned centrally with Slot 0, 5m behind Slot 4)
            5       = Deep Rear Reserve / Tail Security (Behind Slot 3, aligned on central axis with Slot 0)

                              7               6               8  <-- Advanced Scouts (+50m, standardized)
                              |               |               |
                                             [X]                 <-- Platoon Leader (+10m forward from 0)
                                           9 -|                  <-- HQ Command Attachment
                                              |
   11 (50m out from 1) -- 1 (Squad Left) --- 0 (Center) --- 2 (Squad Right) -- 12 (50m out from 2)
                                   |                     |
                                   4 (Halfway 1 and 0)  10 (Platoon Guide)
                                              |
                                              3 (Aligned with 0, 5m behind 4)
                                              |
                                              5 (Deep Reserve)
        */
        // Slot 9: Company HQ Command Group Attachment (Flanking Platoon Leader [X] on the left)
        private _separate_lat_9 = 2;
        private _separate_long_9 = 2;
        _direction_9 = (_leader getRelDir ((_leader getRelPos [_separate_lat_9, 270]) getPos [_separate_long_9, (getDir _leader) - 180]));
        _separate_dis_9 = _leader distance2D ((_leader getRelPos [_separate_lat_9, 270]) getpos [_separate_long_9, getDir _leader]);

        // Slot 0: Center of the main assault line, positioned 10m directly behind Platoon Leader [X]
        _direction_0 = 180;
        _separate_dis_0 = 10 + (_paces_front select 0);

        // Slot 1: Left wing of the assault line (Squad Left), abreast with Slot 0 (standardized lateral lane)
        private _sep_lat_1 = _separate_dis + (_paces_left select 0) + (_paces_right select 1);
        private _pos1 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_0, (getDir _leader) - 180]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        // Slot 2: Right wing of the assault line (Squad Right), abreast with Slot 0 (standardized lateral lane)
        private _sep_lat_2 = _separate_dis + (_paces_right select 0) + (_paces_left select 2);
        private _pos2 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_0, (getDir _leader) - 180]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slot 4: Platoon Sergeant & Support, positioned to the rear centered exactly halfway between Slot 1 and Slot 0
        private _sep_lat_4 = _sep_lat_1 / 2;
        private _sep_long_4 = _separate_dis_0 + _separate_dis + (_paces_rear select 0);
        private _pos4 = ((_leader getRelPos [_sep_lat_4, 270]) getPos [_sep_long_4, (getDir _leader) - 180]);
        _direction_4 = _leader getRelDir _pos4;
        _separate_dis_4 = _leader distance2D _pos4;

        // Slot 10: Platoon Sergeant / Platoon Guide, positioned centered halfway between Slot 0 and Slot 2 (abreast with Slot 4)
        private _sep_lat_10 = _sep_lat_2 / 2;
        private _sep_long_10 = _sep_long_4;
        private _pos10 = ((_leader getRelPos [_sep_lat_10, 90]) getPos [_sep_long_10, (getDir _leader) - 180]);
        _direction_10 = _leader getRelDir _pos10;
        _separate_dis_10 = _leader distance2D _pos10;

        // Slot 3: 4th Squad / Weapons Section, aligned centrally with Slot 0 and 5m behind Slot 4
        _direction_3 = 180;
        _separate_dis_3 = _sep_long_4 + 5;

        // Slot 5: Deep Rear Reserve / Tail, aligned on central axis with Slot 0 (behind Slot 3)
        _direction_5 = 180;
        _separate_dis_5 = _separate_dis_3 + _separate_dis + (_paces_rear select 3) + (_paces_front select 5) + 15;

        // Slots 6, 7 & 8: Forward Scouts Screen (standardized 50m ahead of Leader [X])
        _direction_6 = 0;
        _separate_dis_6 = 50;

        // Slot 7 & 8: Flanking lateral spread matching standardized squad wings
        private _pos7 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_6, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

        private _pos8 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_6, getDir _leader]);
        _direction_8 = _leader getRelDir _pos8;
        _separate_dis_8 = _leader distance2D _pos8;

        // Slots 11 & 12: Outer Wings / Flank Protection screens, positioned 50m outward beyond Squad 1 and 2 wings after pace
        private _sep_lat_11 = _sep_lat_1 + (_paces_left select 1) + 50;
        private _pos11 = ((_leader getRelPos [_sep_lat_11, 270]) getPos [_separate_dis_0, (getDir _leader) - 180]);
        _direction_11 = _leader getRelDir _pos11;
        _separate_dis_11 = _leader distance2D _pos11;

        private _sep_lat_12 = _sep_lat_2 + (_paces_right select 2) + 50;
        private _pos12 = ((_leader getRelPos [_sep_lat_12, 90]) getPos [_separate_dis_0, (getDir _leader) - 180]);
        _direction_12 = _leader getRelDir _pos12;
        _separate_dis_12 = _leader distance2D _pos12;
    };

    case "WEDGE": {
        /*
            Doctrinal Slot Allocation:
            - Slots 0, 1, 2: Dedicated to main combat rifle squads.
            - Slot 3: Dedicated to a 4th main rifle squad (when present in certain doctrines)
              or an additional weapons section (mortars or heavy machine guns).
            - Slot 4: Dedicated to the Platoon Sergeant and accompanying support/escort troops.
            - Slot 9: Dedicated to Company HQ Command Group Attachment Left.
            - Slot 10: Dedicated to Platoon Sergeant / Platoon Guide.

            WEDGE Layout (Platoon Level - Arrowhead / V-Inverted):
            [X]     = Platoon Leader / Commander (Anchor point in vanguard, 5m ahead of Slot 0)
            9       = Company HQ Command Group Attachment Left (Flanking Leader [X])
            (0)     = 1st Rifle Squad (Center / Point of Wedge, 5m behind Leader)
            (4)     = Platoon Sergeant & Support (3m behind Slot 0 after its pace)
            1,2     = Left / Right Flank Wings (Stepped back wings of the Wedge, standardized lateral lanes)
            11,12   = Outer Flank Guards (Abreast with 1 and 2, 50m outward beyond their pace)
            (3)     = Center Rear Support Squad / Mortars (Centered 5m behind Wings 1 & 2 after their pace)
            10      = Platoon Sergeant / Platoon Guide (Following 3m behind Slot 3 after pace)
            (5)     = Tail / Reserve Security Squad (Behind Slot 10, rearmost element)
            6,7,8   = Forward Scout Screens (Screening ahead of Leader [X], 50m forward, standardized)

                      7 ----------- 6 ----------- 8  <-- Forward Scout Screen (+50m, standardized)
                                   |
                                 9-[X]               <-- Leader [X] & HQ Attach (9)
                                   | (5m)
                                  (0)                <-- 1st Rifle Squad (Point)
                                   | (3m after pace)
                                  (4)                <-- Platoon Sergeant & Support
                               .       .
  11 (50m out from 1) -- (1)               (2) -- 12 (50m out from 2)
                               .       .             <-- Flank Wings & Flank Guards
                                  (3)                <-- 4th Squad / Mortars (5m behind 1 & 2)
                                   |
                                  (10)               <-- Platoon Guide (3m after Slot 3 pace)
                                   |
                                  (5)                <-- Tail Security (Rearmost)
        */
        // Slot 0: Center Point Squad, positioned 5m directly behind Platoon Leader [X]
        _direction_0 = 180;
        _separate_dis_0 = 5 + (_paces_front select 0);

        // Slot 9: Company HQ Command Group Attachment, flanking Platoon Leader [X] on the left
        _separate_dis_9 = 2;
        _direction_9 = 270;

        // Slot 4: Platoon Sergeant & Support, directly behind Slot 0 (3m behind Slot 0 after its rear pace)
        _direction_4 = 180;
        _separate_dis_4 = _separate_dis_0 + (_paces_rear select 0) + (_paces_front select 4) + 3;

        // Slots 1 & 2: Flank Wings of the Wedge, positioned laterally in standardized lanes and stepped back
        private _long_dist_wings = _separate_dis_4 + 5;
        private _sep_lat_1 = _separate_dis + (_paces_left select 0) + (_paces_right select 1);
        private _pos1 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_long_dist_wings, (getDir _leader) - 180]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        private _sep_lat_2 = _separate_dis + (_paces_right select 0) + (_paces_left select 2);
        private _pos2 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_long_dist_wings, (getDir _leader) - 180]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slot 3: Center Rear Support Squad / Mortars, positioned on center axis 5m behind the rear pace of Wings 1 & 2
        private _pace_rear_wings = (_paces_rear select 1) max (_paces_rear select 2);
        _direction_3 = 180;
        _separate_dis_3 = _long_dist_wings + _pace_rear_wings + (_paces_front select 3) + 5;

        // Slot 10: Platoon Sergeant / Platoon Guide, following 3m behind Slot 3 after its rear pace
        _direction_10 = 180;
        _separate_dis_10 = _separate_dis_3 + (_paces_rear select 3) + (_paces_front select 10) + 3;

        // Slot 5: Tail / Reserve Security Squad, directly behind Slot 10 (rearmost element)
        _direction_5 = 180;
        _separate_dis_5 = _separate_dis_10 + _separate_dis + (_paces_rear select 10) + (_paces_front select 5);

        // Slots 6, 7 & 8: Forward Scout Screens, advanced 50m forward ahead of Leader [X] (standardized)
        _direction_6 = 0;
        _separate_dis_6 = 50;

        private _pos7 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_6, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

        private _pos8 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_6, getDir _leader]);
        _direction_8 = _leader getRelDir _pos8;
        _separate_dis_8 = _leader distance2D _pos8;
    };

    case "VEE": {
        /*
            Doctrinal Slot Allocation:
            - Slots 0, 1, 2: Dedicated to main combat rifle squads.
            - Slot 3: Dedicated to a 4th main rifle squad (when present in certain doctrines)
              or an additional weapons section (mortars or heavy machine guns).
            - Slot 4: Dedicated to the Platoon Sergeant and accompanying support/escort troops.
            - Slot 9: Dedicated to Company HQ Command Group Attachment Left.
            - Slot 10: Dedicated to Platoon Sergeant / Platoon Guide.

            VEE Layout (Platoon Level - V Shape / Wings Forward):
            [X]     = Platoon Leader / Commander (Anchor in vanguard, 10m ahead of Wings 1 & 2)
            9       = Company HQ Command Group Attachment Left (Flanking Leader [X])
            6,7,8   = Forward Advanced Scout Screen (50m ahead of Leader [X], standardized)
            1,2     = Left / Right Forward Spearhead Wings (10m behind Leader, standardized lateral lanes)
            11,12   = Outer Flank Guards (Aligned with 1 & 2, 50m outward beyond their pace)
            (4)     = Platoon Sergeant & Escort (Positioned 5m ahead of Slot 0 in the central pocket)
            (0)     = 1st Rifle Squad (In the Pocket, occupying the central position behind Wings 1 & 2)
            (3)     = Center Rear Support Squad / Mortars (Positioned 5m behind Slot 0 after rear pace)
            10      = Platoon Sergeant / Platoon Guide (Following 3m behind Slot 3 after pace)
            (5)     = Tail Security Squad (Rearmost element, behind Slot 10)

                      7 ----------- 6 ----------- 8  <-- Advanced Scout Screen (+50m ahead of [X], standardized)
                                   |
                                 9-[X]               <-- Leader [X] & HQ Attach (9) (10m ahead of 1 & 2)
                                   |
                                   | (10m)
  11 (50m out from 1) -- (1)       |       (2) -- 12 (50m out from 2)
                            .     (4)     .          <-- Platoon Sergeant (5m ahead of Slot 0)
                                  (0)                <-- 1st Rifle Squad in the Pocket
                                   | (5m after pace)
                                  (3)                <-- Center Rear Support / Mortars
                                   |
                                  (10)               <-- Platoon Guide (3m after Slot 3 pace)
                                   |
                                  (5)                <-- Tail Security (Behind Slot 10)
        */
        // Slots 1 & 2: Forward Wings of the Vee, advanced forward on the flanks, positioned 10m behind Leader [X] in standardized lateral lanes
        private _sep_long_wings = 10;
        private _sep_lat_1 = _separate_dis + (_paces_left select 0) + (_paces_right select 1);
        private _pos1 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_sep_long_wings, (getDir _leader) - 180]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        private _sep_lat_2 = _separate_dis + (_paces_right select 0) + (_paces_left select 2);
        private _pos2 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_sep_long_wings, (getDir _leader) - 180]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slots 11 & 12: Outer Flank Guards, aligned longitudinally with Wings 1 and 2, and 50m outward laterally after their pace
        private _separate_lat_11 = _sep_lat_1 + (_paces_left select 1) + 50;
        private _pos11 = ((_leader getRelPos [_separate_lat_11, 270]) getPos [_sep_long_wings, (getDir _leader) - 180]);
        _direction_11 = _leader getRelDir _pos11;
        _separate_dis_11 = _leader distance2D _pos11;

        private _separate_lat_12 = _sep_lat_2 + (_paces_right select 2) + 50;
        private _pos12 = ((_leader getRelPos [_separate_lat_12, 90]) getPos [_sep_long_wings, (getDir _leader) - 180]);
        _direction_12 = _leader getRelDir _pos12;
        _separate_dis_12 = _leader distance2D _pos12;

        // Slot 0: 1st Rifle Squad in the Pocket (occupying the central position behind Wings 1 & 2)
        _direction_0 = 180;
        _separate_dis_0 = _sep_long_wings + _separate_dis + (_paces_front select 0);

        // Slot 4: Platoon Sergeant & Escort troops, positioned 5m ahead of Slot 0
        _direction_4 = 180;
        _separate_dis_4 = (_separate_dis_0 - (_paces_front select 0) - (_paces_rear select 4) - 5) max 3;

        // Slot 9: Company HQ Command Group Attachment Left (Flanking Leader [X] on the left)
        _separate_dis_9 = 2;
        _direction_9 = 270;

        // Slot 3: Center Rear Support Squad / Mortars, positioned 5m behind Slot 0 after rear pace
        _direction_3 = 180;
        _separate_dis_3 = _separate_dis_0 + (_paces_rear select 0) + (_paces_front select 3) + 5;

        // Slot 10: Platoon Sergeant / Platoon Guide, following 3m behind Slot 3 after its rear pace
        _direction_10 = 180;
        _separate_dis_10 = _separate_dis_3 + (_paces_rear select 3) + (_paces_front select 10) + 3;

        // Slot 5: Tail / Reserve Security Squad, directly behind Slot 10 (rearmost element)
        _direction_5 = 180;
        _separate_dis_5 = _separate_dis_10 + (_paces_rear select 10) + (_paces_front select 5) + _separate_dis;

        // Slots 6, 7 & 8: Forward Scout Screens, advanced 50m ahead of Leader [X] (standardized)
        _direction_6 = 0;
        _separate_dis_6 = 50;

        private _pos7 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_6, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

        private _pos8 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_6, getDir _leader]);
        _direction_8 = _leader getRelDir _pos8;
        _separate_dis_8 = _leader distance2D _pos8;
    };

    case "ECHELON_RIGHT": {
        /*
            Doctrinal Slot Allocation:
            - Slots 0, 1, 2: Dedicated to main combat rifle squads.
            - Slot 3: Dedicated to a 4th main rifle squad (when present in certain doctrines)
              or an additional weapons section (mortars or heavy machine guns).
            - Slot 4: Dedicated to the Platoon Sergeant and accompanying support/escort troops.
            - Slot 9: Dedicated to Company HQ Command Group Attachment Left.
            - Slot 10: Dedicated to Platoon Sergeant / Platoon Guide.

            ECHELON RIGHT Layout (Platoon Level - Right Flank Refused / Screen):
            [X]     = Platoon Leader / Commander (Anchor centered laterally between Slot 1 and Slot 0)
            9       = Company HQ Command Group Attachment Left (Flanking Leader [X])
            6,7,8   = Forward Advanced Scout Screen (50m ahead of Leader [X], standardized)
            1       = 2nd Rifle Squad (Squad Left - Abreast at line distance, left of [X] by half spread)
            4       = Platoon Sergeant & Support (Directly behind Slot 1 lane, pace + 5m)
            0       = 1st Rifle Squad (Center Squad - 10m further back than in Line, right of [X] by half spread)
            2       = 3rd Rifle Squad (Squad Right - 20m further back than in Line, right of Slot 0 by half spread)
            10      = Platoon Sergeant / Platoon Guide (Halfway lateral between 0 and 2, 4m behind Slot 2 pace)
            3       = 4th Squad / Weapons Section (Aligned behind Slot 0 lane)
            5       = Deep Rear Reserve / Tail Security (Behind Slot 3 lane)
            11,12   = Outer Flank Guards (Aligned with wings 1 and 2, 50m outward beyond pace)

                              7 ----------- 6 ----------- 8  <-- Forward Scout Screen (+50m, standardized)
                                           |
                                          [X]                <-- Platoon Leader (Anchor centered between 1 & 0)
                                        9 -|-                <-- 9: HQ Command Attachment Left
                                           |
    11 (50m out from 1) -- 1 (Squad Left) -+                 <-- Slot 1 (Abreast, half lateral spread left of [X])
                                 |         |
                                 4 (Plt Sgt)
                                           | (10m further back)
                                           +------- (0)      <-- Slot 0 (Center, half lateral spread right of [X])
                                           |         |
                                           |        (3)      <-- Slot 3 (Mortars / Support aligned behind 0)
                                           |         |
                                           |        (5)      <-- Slot 5 (Tail Security aligned behind 3)
                                           |
                                           | (20m further back)
                                           +-------------- 2 -- 12  <-- Slot 2 & Flank Guard 12
                                                           |
                                                          (10)      <-- Slot 10 (Plt Guide: halfway lat 0-2, 4m behind 2)
        */
        // Slot 9: Company HQ Command Group Attachment (Flanking Platoon Leader [X] on the left)
        private _separate_lat_9 = 2;
        private _separate_long_9 = 2;
        _direction_9 = (_leader getRelDir ((_leader getRelPos [_separate_lat_9, 270]) getPos [_separate_long_9, (getDir _leader) - 180]));
        _separate_dis_9 = _leader distance2D ((_leader getRelPos [_separate_lat_9, 270]) getpos [_separate_long_9, getDir _leader]);

        // Standard lateral lanes from Line formation
        private _sep_lat_1 = _separate_dis + (_paces_left select 0) + (_paces_right select 1);
        private _sep_lat_2 = _separate_dis + (_paces_right select 0) + (_paces_left select 2);

        // [X] is positioned laterally halfway between Slot 1 and Slot 0:
        // Slot 1 is laterally to the left of [X] by _half_x
        // Slot 0 is laterally to the right of [X] by _half_x
        private _sep_dist_1_0 = _sep_lat_1 / 2;
        private _half_x = _sep_dist_1_0 / 2;

        // Slot 1: Left wing (Squad Left), abreast at original Line distance behind [X], positioned _half_x left of [X]
        private _long_dist_1 = 10 + (_paces_front select 0);
        private _pos1 = ((_leader getRelPos [_half_x, 270]) getPos [_long_dist_1, (getDir _leader) - 180]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        // Slot 4: Platoon Sergeant & Support, directly behind Slot 1 lane with corresponding pace + 5m back
        private _long_dist_4 = _long_dist_1 + (_paces_rear select 1) + (_paces_front select 4) + 5;
        private _pos4 = ((_leader getRelPos [_half_x, 270]) getPos [_long_dist_4, (getDir _leader) - 180]);
        _direction_4 = _leader getRelDir _pos4;
        _separate_dis_4 = _leader distance2D _pos4;

        // Slot 0: Center Squad, displaced 10m further back than in Line, positioned _half_x right of [X]
        private _long_dist_0 = 20 + (_paces_front select 0);
        private _pos0 = ((_leader getRelPos [_half_x, 90]) getPos [_long_dist_0, (getDir _leader) - 180]);
        _direction_0 = _leader getRelDir _pos0;
        _separate_dis_0 = _leader distance2D _pos0;

        // Slot 2: Right wing (Squad Right), displaced 20m further back than Line
        // Lateral distance from Slot 0 is half of Line's sep_lat_2, so from [X] it is _half_x + (_sep_lat_2 / 2)
        private _long_dist_2 = 30 + (_paces_front select 0);
        private _lat_x_2 = _half_x + (_sep_lat_2 / 2);
        private _pos2 = ((_leader getRelPos [_lat_x_2, 90]) getPos [_long_dist_2, (getDir _leader) - 180]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slot 10: Platoon Sergeant / Platoon Guide, positioned halfway laterally between Slot 0 and Slot 2
        // Lateral from [X]: _half_x + (_sep_lat_2 / 4), and 4m behind Slot 2 rear pace
        private _lat_x_10 = _half_x + (_sep_lat_2 / 4);
        private _long_dist_10 = _long_dist_2 + (_paces_rear select 2) + (_paces_front select 10) + 4;
        private _pos10 = ((_leader getRelPos [_lat_x_10, 90]) getPos [_long_dist_10, (getDir _leader) - 180]);
        _direction_10 = _leader getRelDir _pos10;
        _separate_dis_10 = _leader distance2D _pos10;

        // Slot 3: 4th Squad / Weapons Section, aligned behind Slot 0 lane
        private _long_dist_3 = _long_dist_0 + (_paces_rear select 0) + (_paces_front select 3) + 5;
        private _pos3 = ((_leader getRelPos [_half_x, 90]) getPos [_long_dist_3, (getDir _leader) - 180]);
        _direction_3 = _leader getRelDir _pos3;
        _separate_dis_3 = _leader distance2D _pos3;

        // Slot 5: Deep Rear Reserve / Tail Security, aligned behind Slot 3 lane
        private _long_dist_5 = _long_dist_3 + _separate_dis + (_paces_rear select 3) + (_paces_front select 5);
        private _pos5 = ((_leader getRelPos [_half_x, 90]) getPos [_long_dist_5, (getDir _leader) - 180]);
        _direction_5 = _leader getRelDir _pos5;
        _separate_dis_5 = _leader distance2D _pos5;

        // Slots 6, 7 & 8: Forward Scout Screens, advanced 50m forward ahead of Leader [X] (standardized)
        _direction_6 = 0;
        _separate_dis_6 = 50;

        private _pos7 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_6, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

        private _pos8 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_6, getDir _leader]);
        _direction_8 = _leader getRelDir _pos8;
        _separate_dis_8 = _leader distance2D _pos8;

        // Slots 11 & 12: Outer Wings / Flank Protection screens, positioned 50m outward beyond wings after pace
        private _sep_lat_11 = _half_x + (_paces_left select 1) + 50;
        private _pos11 = ((_leader getRelPos [_sep_lat_11, 270]) getPos [_long_dist_1, (getDir _leader) - 180]);
        _direction_11 = _leader getRelDir _pos11;
        _separate_dis_11 = _leader distance2D _pos11;

        private _sep_lat_12 = _lat_x_2 + (_paces_right select 2) + 50;
        private _pos12 = ((_leader getRelPos [_sep_lat_12, 90]) getPos [_long_dist_2, (getDir _leader) - 180]);
        _direction_12 = _leader getRelDir _pos12;
        _separate_dis_12 = _leader distance2D _pos12;
    };

    case "ECHELON_LEFT": {
        /*
            Doctrinal Slot Allocation:
            - Slots 0, 1, 2: Dedicated to main combat rifle squads.
            - Slot 3: Dedicated to a 4th main rifle squad (when present in certain doctrines)
              or an additional weapons section (mortars or heavy machine guns).
            - Slot 4: Dedicated to the Platoon Sergeant and accompanying support/escort troops.
            - Slot 9: Dedicated to Company HQ Command Group Attachment Left.
            - Slot 10: Dedicated to Platoon Sergeant / Platoon Guide.

            ECHELON LEFT Layout (Platoon Level - Left Flank Refused / Screen - Mirror of Echelon Right):
            [X]     = Platoon Leader / Commander (Anchor centered laterally between Slot 2 and Slot 0)
            9       = Company HQ Command Group Attachment Left (Flanking Leader [X])
            6,7,8   = Forward Advanced Scout Screen (50m ahead of Leader [X], standardized)
            2       = 3rd Rifle Squad (Squad Right - Abreast at line distance, right of [X] by half spread)
            4       = Platoon Sergeant & Support (Directly behind Slot 2 lane, pace + 5m)
            0       = 1st Rifle Squad (Center Squad - 10m further back than in Line, left of [X] by half spread)
            1       = 2nd Rifle Squad (Squad Left - 20m further back than in Line, left of Slot 0 by half spread)
            10      = Platoon Sergeant / Platoon Guide (Halfway lateral between 0 and 1, 4m behind Slot 1 pace)
            3       = 4th Squad / Weapons Section (Aligned behind Slot 0 lane)
            5       = Deep Rear Reserve / Tail Security (Behind Slot 3 lane)
            11,12   = Outer Flank Guards (Aligned with wings 1 and 2, 50m outward beyond pace)

                              7 ----------- 6 ----------- 8  <-- Forward Scout Screen (+50m, standardized)
                                           |
                                          [X]                <-- Platoon Leader (Anchor centered between 2 & 0)
                                        9 -|-                <-- 9: HQ Command Attachment Left
                                           |
                                           +- 2 (Squad Right) -- 12  <-- Slot 2 (Abreast, half spread right of [X])
                                           |  |
                                           |  4 (Plt Sgt)    <-- Slot 4 (Aligned behind 2 lane)
                                           |
                       (0) ----------------+                 <-- Slot 0 (Center, half spread left of [X], 10m back)
                        |                  |
                       (3)                 |                 <-- Slot 3 (Mortars / Support aligned behind 0)
                        |                  |
                       (5)                 |                 <-- Slot 5 (Tail Security aligned behind 3)
                                           |
    11 -- 1 -------------------------------+                 <-- Slot 1 (Squad Left, 20m back from Line)
          |
         (10)                                                <-- Slot 10 (Plt Guide: halfway lat 0-1, 4m behind 1)
        */
        // Slot 9: Company HQ Command Group Attachment (Flanking Platoon Leader [X] on the left)
        private _separate_lat_9 = 2;
        private _separate_long_9 = 2;
        _direction_9 = (_leader getRelDir ((_leader getRelPos [_separate_lat_9, 270]) getPos [_separate_long_9, (getDir _leader) - 180]));
        _separate_dis_9 = _leader distance2D ((_leader getRelPos [_separate_lat_9, 270]) getpos [_separate_long_9, getDir _leader]);

        // Standard lateral lanes from Line formation
        private _sep_lat_1 = _separate_dis + (_paces_left select 0) + (_paces_right select 1);
        private _sep_lat_2 = _separate_dis + (_paces_right select 0) + (_paces_left select 2);

        // [X] is positioned laterally halfway between Slot 2 and Slot 0:
        // Slot 2 is laterally to the right of [X] by _half_x
        // Slot 0 is laterally to the left of [X] by _half_x
        private _sep_dist_2_0 = _sep_lat_2 / 2;
        private _half_x = _sep_dist_2_0 / 2;

        // Slot 2: Right wing (Squad Right), abreast at original Line distance behind [X], positioned _half_x right of [X]
        private _long_dist_2 = 10 + (_paces_front select 0);
        private _pos2 = ((_leader getRelPos [_half_x, 90]) getPos [_long_dist_2, (getDir _leader) - 180]);
        _direction_2 = _leader getRelDir _pos2;
        _separate_dis_2 = _leader distance2D _pos2;

        // Slot 4: Platoon Sergeant & Support, directly behind Slot 2 lane with corresponding pace + 5m back
        private _long_dist_4 = _long_dist_2 + (_paces_rear select 2) + (_paces_front select 4) + 5;
        private _pos4 = ((_leader getRelPos [_half_x, 90]) getPos [_long_dist_4, (getDir _leader) - 180]);
        _direction_4 = _leader getRelDir _pos4;
        _separate_dis_4 = _leader distance2D _pos4;

        // Slot 0: Center Squad, displaced 10m further back than in Line, positioned _half_x left of [X]
        private _long_dist_0 = 20 + (_paces_front select 0);
        private _pos0 = ((_leader getRelPos [_half_x, 270]) getPos [_long_dist_0, (getDir _leader) - 180]);
        _direction_0 = _leader getRelDir _pos0;
        _separate_dis_0 = _leader distance2D _pos0;

        // Slot 1: Left wing (Squad Left), displaced 20m further back than Line
        // Lateral distance from Slot 0 is half of Line's sep_lat_1, so from [X] it is _half_x + (_sep_lat_1 / 2)
        private _long_dist_1 = 30 + (_paces_front select 0);
        private _lat_x_1 = _half_x + (_sep_lat_1 / 2);
        private _pos1 = ((_leader getRelPos [_lat_x_1, 270]) getPos [_long_dist_1, (getDir _leader) - 180]);
        _direction_1 = _leader getRelDir _pos1;
        _separate_dis_1 = _leader distance2D _pos1;

        // Slot 10: Platoon Sergeant / Platoon Guide, positioned halfway laterally between Slot 0 and Slot 1
        // Lateral from [X]: _half_x + (_sep_lat_1 / 4), and 4m behind Slot 1 rear pace
        private _lat_x_10 = _half_x + (_sep_lat_1 / 4);
        private _long_dist_10 = _long_dist_1 + (_paces_rear select 1) + (_paces_front select 10) + 4;
        private _pos10 = ((_leader getRelPos [_lat_x_10, 270]) getPos [_long_dist_10, (getDir _leader) - 180]);
        _direction_10 = _leader getRelDir _pos10;
        _separate_dis_10 = _leader distance2D _pos10;

        // Slot 3: 4th Squad / Weapons Section, aligned behind Slot 0 lane
        private _long_dist_3 = _long_dist_0 + (_paces_rear select 0) + (_paces_front select 3) + 5;
        private _pos3 = ((_leader getRelPos [_half_x, 270]) getPos [_long_dist_3, (getDir _leader) - 180]);
        _direction_3 = _leader getRelDir _pos3;
        _separate_dis_3 = _leader distance2D _pos3;

        // Slot 5: Deep Rear Reserve / Tail Security, aligned behind Slot 3 lane
        private _long_dist_5 = _long_dist_3 + _separate_dis + (_paces_rear select 3) + (_paces_front select 5);
        private _pos5 = ((_leader getRelPos [_half_x, 270]) getPos [_long_dist_5, (getDir _leader) - 180]);
        _direction_5 = _leader getRelDir _pos5;
        _separate_dis_5 = _leader distance2D _pos5;

        // Slots 6, 7 & 8: Forward Scout Screens, advanced 50m forward ahead of Leader [X] (standardized)
        _direction_6 = 0;
        _separate_dis_6 = 50;

        private _pos7 = ((_leader getRelPos [_sep_lat_1, 270]) getPos [_separate_dis_6, getDir _leader]);
        _direction_7 = _leader getRelDir _pos7;
        _separate_dis_7 = _leader distance2D _pos7;

        private _pos8 = ((_leader getRelPos [_sep_lat_2, 90]) getPos [_separate_dis_6, getDir _leader]);
        _direction_8 = _leader getRelDir _pos8;
        _separate_dis_8 = _leader distance2D _pos8;

        // Slots 11 & 12: Outer Wings / Flank Protection screens, positioned 50m outward beyond wings after pace
        private _sep_lat_11 = _lat_x_1 + (_paces_left select 1) + 50;
        private _pos11 = ((_leader getRelPos [_sep_lat_11, 270]) getPos [_long_dist_1, (getDir _leader) - 180]);
        _direction_11 = _leader getRelDir _pos11;
        _separate_dis_11 = _leader distance2D _pos11;

        private _sep_lat_12 = _half_x + (_paces_right select 2) + 50;
        private _pos12 = ((_leader getRelPos [_sep_lat_12, 90]) getPos [_long_dist_2, (getDir _leader) - 180]);
        _direction_12 = _leader getRelDir _pos12;
        _separate_dis_12 = _leader distance2D _pos12;
    };

    default { 
        hint "FTCS Warning: Unknown platoon formation type"; 
    };
};

// Update Platoon Formation Position List global registry (0 to 12 slots)
// Every slot 0 to 12 always receives its theoretical template coordinates [_dist, _dir, _assignedGroup],
// allowing all 13 slots to be tracked / visualized on the map in debug mode, even if no group is currently assigned (grpNull).
{
    private _dist = switch (_forEachIndex) do {
        case 0: { _separate_dis_0 }; case 1: { _separate_dis_1 }; case 2: { _separate_dis_2 };
        case 3: { _separate_dis_3 }; case 4: { _separate_dis_4 }; case 5: { _separate_dis_5 };
        case 6: { _separate_dis_6 }; case 7: { _separate_dis_7 }; case 8: { _separate_dis_8 };
        case 9: { _separate_dis_9 }; case 10: { _separate_dis_10 }; case 11: { _separate_dis_11 };
        case 12: { _separate_dis_12 };
        default { 0 };
    };

    private _dir = switch (_forEachIndex) do {
        case 0: { _direction_0 }; case 1: { _direction_1 }; case 2: { _direction_2 };
        case 3: { _direction_3 }; case 4: { _direction_4 }; case 5: { _direction_5 };
        case 6: { _direction_6 }; case 7: { _direction_7 }; case 8: { _direction_8 };
        case 9: { _direction_9 }; case 10: { _direction_10 }; case 11: { _direction_11 };
        case 12: { _direction_12 };
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

        // Resolve squad formation according to operational phase & macro platoon geometry:
        // In LINE platoon formation: slots 0, 1, 2 (primary assault squads) deploy internally in "LINE",
        // slot 3 (mortars/weapons) deploys in "COLUMN".
        // In other platoon formations, squads adapt echelon or column/wedge per phase.
        private _slotBearing = (Platoon_Formation_Position_List select _forEachIndex) select 1;
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

        private _type_formation = if (_forEachIndex < count _squad_formations_in && {(_squad_formations_in select _forEachIndex) != ""}) then {
            _squad_formations_in select _forEachIndex
        } else {
            switch (_formation_type) do {
                case "LINE": {
                    // Por defecto en LINE de pelotón: los squads 0, 1 y 2 en "LINE"; el 3 (morteros/armas) en "COLUMN"
                    if (_forEachIndex in [0, 1, 2]) then { "LINE" } else { "COLUMN" };
                };
                case "ECHELON_RIGHT": {
                    // Mismo tipo de formación de squads que en LINE de pelotón: squads 0, 1 y 2 en "LINE"; el 3 en "COLUMN"
                    if (_forEachIndex in [0, 1, 2]) then { "LINE" } else { "COLUMN" };
                };
                case "ECHELON_LEFT": {
                    // Mismo tipo de formación de squads que en LINE de pelotón: squads 0, 1 y 2 en "LINE"; el 3 en "COLUMN"
                    if (_forEachIndex in [0, 1, 2]) then { "LINE" } else { "COLUMN" };
                };
                case "WEDGE": {
                    if (_platoonPhase == 1) then {
                        if (_slotBearing > 0 && _slotBearing < 180) then { "ECHELON_RIGHT" }
                        else { if (_slotBearing > 180 && _slotBearing < 360) then { "ECHELON_LEFT" } else { "COLUMN" } };
                    } else {
                        "WEDGE"
                    };
                };
                case "VEE": {
                    if (_platoonPhase == 1) then {
                        if (_slotBearing > 0 && _slotBearing < 180) then { "ECHELON_RIGHT" }
                        else { if (_slotBearing > 180 && _slotBearing < 360) then { "ECHELON_LEFT" } else { "COLUMN" } };
                    } else {
                        "WEDGE"
                    };
                };
                default {
                    "COLUMN"
                };
            };
        };

        // Persist the resolved formation type into the squad leader group registry entry
        // platoonFormation: the macro slot formation this element occupies in the
        // platoon deployment (sole writer: platoon pipeline). Doctrine ladder:
        // companyFormation (future) / platoonFormation / squadFormation / teamFormation.
        _entry set ["platoonFormation", _type_formation];
        FTCS_Groups_Registry_Table set [_elementID, _entry];

        // Update 2D tactical map NATO icon text to display assigned formation slot (0-12)
        private _grpObj = (_x select 0);
        private _slotDist = (Platoon_Formation_Position_List select _forEachIndex) select 0;

        private _isDebug = missionNamespace getVariable ["FTCS_Debug_Mode", false];
        if (_isDebug) then {
            _grpObj setGroupIconParams [[0.55, 0.55, 0.55, 1.0], format ["[Slot %1] %2", _forEachIndex, groupId _grpObj], 1.0, true];
            systemChat format ["[FORMATION SLOT %1] %2 -> %3m at %4° (Leader: %5)", _forEachIndex, _elementID, round _slotDist, round _slotBearing, name (leader (_x select 0))];
        } else {
            _grpObj setGroupIconParams [[0.55, 0.55, 0.55, 1.0], groupId _grpObj, 1.0, true];
        };

        _list pushBack (_x select 0);

        // Recursive call to squad formation function for internal team deployment
        // In relative mode, fireteams align relative to their Squad Leader's heading
        if ((count _x) > 1) then {
            [_x, _type_formation, _local_elements_separation, 0] call FTCS_fnc_formationsTypeSquadSet;
        };
    };
} forEach _formation_elements;

// Return follower list for external command execution
_list