params ["_formation_elements", "_formation_type", "_separate_dis"];

private _return = [-1, -1, -1, -1]; // Return array [distance front, distance rear, distance right, distance left]
private _num_elements = count _formation_elements;

private _aux_Rear = 0;
private _aux_Front = 0;
private _aux_Left = 0;
private _aux_Right = 0;
private _max_units = 0;

switch (_formation_type) do {

    case "COLUMN": {
        /***************************************************************
            COLUMN Pace Calculation Schema:
            Calculates cumulative longitudinal space (rear/front) based on
            the number of soldiers in each sub-group and the separation distance.
            
                       [Element 1 (Vanguard)] -> _aux_Front
                              |
                        [Element 0 (Leader)]
                              |
                       [Element 2 (Main)]   -> _aux_Rear (cumulative)
                              |
                       [Element 3 (Support)]
                              |
                       [Element 4 (Rear)]
        ******************************************************************/
        {
            if (!isNull _x) then {
                private _unit_count = count (units _x);
                if (_unit_count > _max_units) then { _max_units = _unit_count; };
                
                // Calculate group footprint based on unit count and soldier pace factor
                private _aux = if ((_unit_count mod 2) != 0) then {
                    ((_unit_count - 1) / 2) * FTCS_Pace_Soldiers
                } else {
                    (_unit_count / 2) * FTCS_Pace_Soldiers
                };

                // Leader (0) and trailing elements (2,3,4) accumulate distance backward
                if (_forEachIndex == 0 || _forEachIndex >= 2) then {
                    _aux_Rear = _aux_Rear + _aux + _separate_dis;
                };
                
                // Element 1 acts as front vanguard element
                if (_forEachIndex == 1) then {
                    _aux_Front = _aux + _separate_dis;
                };
            };
        } forEach _formation_elements;

        // Calculate lateral space based on the widest sub-group in the column
        if (_max_units > 0) then {
            private _lateral_pace = if ((_max_units mod 2) != 0) then {
                ((_max_units - 1) / 2) * FTCS_Pace_Soldiers
            } else {
                (_max_units / 2) * FTCS_Pace_Soldiers
            };
            _aux_Left = _lateral_pace + _separate_dis;
            _aux_Right = _lateral_pace + _separate_dis;
        };
    };

    case "WEDGE": {
        /********************************-------------------------------
            WEDGE Pace Calculation Schema:
            Expansive wedge footprint calculation for flank opening.
            
                                      [Element 0] (Point)
                                    .             .
                       [Element 1] .               . [Element 2]
                                   .               .
                                      [Element 3]
                                           |
                                      [Element 4]
        ******************************************************************/
        {
            if (!isNull _x) then {
                private _unit_count = count (units _x);
                if (_unit_count > _max_units) then { _max_units = _unit_count; };
            };
        } forEach _formation_elements;

        _aux_Front = _separate_dis * 1.5;
        _aux_Rear  = _separate_dis * 2;
        _aux_Left  = _separate_dis * 1.5;
        _aux_Right = _separate_dis * 1.5;
    };

    case "VEE": {
        /****************-----------------------------------------------
            VEE Pace Calculation Schema:
            Vee footprint calculation (advanced tips and trailing core).
            
                       [Element 1]                   [Element 2]
                                  .               .
                                     .         .
                                        [Element 0]
                                             |
                                        [Element 3]
                                             |
                                        [Element 4]
        ******************************************************************/
        _aux_Front = _separate_dis * 1.5;
        _aux_Rear  = _separate_dis * 2.5;
        _aux_Left  = _separate_dis * 2;
        _aux_Right = _separate_dis * 2;
    };

    case "LINE": {
        /****************-----------------------------------------------
            LINE Pace Calculation Schema:
            Horizontal assault line footprint calculation.
            
            [Element 1] ----- [Element 0] ----- [Element 2]
                                   |
                              [Element 3]
                                   |
                              [Element 4]
        ****************----------------------------------------------**/
        {
            if (!isNull _x) then {
                private _unit_count = count (units _x);
                if (_unit_count > _max_units) then { _max_units = _unit_count; };
            };
        } forEach _formation_elements;

        _aux_Front = _separate_dis;
        _aux_Rear  = _separate_dis * 2;
        _aux_Left  = _separate_dis * 2.5;
        _aux_Right = _separate_dis * 2.5;
    };

    case "DIAMOND": {
        /****************-----------------------------------------------
            DIAMOND Pace Calculation Schema:
            Perimeter diamond footprint calculation.
            
                                      [Element 1]
                                        .             .
                           [Element 2] .     [0]       . [Element 3]
                                       .             .
                                          [Element 4]
        ****************------------------------------------------------**/
        _aux_Front = _separate_dis * 2;
        _aux_Rear  = _separate_dis * 2.5;
        _aux_Left  = _separate_dis * 2;
        _aux_Right = _separate_dis * 2;
    };

    case "DO NOTHING": {
        // Elements out of range or in static hold position
    };

    default { 
        hint "FTCS Warning: Unknown formation type in pace calculation"; 
    };
};

// Assign calculated values to the return vector [Front, Rear, Right, Left]
_return set [0, _aux_Front];
_return set [1, _aux_Rear];
_return set [2, _aux_Right];
_return set [3, _aux_Left];

_return;