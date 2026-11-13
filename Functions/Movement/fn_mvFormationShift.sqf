/*
    ================================================================================
    File: fn_mvFormationShift.sqf
    Module: Movement
    Author: FTCS Team
    Description: FORMATION_SHIFT movement primitive. Translates a squad that is
                 marching in cross-country formation (FOLLOWING_COMMANDER_REL or
                 FOLLOWING_COMMANDER_ABS) to a marked anchor world point,
                 PRESERVING the squad's internal formation geometry.
                 Mechanism (aligned with the live follow loops):
                 - The squad leader's own follow loop projects its slot from its
                   registry relPosition [dist, bearing] relative to its reference
                   leader (the platoon leader) every tick - no stored world point
                   is consumed. Therefore the shift is performed by RE-DERIVING
                   the squad leader's relPosition so that the projected slot lands
                   exactly on the marked target:
                       requiredDist    = distance(referenceLeader, target)
                       requiredBearing = bearing(referenceLeader -> target) -
                                         referenceHeading (REL) or -
                                         platoonDir (ABS)
                   The follow loop then walks the squad leader there, and every
                   bound team (dragged by the squad leader through its own
                   relPosition offsets) travels WITH him - the internal formation
                   geometry is preserved by construction.
                 - No march thread is spawned; no movingMode change: the existing
                   cross-country follow loops keep running. If the platoon
                   formation moves afterwards, the marked point IS the squad's
                   new fixed anchor (its relPosition now points there).
                 - movementType is stamped NORMAL_MOVE on every bound team.
                 Gate: refuses in road march mode (FOLLOWING_ROAD) and in
                 FREE_MOVE (use mvSquadAdvanceToPoint instead).
    Params:
        0: GROUP  - Squad group to shift (squad leader re-anchored, teams follow).
        1: ARRAY  - Target world position [x, y, z] - the new squad anchor.
    Returns:
        NUMBER - Count of bound teams affected (0 when nothing was shifted).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_squad", grpNull], ["_targetPos", [0, 0, 0]]];

if (isNull _squad || { count _targetPos < 2 }) exitWith { 0 };

private _grpId = groupId _squad;
private _mode = [_grpId, "movingMode"] call FTCS_fnc_registryGet;

// Gate: formation shift only applies while marching in cross-country formation
if (_mode != "FOLLOWING_COMMANDER_REL" && { _mode != "FOLLOWING_COMMANDER_ABS" }) exitWith {
    private _msg = switch (true) do {
        case (_mode == "FOLLOWING_ROAD"): { "road march active - exit road march first." };
        case (_mode == "FREE_MOVE"):      { "units are FREE - use the free-move order." };
        default { format ["unsupported movingMode '%1'.", _mode] };
    };
    systemChat format ["[MV SHIFT] %1: %2", _grpId, _msg];
    diag_log format ["[FTCS][MV-SHIFT] ABORT %1: %2", _grpId, _msg];
    0
};

private _boundTeams = [_squad] call FTCS_fnc_movementBoundTeams;
if (count _boundTeams == 0) exitWith {
    diag_log format ["[FTCS][MV-SHIFT] %1: no bound teams - nothing shifted.", _grpId];
    0
};

// Re-derive the squad leader's relPosition so the follow loop's projection
// lands exactly on the marked target. The reference leader and heading come
// from the same sources the follow loop uses (leader ref group + platoon dir).
private _sqdLeader = leader _squad;
if (isNull _sqdLeader) exitWith { 0 };

private _relPos = [_grpId, "relPosition"] call FTCS_fnc_registryGet;
private _refGroup = if (!isNil "_relPos" && { _relPos isEqualType [] } && { count _relPos > 2 } && { !isNull (_relPos select 2) }) then {
    _relPos select 2
} else {
    missionNamespace getVariable ["FTCS_Group_Commander", grpNull]
};
if (isNull _refGroup || { _refGroup == _squad }) exitWith {
    diag_log format ["[FTCS][MV-SHIFT] ABORT %1: invalid reference group.", _grpId];
    0
};

private _refLeader = leader _refGroup;
if (isNull _refLeader) exitWith { 0 };
private _refPos = getPosATL _refLeader;

// Reference heading - CANONICAL platoon axis (fn_platoonAdvanceAxis):
// REL -> live platoon advance direction; ABS -> fixed compass direction;
// road march -> road-aligned anchor axis. Same source the follow loop uses.
private _refHeading = [_refLeader] call FTCS_fnc_platoonAdvanceAxis;

// Required polar slot so the projected position lands on the target
private _requiredDist = _refPos distance2D _targetPos;
private _worldBearing = _refPos getDir _targetPos;
private _requiredBearing = (_worldBearing - _refHeading + 360) % 360;

// Registry-first: write the re-derived relPosition/formationPosition BEFORE the
// follow loop's next tick. [dist, bearing, refGroup] - the SAME reference the
// loop uses, so its next projection walks the squad leader exactly onto target.
[_grpId, "relPosition", [_requiredDist, _requiredBearing, _refGroup]] call FTCS_fnc_registrySet;
[_grpId, "formationPosition", [_requiredDist, _requiredBearing, _refGroup]] call FTCS_fnc_registrySet;

// Stamp the standard march movement type on every bound team (registry-first)
{
    private _teamGrpId = groupId _x;
    private _entry = FTCS_Groups_Registry_Table getOrDefault [_teamGrpId, createHashMap];
    _entry set ["movementType", "NORMAL_MOVE"];
    FTCS_Groups_Registry_Table set [_teamGrpId, _entry];
} forEach _boundTeams;

systemChat format ["[MV SHIFT] %1: squad anchor -> %2 (%3 teams follow, formation preserved).", _grpId, mapGridPosition _targetPos, count _boundTeams];
diag_log format ["[FTCS][MV-SHIFT] DONE: %1 -> %2 (dist %3, bearing %4, %5 teams).", _grpId, _targetPos, (round (_requiredDist * 10) / 10), (round _requiredBearing), count _boundTeams];
count _boundTeams
