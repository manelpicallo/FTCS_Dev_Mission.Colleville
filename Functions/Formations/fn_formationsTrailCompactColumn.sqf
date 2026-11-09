/*
    ================================================================================
    File: fn_formationsTrailCompactColumn.sqf
    Module: Formations
    Author: FTCS Team
    Description: Compacts the leader-trail column into a STAGGERED double lane.
                 - The master trajectory does not change: every slot keeps its
                   arclength over the leader's recorded track. What changes is
                   the chain and the lateral placement:
                     * Teams are paired in march order: pair [1&2], [3&4]...
                     * Both members of a pair share the SAME trail arclength
                       (the first member's), each displaced laterally +/-0.75m
                       perpendicular to the local trail tangent (1.5m total
                       lane separation, centered on the leader's walked line).
                     * The next pair starts after the bigger member's manpower
                       footprint (unitCount * 2m + 3m) + pairGap.
                 - Result: the single-file trail column depth roughly halves
                   while every team still marches exactly on the leader's line.
                 - Groups with trailOffsetDist > 0 participate; forward/center
                   entries are untouched (same criteria as road compact).
                 - Marks the trail anchor columnLayout = "COMPACT" (locks the
                   menu option until the trail order is re-issued).
    Params:
        0: NUMBER - Platoon ID whose trail anchor owns the chain.
    Returns:
        NUMBER - Count of re-assigned groups (0 if not compactable).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_pltId", 1]];

private _pairHalfSeparation = 0.75; // lateral meters each member deviates from the walked line
private _pairGap = 3.0;             // meters between consecutive pairs

private _anchor = missionNamespace getVariable [format ["FTCS_Trail_Anchor_PLT_%1", _pltId], createHashMap];
if (count (_anchor getOrDefault ["trailPath", []]) < 2) exitWith {
    systemChat "[TRAIL COMPACT] Error: no active trail column (anchor missing).";
    0
};

// Collect participating trail groups (rear-marching only), sorted by current offset
private _participants = [];
{
    private _entry = _y;
    private _grpId = _x;
    private _offsetDist = _entry getOrDefault ["trailOffsetDist", -1];
    if (_offsetDist > 0) then {
        _participants pushBack [_offsetDist, _grpId];
    };
} forEach FTCS_Groups_Registry_Table;

if (count _participants < 2) exitWith {
    systemChat "[TRAIL COMPACT] Error: not enough chained groups to pair.";
    0
};
_participants sort true;

// Resolve the group object by groupId to compute its manpower footprint
private _fnc_resolveGroup = {
    params ["_grpId"];
    private _grp = objNull;
    { if (groupId _x == _grpId) exitWith { _grp = _x }; } forEach allGroups;
    _grp
};

// Pairing resolver: consecutive teams share one trail arclength, opposite sides
private _cursor = 0; // longitudinal distance along the trail (relative to leader)
private _pairIndex = 0;
private _count = count _participants;
for "_i" from 0 to (_count - 1) step 2 do {
    private _aIdx = _i;
    private _bIdx = _i + 1;
    private _hasPartner = (_bIdx < _count);

    // Pair footprint: the bigger member drives the inter-pair advance
    private _footprintMax = 0;
    private _members = [_aIdx];
    if (_hasPartner) then { _members pushBack _bIdx; };

    {
        private _grpId = (_participants select _x) select 1;
        private _grp = [_grpId] call _fnc_resolveGroup;
        private _unitCount = if (!isNull _grp) then { count (units _grp) max 1 } else { 4 };
        // MEASURED footprint: real leader->rearmost distance floored by the
        // nominal model (men * 3.5), + 3m tactical interval
        private _rearmost = 0;
        if (!isNull _grp) then {
            { private _d = (leader _grp) distance2D _x; if (_d > _rearmost) then { _rearmost = _d; }; } forEach (units _grp);
        };
        private _footprint = (_rearmost max (_unitCount * 3.5)) + 3.0;
        if (_footprint > _footprintMax) then { _footprintMax = _footprint; };
    } forEach _members;

    // Assign both members of the pair: same arclength, opposite lateral sides
    {
        private _idx = _x;
        private _side = if ((_idx % 2) == 0) then { -1 } else { 1 }; // left / right
        private _grpId = (_participants select _idx) select 1;
        private _entry = FTCS_Groups_Registry_Table getOrDefault [_grpId, createHashMap];

        _entry set ["trailOffsetDist", _cursor];
        _entry set ["trailShoulderOffset", (_pairHalfSeparation * _side)];
        FTCS_Groups_Registry_Table set [_grpId, _entry];
    } forEach _members;

    // Advance to the next pair position
    _cursor = _cursor + _footprintMax + _pairGap;
    _pairIndex = _pairIndex + 1;
};

// Lock the layout and update the max offset for the trail trimming logic
_anchor set ["columnLayout", "COMPACT"];
_anchor set ["maxTrailOffset", _cursor];

systemChat format ["[TRAIL COMPACT] Double lane engaged: %1 pairs, chain depth %2m.", _pairIndex, round _cursor];
_pairIndex
