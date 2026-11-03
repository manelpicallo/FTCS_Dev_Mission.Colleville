/*
    ================================================================================
    File: fn_deployPreviewMarkerUpdate.sqf
    Module: Spawning
    Author: FTCS Team
    Description: Calculates the spatial bounding box for the active military doctrine 
                 and command echelon, applies 2D planar rotation, and updates preview
                 map markers (anchor start, directional arrow, and boundary rectangle).
                 Extracted cleanly from fn_initDeployMenu.sqf per Rule 1 (SRP).
    Language: Strictly English (Rule 7)
    ================================================================================
*/

params [["_pos", missionNamespace getVariable ["FTCS_Deploy_SpawnPos", [0, 0, 0]]]];

if (count _pos < 2) exitWith {};

private _echelon = if (!isNull (findDisplay 88000)) then {
    private _ctrlEch = (findDisplay 88000) displayCtrl 88003;
    _ctrlEch lbData (lbCurSel _ctrlEch)
} else {
    "COMPANY"
};

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
    _m setMarkerTextLocal " DEPLOYMENT ANCHOR";
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
        _hqM setMarkerTextLocal " COMPANY HQ POST";
    };
} else {
    if (getMarkerType "FTCS_PREVIEW_HQ" != "") then {
        deleteMarkerLocal "FTCS_PREVIEW_HQ";
    };
};
