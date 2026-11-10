/*
    ================================================================================
    File: fn_targetGet.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Reads the currently marked commander target with validation.
                 Returns the standard target tuple persisted by fn_targetMark,
                 optionally enforcing freshness (maxAge seconds): a stale target
                 warns the caller and is treated as absent (consumers can react
                 to staleness instead of silently using outdated coordinates).
    Params:
        0: BOOLEAN - Require the target to exist (default true; false = returns
                     [] instead of failing when there is no target).
        1: NUMBER  - Maximum age in seconds of the mark (0 = no expiry check).
    Returns:
        ARRAY - [isObject, targetType, objectRef, approachPos, impactPos,
                 distance, bearing, label, markTime] or [] when absent/stale.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

params [["_requireTarget", true], ["_maxAge", 0]];
diag_log format ["[FTCS][TARGET-GET] Called (require %1).", _requireTarget];

private _tuple = missionNamespace getVariable ["FTCS_Commander_Target", []];
if (count _tuple < 9) exitWith {
    if (_requireTarget) then {
        systemChat "[TARGET] No target marked. Use 'Mark Target (aim & confirm)' first.";
    };
    []
};

// Freshness check (tuple index 8 holds the mark timestamp)
if (_maxAge > 0) then {
    private _markTime = _tuple select 8;
    if ((time - _markTime) > _maxAge) exitWith {
        if (_requireTarget) then {
            systemChat format ["[TARGET] Marked target is stale (%1s old) - re-mark it.", round (time - _markTime)];
        };
        []
    };
};

_tuple
