/*
    ================================================================================
    File: fn_openDeployMenu.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Opens the Operational Deployment Menu dialog over the tactical map.
                 Can be invoked automatically at mission start if no assigned units exist,
                 or manually via command/action.
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) OOP port.
    ================================================================================
*/

if (!hasInterface) exitWith { false };

// Ensure previous dialog is closed if open
if (dialog) then { closeDialog 0; };

// Create and display the tactical deployment dialog
private _dialogCreated = createDialog "FTCS_DeployDialog";

if (!_dialogCreated) then {
    diag_log "FTCS Error: Failed to open FTCS_DeployDialog.";
    hint "FTCS Error: No se pudo abrir la interfaz de despliegue.";
} else {
    // Explicitly guarantee initialization on the newly created display
    private _disp = findDisplay 88000;
    if (!isNull _disp) then {
        [_disp] call FTCS_fnc_initDeployMenu;
    };
};

_dialogCreated;
