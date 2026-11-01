/*
    ================================================================================
    File: fn_executeDeployment.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Gathers all operational parameters from the deployment dialog, closes the UI,
                 spawns the doctrinal combat force at the designated anchor, deploys attached
                 support assets (static artillery at pre-placed marker or custom position, mobile
                 armor in area or custom position) adhering to selected support factions/orientations,
                 and transitions the player seamlessly into their designated command role.
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) OOP port.
    ================================================================================
*/

private _disp = findDisplay 88000;
if (isNull _disp) exitWith {
    diag_log "FTCS Deploy Error: Deployment dialog not found.";
};

// 1. Retrieve User Selections
private _ctrlDoctrine    = _disp displayCtrl 88002;
private _ctrlEchelon     = _disp displayCtrl 88003;
private _ctrlFixedCheck  = _disp displayCtrl 88006;
private _ctrlMobileCheck = _disp displayCtrl 88008;
private _ctrlFixedCombo  = _disp displayCtrl 88024;
private _ctrlMobileCombo = _disp displayCtrl 88025;

private _doctrineKey   = _ctrlDoctrine lbData (lbCurSel _ctrlDoctrine);
private _echelon       = _ctrlEchelon lbData (lbCurSel _ctrlEchelon);
private _fixedEnabled  = cbChecked _ctrlFixedCheck;
private _mobileEnabled = cbChecked _ctrlMobileCheck;

private _fixedFile = if (!isNull _ctrlFixedCombo && {lbCurSel _ctrlFixedCombo >= 0}) then {
    _ctrlFixedCombo lbData (lbCurSel _ctrlFixedCombo)
} else {
    missionNamespace getVariable ["FTCS_Deploy_SelectedFixedFile", "Support_Artillery"]
};

private _mobileFile = if (!isNull _ctrlMobileCombo && {lbCurSel _ctrlMobileCombo >= 0}) then {
    _ctrlMobileCombo lbData (lbCurSel _ctrlMobileCombo)
} else {
    missionNamespace getVariable ["FTCS_Deploy_SelectedMobileFile", "Support_Armor"]
};

private _spawnPos = missionNamespace getVariable ["FTCS_Deploy_SpawnPos", getPos player];
private _advanceDir = missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0];

// Close dialog and clean all potential preview markers from map
closeDialog 1;

if (getMarkerType "FTCS_PREVIEW_MARKER" != "") then {
    deleteMarkerLocal "FTCS_PREVIEW_MARKER";
};
if (getMarkerType "FTCS_PREVIEW_ARROW" != "") then {
    deleteMarkerLocal "FTCS_PREVIEW_ARROW";
};
if (getMarkerType "FTCS_PREVIEW_BOX" != "") then {
    deleteMarkerLocal "FTCS_PREVIEW_BOX";
};
if (getMarkerType "FTCS_PREVIEW_HQ" != "") then {
    deleteMarkerLocal "FTCS_PREVIEW_HQ";
};
if (getMarkerType "FTCS_PREVIEW_ARTY" != "") then {
    deleteMarkerLocal "FTCS_PREVIEW_ARTY";
};
if (getMarkerType "FTCS_PREVIEW_ARMOR" != "") then {
    deleteMarkerLocal "FTCS_PREVIEW_ARMOR";
};

titleText [
    "<t size='1.3' color='#00FFCC' font='PuristaBold'>FTCS - DESPLEGANDO FUERZA TÁCTICA</t><br/><t size='0.9' color='#AAAAAA'>Inicializando doctrina, posiciones y enlaces de mando...</t>", 
    "PLAIN DOWN", 
    0.6, 
    true, 
    true
];

// 2. Load Doctrine Data Template (via centralized loader with alias resolution)
private _doctrineData = [_doctrineKey] call FTCS_fnc_loadDoctrineData;

if (count _doctrineData == 0) exitWith {
    diag_log "FTCS Deploy Error: Doctrine data could not be loaded. Deployment aborted.";
    hint parseText "<t color='#FF5555'>FTCS Error: No se pudo cargar la doctrina seleccionada. Revisa el fichero en Doctrines\Data\.</t>";
};

// Determine force side to provide authentic faction support units
private _doctrineSide = _doctrineData getOrDefault ["side", sideUnknown];
if !(_doctrineSide in [west, east, resistance, independent]) then {
    _doctrineSide = side group player;
};
if (_doctrineSide == civilian || _doctrineSide == sideUnknown) then { _doctrineSide = west; };

// 3. Deploy Main Doctrinal Force
// In Platoon mode, check if a dedicated Company HQ marker exists in the mission
// or if the player manually clicked a custom HQ position via Option B
private _customHQPos = [];
private _customHQDir = -1;
if (_echelon == "PLATOON") then {
    private _hqMarker = missionNamespace getVariable ["FTCS_Deploy_CompanyHQMarker", ""];
    private _clickedHQDir = missionNamespace getVariable ["FTCS_Deploy_HQDir", -1];

    if (_hqMarker != "" && {getMarkerType _hqMarker != ""}) then {
        _customHQPos = getMarkerPos _hqMarker;
        _customHQDir = if (_clickedHQDir >= 0) then { _clickedHQDir } else { markerDir _hqMarker };
        diag_log format ["FTCS: Deploying Company HQ at dedicated editor marker '%1' (Grid %2, Heading %3°).", _hqMarker, mapGridPosition _customHQPos, round _customHQDir];
    } else {
        // Retrieve interactive position chosen by the player via Option B buttons, or default to 150m rear
        private _clickedHQ = missionNamespace getVariable ["FTCS_Deploy_CustomHQPos", []];
        if (count _clickedHQ >= 2) then {
            _customHQPos = _clickedHQ;
            _customHQDir = if (_clickedHQDir >= 0) then { _clickedHQDir } else { _advanceDir };
            diag_log format ["FTCS: Deploying Company HQ at player interactive map position (Grid %1, Heading %2°).", mapGridPosition _customHQPos, round _customHQDir];
        } else {
            // Default: 150m to the rear of the platoon anchor along the reverse advance axis
            private _rad = _advanceDir;
            _customHQPos = [
                (_spawnPos select 0) - (150 * sin _rad),
                (_spawnPos select 1) - (150 * cos _rad),
                0
            ];
            _customHQDir = if (_clickedHQDir >= 0) then { _clickedHQDir } else { _advanceDir };
            diag_log format ["FTCS: Deploying Company HQ at automatic 150m rear position (Grid %1, Heading %2°).", mapGridPosition _customHQPos, round _customHQDir];
        };
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

// 4. Deploy Mobile Support (Interactive chosen position/orientation or default offset)
if (_mobileEnabled) then {
    private _armorPath = format ["Doctrines\Data\%1.sqf", _mobileFile];
    if !(fileExists _armorPath) then {
        _armorPath = "Doctrines\Data\Support_Armor.sqf";
    };

    if (fileExists _armorPath) then {
        private _armorData = call compile preprocessFileLineNumbers _armorPath;
        
        // Retrieve interactive position chosen via "[ UBICAR ]" button, or default lateral offset
        private _customArmor = missionNamespace getVariable ["FTCS_Deploy_CustomArmorPos", []];
        private _mobilePos = if (count _customArmor >= 2) then {
            _customArmor
        } else {
            private _rad = _advanceDir;
            private _offX = 30;
            private _offY = -35;
            private _rotX = (_offX * cos _rad) + (_offY * sin _rad);
            private _rotY = ((-_offX * sin _rad) + (_offY * cos _rad));
            [(_spawnPos select 0) + _rotX, (_spawnPos select 1) + _rotY, _spawnPos select 2]
        };

        // Custom mobile orientation adjusted with RMB + Wheel, or inherit advanceDir
        private _customArmorDir = missionNamespace getVariable ["FTCS_Deploy_ArmorDir", -1];
        private _mobileDir = if (_customArmorDir >= 0) then { _customArmorDir } else { _advanceDir };

        [_armorData, _mobilePos, _mobileDir, _doctrineSide] call FTCS_fnc_spawnSupportUnit;
        diag_log format ["FTCS: Mobile armored support deployed at Grid %1 (Heading %2°).", mapGridPosition _mobilePos, round _mobileDir];
    };
};

// 5. Deploy Fixed Support (Interactive chosen position/orientation or editor marker)
if (_fixedEnabled) then {
    private _artyPath = format ["Doctrines\Data\%1.sqf", _fixedFile];
    if !(fileExists _artyPath) then {
        _artyPath = "Doctrines\Data\Support_Artillery.sqf";
    };

    if (fileExists _artyPath) then {
        private _artilleryData = call compile preprocessFileLineNumbers _artyPath;
        
        // Priority: custom interactive click via "[ UBICAR ]" button, then editor marker
        private _customArty = missionNamespace getVariable ["FTCS_Deploy_CustomArtyPos", []];
        private _customArtyDir = missionNamespace getVariable ["FTCS_Deploy_ArtyDir", -1];
        private _artyPos = [];
        private _artyDir = if (_customArtyDir >= 0) then { _customArtyDir } else { _advanceDir };

        if (count _customArty >= 2) then {
            _artyPos = _customArty;
            diag_log format ["FTCS: Fixed artillery deployed at interactive map position (Grid %1).", mapGridPosition _artyPos];
        } else {
            private _artyMarker = missionNamespace getVariable ["FTCS_Deploy_ArtilleryMarker", ""];
            if (_artyMarker != "" && {getMarkerType _artyMarker != ""}) then {
                _artyPos = getMarkerPos _artyMarker;
                if (_customArtyDir < 0) then {
                    _artyDir = markerDir _artyMarker;
                };
                diag_log format ["FTCS: Fixed artillery support deployed at marker '%1'.", _artyMarker];
            };
        };

        if (count _artyPos >= 2) then {
            [_artilleryData, _artyPos, _artyDir, _doctrineSide] call FTCS_fnc_spawnSupportUnit;
            diag_log format ["FTCS: Fixed artillery deployed at Grid %1 (Heading %2°).", mapGridPosition _artyPos, round _artyDir];
        } else {
            diag_log "FTCS Warning: Fixed artillery selected but no coordinate or marker was found.";
        };
    };
};

// 6. Confirmation Notification: styled floating tactical box in lower viewport
// Rendered via parseText inside a dedicated hintSilent call with transparent structured backdrop
private _rankTitle = if (_echelon == "PLATOON") then { "Teniente" } else { "Capitán" };
private _echelonLabel = if (_echelon == "PLATOON") then { "1er Pelotón (HQ Cía presente)" } else { "Compañía Completa" };

hintSilent parseText format [
    "<t font='PuristaBold' size='1.25' color='#00FFCC'>[ FTCS - DESPLIEGUE OPERACIONAL ]</t><br/>" +
    "<t size='0.95' color='#00FFCC'>════════════════════════════════════</t><br/>" +
    "<t align='left' size='0.90' color='#AAAAAA'>Doctrina:</t><t align='right' size='0.90' color='#FFFFFF'>%1</t><br/>" +
    "<t align='left' size='0.90' color='#AAAAAA'>Mando:</t><t align='right' size='0.90' color='#00BFFF'>%2 (%3)</t><br/>" +
    "<t align='left' size='0.90' color='#AAAAAA'>Zona Táctica:</t><t align='right' size='0.90' color='#FFFFFF'>Grid %4 (Rumbo %5°)</t><br/>" +
    "<t size='0.95' color='#00FFCC'>════════════════════════════════════</t><br/>" +
    "<t size='0.95' color='#00FF66' font='PuristaMedium'>✔ Todas las escuadras enlazadas al mando.</t><br/>" +
    "<t size='0.85' color='#888888'>¡A sus órdenes, mi %3!</t>",
    _doctrineKey,
    _echelonLabel,
    _rankTitle,
    mapGridPosition _spawnPos,
    round _advanceDir
];

diag_log format ["FTCS: Deployment finished successfully for player in role '%1'.", _rankTitle];
true;
