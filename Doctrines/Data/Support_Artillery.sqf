/*
    ================================================================================
    FTCS SUPPORT DATA TEMPLATE: Support_Artillery
    Category: Fixed / Static Support (Artillery & Mortars)
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

createHashMapFromArray [
    ["supportID", "SUPPORT_ARTILLERY_US"],
    ["name", "105mm Artillery Battery (SPE M3 Howitzers)"],
    ["isStatic", true],
    ["requiredMods", ["SPE"]],
    ["requiredMarkerTypes", ["ftcs_artillery", "artillery_pos", "ftcs_support_static", "artillery", "arty"]],
    ["entities", [
        // [className, [offsetX, offsetY, offsetZ], relDir, varName, groupVar, rank, isVehicle]
        ["SPE_105mm_M3", [-8, 0, 0], 0, "SUPPORT_ARTY_GUN_1", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["SPE_US_Guncrew_Sergeant", [-8, -2.5, 0], 0, "SUPPORT_ARTY_SGT_1", "SUPPORT_ARTILLERY_1", "SERGEANT", false],
        ["SPE_US_Guncrew", [-6, -2.5, 0], 0, "SUPPORT_ARTY_CREW_1", "SUPPORT_ARTILLERY_1", "PRIVATE", false],
        ["SPE_US_Guncrew", [-10, -2.5, 0], 0, "SUPPORT_ARTY_CREW_2", "SUPPORT_ARTILLERY_1", "PRIVATE", false],

        ["SPE_105mm_M3", [8, 0, 0], 0, "SUPPORT_ARTY_GUN_2", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["SPE_US_Guncrew_Sergeant", [8, -2.5, 0], 0, "SUPPORT_ARTY_SGT_2", "SUPPORT_ARTILLERY_1", "CORPORAL", false],
        ["SPE_US_Guncrew", [6, -2.5, 0], 0, "SUPPORT_ARTY_CREW_3", "SUPPORT_ARTILLERY_1", "PRIVATE", false],
        ["SPE_US_Guncrew", [10, -2.5, 0], 0, "SUPPORT_ARTY_CREW_4", "SUPPORT_ARTILLERY_1", "PRIVATE", false],

        ["SPE_CCKW_353", [0, -12, 0], 0, "SUPPORT_ARTY_TRUCK_1", "SUPPORT_ARTILLERY_1", "PRIVATE", true]
    ]],
    ["fallbackEntities", [
        ["B_Mortar_01_F", [-6, 0, 0], 0, "SUPPORT_ARTY_GUN_1", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["B_Support_Mort_F", [-6, -2, 0], 0, "SUPPORT_ARTY_SGT_1", "SUPPORT_ARTILLERY_1", "SERGEANT", false],
        ["B_Mortar_01_F", [6, 0, 0], 0, "SUPPORT_ARTY_GUN_2", "SUPPORT_ARTILLERY_1", "PRIVATE", true],
        ["B_Support_Mort_F", [6, -2, 0], 0, "SUPPORT_ARTY_CREW_1", "SUPPORT_ARTILLERY_1", "PRIVATE", false]
    ]]
];
