/*
    ================================================================================
    FTCS (FIRST-PERSON TACTICAL COMMAND) - OPERATIONAL DEPLOYMENT DIALOG
    Module: UI / Spawning
    Description: Interactive Map Deployment Interface allowing dynamic selection of 
                 military doctrine, command echelon (Platoon vs Company), editor 
                 designated deployment zones, and attached support assets (fixed/mobile).
    Compatibility: Arma 3 (SQF) | Designed for Enfusion Engine (Arma 4)
    ================================================================================
*/

class FTCS_DeployDialog
{
    idd = 88000;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "_this call FTCS_fnc_initDeployMenu;";

    class ControlsBackground
    {
        // Fullscreen interactive map control
        class FTCS_Map: RscMapControl
        {
            idc = 88001;
            x = "safeZoneX";
            y = "safeZoneY";
            w = "safeZoneW";
            h = "safeZoneH";
            maxSatelliteAlpha = 0.75;
            alphaFadeStartScale = 1.15;
            alphaFadeEndScale = 1.15;
            showCountourInterval = 1;
            onMouseButtonClick = "_this call FTCS_fnc_onDeployMapClick;";
        };

        // Tactical Command Panel Background - High Transparency Glassmorphic Theme
        // Reduced to ~36% opacity (double transparency) so the 3D world / satellite map dominates
        class FTCS_Panel_Background: RscText
        {
            idc = -1;
            x = "safeZoneX + 0.02 * safeZoneW";
            y = "safeZoneY + 0.03 * safeZoneH";
            w = "0.32 * safeZoneW";
            h = "0.94 * safeZoneH";
            colorBackground[] = {0.0, 0.04, 0.07, 0.36};
        };

        class FTCS_Panel_Border: RscText
        {
            idc = -1;
            x = "safeZoneX + 0.02 * safeZoneW";
            y = "safeZoneY + 0.03 * safeZoneH";
            w = "0.32 * safeZoneW";
            h = "0.003 * safeZoneH";
            colorBackground[] = {1.0, 0.55, 0.0, 0.95};
        };

        class FTCS_Header_Background: RscText
        {
            idc = -1;
            x = "safeZoneX + 0.02 * safeZoneW";
            y = "safeZoneY + 0.033 * safeZoneH";
            w = "0.32 * safeZoneW";
            h = "0.055 * safeZoneH";
            colorBackground[] = {0.0, 0.08, 0.12, 0.40};
        };
    };

    class Controls
    {
        class FTCS_Title: RscText
        {
            idc = -1;
            text = "FTCS - DESPLIEGUE OPERACIONAL";
            font = "PuristaBold";
            sizeEx = "0.035 * safeZoneH";
            colorText[] = {0.0, 1.0, 0.8, 1.0};
            x = "safeZoneX + 0.025 * safeZoneW";
            y = "safeZoneY + 0.036 * safeZoneH";
            w = "0.31 * safeZoneW";
            h = "0.030 * safeZoneH";
        };

        class FTCS_Subtitle: RscText
        {
            idc = -1;
            text = "Mando Táctico, Doctrina Militar y Fuerzas Acopladas";
            font = "PuristaMedium";
            sizeEx = "0.018 * safeZoneH";
            colorText[] = {0.6, 0.75, 0.8, 0.85};
            x = "safeZoneX + 0.025 * safeZoneW";
            y = "safeZoneY + 0.065 * safeZoneH";
            w = "0.31 * safeZoneW";
            h = "0.020 * safeZoneH";
        };

        // ---------------------------------------------------------------------
        // 1. DOCTRINE SELECTION
        // ---------------------------------------------------------------------
        class FTCS_Label_Doctrine: RscText
        {
            idc = -1;
            text = "1. DOCTRINA MILITAR:";
            font = "PuristaBold";
            sizeEx = "0.020 * safeZoneH";
            colorText[] = {0.0, 0.85, 1.0, 1.0};
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.105 * safeZoneH";
            w = "0.30 * safeZoneW";
            h = "0.022 * safeZoneH";
        };

        class FTCS_Combo_Doctrine: RscCombo
        {
            idc = 88002;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.130 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.032 * safeZoneH";
            colorSelectBackground[] = {1.0, 0.55, 0.0, 0.85};
            colorSelect[] = {1.0, 1.0, 1.0, 1.0};
            onLBSelChanged = "_this call FTCS_fnc_onDeployDoctrineChanged;";
        };

        class FTCS_Text_Doctrine_Info: RscStructuredText
        {
            idc = 88012;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.168 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.055 * safeZoneH";
            colorBackground[] = {0.0, 0.04, 0.08, 0.25};
        };

        // ---------------------------------------------------------------------
        // 2. COMMAND ECHELON SELECTION
        // ---------------------------------------------------------------------
        class FTCS_Label_Echelon: RscText
        {
            idc = -1;
            text = "2. ESCALÓN DE MANDO A COMANDAR:";
            font = "PuristaBold";
            sizeEx = "0.020 * safeZoneH";
            colorText[] = {0.0, 0.85, 1.0, 1.0};
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.235 * safeZoneH";
            w = "0.30 * safeZoneW";
            h = "0.022 * safeZoneH";
        };

        class FTCS_Combo_Echelon: RscCombo
        {
            idc = 88003;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.260 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.032 * safeZoneH";
            colorSelectBackground[] = {1.0, 0.55, 0.0, 0.85};
            colorSelect[] = {1.0, 1.0, 1.0, 1.0};
            onLBSelChanged = "_this call FTCS_fnc_onDeployEchelonChanged;";
        };

        class FTCS_Text_Echelon_Info: RscStructuredText
        {
            idc = 88013;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.298 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.060 * safeZoneH";
            colorBackground[] = {0.0, 0.04, 0.08, 0.25};
        };

        // ---------------------------------------------------------------------
        // 3. DEPLOYMENT ZONE SELECTION
        // ---------------------------------------------------------------------
        class FTCS_Label_Area: RscText
        {
            idc = -1;
            text = "3. ÁREA DE DESPLIEGUE EN EL MAPA:";
            font = "PuristaBold";
            sizeEx = "0.020 * safeZoneH";
            colorText[] = {0.0, 0.85, 1.0, 1.0};
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.370 * safeZoneH";
            w = "0.30 * safeZoneW";
            h = "0.022 * safeZoneH";
        };

        class FTCS_Combo_Area: RscCombo
        {
            idc = 88004;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.395 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.032 * safeZoneH";
            colorSelectBackground[] = {1.0, 0.55, 0.0, 0.85};
            colorSelect[] = {1.0, 1.0, 1.0, 1.0};
            onLBSelChanged = "_this call FTCS_fnc_onDeployAreaChanged;";
        };

        class FTCS_Text_Area_Status: RscStructuredText
        {
            idc = 88005;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.433 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.070 * safeZoneH";
            colorBackground[] = {0.0, 0.04, 0.08, 0.25};
        };

        // ---------------------------------------------------------------------
        // 4. ATTACHED SUPPORT UNITS
        // ---------------------------------------------------------------------
        class FTCS_Label_Support: RscText
        {
            idc = -1;
            text = "4. UNIDADES ACOPLADAS DE APOYO:";
            font = "PuristaBold";
            sizeEx = "0.020 * safeZoneH";
            colorText[] = {0.0, 0.85, 1.0, 1.0};
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.515 * safeZoneH";
            w = "0.30 * safeZoneW";
            h = "0.022 * safeZoneH";
        };

        // Fixed Support (Artillery)
        class FTCS_Check_FixedSupport: RscCheckBox
        {
            idc = 88006;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.545 * safeZoneH";
            w = "0.016 * safeZoneW";
            h = "0.028 * safeZoneH";
            onCheckedChanged = "_this call FTCS_fnc_onDeployFixedCheckChanged;";
        };

        class FTCS_Label_FixedSupport: RscText
        {
            idc = -1;
            text = "Apoyo Fijo: Artillería 105mm (SPE Howitzers)";
            font = "PuristaMedium";
            sizeEx = "0.018 * safeZoneH";
            colorText[] = {0.95, 0.95, 0.95, 1.0};
            x = "safeZoneX + 0.048 * safeZoneW";
            y = "safeZoneY + 0.545 * safeZoneH";
            w = "0.280 * safeZoneW";
            h = "0.028 * safeZoneH";
        };

        class FTCS_Text_FixedSupport_Status: RscStructuredText
        {
            idc = 88007;
            x = "safeZoneX + 0.048 * safeZoneW";
            y = "safeZoneY + 0.575 * safeZoneH";
            w = "0.280 * safeZoneW";
            h = "0.055 * safeZoneH";
            colorBackground[] = {0.04, 0.07, 0.10, 0.40};
        };

        // Mobile Support (Armor)
        class FTCS_Check_MobileSupport: RscCheckBox
        {
            idc = 88008;
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.640 * safeZoneH";
            w = "0.016 * safeZoneW";
            h = "0.028 * safeZoneH";
        };

        class FTCS_Label_MobileSupport: RscText
        {
            idc = -1;
            text = "Apoyo Móvil: Sección Blindada (2x M4 Sherman)";
            font = "PuristaMedium";
            sizeEx = "0.018 * safeZoneH";
            colorText[] = {0.95, 0.95, 0.95, 1.0};
            x = "safeZoneX + 0.048 * safeZoneW";
            y = "safeZoneY + 0.640 * safeZoneH";
            w = "0.280 * safeZoneW";
            h = "0.028 * safeZoneH";
        };

        class FTCS_Text_MobileSupport_Status: RscStructuredText
        {
            idc = 88009;
            x = "safeZoneX + 0.048 * safeZoneW";
            y = "safeZoneY + 0.670 * safeZoneH";
            w = "0.280 * safeZoneW";
            h = "0.055 * safeZoneH";
            colorBackground[] = {0.04, 0.07, 0.10, 0.40};
        };

        // ---------------------------------------------------------------------
        // 5. ACTION BUTTONS
        // ---------------------------------------------------------------------
        class FTCS_Btn_Deploy: RscButtonMenu
        {
            idc = 88010;
            text = "[ CONFIRMAR Y DESPLEGAR FUERZA ]";
            font = "PuristaBold";
            sizeEx = "0.020 * safeZoneH";
            colorBackground[] = {0.0, 0.45, 0.40, 0.85};
            colorBackground2[] = {0.0, 0.70, 0.55, 0.95};
            colorFocused[] = {0.0, 0.60, 0.50, 0.90};
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.850 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.048 * safeZoneH";
            action = "[] call FTCS_fnc_executeDeployment;";
            onButtonClick = "[] call FTCS_fnc_executeDeployment;";
        };

        class FTCS_Btn_Cancel: RscButtonMenuCancel
        {
            idc = 88011;
            text = "[ CANCELAR ]";
            font = "PuristaMedium";
            sizeEx = "0.018 * safeZoneH";
            colorBackground[] = {0.25, 0.08, 0.08, 0.70};
            colorBackground2[] = {0.50, 0.12, 0.12, 0.85};
            x = "safeZoneX + 0.028 * safeZoneW";
            y = "safeZoneY + 0.910 * safeZoneH";
            w = "0.304 * safeZoneW";
            h = "0.038 * safeZoneH";
            action = "closeDialog 2;";
            onButtonClick = "closeDialog 2;";
        };
    };
};
