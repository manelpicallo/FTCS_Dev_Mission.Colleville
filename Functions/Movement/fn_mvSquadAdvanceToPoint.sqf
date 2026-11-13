/*
    ================================================================================
    File: fn_mvSquadAdvanceToPoint.sqf
    Module: Movement
    Author: FTCS Team
    Description: SQUAD-scope movement primitive "ADVANCE_TO_POINT" (Movement
                 class). Dispatches every BOUND team of the squad to pre-computed
                 arrival points around a marked world position, replicating the
                 validated formation march pipeline:
                     1. Geometry: each bound team receives a ring/staggered
                        arrival point around the target, sized with its measured
                        footprint (leader->rearmost distance floored by men*3.5)
                        plus a tactical gap - the same spacing model as the
                        road/trail compact columns.
                     2. Registry first: each team writes its arrival point
                        ("mvTargetPos"), switches its movingMode to
                        "MOVING_TO_OBJECTIVE" and stamps its movementType to
                        "NORMAL_MOVE" BEFORE moving - every follow flow observes
                        the state change and yields.
                     3. Per-team march loop (fn_mvTeamMarchLoop, spawned): 1s
                        tick, group move + doFollow, constant pace (no
                        distance-based acceleration), single setFormDir align
                        on arrival - identical behaviour to road/trail marches.
                     4. IA discipline: the standard march profile applied through
                        the project's group functions (rule 15) - never raw
                        native commands scattered here.
                 DETACHED teams (teamAttachment != SQUAD_BOUND: emplaced MG,
                 deployed scouts) are SKIPPED entirely - the whole point of the
                 attachment field (see fn_movementBoundTeams).
                 Future primitives (bounding overwatch, assault, suppression)
                 build on this same skeleton, changing only the point generation
                 and sequencing.
    Params:
        0: GROUP  - Squad group issuing the movement (actor).
        1: ARRAY  - Target world position [x, y, z] (the marked/confirmed point).
        2: STRING - On-arrival behaviour: "KEEP_FORMATION" (re-anchor the slot at
                    the target and resume follow) or "HOLD" (detach + hold at
                    the arrival point) (default "KEEP_FORMATION").
        3: NUMBER - OPTIONAL arrival facing in degrees. Default -1 = face the
                    objective (approach axis, the marked-point behaviour).
                    Flank/fall-back orders pass the platoon axis of advance.
    Returns:
        NUMBER - Count of teams dispatched (0 when nothing was bound).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_squad", grpNull], ["_targetPos", [0, 0, 0]], ["_arrivalBehaviour", "KEEP_FORMATION"], ["_arrivalFacing", -1, [0]]];

if (isNull _squad || { count _targetPos < 2 }) exitWith { 0 };

private _boundTeams = [_squad] call FTCS_fnc_movementBoundTeams;
if (count _boundTeams == 0) exitWith {
    diag_log format ["[FTCS][MV] ADVANCE_TO_POINT: no bound teams for %1 - nothing dispatched.", groupId _squad];
    0
};

// Axis toward the target from the squad's current position (arrival ring is
// oriented so teams end up BEHIND/AROUND the objective relative to the approach)
private _squadLeader = leader _squad;
private _approachBearing = if (!isNull _squadLeader) then { (getPosATL _squadLeader) getDir _targetPos } else { 0 };

// Nominal team footprint helper (same model as trail/road compact columns):
// men * 3.5m + 3m tactical interval. The MEASURED leader->rearmost distance is
// deliberately NOT used here: it reflects the team's CURRENT dispersion, so a
// spread-out squad would inflate the depth and park later teams tens of meters
// behind the objective (observed live: only the first team arrived near the
// mark). Formation footprint scales with headcount, not with dispersion.
private _fnc_teamFootprint = {
    params ["_grp"];
    private _unitCount = count (units _grp) max 1;
    (_unitCount * 3.5) + 3.0
};

// Arrival geometry: a single CONTACT LINE of bound teams at fixed depth in
// front of the marked point, spread laterally along that line. Every team sits
// at the SAME depth (the line parallel to the approach axis), alternating
// sides and widening outward: first pair at +/-5m, second pair at +/-10m...
// (lateral step grows with the pair index). No depth staggering: the squad
// forms abreast on the objective, not in a column behind it.
private _sortedTeams = _boundTeams;           // bound list already in march order
private _leftSide = true;
private _lateralStep = 0;                     // +5m per completed pair
private _dispatched = 0;

// Arrival facing: explicit platoon-axis facing (flank/fall-back) when supplied,
// otherwise the approach axis toward the objective (marked-point default).
private _effectiveFacing = if (_arrivalFacing >= 0) then { _arrivalFacing } else { _approachBearing };

{
    private _team = _x;
    private _footprint = [_team] call _fnc_teamFootprint; // documented model
    private _lateral = if (_leftSide) then { -1 } else { 1 };

    // Lateral distance: first pair 5m each side, then 10m, 15m... as pairs widen
    private _lateralDist = (5.0 + _lateralStep) * _lateral;

    // Advance the outward spread after completing each PAIR (both members placed)
    if (!_leftSide) then { _lateralStep = _lateralStep + 5.0; };
    _leftSide = !_leftSide;

    // Arrival point: single depth line 6m short of the objective (teams must
    // NOT stand on the marked point itself), spread purely laterally.
    private _depth = 6.0;
    private _behindPos = _targetPos getPos [_depth, (_approachBearing + 180) % 360];
    private _arrivalPos = _behindPos getPos [abs _lateralDist, if (_lateralDist < 0) then { (_approachBearing + 270) % 360 } else { (_approachBearing + 90) % 360 }];

    // 2. Registry-first state transition. movementType records the ACTIVE
    // tactical manoeuvre (NORMAL_MOVE for this primitive) so future movement
    // types (bounding overwatch, assault...) can gate/interrupt consistently;
    // fn_mvTeamMarchLoop restores it to NORMAL_MOVE-free state on completion.
    private _grpId = groupId _team;
    private _entry = FTCS_Groups_Registry_Table getOrDefault [_grpId, createHashMap];
    _entry set ["mvTargetPos", _arrivalPos];
    _entry set ["movingMode", "MOVING_TO_OBJECTIVE"];
    _entry set ["movementType", "NORMAL_MOVE"];
    FTCS_Groups_Registry_Table set [_grpId, _entry];

    // 3. Per-team march loop (same skeleton as the formation follow loops).
    // The objective bearing is passed in (approach axis) so the arrival
    // alignment faces the objective regardless of where the team came from.
    [_team, _arrivalPos, _arrivalBehaviour, _effectiveFacing] spawn FTCS_fnc_mvTeamMarchLoop;

    _dispatched = _dispatched + 1;
} forEach _sortedTeams;

diag_log format ["[FTCS][MV] ADVANCE_TO_POINT: %1 teams dispatched to %2 (%3).", _dispatched, _targetPos, _arrivalBehaviour];
_dispatched
