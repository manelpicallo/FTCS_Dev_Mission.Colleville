/*
    ================================================================================
    File: fn_initDeployMenu.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Initializes the Operational Deployment Menu dialog. Populates available
                 military doctrines, command echelons, detects editor deployment markers,
                 verifies pre-placed markers for fixed artillery, enables mobile support,
                 and binds interactive map click event handling.
    Compatibility: Arma 3 (SQF) | Designed for 1:1 Enfusion Engine (Arma 4) OOP port.
    ================================================================================
*/

params [["_inputDisplay", displayNull]];

private _display = if (_inputDisplay isEqualType displayNull) then {
    _inputDisplay
} else {
    if (_inputDisplay isEqualType [] && {count _inputDisplay > 0}) then {
        _inputDisplay select 0
    } else {
        displayNull
    }
};

if (isNull _display) then {
    _display = findDisplay 88000;
};

if (isNull _display) exitWith {
    diag_log "FTCS InitDeployMenu Error: Display 88000 is null.";
    false;
};

// UI Display handles are non-serializable objects in Arma 3 and must not be stored
// in persistent mission-level global variables (causes "Cannot serialize object" engine errors).

// IDCs
private _idcMap          = 88001;
private _idcDoctrine     = 88002;
private _idcEchelon      = 88003;
private _idcArea         = 88004;
private _idcAreaStatus   = 88005;
private _idcFixedCheck   = 88006;
private _idcFixedStatus  = 88007;
private _idcMobileCheck  = 88008;
private _idcMobileStatus = 88009;
private _idcDocInfo      = 88012;
private _idcEchInfo      = 88013;

private _ctrlMap          = _display displayCtrl _idcMap;
private _ctrlDoctrine     = _display displayCtrl _idcDoctrine;
private _ctrlDoctrineInfo = _display displayCtrl _idcDocInfo;
private _ctrlEchelon      = _display displayCtrl _idcEchelon;
private _ctrlEchelonInfo  = _display displayCtrl _idcEchInfo;
private _ctrlArea         = _display displayCtrl _idcArea;
private _ctrlAreaStatus   = _display displayCtrl _idcAreaStatus;
private _ctrlFixedCheck   = _display displayCtrl _idcFixedCheck;
private _ctrlFixedStatus  = _display displayCtrl _idcFixedStatus;
private _ctrlMobileCheck  = _display displayCtrl _idcMobileCheck;
private _ctrlMobileStatus = _display displayCtrl _idcMobileStatus;

// -----------------------------------------------------------------------------
// 1. Hook Interactive Event Handlers
// -----------------------------------------------------------------------------

FTCS_fnc_onDeployMapClick = {
    params ["_control", "_button", "_xPos", "_yPos"];
    
    private _worldPos = _control ctrlMapScreenToWorld [_xPos, _yPos];
    FTCS_Deploy_SpawnPos = _worldPos;
    FTCS_Deploy_SelectedMarker = "";

    if (getMarkerType "FTCS_PREVIEW_MARKER" != "") then {
        "FTCS_PREVIEW_MARKER" setMarkerPosLocal _worldPos;
    } else {
        private _m = createMarkerLocal ["FTCS_PREVIEW_MARKER", _worldPos];
        _m setMarkerTypeLocal "mil_start";
        _m setMarkerColorLocal "ColorGreen";
        _m setMarkerTextLocal " ZONA DE DESPLIEGUE";
    };

    if (!isNull (findDisplay 88000)) then {
        private _disp = findDisplay 88000;
        private _statusCtrl = _disp displayCtrl 88005;
        private _areaCombo = _disp displayCtrl 88004;
        
        _statusCtrl ctrlSetStructuredText parseText format [
            "<t color='#00FFCC'>Punto Seleccionado en Mapa:</t><br/><t color='#AAAAAA'>Coordenadas:</t> Grid %1<br/><t color='#888888'>Posición personalizada por clic interactivo.</t>",
            mapGridPosition _worldPos
        ];

        // Select the custom map click option in combo (last index)
        private _count = lbSize _areaCombo;
        if (_count > 0) then {
            _areaCombo lbSetCurSel (_count - 1);
        };
    };
};

FTCS_fnc_onDeployAreaChanged = {
    params ["_control", "_selectedIndex"];
    
    private _markerName = _control lbData _selectedIndex;
    if (_markerName != "") then {
        private _markerPos = getMarkerPos _markerName;
        FTCS_Deploy_SpawnPos = _markerPos;
        FTCS_Deploy_SelectedMarker = _markerName;

        if (getMarkerType "FTCS_PREVIEW_MARKER" != "") then {
            "FTCS_PREVIEW_MARKER" setMarkerPosLocal _markerPos;
        } else {
            private _m = createMarkerLocal ["FTCS_PREVIEW_MARKER", _markerPos];
            _m setMarkerTypeLocal "mil_start";
            _m setMarkerColorLocal "ColorGreen";
            _m setMarkerTextLocal " ZONA DE DESPLIEGUE";
        };

        if (!isNull (findDisplay 88000)) then {
            private _disp = findDisplay 88000;
            private _map = _disp displayCtrl 88001;
            private _status = _disp displayCtrl 88005;

            _map ctrlMapAnimAdd [0.4, 0.08, _markerPos];
            ctrlMapAnimCommit _map;

            _status ctrlSetStructuredText parseText format [
                "<t color='#00FFCC'>Zona Editor Detectada:</t> '%1'<br/><t color='#AAAAAA'>Coordenadas:</t> Grid %2<br/><t color='#888888'>Despliegue automático en la marca del editor.</t>",
                _markerName,
                mapGridPosition _markerPos
            ];
        };
    };
};

FTCS_fnc_onDeployEchelonChanged = {
    params ["_control", "_selectedIndex"];
    private _echelon = _control lbData _selectedIndex;

    if (!isNull (findDisplay 88000)) then {
        private _infoCtrl = (findDisplay 88000) displayCtrl 88013;
        if (_echelon == "PLATOON") then {
            private _hqMarkerMsg = if (!isNil "FTCS_Deploy_CompanyHQMarker" && {FTCS_Deploy_CompanyHQMarker != ""}) then {
                format ["<br/><t color='#00FF00'>Marcador de Company HQ detectado ('%1') en Grid %2. El HQ de Compañía se desplegará en dicha posición.</t>", FTCS_Deploy_CompanyHQMarker, mapGridPosition (getMarkerPos FTCS_Deploy_CompanyHQMarker)]
            } else {
                "<br/><t color='#AAAAAA'>HQ de Compañía desplegado en el escalón de mando superior.</t>"
            };
            _infoCtrl ctrlSetStructuredText parseText format ["<t color='#00BFFF'>Rol: Teniente (1er Pelotón)</t><br/><t color='#AAAAAA'>Comandas el 1er Pelotón táctico.</t>%1", _hqMarkerMsg];
        } else {
            _infoCtrl ctrlSetStructuredText parseText "<t color='#00FFCC'>Rol: Capitán (Compañía Completa)</t><br/><t color='#AAAAAA'>Comandas la Compañía completa con todos sus pelotones tácticos y secciones de apoyo orgánicas.</t>";
        };
    };
};

FTCS_fnc_onDeployDoctrineChanged = {
    params ["_control", "_selectedIndex"];
    private _docId = _control lbData _selectedIndex;

    if (!isNull (findDisplay 88000)) then {
        private _infoCtrl = (findDisplay 88000) displayCtrl 88012;
        private _infoText = switch (_docId) do {
            case "101_US_PARA_COMPANY": { "<t color='#00FFCC'>101ª División Aerotransportada (Easy Co.)</t><br/><t color='#AAAAAA'>Compañía de paracaidistas: 3 pelotones de fusileros + sección morteros + HQ de compañía (TO&E WWII).</t>" };
            case "US_ARMY":             { "<t color='#00FFCC'>29ª División de Infantería (US Army)</t><br/><t color='#AAAAAA'>Infantería de línea: 3 pelotones de fusileros estándar + elementos pesados de apoyo.</t>" };
            case "US_RANGERS_WW2":      { "<t color='#00FFCC'>2º Batallón de Rangers</t><br/><t color='#AAAAAA'>Infantería ligera de asalto especializado para operaciones de choque e infiltración.</t>" };
            case "GERMAN_PANZER_GRENADIER": { "<t color='#00FFCC'>Panzergrenadier-Kompanie (Wehrmacht)</t><br/><t color='#AAAAAA'>Fuerza mecanizada/blindada según KStN 1114b con semiorugas Sd.Kfz 251 y apoyo pesado.</t>" };
            case "GERMAN_WW2":          { "<t color='#00FFCC'>Wehrmacht Infanterie-Kompanie</t><br/><t color='#AAAAAA'>Infantería regular del ejército alemán: 3 Züge de fusileros + MG-Zug.</t>" };
            case "BRITISH_AIRBORNE":    { "<t color='#00FFCC'>British Parachute Company</t><br/><t color='#AAAAAA'>Paracaidistas británicos de élite con armamento ligero y alta movilidad táctica.</t>" };
            default                     { "<t color='#00FFCC'>Doctrina Militar Seleccionada</t><br/><t color='#AAAAAA'>Plantilla de fuerza táctica para despliegue en combate.</t>" };
        };
        _infoCtrl ctrlSetStructuredText parseText _infoText;
    };
};

FTCS_fnc_onDeployFixedCheckChanged = {
    params ["_control", "_checked"];
    if (_checked == 1 && {isNil "FTCS_Deploy_ArtilleryMarker" || {FTCS_Deploy_ArtilleryMarker == ""}}) then {
        _control cbSetChecked false;
        hint parseText "<t color='#FF5555'><t size='1.2' font='PuristaBold'>Aviso de Despliegue</t><br/><br/>Las unidades fijas como artillería requieren obligatoriamente un marcador previo en el mapa colocado por el editor de la misión (ej: 'ftcs_artillery').<br/><br/>No se ha detectado ningún marcador de artillería en este escenario.</t>";
    };
};

// -----------------------------------------------------------------------------
// 2. Populate Doctrine Options (Dynamic: built from Doctrines\Data\ registry)
//    Every doctrine registered in Doctrines_Registry.sqf appears in the dropdown,
//    so the selection always adapts to the actual available doctrines instead of
//    a hardcoded list. Each entry stores its doctrineID as lbData, which the
//    deployment executor resolves back into a data HashMap via the loader.
// -----------------------------------------------------------------------------
lbClear _ctrlDoctrine;

private _doctrinesList = ["LIST"] call FTCS_fnc_loadDoctrineData;

if (count _doctrinesList == 0) then {
    diag_log "FTCS InitDeployMenu Warning: No doctrines available in the registry.";
    private _idx = _ctrlDoctrine lbAdd "NO DOCTRINES AVAILABLE";
    _ctrlDoctrine lbSetData [_idx, ""];
} else {
    {
        _x params ["_label", "_dataId"];
        private _idx = _ctrlDoctrine lbAdd _label;
        _ctrlDoctrine lbSetData [_idx, _dataId];
    } forEach _doctrinesList;
};

_ctrlDoctrine lbSetCurSel 0;
[_ctrlDoctrine, 0] call FTCS_fnc_onDeployDoctrineChanged;

// -----------------------------------------------------------------------------
// 3. Populate Command Echelons
// -----------------------------------------------------------------------------
lbClear _ctrlEchelon;

private _idxPlt = _ctrlEchelon lbAdd "Pelotón (Platoon Commander - Teniente)";
_ctrlEchelon lbSetData [_idxPlt, "PLATOON"];

private _idxCoy = _ctrlEchelon lbAdd "Compañía (Company Commander - Capitán)";
_ctrlEchelon lbSetData [_idxCoy, "COMPANY"];

_ctrlEchelon lbSetCurSel 0;
[_ctrlEchelon, 0] call FTCS_fnc_onDeployEchelonChanged;

// -----------------------------------------------------------------------------
// 4. Scan & Populate Deployment Area Markers
// -----------------------------------------------------------------------------
lbClear _ctrlArea;

private _foundDeployMarkers = [];
{
    private _mName = _x;
    private _mLow = toLower _mName;
    private _mTextLow = toLower (markerText _mName);

    private _isDeployMarker = 
        (_mLow find "ftcs_deploy" >= 0) || 
        (_mLow find "ftcs_assembly" >= 0) || 
        (_mLow find "ftcs_spawn" >= 0) || 
        (_mLow find "ftcs_aa" >= 0) || 
        (_mLow find "deploy_area" >= 0) || 
        (_mLow find "assembly_area" >= 0) || 
        (_mLow find "respawn_west" >= 0) ||
        (_mTextLow find "despliegue" >= 0) ||
        (_mTextLow find "deploy" >= 0) ||
        (_mTextLow find "assembly" >= 0) ||
        (_mTextLow find "aa" >= 0);

    if (_isDeployMarker) then {
        _foundDeployMarkers pushBack _mName;
    };
} forEach allMapMarkers;

if (count _foundDeployMarkers > 0) then {
    {
        private _itemIdx = _ctrlArea lbAdd format ["[Marcador Editor] %1", _x];
        _ctrlArea lbSetData [_itemIdx, _x];
    } forEach _foundDeployMarkers;

    private _clickIdx = _ctrlArea lbAdd "[Hacer clic en el mapa para ajustar]";
    _ctrlArea lbSetData [_clickIdx, ""];

    _ctrlArea lbSetCurSel 0;
    private _firstMarker = _foundDeployMarkers select 0;
    FTCS_Deploy_SpawnPos = getMarkerPos _firstMarker;
    FTCS_Deploy_SelectedMarker = _firstMarker;

    _ctrlMap ctrlMapAnimAdd [0, 0.08, FTCS_Deploy_SpawnPos];
    ctrlMapAnimCommit _ctrlMap;

    _ctrlAreaStatus ctrlSetStructuredText parseText format [
        "<t color='#00FFCC'>Zona Editor Detectada:</t> '%1'<br/><t color='#AAAAAA'>Coordenadas:</t> Grid %2<br/><t color='#888888'>Despliegue automático en el área marcada por el editor.</t>",
        _firstMarker,
        mapGridPosition FTCS_Deploy_SpawnPos
    ];
} else {
    private _clickIdx = _ctrlArea lbAdd "[Seleccionar punto en el mapa (Haz clic)]";
    _ctrlArea lbSetData [_clickIdx, ""];
    _ctrlArea lbSetCurSel 0;

    FTCS_Deploy_SpawnPos = getPos player;
    FTCS_Deploy_SelectedMarker = "";

    _ctrlMap ctrlMapAnimAdd [0, 0.08, FTCS_Deploy_SpawnPos];
    ctrlMapAnimCommit _ctrlMap;

    _ctrlAreaStatus ctrlSetStructuredText parseText "<t color='#FFD700'>No se detectó área de despliegue previa del editor.</t><br/><t color='#AAAAAA'>Haz clic en cualquier punto del mapa para ubicar la fuerza.</t>";
};

// Create local preview marker on map
if (getMarkerType "FTCS_PREVIEW_MARKER" != "") then {
    "FTCS_PREVIEW_MARKER" setMarkerPosLocal FTCS_Deploy_SpawnPos;
} else {
    private _m = createMarkerLocal ["FTCS_PREVIEW_MARKER", FTCS_Deploy_SpawnPos];
    _m setMarkerTypeLocal "mil_start";
    _m setMarkerColorLocal "ColorGreen";
    _m setMarkerTextLocal " ZONA DE DESPLIEGUE";
};

// -----------------------------------------------------------------------------
// 5. Scan Pre-Placed Fixed Support (Artillery) & Company HQ Markers
// -----------------------------------------------------------------------------
FTCS_Deploy_ArtilleryMarker = "";
FTCS_Deploy_CompanyHQMarker = "";

{
    private _mName = _x;
    private _mLow = toLower _mName;
    private _mTextLow = toLower (markerText _mName);

    // Fixed Artillery marker detection
    private _isArtyMarker = 
        (_mLow find "ftcs_artillery" >= 0) || 
        (_mLow find "artillery_pos" >= 0) || 
        (_mLow find "ftcs_support_static" >= 0) || 
        (_mLow find "ftcs_mortar_static" >= 0) || 
        (_mLow == "artillery") || 
        (_mLow == "arty") ||
        (_mTextLow find "artill" >= 0);

    if (_isArtyMarker && FTCS_Deploy_ArtilleryMarker == "") then {
        FTCS_Deploy_ArtilleryMarker = _mName;
    };

    // Company HQ dedicated marker detection
    private _isHQMarker = 
        (_mLow find "ftcs_company_hq" >= 0) || 
        (_mLow find "ftcs_co_hq" >= 0) || 
        (_mLow find "company_hq" >= 0) || 
        (_mLow find "co_hq" >= 0) || 
        (_mLow find "ftcs_hq" >= 0) || 
        (_mTextLow find "company hq" >= 0) || 
        (_mTextLow find "co hq" >= 0) || 
        (_mTextLow find "cuartel general" >= 0);

    if (_isHQMarker && FTCS_Deploy_CompanyHQMarker == "") then {
        FTCS_Deploy_CompanyHQMarker = _mName;
    };
} forEach allMapMarkers;

if (FTCS_Deploy_CompanyHQMarker != "") then {
    diag_log format ["FTCS: Dedicated Company HQ marker detected at '%1' (Grid %2).", FTCS_Deploy_CompanyHQMarker, mapGridPosition (getMarkerPos FTCS_Deploy_CompanyHQMarker)];
};

if (FTCS_Deploy_ArtilleryMarker != "") then {
    private _artyPos = getMarkerPos FTCS_Deploy_ArtilleryMarker;
    _ctrlFixedStatus ctrlSetStructuredText parseText format [
        "<t color='#00FF00'>Marcador '%1' detectado en mapa.</t><br/><t color='#AAAAAA'>La batería de artillería fija se desplegará en Grid %2.</t>",
        FTCS_Deploy_ArtilleryMarker,
        mapGridPosition _artyPos
    ];
    _ctrlFixedCheck cbSetChecked false;
} else {
    _ctrlFixedStatus ctrlSetStructuredText parseText "<t color='#FF5555'>Requiere marcador 'ftcs_artillery' en mapa.</t><br/><t color='#888888'>No detectado. La artillería estática necesita posición previa fijada por el editor.</t>";
    _ctrlFixedCheck cbSetChecked false;
};

// -----------------------------------------------------------------------------
// 6. Mobile Support Status
// -----------------------------------------------------------------------------
_ctrlMobileStatus ctrlSetStructuredText parseText "<t color='#00FFCC'>Unidad Móvil Dinámica.</t><br/><t color='#AAAAAA'>Se despliega directamente junto a las tropas de infantería en el área doctrinal.</t>";
_ctrlMobileCheck cbSetChecked false;

true;
