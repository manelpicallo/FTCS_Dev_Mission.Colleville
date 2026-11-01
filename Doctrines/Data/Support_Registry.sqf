/*
    ================================================================================
    FTCS SUPPORT REGISTRY
    Directory of available attached support assets under Doctrines\Data\.
    Pure data-driven registry mapping support elements to military factions / sides,
    categories (FIXED vs MOBILE), and template files.
    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)
    ================================================================================
*/

[
    // US / ALLIED (BLUFOR / RESISTANCE / WEST)
    createHashMapFromArray [
        ["id", "SUPPORT_ARTILLERY_US"],
        ["file", "Support_Artillery"],
        ["category", "FIXED"],
        ["name", "105mm Artillery Section (SPE M3 Howitzers)"],
        ["factions", ["US", "ALLIED", "101_US_PARA_COMPANY", "101_US_PARA_COMPANY_V2_1", "SPE_US_Army_Rifle_Company", "SPE_US_ARMY_RIFLE_COMPANY", "US_ARMY", "US_RANGERS_WW2", "BRITISH_AIRBORNE"]],
        ["sides", [resistance, west]]
    ],
    createHashMapFromArray [
        ["id", "SUPPORT_ARMOR_US"],
        ["file", "Support_Armor"],
        ["category", "MOBILE"],
        ["name", "Armor Section (2x M4A1 Sherman)"],
        ["factions", ["US", "ALLIED", "101_US_PARA_COMPANY", "101_US_PARA_COMPANY_V2_1", "SPE_US_Army_Rifle_Company", "SPE_US_ARMY_RIFLE_COMPANY", "US_ARMY", "US_RANGERS_WW2", "BRITISH_AIRBORNE"]],
        ["sides", [resistance, west]]
    ],

    // GERMAN / WEHRMACHT (AXIS / OPFOR / WEST / EAST)
    createHashMapFromArray [
        ["id", "SUPPORT_ARTILLERY_GER"],
        ["file", "Support_Artillery_German"],
        ["category", "FIXED"],
        ["name", "Batería de Artillería (8cm GrW 34 Mortars / Howitzers)"],
        ["factions", ["GERMAN", "WEHRMACHT", "AXIS", "GERMAN_WW2", "SPE_German_Sturmgrenadier_Company", "GERMAN_PANZER_GRENADIER"]],
        ["sides", [west, east]]
    ],
    createHashMapFromArray [
        ["id", "SUPPORT_ARMOR_GER"],
        ["file", "Support_Armor_German"],
        ["category", "MOBILE"],
        ["name", "Sección Blindada / Cañones de Asalto (StuG III / Pz.Kpfw)"],
        ["factions", ["GERMAN", "WEHRMACHT", "AXIS", "GERMAN_WW2", "SPE_German_Sturmgrenadier_Company", "GERMAN_PANZER_GRENADIER"]],
        ["sides", [west, east]]
    ],

    // SOVIET / RED ARMY (OPFOR / EAST / ALLIED)
    createHashMapFromArray [
        ["id", "SUPPORT_ARTILLERY_SOV"],
        ["file", "Support_Artillery_Soviet"],
        ["category", "FIXED"],
        ["name", "Batería de Artillería / Morteros Pesados (120mm / 82mm)"],
        ["factions", ["SOVIET", "RUSSIAN", "RED_ARMY", "USSR", "IFA3_SOV", "LIB_SOV"]],
        ["sides", [east, resistance]]
    ],
    createHashMapFromArray [
        ["id", "SUPPORT_ARMOR_SOV"],
        ["file", "Support_Armor_Soviet"],
        ["category", "MOBILE"],
        ["name", "Sección Blindada del Ejército Rojo (2x T-34-76 / T-34-85)"],
        ["factions", ["SOVIET", "RUSSIAN", "RED_ARMY", "USSR", "IFA3_SOV", "LIB_SOV"]],
        ["sides", [east, resistance]]
    ],

    // JAPANESE / IJA (INDEPENDENT / OPFOR / EAST / RESISTANCE)
    createHashMapFromArray [
        ["id", "SUPPORT_ARTILLERY_IJA"],
        ["file", "Support_Artillery_Japanese"],
        ["category", "FIXED"],
        ["name", "Batería de Artillería IJA (Tipo 97 Mortero / Cañón)"],
        ["factions", ["JAPAN", "JAPANESE", "IJA", "AXIS_PACIFIC", "FOW_IJA"]],
        ["sides", [east, independent, resistance]]
    ],
    createHashMapFromArray [
        ["id", "SUPPORT_ARMOR_IJA"],
        ["file", "Support_Armor_Japanese"],
        ["category", "MOBILE"],
        ["name", "Sección Blindada IJA (2x Tipo 95 Ha-Go / Tipo 97 Chi-Ha)"],
        ["factions", ["JAPAN", "JAPANESE", "IJA", "AXIS_PACIFIC", "FOW_IJA"]],
        ["sides", [east, independent, resistance]]
    ]
];
