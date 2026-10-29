/*
    ================================================================================
    File: fn_executeDeployment.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Gathers all operational parameters from the deployment dialog, closes the UI,
                 spawns the doctrinal combat force at the designated anchor, deploys attached
                 support assets (static artillery at pre-placed marker, mobile armor in area),
                 and transitions the player seamlessly into their designated command role.
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) OOP port.
    ================================================================================
*/

private _disp = findDisplay 88000;
if (isNull _disp) exitWith {
    diag_log "FTCS Deploy Error: Deployment dialog not found.";
};

// 1. Retrieve User Selections
private _ctrlDoctrine   = _disp displayCtrl 88002;
private _ctrlEchelon    = _disp displayCtrl 88003;
private _ctrlFixedCheck = _disp displayCtrl 88006;
private _ctrlMobileCheck= _disp displayCtrl 88008;

private _doctrineKey   = _ctrlDoctrine lbData (lbCurSel _ctrlDoctrine);
private _echelon       = _ctrlEchelon lbData (lbCurSel _ctrlEchelon);
private _fixedEnabled  = cbChecked _ctrlFixedCheck;
private _mobileEnabled = cbChecked _ctrlMobileCheck;

private _spawnPos = missionNamespace getVariable ["FTCS_Deploy_SpawnPos", getPos player];
private _advanceDir = missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0];

// Close dialog and clean preview markers
closeDialog 1;

if (getMarkerType "FTCS_PREVIEW_MARKER" != "") then {
    deleteMarkerLocal "FTCS_PREVIEW_MARKER";
};

titleText [
    "<t size='1.3' color='#00FFCC' font='PuristaBold'>FTCS - DESPLEGANDO FUERZA TÁCTICA</t><br/><t size='0.9' color='#AAAAAA'>Inicializando doctrina, posiciones y enlaces de mando...</t>", 
    "PLAIN DOWN", 
    0.6, 
    true, 
    true
];

// 2. Load Doctrine Data Template
private _doctrineData = createHashMap;
private _doctrinePath = format ["Doctrines\Data\%1.sqf", _doctrineKey];

if (fileExists _doctrinePath) then {
    _doctrineData = call compile preprocessFileLineNumbers _doctrinePath;
} else {
    // Default fallback to 101st Airborne template
    _doctrineData = call compile preprocessFileLineNumbers "Doctrines\Data\101_US_Para_Company.sqf";
    if (count _doctrineData == 0) then {
        _doctrineData = createHashMapFromArray [
            ["doctrineID", _doctrineKey],
            ["companyLetter", "A"],
            ["requiredMods", []],
            ["entities", []]
        ];
    };
};

// 3. Deploy Main Doctrinal Force
// In Platoon mode, check if a dedicated Company HQ marker exists in the mission
private _customHQPos = [];
private _customHQDir = -1;
if (_echelon == "PLATOON") then {
    private _hqMarker = missionNamespace getVariable ["FTCS_Deploy_CompanyHQMarker", ""];
    if (_hqMarker != "" && {getMarkerType _hqMarker != ""}) then {
        _customHQPos = getMarkerPos _hqMarker;
        _customHQDir = markerDir _hqMarker;
        diag_log format ["FTCS: Deploying Company HQ at dedicated editor marker '%1' (Grid %2).", _hqMarker, mapGridPosition _customHQPos];
    };
};

private _deploySuccess = [
    _doctrineData, 
    _spawnPos, 
    _advanceDir, 
    _echelon, 
    player,
    _customHQPos,
    _customHQDir
] call FTCS_fnc_spawnDoctrine;

if (!_deploySuccess) exitWith {
    diag_log "FTCS Deploy Error: Failed to spawn main doctrinal force.";
    hint "FTCS Error: Falló el despliegue de la doctrina.";
};

// 4. Deploy Mobile Support (Alongside troops in deployment area)
if (_mobileEnabled) then {
    private _armorPath = "Doctrines\Data\Support_Armor.sqf";
    if (fileExists _armorPath) then {
        private _armorData = call compile preprocessFileLineNumbers _armorPath;
        
        // Calculate offset position for mobile support (offset to flank/rear)
        private _rad = _advanceDir;
        private _offX = 30;
        private _offY = -35;
        private _rotX = (_offX * cos _rad) + (_offY * sin _rad);
        private _rotY = ((-_offX * sin _rad) + (_offY * cos _rad));
        private _mobilePos = [(_spawnPos select 0) + _rotX, (_spawnPos select 1) + _rotY, _spawnPos select 2];

        [_armorData, _mobilePos, _advanceDir] call FTCS_fnc_spawnSupportUnit;
        diag_log "FTCS: Mobile armored support deployed alongside main force.";
    };
};

// 5. Deploy Fixed Support (At designated editor marker)
if (_fixedEnabled) then {
    private _artyMarker = missionNamespace getVariable ["FTCS_Deploy_ArtilleryMarker", ""];
    if (_artyMarker != "" && {getMarkerType _artyMarker != ""}) then {
        private _artyPath = "Doctrines\Data\Support_Artillery.sqf";
        if (fileExists _artyPath) then {
            private _artilleryData = call compile preprocessFileLineNumbers _artyPath;
            private _artyPos = getMarkerPos _artyMarker;
            private _artyDir = markerDir _artyMarker;

            [_artilleryData, _artyPos, _artyDir] call FTCS_fnc_spawnSupportUnit;
            diag_log format ["FTCS: Fixed artillery support deployed at marker '%1'.", _artyMarker];
        };
    } else {
        diag_log "FTCS Warning: Fixed artillery selected but no valid marker was found.";
    };
};

// 6. Confirmation Notification
private _rankTitle = if (_echelon == "PLATOON") then { "Teniente" } else { "Capitán" };
private _echelonLabel = if (_echelon == "PLATOON") then { "1er Pelotón (HQ Cía presente)" } else { "Compañía Completa" };

hint parseText format [
    "<t color='#00FFCC'><t size='1.3' font='PuristaBold'>¡Despliegue Operacional Exitoso!</t></t><br/><br/>" +
    "<t color='#FFFFFF'>Doctrina:</t> <t color='#AAAAAA'>%1</t><br/>" +
    "<t color='#FFFFFF'>Mando:</t> <t color='#AAAAAA'>%2 (%3)</t><br/>" +
    "<t color='#FFFFFF'>Zona:</t> <t color='#AAAAAA'>Grid %4</t><br/><br/>" +
    "<t color='#00FF00'>Todas las escuadras enlazadas. ¡A sus órdenes, mi %3!</t>",
    _doctrineKey,
    _echelonLabel,
    _rankTitle,
    mapGridPosition _spawnPos
];

diag_log format ["FTCS: Deployment finished successfully for player in role '%1'.", _rankTitle];
true;
