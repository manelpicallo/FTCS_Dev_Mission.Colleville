/*
    ================================================================================
    File: fn_squadOrderApply.sqf
    Module: Formations
    Author: FTCS Team
    Description: Applies the squad 3D-point orders issued from the Squad & Scout
                 Directives menus. The squad is NOT pulled out of the platoon
                 structure: its slot is re-anchored (or detached) and the follow
                 flow adapts automatically on the next tick.
                 Orders (orderCode):
                 - "ADVANCE_KEEP":    doMove to target approach point, re-anchor
                   relPosition to the target (anchored to the WORLD point), keep
                   the follow loop running. The platoon formation now develops
                   from that new point as the leader moves.
                 - "ADVANCE_DETACH_HOLD":    doMove to target, then detach from
                   the platoon follow (movingMode "HOLD_POSITION") and stand.
                 - "ADVANCE_DETACH_DEFEND":  doMove to target, detach, and adopt
                   defensive posture (per-phase awareness/stance via standard
                   group functions).
                 - "FLANK_OPEN_R" / "FLANK_OPEN_L": rotate the squad's bearing
                   within the formation ring by +/- 45 degrees (no detachment).
                 - "FALL_BACK": deepen the squad's slot distance by 15m along
                   the platoon axis (no detachment).
                 - "REJOIN": restore the doctrinal slot (re-run of the platoon
                   formation pipeline is the caller's responsibility; this only
                   restores follow mode and clears hold flags).
                 All movement orders REQUIRE a marked commander target
                 (fn_targetGet with freshness window of 120s).
                 TARGET-CONSUMING orders (ADVANCE_KEEP, ADVANCE_DETACH_HOLD,
                 ADVANCE_DETACH_DEFEND) also clear the squad's per-squad target
                 ("squadTarget" registry field), which removes its persistent
                 3D marker from the world (see fn_targetPersistentMarker).
    Params:
        0: GROUP - Squad (or fireteam) group the order applies to.
        1: STRING - Order code (see above).
    Returns:
        BOOLEAN - true when the order was applied, false otherwise.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_group", grpNull], ["_orderCode", ""]];

if (isNull _group || {_orderCode == ""}) exitWith { false };

private _groupID = groupId _group;
private _leader = leader _group;
if (isNull _leader) exitWith { false };

private _pltLeader = missionNamespace getVariable ["FTCS_Platoon_Leader_Unit", objNull];
if (isNull _pltLeader) then { _pltLeader = player; };

private _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];

// --- Movement orders: require a fresh marked commander target ------------------
private _needsTarget = _orderCode in ["ADVANCE_KEEP", "ADVANCE_DETACH_HOLD", "ADVANCE_DETACH_DEFEND"];
private _consumeTarget = _orderCode in ["ADVANCE_KEEP", "ADVANCE_DETACH_HOLD", "ADVANCE_DETACH_DEFEND"];
private _target = [];
private _approachPos = [0, 0, 0];
private _label = "";

if (_needsTarget) then {
    // Per-squad target first (owned white); fall back to the global commander
    // target for legacy flows
    _target = _entry getOrDefault ["squadTarget", []];
    if (count _target < 8) then { _target = [true, 120] call FTCS_fnc_targetGet; };
    if (count _target < 8) exitWith { false };
    _approachPos = _target select 3;
    _label = _target select 7;
};

// TARGET CONSUMPTION: the movement orders that use the target clear the owning
// squad's white everywhere it was stored (the capture spreads across every
// team group of the squad) - the persistent marker disappears with it. Matches
// entries whose captured approach position equals the consumed one.
private _consumedPos = _approachPos;
if (_consumeTarget) then {
    _entry set ["squadTarget", nil];
    _entry set ["squadTargetSquadName", nil];
    FTCS_Groups_Registry_Table set [_groupID, _entry];
    {
        private _otherId = _x;
        private _otherEntry = _y;
        private _otherTgt = _otherEntry getOrDefault ["squadTarget", []];
        if ((count _otherTgt >= 8) && { ((_otherTgt select 3) distance2D _consumedPos) < 0.5 }) then {
            _otherEntry set ["squadTarget", nil];
            _otherEntry set ["squadTargetSquadName", nil];
            FTCS_Groups_Registry_Table set [_otherId, _otherEntry];
        };
    } forEach FTCS_Groups_Registry_Table;
};

switch (_orderCode) do {

    // --- ADVANCE & KEEP FORMATION: re-anchor the slot at the marked point -------
    case "ADVANCE_KEEP": {
        // Re-anchor relPosition to the target: the follow loop now tracks this
        // world point (anchored to terrain, not to the moving leader).
        private _dist = _pltLeader distance2D _approachPos;
        private _bearing = _pltLeader getDir _approachPos;
        _entry set ["relPosition", [_dist, _bearing, group _pltLeader]];
        _entry set ["anchoredToWorld", true];
        _entry set ["anchorWorldPos", +_approachPos];
        _entry set ["movingMode", "FOLLOWING_COMMANDER_REL"];
        FTCS_Groups_Registry_Table set [_groupID, _entry];

        _group doMove _approachPos;
        systemChat format ["[SQUAD ORDER] %1: advancing to marked point (%2) - formation re-anchored there.", _groupID, _label];
    };

    // --- ADVANCE & DETACH (HOLD): move there and leave the platoon follow -------
    case "ADVANCE_DETACH_HOLD": {
        _entry set ["movingMode", "HOLD_POSITION"];
        _entry set ["anchoredToWorld", true];
        _entry set ["anchorWorldPos", +_approachPos];
        _entry set ["teamAttachment", "DETACHED_HOLD"];
        FTCS_Groups_Registry_Table set [_groupID, _entry];

        _group doMove _approachPos;
        systemChat format ["[SQUAD ORDER] %1: advancing to marked point (%2) - will hold position detached from formation.", _groupID, _label];
    };

    // --- ADVANCE & DETACH (DEFEND): move there, detach, adopt defensive posture --
    case "ADVANCE_DETACH_DEFEND": {
        _entry set ["movingMode", "HOLD_POSITION"];
        _entry set ["anchoredToWorld", true];
        _entry set ["anchorWorldPos", +_approachPos];
        _entry set ["teamAttachment", "DETACHED_HOLD"];
        FTCS_Groups_Registry_Table set [_groupID, _entry];

        _group doMove _approachPos;

        // Defensive posture via standard group functions (phase-aware)
        private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _phase = missionNamespace getVariable [format ["FTCS_Platoon_Phase_%1", _pltId], 2];
        private _aware = if (_phase >= 3) then { "COMBAT" } else { "AWARE" };
        [_group, _aware] call FTCS_fnc_groupSetAwareMode;
        [_group, "FORCE_MIDDLE"] call FTCS_fnc_groupSetStance;
        systemChat format ["[SQUAD ORDER] %1: advancing to marked point (%2) - will defend position detached from formation.", _groupID, _label];
    };

    // --- FLANK OPEN RIGHT / LEFT: rotate the bearing inside the formation ring ---
    case "FLANK_OPEN_R";
    case "FLANK_OPEN_L": {
        private _relPos = _entry getOrDefault ["relPosition", [-1, -1, objNull]];
        if (count _relPos < 2 || {(_relPos select 0) < 0}) exitWith {
            systemChat "[SQUAD ORDER] Error: no formation slot assigned to this squad.";
            false
        };

        private _dist = _relPos select 0;
        private _delta = if (_orderCode == "FLANK_OPEN_R") then { 45 } else { -45 };
        private _newBearing = ((_relPos select 1) + _delta) % 360;

        _entry set ["relPosition", [_dist, _newBearing, _relPos select 2]];
        FTCS_Groups_Registry_Table set [_groupID, _entry];

        // Immediate world move to the re-anchored slot position
        private _refLeader = leader (_relPos select 2);
        if (!isNull _refLeader) then {
            private _tgt = (getPosATL _refLeader) getPos [_dist, ((getDir _refLeader) + _newBearing)];
            _group doMove _tgt;
        };
        systemChat format ["[SQUAD ORDER] %1: flank opened %2 (+%3° bearing).", _groupID, if (_delta > 0) then { "RIGHT" } else { "LEFT" }, _delta];
    };

    // --- FALL BACK: deepen the slot distance along the platoon axis --------------
    case "FALL_BACK": {
        private _relPos = _entry getOrDefault ["relPosition", [-1, -1, objNull]];
        if (count _relPos < 2 || {(_relPos select 0) < 0}) exitWith {
            systemChat "[SQUAD ORDER] Error: no formation slot assigned to this squad.";
            false
        };

        private _newDist = (_relPos select 0) + 15;
        _entry set ["relPosition", [_newDist, _relPos select 1, _relPos select 2]];
        FTCS_Groups_Registry_Table set [_groupID, _entry];

        private _refLeader = leader (_relPos select 2);
        if (!isNull _refLeader) then {
            private _tgt = (getPosATL _refLeader) getPos [_newDist, ((getDir _refLeader) + (_relPos select 1))];
            _group doMove _tgt;
        };
        systemChat format ["[SQUAD ORDER] %1: falling back 15m along the platoon axis.", _groupID];
    };

    // --- REJOIN: clear hold flags and restore the standard follow mode ------------
    case "REJOIN": {
        private _followMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
        _entry set ["movingMode", _followMode];
        _entry set ["anchoredToWorld", false];
        _entry set ["anchorWorldPos", nil];
        _entry set ["teamAttachment", "SQUAD_BOUND"];
        FTCS_Groups_Registry_Table set [_groupID, _entry];

        [_group, _followMode, _pltLeader] spawn FTCS_fnc_formationsGroupDoFollowCommander;
        systemChat format ["[SQUAD ORDER] %1: rejoining platoon formation (%2 follow).", _groupID, _followMode];
    };

    default {
        systemChat format ["[SQUAD ORDER] Error: unknown order code '%1'.", _orderCode];
        false
    };
};

true
