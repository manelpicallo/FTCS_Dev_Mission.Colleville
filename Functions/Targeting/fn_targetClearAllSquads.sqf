/*
    ================================================================================
    File: fn_targetClearAllSquads.sqf
    Module: Targeting
    Author: FTCS Team
    Description: Full squad-target wipe for tactical restarts. Removes EVERY
                 squad's captured target ("squadTarget" + "squadTargetSquadName"
                 registry fields), which erases the world 3D markers (the green
                 persistent markers self-terminate: the draw handler of
                 fn_targetPersistentMarker removes itself when its frame pass
                 finds zero active targets) and returns all squad movement menus
                 to their pristine "no marked point" state.
                 Called when a NEW platoon formation or movement technique is
                 ordered: the tactical picture restarts from zero - nothing about
                 previous point-movements (marks, positions) is remembered.
                 A defensive frame guard in the persistent marker draw handler
                 (alive/COM checks) covers the transition frame where a marked
                 object may already be destroyed.
    Params:
        NONE.
    Returns:
        NUMBER - Count of squads whose target was cleared.
    Compatibility: Arma 3 (SQF) | Designed for Enforce Script (Arma 4) port.
    ================================================================================
*/

private _cleared = 0;
{
    private _grpId = _x;
    private _entry = _y;
    if (!isNil { _entry getOrDefault ["squadTarget", nil] }) then {
        _entry set ["squadTarget", nil];
        _entry set ["squadTargetSquadName", nil];
        FTCS_Groups_Registry_Table set [_grpId, _entry];
        _cleared = _cleared + 1;
    };
} forEach FTCS_Groups_Registry_Table;

diag_log format ["[FTCS][TGT] ClearAllSquads: %1 squad targets wiped.", _cleared];
_cleared
