/*
    ================================================================================
    File: fn_initDeployMenu.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Initializes the Operational Deployment Menu dialog. Populates available
                 military doctrines, command echelons, detects editor deployment markers,
                 verifies pre-placed markers for fixed artillery, enables mobile support,
                 binds interactive map click/RMB rotation event handling, and dynamically
                 filters support asset dropdowns based on the selected force side/faction.
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
private _idcFixedCombo   = 88024;
private _idcMobileCombo  = 88025;

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
private _ctrlFixedCombo   = _display displayCtrl _idcFixedCombo;
private _ctrlMobileCombo  = _display displayCtrl _idcMobileCombo;

// -----------------------------------------------------------------------------
// 1. Hook Interactive Event Handlers & State Variables
// -----------------------------------------------------------------------------

// Active target placement mode in dialog: "PLATOON" (default), "COMPANY_HQ", "FIXED_ARTY", or "MOBILE_ARMOR"
FTCS_Deploy_TargetMode = "PLATOON";
FTCS_Deploy_CustomHQPos = [];
FTCS_Deploy_CustomArtyPos = [];
FTCS_Deploy_CustomArmorPos = [];

// Interactive rotation state variables (Left Mouse Button hold + wheel)
FTCS_Deploy_LMBHeld = false;
FTCS_Deploy_LockedScale = -1;
FTCS_Deploy_HQDir = -1;
FTCS_Deploy_ArtyDir = -1;
FTCS_Deploy_ArmorDir = -1;

// Selected support asset keys from dropdowns
FTCS_Deploy_SelectedFixedFile  = "Support_Artillery";
FTCS_Deploy_SelectedMobileFile = "Support_Armor";

// Helper function to draw or update the dynamic deployment rectangle marker and directional arrow on the map
// Sized and offset strictly to the actual doctrinal spatial footprint of the selected echelon:
// - COMPANY: 140m width (semi-axis A = 75m) x 100m depth (semi-axis B = 55m), centered +35m forward
// - PLATOON:  60m width (semi-axis A = 30m) x 100m depth (semi-axis B = 50m), centered +22m forward
//   (covers scouts in vanguard at Y = +70m to mortars in rear at Y = -32m completely)
FTCS_fnc_updateDeployPreviewMarker = {
    params [["_pos", FTCS_Deploy_SpawnPos]];

    private _echelon = if (!isNull (findDisplay 88000)) then {
        private _ctrlEch = (findDisplay 88000) displayCtrl 88003;
        _ctrlEch lbData (lbCurSel _ctrlEch)
    } else {
        "COMPANY"
    };

    // Semi-axes and forward-center offset along the advance direction
    // Dynamically calculate bounding box from selected doctrine entities and echelon
    private _doctrineKey = if (!isNull (findDisplay 88000)) then {
        private _ctrlDoc = (findDisplay 88000) displayCtrl 88002;
        _ctrlDoc lbData (lbCurSel _ctrlDoc)
    } else {
        ""
    };

    private _sizeA = 75;
    private _sizeB = 55;
    private _lateralDist = 0;
    private _forwardDist = 35;

    if (_doctrineKey != "") then {
        private _docData = [_doctrineKey] call FTCS_fnc_loadDoctrineData;
        private _entities = _docData getOrDefault ["entities", []];
        if (count _entities > 0) then {
            private _minX = 1e6;
            private _maxX = -1e6;
            private _minY = 1e6;
            private _maxY = -1e6;

            private _plt1Offset = [0, 0];
            if (_echelon == "PLATOON") then {
                {
                    if ((_x select 3) == "PLT_1_LEADER") exitWith {
                        private _pPos = _x select 1;
                        _plt1Offset = [_pPos select 0, _pPos select 1];
                    };
                } forEach _entities;
            };

            {
                private _offsetXYZ = _x select 1;
                private _varName = _x select 3;
                private _groupVar = _x select 4;
                private _upGroup = toUpper _groupVar;
                private _upVar = toUpper _varName;

                private _include = true;
                if (_echelon == "PLATOON") then {
                    private _isCompanyHQ = (_upGroup == "SQUAD_0_0" || _upGroup find "SQUAD_0_0_" == 0 || _upGroup find "SQD_0_0_" == 0) || (_upVar find "HQ_" == 0);
                    private _isPlatoon1  = (_upGroup find "SQUAD_1_" == 0 || _upGroup find "SQD_1_" == 0) || (_upVar find "PLT_1_" == 0 || _upVar find "SQD_1_" == 0);
                    // In platoon echelon, preview box covers the 1st Platoon deployment area
                    if (!_isPlatoon1 || _isCompanyHQ) then {
                        _include = false;
                    };
                };

                if (_include) then {
                    private _ox = _offsetXYZ select 0;
                    private _oy = _offsetXYZ select 1;
                    if (_echelon == "PLATOON") then {
                        _ox = _ox - (_plt1Offset select 0);
                        _oy = _oy - (_plt1Offset select 1);
                    };
                    if (_ox < _minX) then { _minX = _ox; };
                    if (_ox > _maxX) then { _maxX = _ox; };
                    if (_oy < _minY) then { _minY = _oy; };
                    if (_oy > _maxY) then { _maxY = _oy; };
                };
            } forEach _entities;

            if (_minX < _maxX && _minY < _maxY) then {
                // Add 8m tactical padding around the outermost units
                private _pad = 8;
                _sizeA = ((_maxX - _minX) / 2) + _pad;
                _sizeB = ((_maxY - _minY) / 2) + _pad;
                _lateralDist = (_maxX + _minX) / 2;
                _forwardDist = (_maxY + _minY) / 2;
            };
        };
    } else {
        // Fallback default dimensions if no doctrine data is loaded
        _sizeA = if (_echelon == "PLATOON") then { 30 } else { 75 };
        _sizeB = if (_echelon == "PLATOON") then { 55 } else { 55 };
        _lateralDist = 0;
        _forwardDist = if (_echelon == "PLATOON") then { 18 } else { 35 };
    };

    private _advanceDir = missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0];

    // Compute true bounding-box geometric center applying 2D rotation for both lateral and forward offsets
    // Arma 2D rotation matching fn_spawnDoctrine:
    // rotX = (offX * cos(dir)) + (offY * sin(dir))
    // rotY = (-offX * sin(dir)) + (offY * cos(dir))
    private _rad = _advanceDir;
    private _sinA = sin _rad;
    private _cosA = cos _rad;

    private _boxRotX = (_lateralDist * _cosA) + (_forwardDist * _sinA);
    private _boxRotY = ((-_lateralDist * _sinA) + (_forwardDist * _cosA));

    private _boxCenterX = (_pos select 0) + _boxRotX;
    private _boxCenterY = (_pos select 1) + _boxRotY;
    private _boxCenterPos = [_boxCenterX, _boxCenterY, 0];

    // 1. Center indicator marker (mil_start icon placed directly at the anchor point)
    if (getMarkerType "FTCS_PREVIEW_MARKER" != "") then {
        "FTCS_PREVIEW_MARKER" setMarkerPosLocal _pos;
        "FTCS_PREVIEW_MARKER" setMarkerDirLocal _advanceDir;
    } else {
        private _m = createMarkerLocal ["FTCS_PREVIEW_MARKER", _pos];
        _m setMarkerTypeLocal "mil_start";
        _m setMarkerColorLocal "ColorOrange";
        _m setMarkerDirLocal _advanceDir;
        _m setMarkerTextLocal " EJE DE DESPLIEGUE";
    };

    // 2. Directional vanguard arrow indicating where the deployed units will face
    private _arrowDist = _forwardDist + _sizeB + 18;
    private _arrowPos = [
        (_pos select 0) + (_arrowDist * sin _rad),
        (_pos select 1) + (_arrowDist * cos _rad),
        0
    ];

    if (getMarkerType "FTCS_PREVIEW_ARROW" != "") then {
        "FTCS_PREVIEW_ARROW" setMarkerPosLocal _arrowPos;
        "FTCS_PREVIEW_ARROW" setMarkerDirLocal _advanceDir;
    } else {
        private _arr = createMarkerLocal ["FTCS_PREVIEW_ARROW", _arrowPos];
        _arr setMarkerTypeLocal "mil_arrow";
        _arr setMarkerColorLocal "ColorOrange";
        _arr setMarkerDirLocal _advanceDir;
        _arr setMarkerSizeLocal [0.8, 1.2];
    };

    // 3. High-visibility solid line bounding box covering the entire formation from rear to vanguard
    deleteMarkerLocal "FTCS_PREVIEW_BOX";
    private _box = createMarkerLocal ["FTCS_PREVIEW_BOX", _boxCenterPos];
    _box setMarkerShapeLocal "RECTANGLE";
    _box setMarkerBrushLocal "SolidBorder";
    _box setMarkerColorLocal "ColorOrange";
    _box setMarkerSizeLocal [_sizeA, _sizeB];
    _box setMarkerDirLocal _advanceDir;

    // 4. Update Company HQ custom marker if set or auto-placed
    if (_echelon == "PLATOON") then {
        private _hqPos = if (count FTCS_Deploy_CustomHQPos >= 2) then {
            FTCS_Deploy_CustomHQPos
        } else {
            // Default: 150 meters directly to the rear of the platoon anchor along the reverse advance axis
            [
                (_pos select 0) - (150 * sin _rad),
                (_pos select 1) - (150 * cos _rad),
                0
            ]
        };

        private _hqDir = if (FTCS_Deploy_HQDir >= 0) then {
            FTCS_Deploy_HQDir
        } else {
            _advanceDir
        };

        if (getMarkerType "FTCS_PREVIEW_HQ" != "") then {
            "FTCS_PREVIEW_HQ" setMarkerPosLocal _hqPos;
            "FTCS_PREVIEW_HQ" setMarkerDirLocal _hqDir;
        } else {
            private _hqM = createMarkerLocal ["FTCS_PREVIEW_HQ", _hqPos];
            _hqM setMarkerTypeLocal "b_hq";
            _hqM setMarkerColorLocal "ColorOrange";
            _hqM setMarkerDirLocal _hqDir;
            _hqM setMarkerTextLocal " PUESTO DE MANDO (HQ CÍA)";
        };
    } else {
        if (getMarkerType "FTCS_PREVIEW_HQ" != "") then {
            deleteMarkerLocal "FTCS_PREVIEW_HQ";
        };
    };
};

// Helper function to update orientation of support element preview markers
FTCS_fnc_updateSupportPreviewMarkerDir = {
    params ["_mode", "_dir"];
    switch (_mode) do {
        case "FIXED_ARTY": {
            if (getMarkerType "FTCS_PREVIEW_ARTY" != "") then {
                "FTCS_PREVIEW_ARTY" setMarkerDirLocal _dir;
            };
            if (!isNull (findDisplay 88000)) then {
                private _pos = missionNamespace getVariable ["FTCS_Deploy_CustomArtyPos", []];
                private _grid = if (count _pos >= 2) then { mapGridPosition _pos } else { "---" };
                private _status = (findDisplay 88000) displayCtrl 88007;
                _status ctrlSetStructuredText parseText format [
                    "<t color='#00FF00'>Posición fijada en Grid %1.</t><br/><t color='#FFAA00'>Orientación:</t> %2° (Giro RMB + Rueda)",
                    _grid,
                    round _dir
                ];
            };
        };
        case "MOBILE_ARMOR": {
            if (getMarkerType "FTCS_PREVIEW_ARMOR" != "") then {
                "FTCS_PREVIEW_ARMOR" setMarkerDirLocal _dir;
            };
            if (!isNull (findDisplay 88000)) then {
                private _pos = missionNamespace getVariable ["FTCS_Deploy_CustomArmorPos", []];
                private _grid = if (count _pos >= 2) then { mapGridPosition _pos } else { "---" };
                private _status = (findDisplay 88000) displayCtrl 88009;
                _status ctrlSetStructuredText parseText format [
                    "<t color='#00FF00'>Posición fijada en Grid %1.</t><br/><t color='#FFAA00'>Orientación:</t> %2° (Giro RMB + Rueda)",
                    _grid,
                    round _dir
                ];
            };
        };
    };
};

// Switch target placement mode across all 4 tactical elements:
// "PLATOON", "COMPANY_HQ", "FIXED_ARTY", or "MOBILE_ARMOR"
FTCS_fnc_onDeployTargetModeChanged = {
    params ["_mode"];
    FTCS_Deploy_TargetMode = _mode;

    if (!isNull (findDisplay 88000)) then {
        private _disp = findDisplay 88000;
        private _btnPlt   = _disp displayCtrl 88020;
        private _btnHQ    = _disp displayCtrl 88021;
        private _btnArty  = _disp displayCtrl 88022;
        private _btnArmor = _disp displayCtrl 88023;
        private _status   = _disp displayCtrl 88005;

        // Reset all 4 buttons to unselected state
        _btnPlt   ctrlSetBackgroundColor [0.0, 0.15, 0.25, 0.60];
        _btnPlt   ctrlSetTextColor [0.8, 0.9, 1.0, 0.8];
        _btnHQ    ctrlSetBackgroundColor [0.0, 0.15, 0.25, 0.60];
        _btnHQ    ctrlSetTextColor [0.8, 0.9, 1.0, 0.8];
        _btnArty  ctrlSetBackgroundColor [0.0, 0.15, 0.25, 0.60];
        _btnArty  ctrlSetTextColor [0.8, 0.9, 1.0, 0.8];
        _btnArmor ctrlSetBackgroundColor [0.0, 0.15, 0.25, 0.60];
        _btnArmor ctrlSetTextColor [0.8, 0.9, 1.0, 0.8];

        switch (_mode) do {
            case "PLATOON": {
                _btnPlt ctrlSetBackgroundColor [1.0, 0.55, 0.0, 0.85];
                _btnPlt ctrlSetTextColor [1.0, 1.0, 1.0, 1.0];
                _status ctrlSetStructuredText parseText "<t color='#00FFCC'>Modo:</t> <t color='#FFFFFF'>Mantén</t> <t color='#FFAA00'>Clic Izquierdo</t> <t color='#FFFFFF'>para ubicar Pelotón y usa la</t> <t color='#FFAA00'>Rueda</t> <t color='#FFFFFF'>para orientar.</t>";
            };
            case "COMPANY_HQ": {
                _btnHQ ctrlSetBackgroundColor [1.0, 0.55, 0.0, 0.85];
                _btnHQ ctrlSetTextColor [1.0, 1.0, 1.0, 1.0];
                _status ctrlSetStructuredText parseText "<t color='#00FFCC'>Modo:</t> <t color='#FFFFFF'>Mantén</t> <t color='#FFAA00'>Clic Izquierdo</t> <t color='#FFFFFF'>para ubicar HQ Cía y usa la</t> <t color='#FFAA00'>Rueda</t> <t color='#FFFFFF'>para orientar.</t>";
            };
            case "FIXED_ARTY": {
                _btnArty ctrlSetBackgroundColor [1.0, 0.55, 0.0, 0.85];
                _btnArty ctrlSetTextColor [1.0, 1.0, 1.0, 1.0];
                _status ctrlSetStructuredText parseText "<t color='#00FFCC'>Modo:</t> <t color='#FFFFFF'>Mantén</t> <t color='#FFAA00'>Clic Izquierdo</t> <t color='#FFFFFF'>para ubicar Artillería y usa la</t> <t color='#FFAA00'>Rueda</t> <t color='#FFFFFF'>para orientar.</t>";
            };
            case "MOBILE_ARMOR": {
                _btnArmor ctrlSetBackgroundColor [1.0, 0.55, 0.0, 0.85];
                _btnArmor ctrlSetTextColor [1.0, 1.0, 1.0, 1.0];
                _status ctrlSetStructuredText parseText "<t color='#00FFCC'>Modo:</t> <t color='#FFFFFF'>Mantén</t> <t color='#FFAA00'>Clic Izquierdo</t> <t color='#FFFFFF'>para ubicar Blindados y usa la</t> <t color='#FFAA00'>Rueda</t> <t color='#FFFFFF'>para orientar.</t>";
            };
        };
    };
};

// Map Mouse Events: Track Left Mouse Button (button 0 in Arma 3 UI) to place location and enable wheel rotation
FTCS_fnc_onDeployMapButtonDown = {
    params ["_control", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
    if (_button == 0) then {
        FTCS_Deploy_LMBHeld = true;
        FTCS_Deploy_LockedScale = ctrlMapScale _control;

        // Place or relocate element immediately on mouse button press
        [_control, _button, _xPos, _yPos] call FTCS_fnc_onDeployMapClick;
    };
    false;
};

FTCS_fnc_onDeployMapButtonUp = {
    params ["_control", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
    if (_button == 0) then {
        FTCS_Deploy_LMBHeld = false;
        FTCS_Deploy_LockedScale = -1;
    };
    false;
};

// Mouse Wheel rotation when Left Mouse Button is held: intercepts map zoom and rotates active deploy marker
FTCS_fnc_onDeployMapMouseZChanged = {
    params ["_control", "_scrollDelta"];

    if (FTCS_Deploy_LMBHeld) exitWith {
        // Step of 5 degrees per notch
        private _step = 5;
        private _rotDelta = if (_scrollDelta > 0) then { _step } else { -_step };

        switch (FTCS_Deploy_TargetMode) do {
            case "COMPANY_HQ": {
                private _curDir = if (FTCS_Deploy_HQDir >= 0) then { FTCS_Deploy_HQDir } else { missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0] };
                private _newDir = (_curDir + _rotDelta + 360) % 360;
                FTCS_Deploy_HQDir = _newDir;
                missionNamespace setVariable ["FTCS_Deploy_HQDir", _newDir];

                if (getMarkerType "FTCS_PREVIEW_HQ" != "") then {
                    "FTCS_PREVIEW_HQ" setMarkerDirLocal _newDir;
                };

                if (!isNull (findDisplay 88000)) then {
                    private _disp = findDisplay 88000;
                    private _statusCtrl = _disp displayCtrl 88005;
                    private _pos = missionNamespace getVariable ["FTCS_Deploy_CustomHQPos", []];
                    private _grid = if (count _pos >= 2) then { mapGridPosition _pos } else { "---" };
                    _statusCtrl ctrlSetStructuredText parseText format [
                        "<t color='#00FFCC'>Puesto de Mando HQ Cía:</t> Grid %1<br/><t color='#FFAA00'>Rumbo Táctico:</t> %2° (Ajustado con Clic Izquierdo + Rueda)",
                        _grid,
                        round _newDir
                    ];
                };
            };
            case "FIXED_ARTY": {
                private _curDir = if (FTCS_Deploy_ArtyDir >= 0) then { FTCS_Deploy_ArtyDir } else { missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0] };
                private _newDir = (_curDir + _rotDelta + 360) % 360;
                FTCS_Deploy_ArtyDir = _newDir;
                missionNamespace setVariable ["FTCS_Deploy_ArtyDir", _newDir];
                ["FIXED_ARTY", _newDir] call FTCS_fnc_updateSupportPreviewMarkerDir;
            };
            case "MOBILE_ARMOR": {
                private _curDir = if (FTCS_Deploy_ArmorDir >= 0) then { FTCS_Deploy_ArmorDir } else { missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0] };
                private _newDir = (_curDir + _rotDelta + 360) % 360;
                FTCS_Deploy_ArmorDir = _newDir;
                missionNamespace setVariable ["FTCS_Deploy_ArmorDir", _newDir];
                ["MOBILE_ARMOR", _newDir] call FTCS_fnc_updateSupportPreviewMarkerDir;
            };
            default {
                // "PLATOON" or company infantry deployment area
                private _curDir = missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0];
                private _newDir = (_curDir + _rotDelta + 360) % 360;
                missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _newDir];

                if (!isNil "FTCS_Deploy_SpawnPos") then {
                    [FTCS_Deploy_SpawnPos] call FTCS_fnc_updateDeployPreviewMarker;
                };

                if (!isNull (findDisplay 88000)) then {
                    private _disp = findDisplay 88000;
                    private _statusCtrl = _disp displayCtrl 88005;
                    _statusCtrl ctrlSetStructuredText parseText format [
                        "<t color='#00FFCC'>Área de Despliegue:</t> Grid %1<br/><t color='#FFAA00'>Rumbo Táctico:</t> %2° (Ajustado con Clic Izquierdo + Rueda)",
                        mapGridPosition FTCS_Deploy_SpawnPos,
                        round _newDir
                    ];
                };
            };
        };

        // Guarantee map scale stays locked: cancel zoom in map control
        if (FTCS_Deploy_LockedScale > 0) then {
            private _center = _control ctrlMapScreenToWorld [0.5, 0.5];
            _control ctrlMapAnimAdd [0, FTCS_Deploy_LockedScale, _center];
            ctrlMapAnimCommit _control;
        };

        // Returning true informs UI engine to block native zoom
        true;
    };

    false;
};

FTCS_fnc_onDeployMapClick = {
    params ["_control", "_button", "_xPos", "_yPos"];
    
    // Only handle left clicks (button 0); right click is reserved for rotation hold
    if (_button != 0) exitWith {};

    private _worldPos = _control ctrlMapScreenToWorld [_xPos, _yPos];

    // Check active placement mode across all 4 potential markers
    switch (FTCS_Deploy_TargetMode) do {
        case "COMPANY_HQ": {
            FTCS_Deploy_CustomHQPos = _worldPos;
            missionNamespace setVariable ["FTCS_Deploy_CustomHQPos", _worldPos];

            private _dir = if (FTCS_Deploy_HQDir >= 0) then { FTCS_Deploy_HQDir } else { missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0] };
            FTCS_Deploy_HQDir = _dir;
            missionNamespace setVariable ["FTCS_Deploy_HQDir", _dir];

            if (getMarkerType "FTCS_PREVIEW_HQ" != "") then {
                "FTCS_PREVIEW_HQ" setMarkerPosLocal _worldPos;
                "FTCS_PREVIEW_HQ" setMarkerDirLocal _dir;
            } else {
                private _hqM = createMarkerLocal ["FTCS_PREVIEW_HQ", _worldPos];
                _hqM setMarkerTypeLocal "b_hq";
                _hqM setMarkerColorLocal "ColorOrange";
                _hqM setMarkerDirLocal _dir;
                _hqM setMarkerTextLocal " PUESTO DE MANDO (HQ CÍA)";
            };

            if (!isNull (findDisplay 88000)) then {
                private _disp = findDisplay 88000;
                private _statusCtrl = _disp displayCtrl 88005;
                _statusCtrl ctrlSetStructuredText parseText format [
                    "<t color='#00FFCC'>Puesto de Mando de Compañía Ubicado:</t><br/><t color='#AAAAAA'>Coordenadas:</t> Grid %1 (Rumbo %2°)<br/><t color='#888888'>Mantén Clic Izquierdo + Rueda para orientar el HQ.</t>",
                    mapGridPosition _worldPos,
                    round _dir
                ];
            };
        };

        case "FIXED_ARTY": {
            FTCS_Deploy_CustomArtyPos = _worldPos;
            missionNamespace setVariable ["FTCS_Deploy_CustomArtyPos", _worldPos];

            private _dir = if (FTCS_Deploy_ArtyDir >= 0) then { FTCS_Deploy_ArtyDir } else { missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0] };
            FTCS_Deploy_ArtyDir = _dir;

            // Auto-check fixed artillery checkbox
            if (!isNull (findDisplay 88000)) then {
                private _chk = (findDisplay 88000) displayCtrl 88006;
                _chk cbSetChecked true;
                private _status = (findDisplay 88000) displayCtrl 88007;
                _status ctrlSetStructuredText parseText format [
                    "<t color='#00FF00'>Posición fijada en Grid %1.</t><br/><t color='#FFAA00'>Orientación:</t> %2° (Mantén Clic Derecho + Rueda para rotar)",
                    mapGridPosition _worldPos,
                    round _dir
                ];
            };

            if (getMarkerType "FTCS_PREVIEW_ARTY" != "") then {
                "FTCS_PREVIEW_ARTY" setMarkerPosLocal _worldPos;
                "FTCS_PREVIEW_ARTY" setMarkerDirLocal _dir;
            } else {
                private _m = createMarkerLocal ["FTCS_PREVIEW_ARTY", _worldPos];
                _m setMarkerTypeLocal "b_art";
                _m setMarkerColorLocal "ColorOrange";
                _m setMarkerDirLocal _dir;
                _m setMarkerTextLocal " BATERÍA DE ARTILLERÍA (FIJO)";
            };
        };

        case "MOBILE_ARMOR": {
            FTCS_Deploy_CustomArmorPos = _worldPos;
            missionNamespace setVariable ["FTCS_Deploy_CustomArmorPos", _worldPos];

            private _dir = if (FTCS_Deploy_ArmorDir >= 0) then { FTCS_Deploy_ArmorDir } else { missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0] };
            FTCS_Deploy_ArmorDir = _dir;

            // Auto-check mobile armor checkbox
            if (!isNull (findDisplay 88000)) then {
                private _chk = (findDisplay 88000) displayCtrl 88008;
                _chk cbSetChecked true;
                private _status = (findDisplay 88000) displayCtrl 88009;
                _status ctrlSetStructuredText parseText format [
                    "<t color='#00FF00'>Posición fijada en Grid %1.</t><br/><t color='#FFAA00'>Orientación:</t> %2° (Mantén Clic Derecho + Rueda para rotar)",
                    mapGridPosition _worldPos,
                    round _dir
                ];
            };

            if (getMarkerType "FTCS_PREVIEW_ARMOR" != "") then {
                "FTCS_PREVIEW_ARMOR" setMarkerPosLocal _worldPos;
                "FTCS_PREVIEW_ARMOR" setMarkerDirLocal _dir;
            } else {
                private _m = createMarkerLocal ["FTCS_PREVIEW_ARMOR", _worldPos];
                _m setMarkerTypeLocal "b_armor";
                _m setMarkerColorLocal "ColorOrange";
                _m setMarkerDirLocal _dir;
                _m setMarkerTextLocal " SECCIÓN BLINDADA (MÓVIL)";
            };
        };

        default {
            // "PLATOON" or default infantry force mode
            FTCS_Deploy_SpawnPos = _worldPos;
            FTCS_Deploy_SelectedMarker = "";

            [_worldPos] call FTCS_fnc_updateDeployPreviewMarker;

            if (!isNull (findDisplay 88000)) then {
                private _disp = findDisplay 88000;
                private _statusCtrl = _disp displayCtrl 88005;
                private _areaCombo = _disp displayCtrl 88004;
                
                _statusCtrl ctrlSetStructuredText parseText format [
                    "<t color='#00FFCC'>Punto Seleccionado en Mapa:</t><br/><t color='#AAAAAA'>Coordenadas:</t> Grid %1 (Rumbo %2°)<br/><t color='#888888'>Mantén Clic Derecho + Rueda para rotar la casilla.</t>",
                    mapGridPosition _worldPos,
                    round (missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0])
                ];

                private _count = lbSize _areaCombo;
                if (_count > 0) then {
                    _areaCombo lbSetCurSel (_count - 1);
                };
            };
        };
    };
};

FTCS_fnc_onDeployAreaChanged = {
    params ["_control", "_selectedIndex"];
    
    private _markerName = _control lbData _selectedIndex;
    if (_markerName != "") then {
        private _markerPos = getMarkerPos _markerName;
        private _markerDir = markerDir _markerName;
        FTCS_Deploy_SpawnPos = _markerPos;
        FTCS_Deploy_SelectedMarker = _markerName;

        // Adopt advance direction from the editor marker orientation if it has one
        if (_markerDir != 0) then {
            missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _markerDir];
        };

        [_markerPos] call FTCS_fnc_updateDeployPreviewMarker;

        if (!isNull (findDisplay 88000)) then {
            private _disp = findDisplay 88000;
            private _map = _disp displayCtrl 88001;
            private _status = _disp displayCtrl 88005;

            _map ctrlMapAnimAdd [0.4, 0.08, _markerPos];
            ctrlMapAnimCommit _map;

            _status ctrlSetStructuredText parseText format [
                "<t color='#00FFCC'>Zona Editor Detectada:</t> '%1'<br/><t color='#AAAAAA'>Coordenadas:</t> Grid %2<br/><t color='#888888'>Despliegue automático en la marca del editor (Rumbo %3°).</t>",
                _markerName,
                mapGridPosition _markerPos,
                round (missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0])
            ];
        };
    };
};

FTCS_fnc_onDeployEchelonChanged = {
    params ["_control", "_selectedIndex"];
    private _echelon = _control lbData _selectedIndex;

    // Dynamically resize preview rectangle according to the newly selected echelon
    if (!isNil "FTCS_Deploy_SpawnPos") then {
        [FTCS_Deploy_SpawnPos] call FTCS_fnc_updateDeployPreviewMarker;
    };

    if (!isNull (findDisplay 88000)) then {
        private _disp = findDisplay 88000;
        private _infoCtrl = _disp displayCtrl 88013;
        private _btnPlt = _disp displayCtrl 88020;
        private _btnHQ  = _disp displayCtrl 88021;

        if (_echelon == "PLATOON") then {
            // Show Option B target buttons when in Platoon mode
            _btnPlt ctrlShow true;
            _btnHQ  ctrlShow true;

            private _hqMarkerMsg = if (!isNil "FTCS_Deploy_CompanyHQMarker" && {FTCS_Deploy_CompanyHQMarker != ""}) then {
                format ["<br/><t color='#00FF00'>Marcador de Company HQ detectado ('%1') en Grid %2. El HQ de Compañía se desplegará en dicha posición.</t>", FTCS_Deploy_CompanyHQMarker, mapGridPosition (getMarkerPos FTCS_Deploy_CompanyHQMarker)]
            } else {
                "<br/><t color='#AAAAAA'>HQ de Compañía desplegable con el botón '[• UBICAR HQ CIA]' o auto a 150m detrás.</t>"
            };
            _infoCtrl ctrlSetStructuredText parseText format ["<t color='#00BFFF'>Rol: Teniente (1er Pelotón)</t><br/><t color='#AAAAAA'>Comandas el 1er Pelotón táctico.</t>%1", _hqMarkerMsg];
        } else {
            // Hide Option B target buttons when in full Company mode
            _btnPlt ctrlShow false;
            _btnHQ  ctrlShow false;
            ['PLATOON'] call FTCS_fnc_onDeployTargetModeChanged;

            _infoCtrl ctrlSetStructuredText parseText "<t color='#00FFCC'>Rol: Capitán (Compañía Completa)</t><br/><t color='#AAAAAA'>Comandas la Compañía completa con todos sus pelotones tácticos y secciones de apoyo orgánicas.</t>";
        };
    };
};

// Dynamic population of support unit dropdowns filtered strictly by doctrine faction and military side
FTCS_fnc_populateSupportCombos = {
    params [["_doctrineKey", ""]];

    if (isNull (findDisplay 88000)) exitWith {};
    private _disp = findDisplay 88000;
    private _cFixed  = _disp displayCtrl 88024;
    private _cMobile = _disp displayCtrl 88025;

    lbClear _cFixed;
    lbClear _cMobile;

    private _docData = [_doctrineKey] call FTCS_fnc_loadDoctrineData;
    private _docSide = _docData getOrDefault ["side", sideUnknown];
    if !(_docSide in [west, east, resistance, independent]) then {
        _docSide = side group player;
    };
    if (_docSide == civilian || _docSide == sideUnknown) then { _docSide = west; };

    private _docId = _docData getOrDefault ["doctrineID", ""];
    private _docSearchStr = format ["%1 %2", toUpper _doctrineKey, toUpper _docId];

    // Identify authentic national / faction family from doctrine definition
    private _isGerman = (_docSearchStr find "GERMAN" >= 0) || (_docSearchStr find "WEHRMACHT" >= 0) || (_docSearchStr find "STURM" >= 0) || (_docSearchStr find "PANZER" >= 0) || (_docSearchStr find "AXIS" >= 0);
    private _isUS = (_docSearchStr find "US_" >= 0) || (_docSearchStr find "PARA" >= 0) || (_docSearchStr find "101" >= 0) || (_docSearchStr find "AIRBORNE" >= 0) || (_docSearchStr find "RANGER" >= 0) || (_docSearchStr find "ARMY" >= 0) || (_docSearchStr find "BRITISH" >= 0) || (_docSearchStr find "ALLIED" >= 0);
    private _isSoviet = (_docSearchStr find "SOV" >= 0) || (_docSearchStr find "RUS" >= 0) || (_docSearchStr find "RED" >= 0) || (_docSearchStr find "USSR" >= 0);
    private _isJapanese = (_docSearchStr find "JAP" >= 0) || (_docSearchStr find "IJA" >= 0);

    private _regPath = "Doctrines\Data\Support_Registry.sqf";
    private _regList = if (fileExists _regPath) then {
        call compile preprocessFileLineNumbers _regPath
    } else {
        []
    };

    {
        private _entry = _x;
        private _cat   = _entry getOrDefault ["category", ""];
        private _name  = _entry getOrDefault ["name", "Support Element"];
        private _file  = _entry getOrDefault ["file", ""];
        private _sides = _entry getOrDefault ["sides", []];
        private _facs  = _entry getOrDefault ["factions", []];

        private _entryIsGerman   = ("GERMAN" in _facs) || ("WEHRMACHT" in _facs);
        private _entryIsUS       = ("US" in _facs) || ("ALLIED" in _facs);
        private _entryIsSoviet   = ("SOVIET" in _facs) || ("RED_ARMY" in _facs);
        private _entryIsJapanese = ("JAPAN" in _facs) || ("IJA" in _facs);

        private _matchesFaction = false;
        if (_isGerman && _entryIsGerman) then { _matchesFaction = true; };
        if (_isUS && _entryIsUS) then { _matchesFaction = true; };
        if (_isSoviet && _entryIsSoviet) then { _matchesFaction = true; };
        if (_isJapanese && _entryIsJapanese) then { _matchesFaction = true; };

        // Fallback to strict side matching only if no explicit historical faction was tagged
        if (!_isGerman && !_isUS && !_isSoviet && !_isJapanese) then {
            _matchesFaction = (_docSide in _sides);
        };

        if (_matchesFaction) then {
            if (_cat == "FIXED") then {
                private _idx = _cFixed lbAdd _name;
                _cFixed lbSetData [_idx, _file];
            };
            if (_cat == "MOBILE") then {
                private _idx = _cMobile lbAdd _name;
                _cMobile lbSetData [_idx, _file];
            };
        };
    } forEach _regList;

    // Safety fallback only if no items matched
    if (lbSize _cFixed == 0) then {
        private _defFile = if (_isGerman) then { "Support_Artillery_German" } else { "Support_Artillery" };
        private _defLabel = if (_isGerman) then { "Batería de Artillería (8cm GrW 34 Mortars)" } else { "Artillería 105mm (SPE M3 Howitzers)" };
        private _idx = _cFixed lbAdd _defLabel;
        _cFixed lbSetData [_idx, _defFile];
    };
    if (lbSize _cMobile == 0) then {
        private _defFile = if (_isGerman) then { "Support_Armor_German" } else { "Support_Armor" };
        private _defLabel = if (_isGerman) then { "Sección Blindada / Cañones de Asalto (StuG III)" } else { "Sección Blindada (2x M4A1 Sherman)" };
        private _idx = _cMobile lbAdd _defLabel;
        _cMobile lbSetData [_idx, _defFile];
    };

    _cFixed lbSetCurSel 0;
    _cMobile lbSetCurSel 0;

    FTCS_Deploy_SelectedFixedFile  = _cFixed lbData 0;
    FTCS_Deploy_SelectedMobileFile = _cMobile lbData 0;
};

FTCS_fnc_onDeployDoctrineChanged = {
    params ["_control", "_selectedIndex"];
    private _docId = _control lbData _selectedIndex;

    // Repopulate support combos according to the selected doctrine's faction & side
    [_docId] call FTCS_fnc_populateSupportCombos;

    // Dynamically recalculate bounding box dimensions and center offset for the newly selected doctrine
    if (!isNil "FTCS_Deploy_SpawnPos") then {
        [FTCS_Deploy_SpawnPos] call FTCS_fnc_updateDeployPreviewMarker;
    };

    if (!isNull (findDisplay 88000)) then {
        private _infoCtrl = (findDisplay 88000) displayCtrl 88012;
        private _infoText = switch (_docId) do {
            case "101_US_Para_Company_V2_1";
            case "101_US_PARA_COMPANY": { "<t color='#00FFCC'>101st Airborne Division (Easy Co.)</t><br/><t color='#AAAAAA'>Parachute Infantry Company: 3 Rifle Platoons + Mortar Section + Company HQ (WWII TO&E).</t>" };
            case "SPE_German_Sturmgrenadier_Company";
            case "GERMAN_WW2":          { "<t color='#00FFCC'>Wehrmacht Sturmgrenadier-Kompanie (SPE)</t><br/><t color='#AAAAAA'>German assault force: I. Zug (Sturm w/ StG44), II/III. Züge (Grenadier w/ Kar98k), MG42 and 8cm Mortars.</t>" };
            case "SPE_US_Army_Rifle_Company";
            case "SPE_US_ARMY_RIFLE_COMPANY";
            case "US_ARMY":             { "<t color='#00FFCC'>U.S. Army Rifle Company (TO&E 7-17)</t><br/><t color='#AAAAAA'>Standard Line Infantry: 3 Rifle Platoons (Able/Baker/Charlie teams) + 1 Weapons Platoon (60mm Mortars & M1919 LMGs) + Company HQ.</t>" };
            case "US_RANGERS_WW2":      { "<t color='#00FFCC'>2nd Ranger Battalion</t><br/><t color='#AAAAAA'>Specialized light assault infantry for shock and infiltration operations.</t>" };
            case "GERMAN_PANZER_GRENADIER": { "<t color='#00FFCC'>Panzergrenadier-Kompanie (Wehrmacht)</t><br/><t color='#AAAAAA'>Mechanized armored force according to KStN 1114b with Sd.Kfz 251 halftracks and heavy support.</t>" };
            case "BRITISH_AIRBORNE":    { "<t color='#00FFCC'>British Parachute Company</t><br/><t color='#AAAAAA'>Elite British paratroopers with light weaponry and high tactical mobility.</t>" };
            default                     { "<t color='#00FFCC'>Selected Military Doctrine</t><br/><t color='#AAAAAA'>Tactical force template for combat deployment.</t>" };
        };
        _infoCtrl ctrlSetStructuredText parseText _infoText;
    };
};

FTCS_fnc_onDeployFixedComboChanged = {
    params ["_control", "_selectedIndex"];
    FTCS_Deploy_SelectedFixedFile = _control lbData _selectedIndex;
    missionNamespace setVariable ["FTCS_Deploy_SelectedFixedFile", FTCS_Deploy_SelectedFixedFile];
};

FTCS_fnc_onDeployMobileComboChanged = {
    params ["_control", "_selectedIndex"];
    FTCS_Deploy_SelectedMobileFile = _control lbData _selectedIndex;
    missionNamespace setVariable ["FTCS_Deploy_SelectedMobileFile", FTCS_Deploy_SelectedMobileFile];
};

FTCS_fnc_onDeployFixedCheckChanged = {
    params ["_control", "_checked"];
    if (_checked == 1) then {
        // Switch to interactive placement if no custom coordinate was picked yet
        if (count FTCS_Deploy_CustomArtyPos == 0 && {isNil "FTCS_Deploy_ArtilleryMarker" || {FTCS_Deploy_ArtilleryMarker == ""}}) then {
            ['FIXED_ARTY'] call FTCS_fnc_onDeployTargetModeChanged;
        };
    } else {
        // Unchecked: clean preview marker
        FTCS_Deploy_CustomArtyPos = [];
        missionNamespace setVariable ["FTCS_Deploy_CustomArtyPos", []];
        if (getMarkerType "FTCS_PREVIEW_ARTY" != "") then {
            deleteMarkerLocal "FTCS_PREVIEW_ARTY";
        };
    };
};

FTCS_fnc_onDeployMobileCheckChanged = {
    params ["_control", "_checked"];
    if (_checked == 1) then {
        // Switch to interactive placement if no custom coordinate was picked yet
        if (count FTCS_Deploy_CustomArmorPos == 0) then {
            ['MOBILE_ARMOR'] call FTCS_fnc_onDeployTargetModeChanged;
        };
    } else {
        // Unchecked: clean preview marker
        FTCS_Deploy_CustomArmorPos = [];
        missionNamespace setVariable ["FTCS_Deploy_CustomArmorPos", []];
        if (getMarkerType "FTCS_PREVIEW_ARMOR" != "") then {
            deleteMarkerLocal "FTCS_PREVIEW_ARMOR";
        };
    };
};

// -----------------------------------------------------------------------------
// 2. Populate Doctrine Options (Dynamic: built from Doctrines\Data\ registry)
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

    // Adopt marker orientation if defined by the editor
    private _fDir = markerDir _firstMarker;
    if (_fDir != 0) then {
        missionNamespace setVariable ["FTCS_Platoon_Advance_Direction", _fDir];
    };

    _ctrlMap ctrlMapAnimAdd [0, 0.08, FTCS_Deploy_SpawnPos];
    ctrlMapAnimCommit _ctrlMap;

    _ctrlAreaStatus ctrlSetStructuredText parseText format [
        "<t color='#00FFCC'>Zona Editor Detectada:</t> '%1'<br/><t color='#AAAAAA'>Coordenadas:</t> Grid %2<br/><t color='#888888'>Despliegue automático en el área marcada por el editor (Rumbo %3°).</t>",
        _firstMarker,
        mapGridPosition FTCS_Deploy_SpawnPos,
        round (missionNamespace getVariable ["FTCS_Platoon_Advance_Direction", 0])
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

// Create or update local preview markers on map (center point, directional arrow, and tactical bounding box)
[FTCS_Deploy_SpawnPos] call FTCS_fnc_updateDeployPreviewMarker;

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
    _ctrlFixedStatus ctrlSetStructuredText parseText "<t color='#FFD700'>Sin marcador previo 'ftcs_artillery'.</t><br/><t color='#888888'>Usa '[ UBICAR ]' o clic en mapa para posicionar la batería.</t>";
    _ctrlFixedCheck cbSetChecked false;
};

// -----------------------------------------------------------------------------
// 6. Mobile Support Status
// -----------------------------------------------------------------------------
_ctrlMobileStatus ctrlSetStructuredText parseText "<t color='#00FFCC'>Unidad Móvil Dinámica.</t><br/><t color='#AAAAAA'>Despliegue lateral automático o posición y rumbo personalizado con '[ UBICAR ]'.</t>";
_ctrlMobileCheck cbSetChecked false;

// -----------------------------------------------------------------------------
// 7. Bind Display-Level Mouse Events for Total Zoom Interception
//    In Arma 3, display-level MouseZChanged handler guarantees return true stops
//    engine-level map zoom from triggering when LMB is held down during rotation.
// -----------------------------------------------------------------------------
_display displayAddEventHandler ["MouseButtonDown", {
    params ["_disp", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
    if (_button == 0) then {
        FTCS_Deploy_LMBHeld = true;
        private _map = _disp displayCtrl 88001;
        if (!isNull _map) then {
            FTCS_Deploy_LockedScale = ctrlMapScale _map;
        };
    };
    false;
}];

_display displayAddEventHandler ["MouseButtonUp", {
    params ["_disp", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
    if (_button == 0) then {
        FTCS_Deploy_LMBHeld = false;
        FTCS_Deploy_LockedScale = -1;
    };
    false;
}];

_display displayAddEventHandler ["MouseZChanged", {
    params ["_disp", "_scrollDelta"];
    if (missionNamespace getVariable ["FTCS_Deploy_LMBHeld", false]) then {
        private _map = _disp displayCtrl 88001;
        if (!isNull _map) then {
            [_map, _scrollDelta] call FTCS_fnc_onDeployMapMouseZChanged;
        };
        true;
    } else {
        false;
    };
}];

true;
