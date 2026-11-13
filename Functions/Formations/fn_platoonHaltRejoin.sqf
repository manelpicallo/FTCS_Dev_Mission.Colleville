/*
    ================================================================================
    File: fn_platoonHaltRejoin.sqf
    Module: Formations
    Author: FTCS Team
    Description: PLATOON-level HALT and REJOIN primitive (lieutenant orders).

                 PLT_HALT:
                  - Cancels any active squad mark-3D march (movingMode flip ends
                    every mvTeamMarchLoop), every bound group freezes where it
                    is at that instant - that frozen spot IS its formation
                    point, it does NOT exclude it from the formation.
                  - Snapshot stored REGISTRY-FIRST: platoon orderState "HALTED",
                    per-group haltedAtPos + haltSnapshotLeaderPos + haltFacing.
                    Company-scale safe (FTCS_Platoons_Registry), no globals.
                  - The platoon leader is NOT frozen: he keeps exploring.
                  - Follow loops stay alive: while orderState == "HALTED" their
                    slot source switches from the (far, exploring) leader to
                    the group's haltedAtPos snapshot - squads in transit
                    converge on their freezing point, not on the lieutenant.
                  - The march watchdog KEEPS RUNNING (never paused): in HALT
                    its L1 re-route and L2 sprint target the group snapshot
                    (haltedAtPos), so stragglers of squads still in transit
                    recover toward the freezing point while the lieutenant
                    scouts.

                 PLT_REJOIN:
                  - Squads converge on the CURRENT platoon leader position
                    (mechanism: mvFormationShift - re-derive relPosition so the
                    follow loop projects each squad slot onto leader +
                    frozen-offset). The offset used is the squad's frozen
                    offset from the halt snapshot leader position, rotated into
                    the platoon axis of advance at REJOIN time - so the platoon
                    re-groups around the lieutenant preserving its geometry.
                  - Destination squads sent to a 3D mark DO participate (their
                    march is a slot re-anchor, not an emplacement). Only teams
                    with teamAttachment != "SQUAD_BOUND" (genuinely emplaced:
                    MGs, deployed scouts) are excluded from both orders.
                  - Facing on arrival: platoon axis of advance (fn_platoonAdvanceAxis).
                  - State returns to "MARCH"; follow loops resume normal
                    leader-relative/absolute tracking (they never stopped).

     Registry layout:
         platoon entry (FTCS_Platoons_Registry > pltId):
             "orderState"            : "MARCH" | "HALTED" | "REJOINING"
             "haltSnapshotLeaderPos" : [x, y, z]
             "haltFacing"            : NUMBER
         group entry (FTCS_Groups_Registry_Table > groupId):
             "haltedAtPos"           : [x, y, z]  (set on HALT, cleared on REJOIN)

     Params:
         0: STRING - "HALT" | "REJOIN".
         1: NUMBER - OPTIONAL platoon ID (default: player's platoon).
     Returns:
         BOOLEAN - true when the order was applied.
     Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_order", ""], ["_pltId", -1, [-1]]];

if (!(_order in ["HALT", "REJOIN"])) exitWith { false };
if (_pltId < 0) then { _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1]; };

// --- Resolve the platoon registry entry (company-scale, no globals) ----------
// RULE 16 compliance: the squad ORBAT comes from the PLATOON REGISTRY
// (FTCS_Platoons_Registry > pltId > "squads", seeded by fn_registryInit at
// doctrine parse time). Runtime code NEVER re-derives squads from
// FTCS_Company_Data.
private _registry = missionNamespace getVariable ["FTCS_Platoons_Registry", createHashMap];
private _plt = _registry getOrDefault [_pltId, createHashMap];
private _squadList = (_plt getOrDefault ["squads", []]) select { !isNull _x };

// --- Platoon leader (lieutenant) resolution ----------------------------------
private _pltLeader = missionNamespace getVariable ["FTCS_Platoon_Leader_Unit", objNull];
if (isNull _pltLeader) then {
    private _pltGrp = missionNamespace getVariable [format ["FTCS_Platoon_Group_%1", _pltId], grpNull];
    if (!isNull _pltGrp) then { _pltLeader = leader _pltGrp; };
};
if (isNull _pltLeader) then {
    { if (!isNull _x && { !isNull (leader _x) }) exitWith { _pltLeader = leader _x }; } forEach _squadList;
};
if (isNull _pltLeader) exitWith {
    systemChat "[PLT HALT/REJOIN] Error: platoon leader not resolved.";
    false
};

// --- Collect participating groups --------------------------------------------
// Every registered group belonging to this platoon's squads, EXCLUDING:
//   - the leader's own group (the lieutenant is never halted/rejoined)
//   - teams genuinely emplaced (teamAttachment != "SQUAD_BOUND": deployed
//     MGs, detached scouts). Teams marching to a 3D mark ARE SQUAD_BOUND,
//     so they DO participate: HALT freezes them mid-transit at their haltedAtPos,
//     REJOIN re-anchors their slot (march re-anchoring, not emplacement).
private _pltIdTag = format ["SQD_%1_", _pltId];
private _participants = [];
{
    if (isNull _x) then { continue; };
    _participants pushBackUnique _x;
    // Fireteams / sub-teams bound to this squad (registry family scan)
    {
        private _gKey = _x;
        private _entry = _y;
        if ((format ["%1", _gKey]) find _pltIdTag == 0
            && { (_entry getOrDefault ["teamAttachment", "SQUAD_BOUND"]) == "SQUAD_BOUND" }) then {
            private _g = missionNamespace getVariable [_gKey, grpNull];
            if (!isNull _g && { !isNull (leader _g) }) then { _participants pushBackUnique _g; };
        };
    } forEach FTCS_Groups_Registry_Table;
} forEach _squadList;

_participants = _participants select { !isNull _x && { group _pltLeader != _x } && { count (units _x) > 0 } };

// ===========================================================================
// HALT
// ===========================================================================
if (_order == "HALT") exitWith {

    // Idempotence: an already-frozen platoon just re-confirms (no state churn)
    private _curState = _plt getOrDefault ["orderState", "MARCH"];

    // 1. Registry-FIRST snapshot before touching any loop state
    _plt set ["orderState", "HALTED"];
    _plt set ["haltSnapshotLeaderPos", getPosATL _pltLeader];
    _plt set ["haltFacing", [_pltLeader] call FTCS_fnc_platoonAdvanceAxis];

    {
        private _grpId = groupId _x;
        private _entry = FTCS_Groups_Registry_Table getOrDefault [_grpId, createHashMap];

        // Snapshot the frozen position of THIS group (its formation point)
        private _ld = leader _x;
        _entry set ["haltedAtPos", getPosATL _ld];

        // Cancel any in-flight mark-3D march: mvTeamMarchLoop exits as soon as
        // movingMode leaves "MOVING_TO_OBJECTIVE". Also ends flank/fallback
        // HOLD_POSITION loops and road/trail follows cleanly.
        _entry set ["movingMode", "HALT_FREEZE"];

        // Kill the live follow loop(s) of this group: both the cross-country
        // follow (fn_formationsGroupDoFollowCommander) and the road/trail
        // follow (fn_formationsGroupFollowRoad) poll FTCS_FollowThread_ID -
        // bumping it makes their while-loop exit on the next tick, so no
        // orphan thread re-issues moves toward the (exploring) lieutenant
        // while the platoon is frozen.
        _x setVariable ["FTCS_FollowThread_ID", -1];

        // Restore march pacing: any in-flight catch-up sprint (limitSpeed -1
        // granted by watchdog level 2) must be reverted or the frozen unit
        // would keep wandering past its snapshot point. The group stays at its
        // own frozen position (haltedAtPos) - its formation point.
        { _x limitSpeed 0; } forEach (units _x);
        // Freeze in place: a short hold move cancels any pending long move
        _x move (getPosATL _ld);

        FTCS_Groups_Registry_Table set [_grpId, _entry];
    } forEach _participants;

    _registry set [_pltId, _plt];
    missionNamespace setVariable ["FTCS_Platoons_Registry", _registry];

    // Face the platoon axis: static security facing without moving anyone
    private _f = _plt getOrDefault ["haltFacing", getDir _pltLeader];
    { _x setFormDir _f; } forEach _participants;

    if (_curState != "HALTED") then {
        systemChat format ["[PLT HALT] Platoon frozen in place (%1 elements). Lieutenant free to explore.", count _participants];
        diag_log format ["[FTCS][HALT] plt %1: %2 groups frozen at snapshot; watchdog keeps routing stragglers to haltedAtPos.", _pltId, count _participants];
    };
    true
};

// ===========================================================================
// REJOIN
// ===========================================================================

// Requires a previous HALT (rejoin semantics depend on the frozen snapshot)
if ((_plt getOrDefault ["orderState", "MARCH"]) != "HALTED") exitWith {
    systemChat "[PLT REJOIN] Refused: the platoon is not HALTED - issue HALT first.";
    diag_log "[FTCS][REJOIN] Refused: platoon orderState != HALTED.";
    false
};

_plt set ["orderState", "REJOINING"];
private _snapshotLeaderPos = _plt getOrDefault ["haltSnapshotLeaderPos", getPosATL _pltLeader];
private _rejoinFacing = [_pltLeader] call FTCS_fnc_platoonAdvanceAxis;

{
    private _grpId = groupId _x;
    private _entry = FTCS_Groups_Registry_Table getOrDefault [_grpId, createHashMap];

    // Restore pacing (limitSpeed 0 from HALT) and resume radio discipline
    { _x limitSpeed -1; } forEach (units _x);

    // Mode restored is the platoon's ACTIVE follow mode (REL/ABS)
    private _followModeR = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
    if (!(_followModeR in ["FOLLOWING_COMMANDER_REL", "FOLLOWING_COMMANDER_ABS"])) then {
        _followModeR = "FOLLOWING_COMMANDER_REL";
    };

    // ---------------- HIERARCHY SPLIT ----------------
    // SQUAD-level groups (in the registry "squads" list): reference = the
    // lieutenant. Re-anchor their slot to (current lieutenant pos + frozen
    // offset from the halt snapshot) and respawn their follow loop with
    // _pltLeader.
    // FIRETEAM/sub-team groups (NOT in the squads list): reference = their
    // SQUAD LEADER. Re-anchoring them with mvFormationShift re-derives
    // their slot against the WRONG reference (falls back to
    // FTCS_Group_Commander), which collapsed every fireteam onto one shared
    // anchor in front of the lieutenant. Their relPosition is untouched:
    // restore mode + respawn their loop with their squad leader ref only -
    // the squad-leader loop drags them along with formation preserved.
    if (_x in _squadList) then {
        // Destination: CURRENT lieutenant position + frozen slot offset
        //     _frozenOffset = _haltPos - _snapshotLeaderPos (leader->squad)
        private _haltPos = _entry getOrDefault ["haltedAtPos", getPosATL (leader _x)];
        private _frozenOffset = _haltPos vectorDiff _snapshotLeaderPos;
        private _dist = vectorMagnitude _frozenOffset;
        private _bearing = if (_dist > 1) then { _snapshotLeaderPos getDir _haltPos } else { _rejoinFacing };
        private _target = (getPosATL _pltLeader) getPos [_dist, _bearing];

        _entry set ["haltedAtPos", nil];
        _entry set ["movingMode", _followModeR];
        FTCS_Groups_Registry_Table set [_grpId, _entry];

        // Re-anchor the slot registry-first, then respawn the follow loop
        // (HALT killed it: FTCS_FollowThread_ID = -1).
        [_x, _target] call FTCS_fnc_mvFormationShift;
        [_x, _followModeR, _pltLeader] spawn FTCS_fnc_formationsGroupDoFollowCommander;

        diag_log format ["[FTCS][REJOIN] %1 (squad) re-anchoring to %2 (dist %3m, frozen offset preserved).", _grpId, _target, round _dist];
    } else {
        _entry set ["haltedAtPos", nil];
        _entry set ["movingMode", _followModeR];
        FTCS_Groups_Registry_Table set [_grpId, _entry];

        // Fireteam: respawn its follow loop with its OWN squad leader as
        // reference - same hierarchy it had before the halt. The squad
        // parent is resolved via the registry-stamped parentSquadGroup
        // (groupIds are doctrine display names, so prefix matching does
        // NOT work). Registry relPosition untouched (formation preserved).
        private _parentSqd = _entry getOrDefault ["parentSquadGroup", grpNull];
        private _sqdLeaderRef = if (!isNull _parentSqd && { !isNull (leader _parentSqd) }) then { leader _parentSqd } else { _pltLeader };
        [_x, _followModeR, _sqdLeaderRef] spawn FTCS_fnc_formationsGroupDoFollowCommander;

        diag_log format ["[FTCS][REJOIN] %1 (fireteam) follow respawned on squad-leader ref %2 (geometry preserved).", _grpId, groupId _parentSqd];
    };
} forEach _participants;

// Settle: once every participant left REJOIN_MOVE (mvSquadMoveOrder dispatches
// synchronously per mode), flip the platoon state back to MARCH.
_plt set ["orderState", "MARCH"];
_plt set ["haltSnapshotLeaderPos", nil];
_plt set ["haltFacing", nil];
_registry set [_pltId, _plt];
missionNamespace setVariable ["FTCS_Platoons_Registry", _registry];

systemChat format ["[PLT REJOIN] %1 elements converging on the lieutenant (facing %2°).", count _participants, round _rejoinFacing];
diag_log format ["[FTCS][REJOIN] plt %1: %2 groups re-anchoring to leader via mvFormationShift.", _pltId, count _participants];
true
