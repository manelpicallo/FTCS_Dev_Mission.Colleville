/*
    ================================================================================
    FTCS SUPPORT DATA TEMPLATE: Support_Armor_German
    Category: Mobile Support (German Assault Guns / StuG III & Tanks)
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

createHashMapFromArray [
    ["supportID", "SUPPORT_ARMOR_GER"],
    ["name", "German Assault Gun / Panzer Section (StuG III / Panzer)"],
    ["isStatic", false],
    ["requiredMods", ["SPE"]],
    ["entities", [
        // [className, [offsetX, offsetY, offsetZ], relDir, varName, groupVar, rank, isVehicle]
        ["SPE_StuG_III_G_Early", [-10, 0, 0], 0, "VEH_SUPPORT_ARMOR_1", "SUPPORT_ARMOR_1", "SERGEANT", true],
        ["SPE_GER_squadlead", [-10, -3, 0], 0, "SUPPORT_CREW_1", "SUPPORT_ARMOR_1", "SERGEANT", false],
        ["SPE_GER_rifleman", [-8, -3, 0], 0, "SUPPORT_CREW_2", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["SPE_GER_rifleman", [-12, -3, 0], 0, "SUPPORT_CREW_3", "SUPPORT_ARMOR_1", "PRIVATE", false],

        ["SPE_StuG_III_G_Early", [10, 0, 0], 0, "VEH_SUPPORT_ARMOR_2", "SUPPORT_ARMOR_1", "CORPORAL", true],
        ["SPE_GER_squadlead", [10, -3, 0], 0, "SUPPORT_CREW_4", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["SPE_GER_rifleman", [12, -3, 0], 0, "SUPPORT_CREW_5", "SUPPORT_ARMOR_1", "PRIVATE", false],
        ["SPE_GER_rifleman", [8, -3, 0], 0, "SUPPORT_CREW_6", "SUPPORT_ARMOR_1", "PRIVATE", false]
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
