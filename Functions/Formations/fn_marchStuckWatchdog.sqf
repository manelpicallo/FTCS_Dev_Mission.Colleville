/*
    ================================================================================
    File: fn_marchStuckWatchdog.sqf
    Module: Formations
    Author: FTCS Team
    Description: Straggler recovery supervisor for column marches (road and
                 trail). Scans every subordinate group member every cycle and
                 recovers units stranded by the pathfinding in complex terrain:
                 - DETECTION: a soldier is "lost" when he is farther than
                   _stragglerDistance from his group leader AND effectively
                   stationary (speed below _stuckSpeed) for 2 consecutive cycles.
                 - LEVEL 1: fresh doMove to the group leader's CURRENT position -
                   forces a complete path re-plan from the straggler's spot, which
                   usually frees soldiers stuck routing around the wrong side of
                   an obstacle. The column NEVER waits: the target is live.
                 - LEVEL 2: if still stuck on the next cycle after level 1,
                   grant an individual catch-up sprint (limitSpeed -1) and repeat
                   the doMove. Reverts automatically once the soldier closes in.
                 - RE-ATTACH: below _reattachDistance no further intervention; the
                   normal follow flow picks the soldier up.
                 The supervisor never touches healthy units, never slows or stops
                 any group, and acts only on individual stragglers.
                 Level 3 (physical teleport) is deliberately NOT implemented.
    Params:
        0: NUMBER - Platoon ID.
        1: NUMBER - Generation token: exits when a newer march order increments
                    FTCS_March_Watchdog_Gen_PLT_<id>.
    Returns:
        NOTHING (spawns as a thread body).
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_pltId", 1], ["_gen", 0]];

private _cycleTime = 3.5;          // seconds between scans
private _stragglerDistance = 40.0; // meters from group leader to declare "lost"
private _reattachDistance = 15.0;  // meters closing in stops supervision
private _stuckSpeed = 0.5;         // km/h under which a unit is considered stalled

diag_log format ["[FTCS][WATCHDOG] Started (plt %1, gen %2).", _pltId, _gen];

while { (missionNamespace getVariable [format ["FTCS_March_Watchdog_Gen_PLT_%1", _pltId], 0]) == _gen } do
{
    sleep _cycleTime;

    {
        private _grp = _y;
        // Skip non-group entries defensively
        if (_grp isEqualType grpNull && { !isNull _grp }) then {
            private _grpLeader = leader _grp;
            if (!isNull _grpLeader && { alive _grpLeader }) then {
                {
                    private _u = _x;
                    if (!alive _u || { isPlayer _u }) then { continue; };

                    // Per-unit recovery state kept on the unit itself
                    private _stuckCycles = _u getVariable ["FTCS_Stuck_Cycles", 0];
                    private _distToLeader = _u distance2D _grpLeader;
                    private _moving = (speed _u) > _stuckSpeed;

                    if (_distToLeader > _reattachDistance) then {
                        // (Re)enter supervision only when truly far AND stalled
                        if (_distToLeader > _stragglerDistance && { !_moving }) then {
                            _stuckCycles = _stuckCycles + 1;
                            _u setVariable ["FTCS_Stuck_Cycles", _stuckCycles];

                            if (_stuckCycles >= 2) then {
                                // LEVEL 1 / LEVEL 2 escalation ladder
                                if (_stuckCycles == 2) then {
                                    // LEVEL 1: fresh path re-plan to the live group position
                                    _u doMove (getPosATL _grpLeader);
                                    diag_log format ["[FTCS][WATCHDOG] L1 re-route: %1 -> %2 (%3m behind)", (name _u), (groupId _grp), round _distToLeader];
                                } else {
                                    // LEVEL 2: catch-up sprint + repeat re-route
                                    _u limitSpeed -1;
                                    _u doMove (getPosATL _grpLeader);
                                    diag_log format ["[FTCS][WATCHDOG] L2 sprint: %1 -> %2 (%3m behind)", (name _u), (groupId _grp), round _distToLeader];
                                };
                            };
                        } else {
                            // Far but moving (or recovering): decay the counter
                            if (_stuckCycles > 0) then { _u setVariable ["FTCS_Stuck_Cycles", (_stuckCycles - 1) max 0]; };
                        };
                    } else {
                        // RE-ATTACHED: clear recovery state and restore group pacing
                        if (_stuckCycles >= 2) then {
                            _u limitSpeed -1; // back under the follow-loop's group pacing
                            diag_log format ["[FTCS][WATCHDOG] Re-attached: %1 -> %2", (name _u), (groupId _grp)];
                        };
                        _u setVariable ["FTCS_Stuck_Cycles", 0];
                    };
                } forEach (units _grp);
            };
        };
    } forEach FTCS_Groups_Registry_Table;
};

diag_log format ["[FTCS][WATCHDOG] Stopped (plt %1, gen %2 superseded).", _pltId, _gen];
