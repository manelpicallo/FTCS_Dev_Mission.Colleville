params ["_formation_elements", "_formation_type", "_separate_dis", "_direction"];

private _num_elements = count _formation_elements;

if ((_num_elements < 1) || (_num_elements > FTCS_Squad_MAX_Infantry_Groups)) exitWith {
    hint "Number of groups in the squad out of range";
};

if (isNull (_formation_elements select 0)) exitWith {
    hint "No squad leader group present";
};

private _leader = leader (_formation_elements select 0);

private _units_pace = FTCS_Pace_Soldiers;
private _aux_number_units = 0;

private _separate_dis_1 = 0;
private _separate_dis_2 = 0;
private _separate_dis_3 = 0;
private _separate_dis_4 = 0;

private _direction_1 = 0;
private _direction_2 = 0;
private _direction_3 = 0;
private _direction_4 = 0;

private _formation_0 = "WEDGE";
private _formation_1 = "WEDGE";
private _formation_2 = "WEDGE";
private _formation_3 = "WEDGE";
private _formation_4 = "WEDGE";

private _pace_rear_0 = 0;
private _pace_rear_1 = 0;
private _pace_rear_2 = 0;
private _pace_rear_3 = 0;
private _pace_rear_4 = 0;

{
    if (!isNull _x) then {
        _aux_number_units = count units _x;
        private _pace = if ((_aux_number_units mod 2) != 0) then {
            (_aux_number_units - 1) / 2 * _units_pace
        } else {
            (_aux_number_units / 2) * _units_pace
        };
        
        switch (_forEachIndex) do {
            case 0: { _pace_rear_0 = _pace; };
            case 1: { _pace_rear_1 = _pace; };
            case 2: { _pace_rear_2 = _pace; };
            case 3: { _pace_rear_3 = _pace; };
            case 4: { _pace_rear_4 = _pace; };
        };
    };
} forEach _formation_elements;

switch (_formation_type) do {

    case "COLUMN": {
        /********************************-------------------------------
            COLUMN Squad Layout: Pure longitudinal trail in single column.
            Each fireteam follows directly behind in WEDGE formation.
            
                                        .(1) [WEDGE] ==> Lead / Scout Team
                                         |
                                        .(0) [WEDGE] ==> Squad Leader Team
                                         |
                                        .(2) [WEDGE] ==> Maneuver Team
                                         |
                                        .(3) [WEDGE] ==> Support / BAR Team
                                         |
                                        .(4) [WEDGE]
        ******************************************************************/
        _separate_dis_1 = _pace_rear_1 + _separate_dis;
        _separate_dis_2 = _pace_rear_0 + _separate_dis;
        _separate_dis_3 = _separate_dis_2 + _pace_rear_2 + _separate_dis;
        _separate_dis_4 = _separate_dis_3 + _pace_rear_3 + _separate_dis;

        _direction_1 = 0;
        _direction_2 = 180;
        _direction_3 = 180;
        _direction_4 = 180;

        // Sub-groups deploy in WEDGE for all-round security even during column march
        _formation_0 = "WEDGE";
        _formation_1 = "WEDGE";
        _formation_2 = "WEDGE";
        _formation_3 = "WEDGE";
        _formation_4 = "WEDGE";
    };

    case "WEDGE": {
        /********************************-------------------------------
            WEDGE Squad Layout: Flanks angled with echelon sub-groups.
            
                                         .(0) [WEDGE] ==> leader
                                      .        .
                        [ECHELON LEFT] .(1)  .(2) [ECHELON RIGHT]
                                      .        .
                                         .(3) [COLUMN]
                                         .     .
                                         .(4) [COLUMN]
                                         .     .
        ******************************************************************/
        _separate_dis_1 = _pace_rear_1 + _separate_dis;
        _direction_1 = 315;

        _separate_dis_2 = _pace_rear_2 + _separate_dis;
        _direction_2 = 45;

        _separate_dis_3 = _pace_rear_0 + _separate_dis;
        _direction_3 = 180;

        _separate_dis_4 = _separate_dis_3 + _pace_rear_3 + _separate_dis;
        _direction_4 = 180;

        _formation_0 = "WEDGE";
        _formation_1 = "ECH LEFT";
        _formation_2 = "ECH RIGHT";
        _formation_3 = "COLUMN";
        _formation_4 = "COLUMN";
    };

    case "VEE": {
        /****************-----------------------------------------------
            VEE Squad Layout: Leading edge spearheads.
            
                       [WEDGE] .(1)           .(2) [WEDGE]
                                 .          .
                                    .    .
                                  .(0) [COLUMN] ==> leader
                                    .
                                  .(3) [COLUMN]
                                  .     .
                                  .(4) [COLUMN]
                                  .     .
        ******************************************************************/
        _separate_dis_1 = _separate_dis * 1.5;
        _direction_1 = 330;

        _separate_dis_2 = _separate_dis * 1.5;
        _direction_2 = 30;

        _separate_dis_3 = _separate_dis;
        _direction_3 = 180;

        _separate_dis_4 = _separate_dis * 2;
        _direction_4 = 180;

        _formation_0 = "COLUMN";
        _formation_1 = "WEDGE";
        _formation_2 = "WEDGE";
        _formation_3 = "COLUMN";
        _formation_4 = "COLUMN";
    };

    case "LINE": {
        /****************-----------------------------------------------
            LINE Squad Layout: Assault line abreast.
            
            [LINE] .(1) ----- .(0) [LINE] ==> leader ----- .(2) [LINE]
                                     .
                                     .(3) [COLUMN]
                                     .     .
                                     .(4) [COLUMN]
                                     .     .
        ******************************************************************/
        _separate_dis_1 = _separate_dis * 2;
        _direction_1 = 270;

        _separate_dis_2 = _separate_dis * 2;
        _direction_2 = 90;

        _separate_dis_3 = _separate_dis;
        _direction_3 = 180;

        _separate_dis_4 = _separate_dis * 2;
        _direction_4 = 180;

        _formation_0 = "LINE";
        _formation_1 = "LINE";
        _formation_2 = "LINE";
        _formation_3 = "COLUMN";
        _formation_4 = "COLUMN";
    };

    case "DIAMOND": {
        /****************-----------------------------------------------
            DIAMOND Squad Layout: Perimeter security layout.
            
                                         .(1) [WEDGE]
                                      .        .
                 [ECHELON LEFT] .(2)          .(3) [ECHELON RIGHT]
                                      .        .
                                         .(0) [COLUMN] ==> leader / (4) [COLUMN]
                                         .     .
        ******************************************************************/
        _separate_dis_1 = _separate_dis * 1.5;
        _direction_1 = 0;

        _separate_dis_2 = _separate_dis * 1.5;
        _direction_2 = 270;

        _separate_dis_3 = _separate_dis * 1.5;
        _direction_3 = 90;

        _separate_dis_4 = _separate_dis * 1.5;
        _direction_4 = 180;

        _formation_0 = "COLUMN";
        _formation_1 = "WEDGE";
        _formation_2 = "ECH LEFT";
        _formation_3 = "ECH RIGHT";
        _formation_4 = "COLUMN";
    };

    case "ECHELON_RIGHT": {
        /********************************-------------------------------
            ECHELON RIGHT Squad Layout (1 Leader + up to 4 Sub-teams):
            Sub-groups stepped back diagonally to the right (135° bearing).
            Each sub-group maintains its native column / file march posture.

                         ▲ [Advance Direction 0°]
                         │
                        (0) [Squad Leader Team - Point]
                           \
                            \ (135°)
                             (1) [Sub-team 1: Support / BAR]
                                \
                                 \ (135°)
                                  (2) [Sub-team 2: Assault / Clearing]
                                     \
                                      \ (135°)
                                       (3) [Sub-team 3: Reserve / Ammo]
                                          \
                                           \ (135°)
                                            (4) [Sub-team 4: Tail Guard]
        ******************************************************************/
        _separate_dis_1 = _pace_rear_1 + _separate_dis;
        _direction_1 = 135;

        _separate_dis_2 = _separate_dis_1 + _pace_rear_2 + _separate_dis;
        _direction_2 = 135;

        _separate_dis_3 = _separate_dis_2 + _pace_rear_3 + _separate_dis;
        _direction_3 = 135;

        _separate_dis_4 = _separate_dis_3 + _pace_rear_4 + _separate_dis;
        _direction_4 = 135;

        _formation_0 = "COLUMN";
        _formation_1 = "COLUMN";
        _formation_2 = "COLUMN";
        _formation_3 = "COLUMN";
        _formation_4 = "COLUMN";
    };

    case "ECHELON_LEFT": {
        /********************************-------------------------------
            ECHELON LEFT Squad Layout (1 Leader + up to 4 Sub-teams):
            Sub-groups stepped back diagonally to the left (225° bearing).
            Each sub-group maintains its native column / file march posture.

                         ▲ [Advance Direction 0°]
                         │
                        (0) [Squad Leader Team - Point]
                           /
                  (225°)  /
                        (1) [Sub-team 1: Support / BAR]
                         /
                (225°)  /
                      (2) [Sub-team 2: Assault / Clearing]
                       /
              (225°)  /
                    (3) [Sub-team 3: Reserve / Ammo]
                     /
            (225°)  /
                  (4) [Sub-team 4: Tail Guard]
        ******************************************************************/
        _separate_dis_1 = _pace_rear_1 + _separate_dis;
        _direction_1 = 225;

        _separate_dis_2 = _separate_dis_1 + _pace_rear_2 + _separate_dis;
        _direction_2 = 225;

        _separate_dis_3 = _separate_dis_2 + _pace_rear_3 + _separate_dis;
        _direction_3 = 225;

        _separate_dis_4 = _separate_dis_3 + _pace_rear_4 + _separate_dis;
        _direction_4 = 225;

        _formation_0 = "COLUMN";
        _formation_1 = "COLUMN";
        _formation_2 = "COLUMN";
        _formation_3 = "COLUMN";
        _formation_4 = "COLUMN";
    };

    case "DO NOTHING": {};

    default { hint "Unknown formation type"; };
};

if (_num_elements > 0) then {
    if (!isNull (_formation_elements select 0)) then {
        [groupId (_formation_elements select 0), "formationType", _formation_type] call FTCS_fnc_registrySet;
        (_formation_elements select 0) setFormation _formation_0;
    };
};

if (_num_elements > 1 && {!isNull (_formation_elements select 1)}) then {
    [groupId (_formation_elements select 1), _separate_dis_1, _direction_1 + _direction, _formation_elements select 0] call FTCS_fnc_registryUpdatePos;
    (_formation_elements select 1) setFormation _formation_1;
};

if (_num_elements > 2 && {!isNull (_formation_elements select 2)}) then {
    [groupId (_formation_elements select 2), _separate_dis_2, _direction_2 + _direction, _formation_elements select 0] call FTCS_fnc_registryUpdatePos;
    (_formation_elements select 2) setFormation _formation_2;
};

if (_num_elements > 3 && {!isNull (_formation_elements select 3)}) then {
    [groupId (_formation_elements select 3), _separate_dis_3, _direction_3 + _direction, _formation_elements select 0] call FTCS_fnc_registryUpdatePos;
    (_formation_elements select 3) setFormation _formation_3;
};

if (_num_elements > 4 && {!isNull (_formation_elements select 4)}) then {
    [groupId (_formation_elements select 4), _separate_dis_4, _direction_4 + _direction, _formation_elements select 0] call FTCS_fnc_registryUpdatePos;
    (_formation_elements select 4) setFormation _formation_4;
};

private _list = +_formation_elements;
_list deleteAt 0;
_list