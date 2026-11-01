/*
    ================================================================================
    FTCS SUPPORT DATA TEMPLATE: Support_Armor_Japanese
    Category: Mobile Support (IJA Armor & Light Tanks / Ha-Go & Chi-Ha)
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

createHashMapFromArray [
    ["supportID", "SUPPORT_ARMOR_IJA"],
    ["name", "Sección Blindada IJA (2x Tipo 95 Ha-Go / Tipo 97 Chi-Ha)"],
    ["isStatic", false],
    ["requiredMods", ["fow"]],
    ["entities", [
        // [className, [offsetX, offsetY, offsetZ], relDir, varName, groupVar, rank, isVehicle]
        ["fow_v_type95_HaGo", [-10, 0, 0], 0, "VEH_SUPPORT_ARMOR_1", "SUPPORT_ARMOR_1", "SERGEANT", true],
        ["fow_s_ija_nco", [-10, -3, 0], 0, "SUPPORT_CREW_1", "SUPPORT_ARMOR_1", "SERGEANT", false],
        ["fow_s_ija_rifleman", [-8, -3, 0], 0, "SUPPORT_CREW_2", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["fow_s_ija_rifleman", [-12, -3, 0], 0, "SUPPORT_CREW_3", "SUPPORT_ARMOR_1", "PRIVATE", false],

        ["fow_v_type95_HaGo", [10, 0, 0], 0, "VEH_SUPPORT_ARMOR_2", "SUPPORT_ARMOR_1", "CORPORAL", true],
        ["fow_s_ija_nco", [10, -3, 0], 0, "SUPPORT_CREW_4", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["fow_s_ija_rifleman", [12, -3, 0], 0, "SUPPORT_CREW_5", "SUPPORT_ARMOR_1", "PRIVATE", false],
        ["fow_s_ija_rifleman", [8, -3, 0], 0, "SUPPORT_CREW_6", "SUPPORT_ARMOR_1", "PRIVATE", false]
    ]],
    ["fallbackEntities", [
        ["I_MBT_03_cannon_F", [-12, 0, 0], 0, "VEH_SUPPORT_ARMOR_1", "SUPPORT_ARMOR_1", "SERGEANT", true],
        ["I_crew_F", [-12, -3, 0], 0, "SUPPORT_CREW_1", "SUPPORT_ARMOR_1", "SERGEANT", false],
        ["I_crew_F", [-10, -3, 0], 0, "SUPPORT_CREW_2", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["I_MBT_03_cannon_F", [12, 0, 0], 0, "VEH_SUPPORT_ARMOR_2", "SUPPORT_ARMOR_1", "CORPORAL", true],
        ["I_crew_F", [12, -3, 0], 0, "SUPPORT_CREW_3", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["I_crew_F", [14, -3, 0], 0, "SUPPORT_CREW_4", "SUPPORT_ARMOR_1", "PRIVATE", false]
    ]]
];
