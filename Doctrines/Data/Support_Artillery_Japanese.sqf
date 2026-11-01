/*
    ================================================================================
    FTCS SUPPORT DATA TEMPLATE: Support_Artillery_Japanese
    Category: Fixed / Static Support (IJA Artillery & Heavy Mortars)
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

createHashMapFromArray [
    ["supportID", "SUPPORT_ARTILLERY_IJA"],
    ["name", "Batería de Artillería IJA (Tipo 97 Mortero / Cañón de Montaña)"],
    ["isStatic", true],
    ["requiredMods", ["fow"]],
    ["requiredMarkerTypes", ["ftcs_artillery", "artillery_pos", "ftcs_support_static", "artillery", "arty"]],
    ["entities", [
        // [className, [offsetX, offsetY, offsetZ], relDir, varName, groupVar, rank, isVehicle]
        ["fow_w_type97_mortar", [-8, 0, 0], 0, "SUPPORT_ARTY_GUN_1", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["fow_s_ija_nco", [-8, -2.5, 0], 0, "SUPPORT_ARTY_SGT_1", "SUPPORT_ARTILLERY_1", "SERGEANT", false],
        ["fow_s_ija_rifleman", [-6, -2.5, 0], 0, "SUPPORT_ARTY_CREW_1", "SUPPORT_ARTILLERY_1", "PRIVATE", false],
        ["fow_s_ija_rifleman", [-10, -2.5, 0], 0, "SUPPORT_ARTY_CREW_2", "SUPPORT_ARTILLERY_1", "PRIVATE", false],

        ["fow_w_type97_mortar", [8, 0, 0], 0, "SUPPORT_ARTY_GUN_2", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["fow_s_ija_nco", [8, -2.5, 0], 0, "SUPPORT_ARTY_SGT_2", "SUPPORT_ARTILLERY_1", "CORPORAL", false],
        ["fow_s_ija_rifleman", [6, -2.5, 0], 0, "SUPPORT_ARTY_CREW_3", "SUPPORT_ARTILLERY_1", "PRIVATE", false],
        ["fow_s_ija_rifleman", [10, -2.5, 0], 0, "SUPPORT_ARTY_CREW_4", "SUPPORT_ARTILLERY_1", "PRIVATE", false]
    ]],
    ["fallbackEntities", [
        ["I_Mortar_01_F", [-6, 0, 0], 0, "SUPPORT_ARTY_GUN_1", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["I_Support_Mort_F", [-6, -2, 0], 0, "SUPPORT_ARTY_SGT_1", "SUPPORT_ARTILLERY_1", "SERGEANT", false],
        ["I_Mortar_01_F", [6, 0, 0], 0, "SUPPORT_ARTY_GUN_2", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["I_Support_Mort_F", [6, -2, 0], 0, "SUPPORT_ARTY_CREW_1", "SUPPORT_ARTILLERY_1", "PRIVATE", false]
    ]]
];
