/*
    ================================================================================
    File: fn_squadOrderApply.sqf
    Module: Squads
    Author: FTCS Team
    Description: Single dispatcher that applies a commander order to the squad
                 currently addressed through the Squad & Scout Directives menu.
                 Orders are resolved against the persisted commander target
                 (Targeting class) when the order needs a world point:
                     MOVE_ADVANCE_DETACH : advance to target, then HOLD (stand,
                                           anchored to that world point). The
                                           squad leaves formation-follow.
                     MOVE_ADVANCE_KEEP   : advance to target, then re-anchor the
                                           platoon-formation slot at that world
                                           point and resume formation follow
                                           from there (Move & Keep).
                     MOVE_FLANK          : advance to target as a flank bound and
                                           re-anchor the formation slot there.
                     MOVE_FALL_BACK      : retreat to the target point and HOLD.
                     MOVE_REJOIN         : clear any pinned anchor and resume the
                                           normal formation-follow slot chain.
                     DEFEND              : hold at the marked point and adopt a
                                           defensive posture (stance + awareness).
                     TARGET_MARK         : acquisition only - no movement order,
                                           the target stays available for the
                                           next directive.
                 All movement orders operate in the commander's platoon (the
                 player's platoon); scout squads resolve through the scout
                 registry exactly like the formation menus do.
    Params:
        0: NUMBER - Squad slot index (1-based, matches FTCS_MENU_SquadOrders_X).
        1: STRING - Order token (see table above).
    Returns:
        BOOLEAN - true when the order was applied.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_slotIndex", 1], ["_order", ""]];

if (_order == "") exitWith { false };

// --- Resolve the addressed squad group --------------------------------------
// Dual input contract: callers may pass a GROUP directly (as the Squad Directives
// menu dispatcher in fn_applyCommandToTarget does for slot-parsed order tokens)
// or a NUMBER slot index (legacy contract). A STRING is also accepted when it
// matches a group ID in the groups registry (FTCS_Groups_Registry_Table key).
private _group = objNull;
private _groupID = "";
private _entry = locationNull;
private _registryEntryValid = false;

private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
private _registry = missionNamespace getVariable ["FTCS_Platoons_Registry", createHashMap];
private _plt = _registry getOrDefault [_pltId, createHashMap];
private _squadList = _plt getOrDefault ["squads", []];

switch (typeName _slotIndex) do {
    case "GROUP";
    case "OBJECT": {
        if (!isNull _slotIndex && { { _x == (leader _slotIndex) } count (units _slotIndex) > 0 }) then {
            _group = _slotIndex;
            _groupID = groupId _group;
            _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];
            _registryEntryValid = (count _entry > 0);
        };
    };
    case "STRING": {
        _groupID = _slotIndex;
        _group = missionNamespace getVariable [_groupID, objNull];
        if (isNull _group) then {
            // Fallback: search the platoon squad list by groupId string
            { if (groupId _x == _groupID) exitWith { _group = _x }; } forEach _squadList;
        };
        _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];
        _registryEntryValid = (count _entry > 0);
    };
    default {
        if (_slotIndex <= count _squadList) then {
            _group = _squadList select (_slotIndex - 1);
        };
        if (!isNull _group) then {
            _groupID = groupId _group;
            _entry = FTCS_Groups_Registry_Table getOrDefault [_groupID, createHashMap];
            _registryEntryValid = (count _entry > 0);
        };
    };
};
// Scout slot fallback: the scout submenu shares this dispatcher with a special index
if (isNull _group && { typeName _slotIndex == "SCALAR" && { _slotIndex == 99 } }) then {
    _group = missionNamespace getVariable ["FTCS_Scout_Group", objNull];
};
if (isNull _group) exitWith {
    systemChat format ["[SQD ORDER] Error: no squad resolved for slot %1.", _slotIndex];
    false
};

private _grpId = groupId _group;

// --- Resolve the marked commander target ------------------------------------
private _target = [] call FTCS_fnc_targetGet;
_target params [["_tPos", [0, 0, 0]], ["_tObj", objNull], ["_tLabel", ""]];
private _hasTarget = (count _tPos > 0) && { !(_tPos isEqualTo [0, 0, 0]) };

// Movement orders require a target (they are gated disabled in the menu, but the
// runtime re-validation keeps the guarantee even if the menu state went stale).
private _needsTarget = _order in
    ["SQD_MOVE_ADVANCE_DETACH", "SQD_MOVE_ADVANCE_KEEP", "SQD_DEFEND"];

if (_needsTarget && { !_hasTarget }) exitWith {
    systemChat "[SQD ORDER] No marked target - mark a target first (option 1).";
    false
};

switch (_order) do
{
    case "SQD_TARGET_MARK": {
        // Handled by fn_squadTarget3DScan (menu rebuild + auto reopen). Here we
        // only confirm the persisted target exists.
        if (_hasTarget) then {
            systemChat format ["[SQD ORDER] Target marked: %1 (%2m).", _tLabel, round ((getPosATL player) distance2D _tPos)];
        };
        true
    };

    case "SQD_MOVE_ADVANCE_DETACH": {
        // Advance to the target and HOLD: exit formation-follow, anchor to world
        [_grpId, "movingMode", "STOP"] call FTCS_fnc_registrySet;
        [_grpId, "pinnedAnchorPos", _tPos] call FTCS_fnc_registrySet;
        [_group, _tPos] call FTCS_fnc_mvSquadMoveOrder;
        systemChat format ["[SQD ORDER] %1: advance & hold at %2.", _grpId, _tLabel];
        true
    };

    case "SQD_MOVE_ADVANCE_KEEP": {
        // Contextual move-to-point: the Movement dispatcher picks the primitive
        // by the squad's active movingMode (formation shift preserves geometry
        // in cross-country; free-move primitive when detached; road refused).
        // (Legacy raw move/doMove + orphan pinnedAnchor removed.)
        [_group, _tPos] call FTCS_fnc_mvSquadMoveOrder;
        systemChat format ["[SQD ORDER] %1: move to %2.", _grpId, _tLabel];
        true
    };

    // NOTE: legacy dead cases SQD_MOVE_FLANK / SQD_MOVE_FALL_BACK removed -
    // they wrote movingMode STOP before dispatching, which made
    // mvFormationShift refuse the order (pre-Movement-era code, never invoked).

    case "FLANK_OPEN_R";
    case "FLANK_OPEN_L": {
        // FLANK MOVE (perpendicular bound): the squad moves 90deg LEFT/RIGHT of
        // the platoon's CURRENT axis of advance, a fixed 25m, then stops there
        // facing the platoon's direction of advance. The formation slot bearing
        // is NOT rotated permanently - this is a positional bound, not a slot
        // re-anchor (the follow loop keeps the canonical slot as-is).
        // Axis of advance = the platoon leader's heading (world direction the
        // formation is moving in right now).
        private _refLeader = leader _group;
        private _pltIdF = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltGrpF = missionNamespace getVariable [format ["FTCS_Platoon_Group_%1", _pltIdF], objNull];
        if (!isNull _pltGrpF) then { _refLeader = leader _pltGrpF; };
        if (isNull _refLeader) exitWith {
            systemChat "[SQD ORDER] Error: no platoon leader to derive the axis of advance from.";
            false
        };

        // Axis of advance - CANONICAL platoon reference (fn_platoonAdvanceAxis):
        // road anchor advanceDir > ABS frozen lock > live REL direction.
        private _axisDir = [_refLeader] call FTCS_fnc_platoonAdvanceAxis;
        private _flankDir = _axisDir + (if (_order == "FLANK_OPEN_R") then { 90 } else { -90 });
        private _sqdPos = getPosATL (leader _group);
        if (count _sqdPos < 2) then { _sqdPos = getPosATL _refLeader; };
        private _tgt = _sqdPos getPos [25, _flankDir];

        // Walk the squad to the flank point THROUGH THE FORMATION SYSTEM:
        // mvSquadMoveOrder delegates to the mode-matching primitive, which owns
        // the march and the ON-ARRIVAL alignment. The platoon axis of advance
        // is passed as the arrival facing (4th dispatcher param) so the squad
        // ends up facing the platoon's direction of march - no synchronous
        // setFormDir here (it would fight the follow loop).
        [_group, _tgt, _axisDir] call FTCS_fnc_mvSquadMoveOrder;
        systemChat format ["[SQD ORDER] %1: flanking %2 25m (perpendicular to advance %3deg).", _grpId, if (_order == "FLANK_OPEN_R") then { "RIGHT" } else { "LEFT" }, round _axisDir];
        true
    };

    case "FALL_BACK": {
        // FALL BACK: move 180deg opposite to the platoon's CURRENT axis of
        // advance, a fixed 25m, keeping the platoon's facing on arrival.
        private _refLeader = leader _group;
        private _pltIdB = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];
        private _pltGrpB = missionNamespace getVariable [format ["FTCS_Platoon_Group_%1", _pltIdB], objNull];
        if (!isNull _pltGrpB) then { _refLeader = leader _pltGrpB; };
        if (isNull _refLeader) exitWith {
            systemChat "[SQD ORDER] Error: no platoon leader to derive the axis of advance from.";
            false
        };

        // Axis of advance - CANONICAL platoon reference (see FLANK branch above)
        private _axisDir = [_refLeader] call FTCS_fnc_platoonAdvanceAxis;
        private _backDir = _axisDir + 180;
        private _sqdPos = getPosATL (leader _group);
        if (count _sqdPos < 2) then { _sqdPos = getPosATL _refLeader; };
        private _tgt = _sqdPos getPos [25, _backDir];

        // Walk the squad back THROUGH THE FORMATION SYSTEM (same contract as
        // the flank bound: dispatcher picks the primitive, which owns the march
        // and aligns the squad to the platoon axis on arrival - no synchronous
        // setFormDir, no detach race on platoon advance).
        [_group, _tgt, _axisDir] call FTCS_fnc_mvSquadMoveOrder;
        systemChat format ["[SQD ORDER] %1: falling back 25m (opposite to advance %2deg).", _grpId, round _axisDir];
        true
    };

    case "SQD_DEFEND": {
        // HOLD CURRENT POSITION: detach from formation-follow and freeze in
        // place (no movement to the marked point) + defensive posture.
        [_grpId, "movingMode", "STOP"] call FTCS_fnc_registrySet;
        { doStop _x; } forEach (units _group);
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        systemChat format ["[SQD ORDER] %1: holding and defending current position.", _grpId];
        true
    };

    case "SQD_MOVE_REJOIN": {
        // Clear pinned anchors and resume the formation-follow chain
        [_grpId, "pinnedAnchorPos", nil] call FTCS_fnc_registrySet;
        [_grpId, "pinnedKeepFormation", nil] call FTCS_fnc_registrySet;
        [_grpId, "movingMode", "FOLLOWING_COMMANDER_REL"] call FTCS_fnc_registrySet;
        systemChat format ["[SQD ORDER] %1: rejoining formation.", _grpId];
        true
    };

    default {
        systemChat format ["[SQD ORDER] Unknown order token: %1.", _order];
        false
    };
};
