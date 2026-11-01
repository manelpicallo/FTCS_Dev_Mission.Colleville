/*
    ================================================================================
    FTCS SUPPORT DATA TEMPLATE: Support_Artillery_Soviet
    Category: Fixed / Static Support (Soviet Mortars & Artillery)
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

createHashMapFromArray [
    ["supportID", "SUPPORT_ARTILLERY_SOV"],
    ["name", "Batería de Artillería / Morteros Pesados (120mm / 82mm)"],
    ["isStatic", true],
    ["requiredMods", ["LIB"]],
    ["requiredMarkerTypes", ["ftcs_artillery", "artillery_pos", "ftcs_support_static", "artillery", "arty"]],
    ["entities", [
        // [className, [offsetX, offsetY, offsetZ], relDir, varName, groupVar, rank, isVehicle]
        ["LIB_M1938", [-8, 0, 0], 0, "SUPPORT_ARTY_GUN_1", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["LIB_SOV_sergeant", [-8, -2.5, 0], 0, "SUPPORT_ARTY_SGT_1", "SUPPORT_ARTILLERY_1", "SERGEANT", false],
        ["LIB_SOV_rifleman", [-6, -2.5, 0], 0, "SUPPORT_ARTY_CREW_1", "SUPPORT_ARTILLERY_1", "PRIVATE", false],
        ["LIB_SOV_rifleman", [-10, -2.5, 0], 0, "SUPPORT_ARTY_CREW_2", "SUPPORT_ARTILLERY_1", "PRIVATE", false],

        ["LIB_M1938", [8, 0, 0], 0, "SUPPORT_ARTY_GUN_2", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["LIB_SOV_sergeant", [8, -2.5, 0], 0, "SUPPORT_ARTY_SGT_2", "SUPPORT_ARTILLERY_1", "CORPORAL", false],
        ["LIB_SOV_rifleman", [6, -2.5, 0], 0, "SUPPORT_ARTY_CREW_3", "SUPPORT_ARTILLERY_1", "PRIVATE", false],
        ["LIB_SOV_rifleman", [10, -2.5, 0], 0, "SUPPORT_ARTY_CREW_4", "SUPPORT_ARTILLERY_1", "PRIVATE", false]
    ]],
    ["fallbackEntities", [
        ["O_Mortar_01_F", [-6, 0, 0], 0, "SUPPORT_ARTY_GUN_1", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["O_Support_Mort_F", [-6, -2, 0], 0, "SUPPORT_ARTY_SGT_1", "SUPPORT_ARTILLERY_1", "SERGEANT", false],
        ["O_Mortar_01_F", [6, 0, 0], 0, "SUPPORT_ARTY_GUN_2", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["O_Support_Mort_F", [6, -2, 0], 0, "SUPPORT_ARTY_CREW_1", "SUPPORT_ARTILLERY_1", "PRIVATE", false]
    ]]
];
