/*
    ================================================================================
    FTCS SUPPORT DATA TEMPLATE: Support_Armor_Soviet
    Category: Mobile Support (Soviet Armor & Assault Guns / T-34)
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

createHashMapFromArray [
    ["supportID", "SUPPORT_ARMOR_SOV"],
    ["name", "Sección Blindada del Ejército Rojo (2x T-34-76 / T-34-85)"],
    ["isStatic", false],
    ["requiredMods", ["LIB"]],
    ["entities", [
        // [className, [offsetX, offsetY, offsetZ], relDir, varName, groupVar, rank, isVehicle]
        ["LIB_T34_76", [-10, 0, 0], 0, "VEH_SUPPORT_ARMOR_1", "SUPPORT_ARMOR_1", "SERGEANT", true],
        ["LIB_SOV_sergeant", [-10, -3, 0], 0, "SUPPORT_CREW_1", "SUPPORT_ARMOR_1", "SERGEANT", false],
        ["LIB_SOV_rifleman", [-8, -3, 0], 0, "SUPPORT_CREW_2", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["LIB_SOV_rifleman", [-12, -3, 0], 0, "SUPPORT_CREW_3", "SUPPORT_ARMOR_1", "PRIVATE", false],

        ["LIB_T34_76", [10, 0, 0], 0, "VEH_SUPPORT_ARMOR_2", "SUPPORT_ARMOR_1", "CORPORAL", true],
        ["LIB_SOV_sergeant", [10, -3, 0], 0, "SUPPORT_CREW_4", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["LIB_SOV_rifleman", [12, -3, 0], 0, "SUPPORT_CREW_5", "SUPPORT_ARMOR_1", "PRIVATE", false],
        ["LIB_SOV_rifleman", [8, -3, 0], 0, "SUPPORT_CREW_6", "SUPPORT_ARMOR_1", "PRIVATE", false]
    ]],
    ["fallbackEntities", [
        ["O_MBT_02_cannon_F", [-12, 0, 0], 0, "VEH_SUPPORT_ARMOR_1", "SUPPORT_ARMOR_1", "SERGEANT", true],
        ["O_crew_F", [-12, -3, 0], 0, "SUPPORT_CREW_1", "SUPPORT_ARMOR_1", "SERGEANT", false],
        ["O_crew_F", [-10, -3, 0], 0, "SUPPORT_CREW_2", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["O_MBT_02_cannon_F", [12, 0, 0], 0, "VEH_SUPPORT_ARMOR_2", "SUPPORT_ARMOR_1", "CORPORAL", true],
        ["O_crew_F", [12, -3, 0], 0, "SUPPORT_CREW_3", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["O_crew_F", [14, -3, 0], 0, "SUPPORT_CREW_4", "SUPPORT_ARMOR_1", "PRIVATE", false]
    ]]
];
