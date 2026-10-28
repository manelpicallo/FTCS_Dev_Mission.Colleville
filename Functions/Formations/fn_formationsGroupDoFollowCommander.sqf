/*
    Author: FTCS Framework / Manel P.
    Function: FTCS_fnc_formationsGroupDoFollowCommander
    Description: Controls the individual group movement loop to follow the commander 
                 in relative or absolute modes (AI-Agnostic).
*/

params ["_group", "_mode", "_leader"];

private _groupID = groupId _group;
private _not_able_time = 1;  
private _timer = time;
private _spd = speed _leader;
private _last_spd = 10;

private _last_commander_dir = getDir _leader;
missionNamespace setVariable ["FTCS_Last_Commander_Dir", _last_commander_dir];

[ _groupID, "movingMode", _mode ] call FTCS_fnc_registrySet;

(leader _group) enableAI "PATH";

if (_mode == "FOLLOWING_COMMANDER_REL") then 
{
    private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
    _group move (_leader getRelPos [_relPos select 0, _relPos select 1]);
    units _group doFollow leader _group;
};

if (_mode == "FOLLOWING_COMMANDER_ABS") then 
{
    private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
    _group move (_leader getPos [_relPos select 0, _relPos select 1]);
    units _group doFollow leader _group;
};

while {(([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_COMMANDER_REL") ||
       (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_COMMANDER_ABS") || 
       (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "HALT")} do
{
    _spd = speed _leader;

    if (_spd > 2) then 
    {
        _last_spd = _spd;
        { _x limitSpeed _spd; } foreach units _group;

        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_COMMANDER_REL") then 
        {
            { _x disableAI "RADIOPROTOCOL"; } foreach units _group;
                
            _timer = time + _not_able_time;
            waitUntil { time > _timer || unitReady leader _group || lifeState leader _group == "DEAD" || lifeState leader _group == "INCAPACITATED" };
            
            { _x disableAI "RADIOPROTOCOL"; } foreach units _group;
            private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
            _group move (_leader getRelPos [_relPos select 0, _relPos select 1]);
            units _group doFollow leader _group;    

            if (time < _timer) then {
                _group setFormDir (missionNamespace getVariable "FTCS_Last_Commander_Dir");
            };
        };
    
        if (([ _groupID, "movingMode" ] call FTCS_fnc_registryGet) == "FOLLOWING_COMMANDER_ABS") then 
        {
            { _x disableAI "RADIOPROTOCOL"; } foreach units _group;
                
            _timer = time + _not_able_time;
            waitUntil { time > _timer || unitReady leader _group || lifeState leader _group == "DEAD" || lifeState leader _group == "INCAPACITATED" };
            
            { _x disableAI "RADIOPROTOCOL"; } foreach units _group;
            private _relPos = [ _groupID, "relPosition" ] call FTCS_fnc_registryGet;
            _group move (_leader getPos [_relPos select 0, _relPos select 1]);
            units _group doFollow leader _group;    

            if (time < _timer) then {
                _group setFormDir (missionNamespace getVariable "FTCS_Platoon_Advance_Direction");
            };
        };

        { _x enableAI "RADIOPROTOCOL"; } foreach units _group;

        _last_commander_dir = getDir _leader;
        missionNamespace setVariable ["FTCS_Last_Commander_Dir", _last_commander_dir];
    }
    else 
    {
        { _x limitSpeed _last_spd; } foreach units _group;
        sleep 0.5;
    };
};