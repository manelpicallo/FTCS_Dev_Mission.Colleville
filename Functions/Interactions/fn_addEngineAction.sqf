/*
    File: fn_addEngineAction.sqf
    Module: Ctrl_Interactions
    Author: FTCS Team
    Description: Abstracts engine-specific interaction calls (addAction for Arma 3) 
                 to ensure clean architecture and effortless portability to Arma 4 (Enfusion).
*/

params [
    "_target", 
    "_title", 
    "_script", 
    ["_arguments", []], 
    ["_priority", 1.5], 
    ["_radius", 3.0], 
    ["_condition", "true"]
];

if (isNull _target) exitWith {-1};

// Arma 3 Engine Implementation 
// hideOnUse set to FALSE so actions don't disappear after one interaction
_target addAction [
    _title,
    _script,
    _arguments,
    _priority,
    true,       // showWindow
    false,      // hideOnUse -> FIXED: Permanece activa y reutilizable
    "",         // shortcut
    _condition,
    _radius,
    false,      // unconscious
    "",         // selection
    ""          // memoryPoint
];
