/*
    ================================================================================
    File: fn_formationsRoadCompactColumn.sqf
    Module: Formations
    Author: FTCS Team
    Description: Compacts the road march column by removing the staggered
                 distance stepping between consecutive road slots.
                 - Collects every registered group that participates in the road
                   march (roadOffsetDist > 0) and splits it into LEFT and RIGHT
                   shoulder columns according to its current roadShoulderOffset
                   sign (-1 = left / +1 = right).
                 - Within each column, groups keep their relative order (sorted
                   by original roadOffsetDist ascending) and are re-anchored so
                   that each one sits at:
                       dist = previous dist + previous pace + _compactGap
                   where pace = unitCount * 3 + 3 (the compact footprint,
                   wider per-man stride than the staggered layout to keep the
                   inner formation clear of neighbouring teams on the shoulder).
                   The first element of each column starts 1m behind the
                   leader's arclength on the frozen anchor path.
                 - Groups with roadOffsetDist <= 0 (forward elements such as
                   scouts) or == 0 (center trail) are NOT compacted: they keep
                   their assigned distance and side untouched.
                 - Only registry offsets are rewritten: the runtime consumers
                   (fn_formationsGroupFollowRoad and the live debug worker)
                   re-sample the frozen anchor path transparently on their next
                   tick, so the column physically compacts by walking.
                 - Parameterized by side: "BOTH" (compact, default), "LEFT"
                   (single left-shoulder column) and "RIGHT" (single right-
                   shoulder column) are supported for the future menu options.
    Params:
        0: NUMBER - Platoon ID whose road march anchor is compacted.
        1: STRING - Column scope: "BOTH" | "LEFT" | "RIGHT" (default "BOTH").
    Returns:
        NUMBER - Count of re-assigned groups (0 if not compactable).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_pltId", 1], ["_scope", "BOTH"]];

private _compactGap = 2.5; // meters between consecutive teams inside a column
private _headGap = 1.0;    // meters from the leader arclength to the first slot

private _anchor = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltId], createHashMap];
private _roadPath = _anchor getOrDefault ["roadPath", []];
if (count _roadPath < 2) exitWith {
    systemChat "[ROAD COMPACT] Error: no active road march column (anchor missing).";
    0
};
private _leaderArcLen = _anchor getOrDefault ["headDist", 0];

// Collect road-march participants from the master registry, split by shoulder side.
// NOTE: registry keys are groupId strings; the group OBJECT is not required here -
// team pace (footprint) is derived from consecutive original slot distances, which
// roadColumnSet already materialized (dist(next) - dist(current) - interSquadGap).
private _leftGroups = [];
private _rightGroups = [];
{
    private _entry = _y;
    private _grpId = _x;
    private _offsetDist = _entry getOrDefault ["roadOffsetDist", -1];
    private _shoulder = _entry getOrDefault ["roadShoulderOffset", 0];

    // Only rear-marching groups on a shoulder participate; forward/center stay untouched.
    // Scope LEFT/RIGHT (single-shoulder column): EVERY participant joins the requested
    // chain regardless of its original side — all teams end up on the same shoulder.
    if (_offsetDist > 0 && {_shoulder != 0}) then {
        private _bucket = switch (_scope) do {
            case "LEFT": { _leftGroups };
            case "RIGHT": { _rightGroups };
            default { if (_shoulder < 0) then { _leftGroups } else { _rightGroups }; };
        };
        _bucket pushBack [_offsetDist, _grpId];
    };
} forEach FTCS_Groups_Registry_Table;

if (count _leftGroups == 0 && count _rightGroups == 0) exitWith {
    systemChat "[ROAD COMPACT] Error: no formed road march slots found in the registry.";
    0
};

// Sort each column by original road offset (march order is preserved)
_leftGroups sort true;
_rightGroups sort true;

// Helper: sample the path at arclength (defined BEFORE the resolver that uses it)
private _fnc_getRoadSampleLocal = {
    params ["_distTarget", "_path"];
    private _accum = 0;
    private _foundPt = _path select 0;
    for "_i" from 0 to (count _path - 2) do {
        private _ptA = (_path select _i) select 0;
        private _ptB = (_path select (_i + 1)) select 0;
        private _d = _ptA distance2D _ptB;
        if ((_accum + _d) >= _distTarget) exitWith {
            private _frac = if (_d > 0) then { (_distTarget - _accum) / _d } else { 0 };
            _foundPt = [
                [
                    (_ptA select 0) + ((_ptB select 0) - (_ptA select 0)) * _frac,
                    (_ptA select 1) + ((_ptB select 1) - (_ptA select 1)) * _frac,
                    (_ptA select 2) + ((_ptB select 2) - (_ptA select 2)) * _frac
                ],
                (_path select _i) select 1,
                (_path select _i) select 2
            ];
        };
        _accum = _accum + _d;
    };
    _foundPt
};

// Resolver: assign compacted distances to one shoulder column.
// Offsets are RELATIVE to the leader (consumers sample at headDist - offset):
// first team sits headGap meters behind the leader, then each next team adds
// its own manpower footprint (unitCount * 2m pace + 3m interval) plus the
// compact gap. The ABSOLUTE arclength used for geometry is headDist - offset.
private _compactColumn = {
    params ["_groups", "_side", "_startOffset"];
    private _cursor = _startOffset; // relative offset behind the leader
    private _assigned = 0;
    {
        private _grpId = _x select 1;
        private _entry = FTCS_Groups_Registry_Table getOrDefault [_grpId, createHashMap];

        // Resolve the group object by groupId (allGroups scan is reliable;
        // missionNamespace lookup by groupId string is NOT a valid mechanism)
        private _grp = objNull;
        { if (groupId _x == _grpId) exitWith { _grp = _x }; } forEach allGroups;
        private _unitCount = if (!isNull _grp) then { count (units _grp) max 1 } else { 4 };

        // MEASURED team length: real leader->rearmost distance floored by the
        // nominal model (men * 3.5), + 3m tactical interval. Engine formations
        // do not spread linearly with man count, hence the measurement.
        private _rearmost = 0;
        if (!isNull _grp) then {
            { private _d = (leader _grp) distance2D _x; if (_d > _rearmost) then { _rearmost = _d; }; } forEach (units _grp);
        };
        private _pace = (_rearmost max (_unitCount * 3.5)) + 3.0;

        // ABSOLUTE arclength on the march-oriented path for this slot
        private _absArc = (_leaderArcLen - _cursor) max 0;

        // Shoulder offset: staggered edge value on this column's side, shifted
        // (steps * 3m) beyond the asphalt edge by the anchor edge margin steps
        private _sample = [_absArc, _roadPath] call _fnc_getRoadSampleLocal;
        private _width = _sample select 2;
        private _effectiveWidth = if (_width isEqualType 0 && {_width > 0}) then { _width } else { 4.5 };
        private _edgeMarginC = (_anchor getOrDefault ["edgeMarginSteps", 0]) * 3.0;
        private _shoulderOffset = if (_effectiveWidth <= 1.5) then {
            0
        } else {
            if (_edgeMarginC > 0) then {
                ((_effectiveWidth / 2.0) + _edgeMarginC) * _side
            } else {
                ((_effectiveWidth / 2.0) * 0.85) * _side
            };
        };

        // Perpendicular offset from road center line
        private _tangent = _sample select 1;
        private _perpDir = (_tangent + 90) % 360;
        private _finalPos = (_sample select 0) getPos [abs _shoulderOffset, if (_shoulderOffset < 0) then { (_perpDir + 180) % 360 } else { _perpDir }];

        // Rewrite registry: runtime consumers pick this up on next tick
        _entry set ["roadOffsetDist", _cursor];
        _entry set ["roadShoulderOffset", _shoulderOffset];
        _entry set ["roadTargetPos", _finalPos];
        _entry set ["roadTangentDir", _tangent];
        FTCS_Groups_Registry_Table set [_grpId, _entry];

        _assigned = _assigned + 1;
        // Advance by this team's own manpower footprint plus the compact gap
        _cursor = _cursor + _pace + _compactGap;
    } forEach _groups;
    _assigned
};

// Apply according to scope
private _assignedCount = 0;
if (_scope in ["BOTH", "LEFT"]) then {
    _assignedCount = _assignedCount + ([_leftGroups, -1, _headGap] call _compactColumn);
};
if (_scope in ["BOTH", "RIGHT"]) then {
    _assignedCount = _assignedCount + ([_rightGroups, 1, _headGap] call _compactColumn);
};

systemChat format ["[ROAD COLUMN] %1 teams re-chained on the %2 shoulder (scope: %3).", _assignedCount, if (_scope == "LEFT") then { "LEFT" } else { "RIGHT" }, _scope];
// Layout state: LEFT/RIGHT single-shoulder columns lock the layout; re-ordering
// Staggered Column restores STAGGERED and re-enables Compact and the other modes.
_anchor set ["columnLayout", if (_scope == "LEFT") then { "LEFT" } else { "RIGHT" }];
_assignedCount
