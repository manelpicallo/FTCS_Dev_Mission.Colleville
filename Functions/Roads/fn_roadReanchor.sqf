/*
    ================================================================================
    File: fn_roadReanchor.sqf
    Module: Roads
    Author: FTCS Team
    Description: Rebuilds the road march anchor onto a NEW road branch after the
                 platoon leader performs a sustained turn (junction / T crossing).
    Trigger policy (evaluated by fn_roadAdvanceAnchor, ALL must hold - AND):
    (1) real movement bearing deviated beyond the angular dead-zone,
    (2) cumulative real displacement since deviation start >= 15 m,
    (3) a road segment within 20 m of the leader position,
    sustained for _reanchorDelay seconds OF SIMULATION TIME (mission 'time').
                 No cardinal reference is used: the new march sense is the
                 leader's measured movement bearing at re-anchor moment.
                 Reuses the order-time composition philosophy:
                 rear portion = PRESERVED old path truncated at the junction cut
                 (its march sense is already correct, never rebuilt) + front
                 stretch mapped fresh on the new bearing (roadGetPointsBehind
                 with inverted override) + leader arclength at the cut point.
                 Squad offsets (roadOffsetDist / roadShoulderOffset) are NOT
                 touched: slots re-sample on the new path preserving order.
    Params:
        0: OBJECT - Platoon leader unit.
        1: HASHMAP - Road march anchor (mutated in-place on success).
        2: NUMBER - New march bearing (leader's real movement bearing, degrees).
    Returns:
        BOOL - true if the anchor was rebuilt, false if no road branch nearby.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_leader", objNull], ["_anchor", locationNull], ["_newBearing", 0]];

if (isNull _leader || { _anchor isEqualTo locationNull }) exitWith { false };

private _leaderPos = getPosATL _leader;

// Keep the EXISTING rear path: it already traced the real route up to this
// junction with the correct march sense. Rebuilding it from the nearest road
// segment could pick the old road branch inverted (slots jumping ahead of the
// junction reversed). The old path is only TRUNCATED at the point closest to
// the leader; only the forward stretch is mapped fresh on the new bearing.
private _oldPath = _anchor getOrDefault ["roadPath", []];

// Required rear depth: deepest assigned slot offset plus a safety margin
private _maxAssignedDist = 0;
{
    private _od = _y getOrDefault ["roadOffsetDist", 0];
    if (_od > _maxAssignedDist) then { _maxAssignedDist = _od; };
} forEach FTCS_Groups_Registry_Table;

// Truncate the old path at the sampled point nearest to the leader (junction cut)
private _cutIdx = 0;
private _bestCutDist = 1e10;
{
    private _d = (_x select 0) distance2D _leaderPos;
    if (_d < _bestCutDist) then { _bestCutDist = _d; _cutIdx = _forEachIndex; };
} forEach _oldPath;

// Rear portion = old path from tail (index 0) up to the cut point (inclusive).
// Its tangents already point along the march sense: kept untouched.
private _rearPath = [];
for "_ri" from 0 to _cutIdx do {
    _rearPath pushBack (_oldPath select _ri);
};

// Leader's arclength = length of the preserved rear portion up to the cut
// (computed BEFORE any safety extension, so the extension never counts)
private _headStart = 0;
for "_pi" from 0 to (count _rearPath - 2) do {
    _headStart = _headStart + (((_rearPath select _pi) select 0) distance2D ((_rearPath select (_pi + 1)) select 0));
};

// Safety: if the preserved rear is shorter than the deepest slot, extend it
// straight-line along its last tangent (no graph traversal involved)
private _rearLength = _headStart;
if (_rearLength < _maxAssignedDist + 20 && { count _rearPath >= 2 }) then {
    _rearPath = [_rearPath, (_maxAssignedDist + 20 - _rearLength), false] call FTCS_fnc_roadPathExtend;
};

// Compose the MARCH-ORIENTED path (index 0 = rearmost, last = frontmost):
// preserved old rear portion (tail -> junction, march sense untouched)
// + fresh forward stretch ahead of the leader on the NEW branch
// (rear heading inverted via dirOverride)
private _frontPath = [_leader, 200, (_newBearing + 180) % 360] call FTCS_fnc_roadGetPointsBehind;
if (count _frontPath < 2) exitWith { false };
// Returned tangents point BACK at the leader: flip them to march orientation
{ _x set [1, ((_x select 1) + 180) % 360]; } forEach _frontPath;
// Drop the duplicated joint point near the leader and append the front stretch
_frontPath deleteAt 0;
{ _rearPath pushBack _x; } forEach _frontPath;

// Swap the anchor geometry in-place: consumers re-sample transparently next tick.
// columnLayout is PRESERVED: if the column was compacted, the re-anchored column
// stays compact (only an explicit Staggered order changes the layout back).
_anchor set ["roadPath", _rearPath];
_anchor set ["headDist", _headStart];
_anchor set ["advanceDir", _newBearing];
_anchor set ["anchorPos", _leaderPos];
_anchor set ["lastAnchorMovePos", _leaderPos];
_anchor set ["devStart", -1];
_anchor set ["devAccumDist", 0];
// edgeMode and columnLayout are intentionally NOT touched: a junction re-anchor
// preserves the current road-edge placement and column layout of the march.

true
