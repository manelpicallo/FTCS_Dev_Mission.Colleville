/*
    File: fn_configDoctrines.sqf
    Module: Ctrl_Doctrines
    Author: FTCS Team
    Description: Defines real-world military unit counts, platoons, squads, organic 
                 roles, and transport assets per doctrine (US, German, British, 
                 Japanese forces, Rangers, Airborne, Motorized, and Mechanized units).
*/

if (isNil "FTCS_Config") then { FTCS_Config = createHashMap; };

// Active global configuration defaults
FTCS_Config set ["activeDoctrine", "US_AIRBORNE"]; 
FTCS_Config set ["companyLetter", "E"]; // Easy Company, 506th PIR default

FTCS_Doctrines = createHashMapFromArray [
    [
        "US_AIRBORNE", createHashMapFromArray [
            ["companyFormat", "Company %1, %2 Parachute Infantry Regiment"],
            ["platoons", ["Company HQ", "1st Airborne Platoon", "2nd Airborne Platoon", "3rd Airborne Platoon"]],
            ["squadsPerPlatoon", 4], // 3 Rifle Squads + 1 Mortar Squad
            ["isMechanized", false],
            ["transportAsset", ""],
            // HQ Special Roles for Backend Parsing and UI Command Assignment
            ["companyHQRoles", [
                "CO_CAPTAIN",       // Company Commander
                "XO_LIEUTENANT",    // Executive Officer
                "FIRST_SERGEANT",   // 1st Sgt
                "COMM_SERGEANT",    // Signal / Comms Sgt
                "RADIO_OPERATOR",   // SCR-300 RTO
                "MESSENGER_1",      // Runner / Messenger A
                "MESSENGER_2",      // Runner / Messenger B
                "COMPANY_MEDIC"     // Company Medic
            ]],
            ["platoonHQRoles", [
                "PLATOON_LEADER",   // 1st / 2nd Lt
                "ASST_PL_LEADER",   // Asst Platoon Leader
                "PLATOON_SERGEANT", // Tech Sgt
                "PLATOON_RTO",      // SCR-536 Handy-Talkie
                "PLATOON_RUNNER",   // Runner
                "PLATOON_MEDIC"     // Platoon Medic
            ]],
            // Platoon HQ Team Structure (Team 1: Command & Comms, Team 2: Leadership & Support)
            ["platoonHQTeamStructure", [
                ["Command Element", ["PLATOON_LEADER", "PLATOON_RTO"]],
                ["Support Element", ["PLATOON_SERGEANT", "PLATOON_RUNNER", "PLATOON_MEDIC"]]
            ]],
            ["squadTypes", [
                "1st Rifle Squad",
                "2nd Rifle Squad",
                "3rd Rifle Squad",
                "Mortar Section"
            ]],
            // Flexible structure supporting up to 4 teams and their associated tactical roles
            ["teamStructure", ["Scout Team", "Rifle Team A", "Rifle Team B", "BAR Support Team"]],
            ["teamRoles",     ["ASSAULT",    "ASSAULT",    "ASSAULT",    "SUPPORT"]]
        ]
    ],
    [
        "US_ARMY", createHashMapFromArray [
            ["companyFormat", "Company %1, %2 Infantry Regiment"],
            ["platoons", ["Company HQ", "1st Platoon", "2nd Platoon", "3rd Platoon", "Weapons Platoon"]],
            ["squadsPerPlatoon", 3], // 3 Rifle Squads per Rifle Platoon (Weapons Platoon managed via specific slots)
            ["isMechanized", false],
            ["transportAsset", ""],
            // Company HQ Roles (TO&E 7-17 Standard Infantry Company HQ)
            ["companyHQRoles", [
                "CO_CAPTAIN",       // Company Commander (Captain)
                "XO_LIEUTENANT",    // Executive Officer (1st Lieutenant)
                "FIRST_SERGEANT",   // Company First Sergeant
                "COMM_SERGEANT",    // Communications Sergeant
                "RADIO_OPERATOR",   // Company RTO / Signalman
                "MESSENGER_1",      // Company Runner A
                "MESSENGER_2" ,     // Company Runner B
                "COMPANY_MEDIC"     // Company Medic
            ]],
            // Platoon HQ Roles for Standard Infantry (including Platoon Guide)
            ["platoonHQRoles", [
                "PLATOON_LEADER",   // Platoon Leader (Lieutenant)
                "PLATOON_SERGEANT", // Platoon Sergeant (Tech Sgt)
                "PLATOON_GUIDE",    // Platoon Guide (Staff Sgt)
                "PLATOON_RTO",      // Platoon Messenger / Radio
                "PLATOON_RUNNER",   // Platoon Runner
                "PLATOON_MEDIC"     // Platoon Medic
            ]],
            // Platoon HQ Team Structure (Team 1: Command & Comms, Team 2: Leadership & Support)
            ["platoonHQTeamStructure", [
                ["Command Element", ["PLATOON_LEADER", "PLATOON_RTO"]],
                ["Support Element", ["PLATOON_SERGEANT", "PLATOON_RUNNER", "PLATOON_MEDIC"]]
            ]],
            ["squadTypes", [
                "1st Rifle Squad",
                "2nd Rifle Squad",
                "3rd Rifle Squad"
            ]],
            ["teamStructure", ["Scout Team", "Rifle Team", "BAR Support Team"]],
            ["teamRoles",     ["ASSAULT",    "ASSAULT",    "SUPPORT"]]
        ]
    ],
    [
        "US_ARMY_MECHANIZED", createHashMapFromArray [
            ["companyFormat", "Company %1, %2 Armored Infantry Battalion"],
            ["platoons", ["1st Armored Platoon", "2nd Armored Platoon", "3rd Armored Platoon", "Assault Platoon"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", true],
            ["transportAsset", "US_M3_Halftrack"]
        ]
    ],
    [
        "US_RANGERS_WW2", createHashMapFromArray [
            ["companyFormat", "Company %1, %2 Ranger Battalion"],
            ["platoons", ["1st Ranger Platoon", "2nd Ranger Platoon", "3rd Ranger Platoon"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ],
    [
        "US_MC", createHashMapFromArray [
            ["companyFormat", "Company %1, %2 Marine Regiment"],
            ["platoons", ["1st Platoon", "2nd Platoon", "3rd Platoon", "Weapons Platoon"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ],
    [
        "GERMAN_WW2", createHashMapFromArray [
            ["companyFormat", "%1. Kompanie"],
            ["platoons", ["I. Zug", "II. Zug", "III. Zug", "MG-Zug"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ],
    [
        "GERMAN_PANZER_GRENADIER", createHashMapFromArray [
            ["companyFormat", "%1. Panzergrenadier-Kompanie"],
            
            // Organic platoons according to KStN 1114b
            ["platoons", [
                "Company HQ", 
                "1. Gepanzerter Zug", 
                "2. Gepanzerter Zug", 
                "3. Gepanzerter Zug", 
                "Schwere-Zug"
            ]],
            
            ["squadsPerPlatoon", 3],
            ["isMechanized", true],
            ["transportAsset", "SdKfz_251_Halftrack"],
            
            // Tactical team structure adapted for Panzergrenadiere
            ["teamStructure", ["Spähtrupp (Scouts)", "Schützentrupp (Assault)", "MG-Trupp (Support)"]],
            ["teamRoles",     ["ASSAULT",             "ASSAULT",                 "SUPPORT"]],

            // Platoon HQ Team Structure (Team 1: Command & Comms, Team 2: Leadership & Support)
            ["platoonHQTeamStructure", [
                ["Command Element", ["PLATOON_LEADER", "PLATOON_RTO"]],
                ["Support Element", ["PLATOON_SERGEANT", "PLATOON_RUNNER", "PLATOON_MEDIC"]]
            ]],

            // Crew Doctrine Configuration (Robust via base classes and isKindOf)
            ["crewDoctrine", createHashMapFromArray [
                ["useGroupAssociation", true],     
                ["spwBesatzungGroup", "SPW_CREW"], // Identifier for armored personnel carrier crew group
                ["melderTruppGroup", "HQ_CREW"],   // Identifier for HQ liaison element group
                
                // Base class filters (Editor-proof: accepts any logical variant or replacement)
                ["spwBesatzungAllowedParents", ["Tank", "Car"]], // Validates armored / halftrack chassis
                ["melderTruppAllowedParents", ["Car", "Truck"]]   // Validates light liaison cars or trucks (Kübelwagen, etc.)
            ]],

            // Ideal role distribution matrix for HQ Fleet
            ["hqVehicleAssignments", createHashMapFromArray [
                ["VEH_CO", [
                    "CO_CAPTAIN", 
                    "XO_LIEUTENANT", 
                    "FIRST_SERGEANT", 
                    "COMM_SERGEANT", 
                    "RADIO_OPERATOR", 
                    "MESSENGER_1", 
                    "MESSENGER_2", 
                    "COMM_SPECIALIST"
                ]],
                ["VEH_CO_2", [
                    "MESSENGER_3",      
                    "COMPANY_MEDIC", 
                    "VEHICLE_MECHANIC"
                ]]
            ]],

            // Unified Kompanietrupp roles
            ["companyHQRoles", [
                "CO_CAPTAIN", "XO_LIEUTENANT", "FIRST_SERGEANT", 
                "COMM_SERGEANT", "RADIO_OPERATOR", "MESSENGER_1", 
                "MESSENGER_2", "COMM_SPECIALIST", "MESSENGER_3", 
                "COMPANY_MEDIC", "VEHICLE_MECHANIC"
            ]],

            // Platoon Headquarters (Zugtrupp) roles
            ["platoonHQRoles", [
                "PLATOON_LEADER", "ASST_PL_LEADER", "PLATOON_SERGEANT", 
                "PLATOON_RTO", "PLATOON_RUNNER_1", "PLATOON_RUNNER_2", 
                "PLATOON_MEDIC"
            ]],

            // Squad types for Rifle Platoons
            ["squadTypes", [
                "1. Schützen-Gruppe",
                "2. Schützen-Gruppe",
                "3. Schützen-Gruppe"
            ]],

            // Squad types for Heavy Platoon
            ["heavySquadTypes", [
                "1. sMG-Gruppe",        
                "2. sMG-Gruppe",        
                "Kanonen-Gruppe"        
            ]]
        ]
    ],
    [
        "GERMAN_FALLSCHIRMJAEGER", createHashMapFromArray [
            ["companyFormat", "%1. Kompanie / Fallschirmjäger-Regiment"],
            ["platoons", ["I. Fallschirm-Zug", "II. Fallschirm-Zug", "III. Fallschirm-Zug"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ],
    [
        "BRITISH_ARMY", createHashMapFromArray [
            ["companyFormat", "%1 Company"],
            ["platoons", ["1 Platoon", "2 Platoon", "3 Platoon", "Support Platoon"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ],
    [
        "BRITISH_MOTORIZED", createHashMapFromArray [
            ["companyFormat", "%1 Motorized Company"],
            ["platoons", ["1 Motorized Platoon", "2 Motorized Platoon", "3 Motorized Platoon", "Support Platoon"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", true],
            ["transportAsset", "Bedford_3ton_Truck"]
        ]
    ],
    [
        "BRITISH_AIRBORNE", createHashMapFromArray [
            ["companyFormat", "%1 Parachute Company"],
            ["platoons", ["1 Para Platoon", "2 Para Platoon", "3 Para Platoon", "Support Platoon"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ],
    [
        "JAPANESE_IJA", createHashMapFromArray [
            ["companyFormat", "%1. Chutai (Company), IJA Infantry"],
            ["platoons", ["1. Shotai (Platoon)", "2. Shotai (Platoon)", "3. Shotai (Platoon)"]],
            ["squadsPerPlatoon", 4],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ],
    [
        "JAPANESE_PARATROOPERS", createHashMapFromArray [
            ["companyFormat", "%1. Teishin Shudan (Parachute Company)"],
            ["platoons", ["1. Teishin Shotai", "2. Teishin Shotai", "Heavy Weapons Shotai"]],
            ["squadsPerPlatoon", 3],
            ["isMechanized", false],
            ["transportAsset", ""]
        ]
    ]
];