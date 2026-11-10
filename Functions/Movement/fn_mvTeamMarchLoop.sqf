/*
    ================================================================================
    File: fn_mvTeamMarchLoop.sqf
    Module: Movement
    Author: FTCS Team
    Description: Per-team march loop for Movement-class primitives (spawned
                 body). Mirrors the validated formation follow loops
                 (fn_formationsGroupFollowRoad / FollowTrail) exactly:
                 - Marching phase (team leader speed > 2 km/h AND arrival point
                   farther than 3m): group move to the arrival point at natural
                   pace, doFollow to keep internal cohesion. NO distance-based
                   acceleration (learned from the trail chase problem).
                 - Arrival: once inside 3m of the target, ONE alignment pass
                   (setFormDir toward the objective bearing) and stop issuing
                   moves; the loop then exits, leaving units settled.
                 - Exit conditions: movingMode leaves "MOVING_TO_OBJECTIVE" (a
                   newer order superseded this one), or group becomes empty/null.
                 - On every exit path movementType resets to "NORMAL_MOVE": the
                   stamped manoeuvre ends with the loop that executed it.
                 IA discipline is owned by the dispatcher/pipeline (rule 15):
                 this loop only navigates.
    Params:
        0: GROUP  - Team group to march.
        1: ARRAY  - Arrival world position [x, y, z].
        2: STRING - Arrival behaviour tag ("KEEP_FORMATION"|"HOLD") - informational
                    for the registry; follow re-anchoring is handled by the
                    existing follow flows reading the pinned state.
        3: NUMBER - Objective bearing (degrees) the team aligns to on arrival
                    (passed by the dispatcher: the approach axis toward the
                    marked point).
    Returns:
        NOTHING (spawned).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_team", grpNull], ["_arrivalPos", [0, 0, 0]], ["_behaviour", "KEEP_FORMATION"], ["_objectiveBearing", 0, [0]]];

if (isNull _team || { count _arrivalPos < 2 }) exitWith {};

private _grpId = groupId _team;
private _threadId = round (time * 1000) + floor (random 1000);
_team setVariable ["FTCS_MV_Thread_ID", _threadId];

// Objective bearing arrives from the dispatcher (approach axis toward the
// marked point) - no per-thread player-derived fallback needed
// Radio protocol silenced for the whole march (same discipline as the trail
// follow loop): silent movement to the objective, no chatter en route.
// On loop exit the protocol is RE-ENABLED in every exit path so units report
// normally once the movement primitive completes.
{ _x disableAI "RADIOPROTOCOL"; } forEach (units _team);
diag_log format ["[FTCS][MV] March loop started: %1 -> %2.", _grpId, _arrivalPos];

private _done = false;
while { !_done &&
        ((_team getVariable ["FTCS_MV_Thread_ID", -1]) == _threadId) &&
        (([_grpId, "movingMode"] call FTCS_fnc_registryGet) == "MOVING_TO_OBJECTIVE") &&
        { !isNull _team && { count (units _team) > 0 } } } do
{
    private _leaderUnit = leader _team;
    if (isNull _leaderUnit) exitWith {};

    private _dist = (getPosATL _leaderUnit) distance2D _arrivalPos;

    if (_dist > 3) then {
        // Marching: natural pace toward the arrival point, cohesive follow.
        // Speed is NOT boosted by distance (formation-march discipline).
        _team move _arrivalPos;
        units _team doFollow _leaderUnit;
    } else {
        // Arrival: single alignment pass, then the primitive completes.
        if (!([_grpId, "mvAligned"] call FTCS_fnc_registryGet)) then {
            _team setFormDir _objectiveBearing;
            [_grpId, "mvAligned", true] call FTCS_fnc_registrySet;
        };
        // Terminal transition: release the loop by flipping the mode; the next
        // while-condition evaluation ends the loop naturally. Avoids break/
        // exitWith after a trailing call, which SQF misparses as a control block
        // (that mis-parse was the source of the arrival-time _value error).
        [_grpId, "movingMode", "HOLD_POSITION"] call FTCS_fnc_registrySet;
        _done = true;
    };

    sleep 1.0;
};

// Loop exit cleanup: clear the transient alignment flag, reset the movementType
// stamp back to NORMAL_MOVE (the active manoeuvre is over - a newer primitive
// overwrites it with its own type when it dispatches) and restore radio protocol
// in every exit path (normal completion, superseded order, empty group)
// - units report normally again once the movement primitive is done.
if (!isNull _team) then {
    [_grpId, "mvAligned", nil] call FTCS_fnc_registrySet;
    [_grpId, "movementType", "NORMAL_MOVE"] call FTCS_fnc_registrySet;
    { _x enableAI "RADIOPROTOCOL"; } forEach (units _team);
};
