/*
    Debug helper: paste in the Arma 3 DEBUG CONSOLE (Escape menu, bottom field)
    and press LOCAL EXEC. Shows, in the bottom-right message area, the className
    and displayName of everything intersected by your aim ray right now.
    Re-run the same snippet each time you aim at a new object whose class you
    want to learn (it reads once per execution - not continuous).
*/

private _eye = eyePos player;
private _dir = getCameraViewDirection player;
private _hits = lineIntersectsSurfaces [
    _eye,
    _eye vectorAdd (_dir vectorMultiply 150),
    player,
    objNull,
    true, 8, "VIEW", "FIRE"
];

if (count _hits == 0) exitWith { systemChat "[DBG] Nothing under the aim (no intersections)." };

private _lines = ["[DBG] AIM INTERSECTIONS:"];
{
    private _obj = _x select 2;
    if (!isNull _obj) then {
        private _cls = typeOf _obj;
        private _disp = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
        _lines pushBack format ["%1 | disp: %2", _cls, _disp];
    };
} forEach _hits;

hintSilent parseText format [
    "<t align='left' size='0.9'><t color='#00FFCC'>[DBG] AIM INTERSECTIONS</t><br/>%1</t>",
    ((_lines select [1]) joinString "<br/>")
];
copyToClipboard (_lines joinString toString [13, 10]);
systemChat "[DBG] Classes copied to clipboard.";
