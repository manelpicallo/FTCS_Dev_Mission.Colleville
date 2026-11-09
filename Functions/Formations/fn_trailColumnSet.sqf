/*
    ================================================================================
    File: fn_trailColumnSet.sqf
    Module: Formations
    Author: FTCS Team
    Description: Freezes the leader-trail anchor and assigns staggered trail
                 offsets to every subordinate group for TRAIL_COLUMN march.
                 - Column definition is identical to the road march order of
                   slots (HQ Escort first, then squads per footprint), but the
                   master trajectory is the LEADER'S OWN TRACK: groups inherit
                   the exact points the leader walked, so everyone follows the
                   same terrain line (ravines, tree lanes, defiles).
                 - slot order: [9, 0, 4, 1, 2, 3, 10, 5]; each team consumes
                   (unitCount * 2m + 3m) + inter-squad separation, matching the
                   road march pace math. Scouts (forward / non-positive slots)
                   are excluded from the trail chain.
                 - Offsets are RELATIVE to the leader (consumers sample at
                   headDist - offsetDist over the recorded trail).
                 - Initial formation: all groups start stacked 1m behind the
                   leader and shift into place as the leader walks (the trail
                   grows behind him and slots ride along).
                 Writes into FTCS_Groups_Registry_Table (trailOffsetDist /
                 trailTargetPos / trailTangentDir) consumed by
                 fn_formationsGroupFollowTrail on its 1s ticks.
    Params:
        0: NUMBER - Platoon ID.
        1: ARRAY - Subordinate groups to chain into the column.
        2: OBJECT - Platoon leader unit (trail source).
    Returns:
        NUMBER - Count of chained groups (0 on failure).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_pltId", 1], ["_subGroups", []], ["_leader", objNull]];

if (isNull _leader || { count _subGroups == 0 }) exitWith {
    0
};

private _separateDis = 8.0; // inter-squad separation buffer (matches road march)
private _headGap = 1.0;     // first slot starts 1m behind the leader

// Freeze the trail anchor: seeded with the leader's current position.
// The seed direction is 0 as a placeholder: consumers facing the first walked
// segment (point0 -> point1) instead of trusting the seed facing, so the
// leader's head rotation at order time never leaks into group orientation.
private _trailPath = [[getPosATL _leader, 0]];
private _anchor = createHashMap;
_anchor set ["anchorPos", getPosATL _leader];
_anchor set ["trailPath", _trailPath];
_anchor set ["headDist", 0];               // leader sits at the trail tip (index = last)
_anchor set ["lastAnchorMovePos", getPosATL _leader];
_anchor set ["generation", (missionNamespace getVariable [format ["FTCS_Trail_Gen_PLT_%1", _pltId], 0])];
missionNamespace setVariable [format ["FTCS_Trail_Anchor_PLT_%1", _pltId], _anchor];

// Chain the subordinate groups in march order, same pace math as road march.
// Groups are sorted by their current distance to the leader: nearest first,
// which reproduces the doctrinal vanguard-first ordering without slot plumbing.
private _chained = [];
{
    if (!isNull _x && { _x != group _leader }) then {
        _chained pushBack [(leader _x) distance2D _leader, groupId _x, _x];
    };
} forEach _subGroups;
_chained sort true;

private _cursor = _headGap;
private _assignedCount = 0;
{
    private _grpId = _x select 1;
    private _grp = _x select 2;
    private _unitCount = count (units _grp) max 1;

    private _entry = FTCS_Groups_Registry_Table getOrDefault [_grpId, createHashMap];
    _entry set ["trailOffsetDist", _cursor];
    _entry set ["trailTargetPos", getPosATL _leader]; // first tick refines from the trail
    _entry set ["trailTangentDir", getDir _leader];
    _entry set ["trailShoulderOffset", 0]; // single-file: clears any prior compact pairing
    _entry set ["movingMode", "FOLLOWING_TRAIL"];
    FTCS_Groups_Registry_Table set [_grpId, _entry];

    // Advance by this team's footprint plus the inter-squad separation
    // MEASURED team length: real leader->rearmost distance floored by the
    // nominal model (men * 3.5), + 3m tactical interval + inter-squad separation
    private _rearmost = 0;
    { private _d = (leader _grp) distance2D _x; if (_d > _rearmost) then { _rearmost = _d; }; } forEach (units _grp);
    _cursor = _cursor + ((_rearmost max ((_unitCount * 3.5))) + 3.0) + _separateDis;
    _assignedCount = _assignedCount + 1;
} forEach _chained;

// Highest assigned offset (needed by the trail trimming logic)
private _maxOffset = _cursor;
_anchor set ["maxTrailOffset", _maxOffset];
_anchor set ["columnLayout", "STAGGERED"]; // re-issuing trail unlocks the Compact option

systemChat format ["[TRAIL COLUMN] %1 teams chained behind the leader track.", _assignedCount];
_assignedCount
