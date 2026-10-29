/*
    ================================================================================
    FTCS SUPPORT DATA TEMPLATE: Support_Armor
    Category: Mobile Support (Tanks & Assault Guns)
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

createHashMapFromArray [
    ["supportID", "SUPPORT_ARMOR_US"],
    ["name", "Armored Tank Section (2x M4A1 Sherman)"],
    ["isStatic", false],
    ["requiredMods", ["SPE"]],
    ["entities", [
        // [className, [offsetX, offsetY, offsetZ], relDir, varName, groupVar, rank, isVehicle]
        ["SPE_M4A1_75", [-10, 0, 0], 0, "VEH_SUPPORT_ARMOR_1", "SUPPORT_ARMOR_1", "SERGEANT", true],
        ["SPE_US_Tank_Crew", [-10, -3, 0], 0, "SUPPORT_CREW_1", "SUPPORT_ARMOR_1", "SERGEANT", false],
        ["SPE_US_Tank_Crew", [-8, -3, 0], 0, "SUPPORT_CREW_2", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["SPE_US_Tank_Crew", [-12, -3, 0], 0, "SUPPORT_CREW_3", "SUPPORT_ARMOR_1", "PRIVATE", false],

        ["SPE_M4A1_75", [10, 0, 0], 0, "VEH_SUPPORT_ARMOR_2", "SUPPORT_ARMOR_1", "CORPORAL", true],
        ["SPE_US_Tank_Crew", [10, -3, 0], 0, "SUPPORT_CREW_4", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["SPE_US_Tank_Crew", [12, -3, 0], 0, "SUPPORT_CREW_5", "SUPPORT_ARMOR_1", "PRIVATE", false],
        ["SPE_US_Tank_Crew", [8, -3, 0], 0, "SUPPORT_CREW_6", "SUPPORT_ARMOR_1", "PRIVATE", false]
    ]],
    ["fallbackEntities", [
        ["B_MBT_01_cannon_F", [-12, 0, 0], 0, "VEH_SUPPORT_ARMOR_1", "SUPPORT_ARMOR_1", "SERGEANT", true],
        ["B_crew_F", [-12, -3, 0], 0, "SUPPORT_CREW_1", "SUPPORT_ARMOR_1", "SERGEANT", false],
        ["B_crew_F", [-10, -3, 0], 0, "SUPPORT_CREW_2", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["B_MBT_01_cannon_F", [12, 0, 0], 0, "VEH_SUPPORT_ARMOR_2", "SUPPORT_ARMOR_1", "CORPORAL", true],
        ["B_crew_F", [12, -3, 0], 0, "SUPPORT_CREW_3", "SUPPORT_ARMOR_1", "CORPORAL", false],
        ["B_crew_F", [14, -3, 0], 0, "SUPPORT_CREW_4", "SUPPORT_ARMOR_1", "PRIVATE", false]
    ]]
];
