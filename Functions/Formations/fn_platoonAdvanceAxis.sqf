/*
    ================================================================================
    File: fn_platoonAdvanceAxis.sqf
    Module: Formations
    Author: FTCS Team
    Description: CANONICAL platoon axis-of-advance resolution - the SINGLE
                 authority every consumer must use (follow loop, formation
                 shift, flank/fall-back bounds, future primitives). Resolution
                 order (matches fn_formationsGroupDoFollowCommander's own
                 semantics and fn_mvFormationShift's heading model):
                     1. Road march column active (road anchor has a path) ->
                        anchor advanceDir (road-aligned axis).
                     2. ABS follow mode -> frozen compass lock
                        FTCS_Platoon_Fixed_Abs_Dir.
                     3. REL (default) -> live platoon advance direction
                        FTCS_Platoon_Advance_Direction.
                     Fallback in every branch: the reference leader's getDir.
                 Params:
                     0: OBJECT - OPTIONAL reference leader (default: the platoon
                        group's leader; used only for the fallback heading).
                 Returns:
                     NUMBER - Axis of advance in degrees (0-360).
                 Compatibility: Arma 3 (SQF) | Designed for Enforce Script port.
    ================================================================================
*/

params [["_refLeader", objNull, [objNull]]];

private _pltId = missionNamespace getVariable ["FTCS_Player_Platoon_ID", 1];

// Reference leader fallback (heading source when no canonical variable exists)
if (isNull _refLeader) then {
    private _pltGrp = missionNamespace getVariable [format ["FTCS_Platoon_Group_%1", _pltId], grpNull];
    if (!isNull _pltGrp) then { _refLeader = leader _pltGrp; };
};
private _fallbackDir = if (!isNull _refLeader) then { getDir _refLeader } else { 0 };

// 1. Road march column active -> road-aligned anchor axis
private _roadAnchor = missionNamespace getVariable [format ["FTCS_Road_Anchor_PLT_%1", _pltId], createHashMap];
if (count (_roadAnchor getOrDefault ["roadPath", []]) >= 2) exitWith {
    _roadAnchor getOrDefault ["advanceDir", _fallbackDir]
};

// 2. ABS follow mode -> frozen compass lock
private _followMode = missionNamespace getVariable ["FTCS_Platoon_Follow_Mode", "FOLLOWING_COMMANDER_REL"];
if (_followMode == "FOLLOWING_COMMANDER_ABS") exitWith {
    missionNamespace getVariable ["FTCS_Platoon_Fixed_Abs_Dir", _fallbackDir]
};

// 3. REL (default) -> live platoon advance direction
missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", _fallbackDir]
