# FTCS - Especificación Completa de la Estructura de Datos (Architecture & Data Model)

> **Documento Vivo de Arquitectura:** Esta es la referencia técnica formal y visual del modelo de datos de FTCS.
> Si se modifican, añaden o eliminan campos, tablas de hash o enumeraciones en el código backend (`FTCS_Company_Data`, `FTCS_Groups_Registry_Table`, plantillas doctrinales o registros auxiliares), **este documento debe ser actualizado obligatoriamente** para mantener sincronizada la fuente de verdad.

---

## 1. Mapa Global de Puntos de Entrada (`missionNamespace`)

En el backend de FTCS, toda la simulación se gobierna a través de tres estructuras de datos centrales en memoria:

```
missionNamespace
├── FTCS_Config                     (HashMap: Parámetros de misión y doctrina activa)
├── FTCS_Company_Data               (HashMap: Árbol Jerárquico Táctico de Compañía - ORBAT)
├── FTCS_Groups_Registry_Table      (HashMap: Registro Plano de Estados y Físicas de Grupos)
├── FTCS_Platoon_Phase_1 .. 4       (NUMBER: Fase operacional activa individual por pelotón: 1, 2 o 3)
├── FTCS_Platoon_Follow_Mode        (STRING: Modo de seguimiento activo: "FOLLOWING_COMMANDER_REL" | "FOLLOWING_COMMANDER_ABS")
├── FTCS_Platoon_Fixed_Abs_Dir      (NUMBER: Rumbo fijo congelado en brújula [0-360] para seguimiento y debug en modo absoluto)
└── FTCS_Debug_Mode                 (BOOLEAN: Centinela de depuración, true para telemetría visual y slots en mapa)
```

---

## 2. Árbol Jerárquico Táctico: `FTCS_Company_Data`

Este árbol define la jerarquía militar y el orden de batalla (ORBAT) de la fuerza, desde el Puesto de Mando de Compañía hasta cada escuadra, sus sub-equipos (*fireteams*) y los soldados con roles asignados.

```
FTCS_Company_Data (HashMap)
│
├── "companyID"          : STRING           -> Código táctico de la compañía (ej. "CO_E", "CO_A", "CO_C")
├── "isMechanized"       : BOOLEAN          -> true / false
├── "transportAsset"     : STRING           -> Classname de vehículo orgánico o ""
├── "selectedIDs"        : ARRAY of STRINGS -> Elementos bajo selección de mando (ej. ["ALL"], ["SQD_1_1"])
├── "selectedType"       : ENUM STRING      -> Ámbito de selección: "COMPANY" | "PLATOON" | "SQUAD" | "VEHICLE"
│
├── "companyHQ"          : HashMap (Puesto de Mando de Compañía)
│     ├── "group"        : GROUP (Arma 3)   -> Objeto del grupo de mando SQUAD_0_0
│     ├── "leader"       : OBJECT (Unit)    -> Oficial al mando (Capitán / HQ_CO_CAPTAIN)
│     ├── "name"         : STRING           -> Nombre doctrinal (ej. "Company HQ")
│     ├── "units"        : ARRAY of OBJECTS -> Soldados asignados a SQUAD_0_0
│     │
│     ├── "assignedRoles": HashMap (Mapeo directo de roles individuales del Estado Mayor)
│     │     ├── "HQ_CO_CAPTAIN"     : OBJECT -> Capitán (Company Commander)
│     │     ├── "HQ_XO_LIEUTENANT"  : OBJECT -> 1st Lieutenant (Executive Officer)
│     │     ├── "HQ_FIRST_SERGEANT" : OBJECT -> First Sergeant (Sargento Primero de Compañía)
│     │     ├── "HQ_COMM_SERGEANT"  : OBJECT -> Communications Sergeant
│     │     ├── "HQ_RADIO_OPERATOR" : OBJECT -> RTO / Radio Operador SCR-300
│     │     ├── "HQ_MESSENGER_1..6" : OBJECT -> Estafetas / Mensajeros a pie (1 al 6)
│     │     └── "HQ_MEDIC"          : OBJECT -> Sanitario de Compañía
│     │
│     └── "tacticalTeams": HashMap (Sub-equipos de SQUAD_0_0)
│           ├── "SQD_0_0_TEAM_1" : [name: "Command Element", group: Group, leader: Object, units: Array]
│           └── "SQD_0_0_TEAM_2" : [name: "Signals & Liaison", group: Group, leader: Object, units: Array]
│
├── "squadsRegistry"     : HashMap (Directorio plano de todas las escuadras: "SQD_X_Y" -> Squad Data)
│
└── "platoons"           : HashMap (Colección de Pelotones: "PLT_0" a "PLT_4")
      │
      ├── "PLT_0" : Pelotón de Mando (Apunta internamente a la estructura de Company HQ)
      │
      └── "PLT_1" .. "PLT_4" : HashMap (Pelotones Tácticos de Combate y Apoyo)
            ├── "name"              : STRING      -> Nombre semántico (ej. "1st Rifle Platoon", "Weapons Platoon")
            ├── "currentPhase"      : NUMBER      -> Fase operacional activa del pelotón (1: APPROACH, 2: OVERWATCH, 3: COMBAT)
            ├── "movementTechnique" : STRING      -> "CROSS_COUNTRY" (táctico a campo través) | "ROAD_COLUMN" (carretera) | "TRAIL_FILE"
            ├── "roadPath"          : ARRAY       -> Polilínea de carretera activa [[posATL, tangentDir, roadWidth], ...] o []
            ├── "isMechanized"      : BOOLEAN     -> true / false
            ├── "transportAsset"    : STRING      -> Classname de transporte de pelotón o ""
            ├── "squads"            : ARRAY of ID -> Lista de IDs de escuadras: ["SQD_1_0", "SQD_1_1", "SQD_1_2", "SQD_1_3"]
            ├── "formationSlots"    : HashMap     -> Mapeo pre-resuelto de slots doctrinales (Slot 0..12 -> ID escuadra/team)
            │
            └── "parsedSquads"   : HashMap (Escuadras resueltas en el motor)
                  │
                  ├── "SQD_X_0" : HashMap (Platoon Leadership HQ Slot)
                  │     ├── "name"          : STRING   -> "HQ Squad"
                  │     ├── "platoonID"     : STRING   -> "PLT_X"
                  │     ├── "group"         : GROUP    -> Grupo de mando (SQUAD_X_0_TEAM_1)
                  │     ├── "leader"        : OBJECT   -> Teniente (PLT_X_LEADER)
                  │     ├── "assignedRoles" : HashMap  -> [PLT_X_LEADER, PLT_X_SERGEANT, PLT_X_RADIO_OPERATOR, PLT_X_RUNNER, PLT_X_MEDIC, PLT_X_GUIDE]
                  │     └── "tacticalTeams" : HashMap (Sub-equipos de Platoon HQ)
                  │           ├── "SQD_X_0_TEAM_1" -> [name: "Command Element", leader: Teniente, units: [Teniente, RTO]]
                  │           ├── "SQD_X_0_TEAM_2" -> [name: "Support Element", leader: Sargento Plt, units: [Sargento, Runner, Medic]]
                  │           └── "SQD_X_0_TEAM_3" -> [name: "Guide & Security Element", leader: Guía Plt, units: [Guía, Estafeta/Seguridad]]
                  │
                  ├── "SQD_X_1" .. "SQD_X_3" : HashMap (Escuadras de Fusileros con Multi-Team)
                  │     ├── "name"          : STRING   -> "1st Rifle Squad", "2nd Rifle Squad", etc.
                  │     ├── "platoonID"     : STRING   -> "PLT_X"
                  │     ├── "isUnified"     : false    -> Tiene sub-equipos tácticos (Teams)
                  │     ├── "leader"        : OBJECT   -> Squad Leader (SQD_X_Y_LEADER)
                  │     │
                  │     └── "tacticalTeams" : HashMap (Equipos de Combate / Fireteams)
                  │           │
                  │           ├── "SQD_X_Y_TEAM_1" : HashMap (Punta / Recon)
                  │           │     ├── "name"         : STRING   -> "Able Team (Scouts)"
                  │           │     ├── "parentSquad"  : STRING   -> "SQD_X_Y"
                  │           │     ├── "type"         : STRING   -> "TEAM_1"
                  │           │     ├── "tacticalRole" : STRING   -> "ASSAULT" | "POINT" | "RECON"
                  │           │     ├── "group"        : GROUP    -> Grupo de Arma 3 (SQUAD_X_Y_TEAM_1)
                  │           │     ├── "leader"       : OBJECT   -> Squad Leader
                  │           │     └── "units"        : ARRAY    -> [Squad Leader, Scout 1, Scout 2]
                  │           │
                  │           ├── "SQD_X_Y_TEAM_2" : HashMap (Base de Fuego)
                  │           │     ├── "name"         : STRING   -> "Baker Team (Base of Fire)"
                  │           │     ├── "tacticalRole" : STRING   -> "SUPPORT"
                  │           │     ├── "group"        : GROUP    -> Grupo de Arma 3 (SQUAD_X_Y_TEAM_2)
                  │           │     └── "units"        : ARRAY    -> [BAR Gunner, Assistant, Ammo Bearer]
                  │           │
                  │           └── "SQD_X_Y_TEAM_3" : HashMap (Maniobra y Asalto)
                  │                 ├── "name"         : STRING   -> "Charlie Team (Maneuver)"
                  │                 ├── "tacticalRole" : STRING   -> "ASSAULT"
                  │                 ├── "group"        : GROUP    -> Grupo de Arma 3 (SQUAD_X_Y_TEAM_3)
                  │                 └── "units"        : ARRAY    -> [Assist Squad Lead, 2x Grenadiers, Riflemen, Medic]
                  │
                  └── "SQD_X_4" (o SQD_4_1..4) : HashMap (Escuadra Unificada de Apoyo Pesado / Mortero / MG)
                        ├── "name"          : STRING   -> "1st Mortar Section", "1st Machine Gun Section"
                        ├── "platoonID"     : STRING   -> "PLT_X"
                        ├── "isUnified"     : true     -> Bypassea la división en teams (opera como un único grupo)
                        ├── "group"         : GROUP    -> Grupo unificado de Arma 3 (ej. SQUAD_4_1_TEAM_1)
                        ├── "leader"        : OBJECT   -> Cabo / Sargento de dotación
                        └── "units"         : ARRAY    -> [Leader, Gunner M2, Assistant, 2x Ammo Bearers]
```

---

## 3. Registro Plano de Físicas y Máquinas de Estado: `FTCS_Groups_Registry_Table`

Mientras que `FTCS_Company_Data` representa la jerarquía militar, esta tabla es un **directorio plano indexado por el identificador del grupo en el motor (`groupId _group`)**. 

Permite que las funciones de combate, IA, órdenes y formaciones consulten y alteren en tiempo real el comportamiento físico de cualquier grupo sin tener que recorrer árboles anidados.

```
FTCS_Groups_Registry_Table (HashMap)
│
└── [GroupID: STRING] (ej. "SQUAD_1_1_TEAM_1", "SQUAD_4_1_TEAM_1", "SQUAD_0_0")
      │
      ├── "movingMode"        : ENUM STRING
      │     Valores válidos:
      │     ├── "AT_WILL"                 -> La IA decide su movimiento táctico libremente.
      │     ├── "FOLLOWING_COMMANDER_REL" -> Sigue al líder manteniendo rumbo y vector relativo.
      │     ├── "FOLLOWING_COMMANDER_ABS" -> Sigue al líder congelando la geometría absoluta del mapa.
      │     ├── "HALT"                    -> Alto temporal manteniendo sector y cobertura.
      │     ├── "STOP"                    -> Parada estricta (`doStop`, cero reubicación de IA).
      │     └── "CONVOY"                  -> Marcha en convoy rodado detrás de un vehículo guía.
      │
      ├── "stance"            : ENUM STRING
      │     Valores válidos:
      │     ├── "AUTO"         -> La IA adapta su postura al fuego recibido.
      │     ├── "FORCE_UP"     -> Obliga a mantenerse de pie (asalto rápido / carrera).
      │     ├── "FORCE_MIDDLE" -> Obliga a permanecer agachado (avance cauteloso).
      │     └── "FORCE_DOWN"   -> Obliga a permanecer cuerpo a tierra (cuerpo a cubierto).
      │
      ├── "awareMode"         : ENUM STRING (Comportamiento nativo de combate en Arma 3)
      │     Valores válidos:
      │     └── "CARELESS" | "SAFE" | "AWARE" | "COMBAT" | "STEALTH"
      │
      ├── "speed"             : ENUM STRING
      │     Valores válidos:
      │     └── "LIMITED" (Paso) | "NORMAL" (Trote) | "FULL" (Carrera a fondo)
      │
      ├── "roe"               : ENUM STRING (Reglas de Enfrentamiento)
      │     Valores válidos:
      │     ├── "FIRE_AT_WILL"         -> Disparar libremente al detectar enemigos (Combate Amarillo).
      │     ├── "FIRE_IF_FIRED_UPON"   -> Fuego de respuesta / discreción (Combate Verde).
      │     └── "HOLD_FIRE"            -> Alto el fuego total / sigilo estricto (Combate Azul).
      │
      ├── "task"              : ENUM STRING (Directiva táctica activa)
      │     Valores válidos:
      │     ├── "AT_WILL"      -> Libre albedrío táctico.
      │     ├── "MOVING"       -> Desplazándose hacia waypoint o línea de fase.
      │     ├── "SUPPRESSING"  -> Fuego de supresión continuo sobre un sector/edificio.
      │     ├── "ATTACKING"    -> Asaltando y limpiando una posición enemiga.
      │     ├── "WATCHING"     -> Vigilando un sector asignado en desenfilada.
      │     └── "WAITING"      -> En espera en Assembly Area o Línea de Partida.
      │
      ├── "formationType"     : ENUM STRING
      │     Valores válidos:
      │     └── "COLUMN" | "LINE" | "WEDGE" | "VEE" | "ECHELON_RIGHT" | "ECHELON_LEFT" | "DIAMOND" | "FILE"
      │
      ├── "allocationSlot"    : SCALAR (Entero: 0, 1, 2, 3...)
      │     Índice de ranura geométrica dentro de la formación de su pelotón/escuadra.
      │
      ├── "formationPosition" : ARRAY [Distance: SCALAR, Direction: SCALAR, LeaderRef: OBJECT/GROUP]
      │     Posición relativa teórica asignada dentro de la formación respecto a su líder guía.
      │     Ejemplo: [25, 180, Group_Platoon_Leader] (a 25 metros a retaguardia del líder).
      │
      ├── "relPosition"       : ARRAY [Distance: SCALAR, Direction: SCALAR, LeaderRef: OBJECT/GROUP]
      │     Vector de posición relativa real instantáneo en el terreno para corregir desvíos.
      │
      ├── "roadTargetPos"     : ARRAY [x, y, z]  -> Posición objetivo instantánea en la carretera (modo marcha en carretera).
      ├── "roadTangentDir"    : SCALAR           -> Rumbo/tangente de la carretera en la posición objetivo asignada.
      ├── "roadOffsetDist"    : SCALAR           -> Distancia lineal acumulada a lo largo de la carretera desde el líder guía.
      ├── "roadShoulderOffset": SCALAR           -> Desplazamiento lateral perpendicular al eje de la calzada (-1 babor / +1 estribor / 0 centro).
      └── "roadTeamIndex"     : SCALAR           -> Índice numérico ordinal del sub-equipo/fireteam dentro de la escuadra (1, 2, 3...).
```

---

## 4. Estructura de Plantillas de Doctrina: `Doctrines/Data/*.sqf`

Es la estructura pura *Data-Driven* que genera el conversor de composiciones 3DEN (`tools/convert_compositions.ps1`) y que alimenta tanto al motor genérico de spawn `FTCS_fnc_spawnDoctrine` como al constructor jerárquico `FTCS_fnc_applyDoctrine`:

```
Doctrinal Data Template (HashMap devuelto por cada fichero SQF)
│
├── "doctrineID"              : STRING           -> "SPE_US_ARMY_RIFLE_COMPANY", "101_US_PARA_COMPANY_V2_1"
├── "companyLetter"           : STRING           -> Letra designada: "E", "A", "C"
├── "side"                    : SIDE (Arma 3)    -> west (Eje) | east (Soviéticos) | resistance (Aliados)
├── "requiredMods"            : ARRAY of STRINGS -> ["SPE"], ["IFA3"], ["fow"]
├── "isMechanized"            : BOOLEAN          -> false / true
├── "transportAsset"          : STRING           -> "" o clase de semioruga / camión
│
├── "platoonNames"            : ARRAY of STRINGS -> ["Company HQ", "1st Rifle Platoon", "2nd Rifle Platoon", ...]
├── "squadsPerPlatoon"        : SCALAR           -> 4
│
├── "companyHQRoles"          : ARRAY of STRINGS -> Roles asignados en SQUAD_0_0:
│                                                  ["CO_CAPTAIN", "XO_LIEUTENANT", "FIRST_SERGEANT",
│                                                   "COMM_SERGEANT", "RADIO_OPERATOR", "MESSENGER_1..6", "COMPANY_MEDIC"]
│
├── "platoonHQRoles"          : ARRAY of STRINGS -> Roles asignados en SQD_X_0:
│                                                  ["PLATOON_LEADER", "PLATOON_SERGEANT", "PLATOON_RTO", "PLATOON_RUNNER", "PLATOON_MEDIC", "PLATOON_GUIDE", "PLATOON_MESSENGER"]
│
├── "platoonHQTeamStructure"  : ARRAY of ARRAYS  -> [["Command Element", ["PLATOON_LEADER", "PLATOON_RTO"]],
│                                                   ["Support Element", ["PLATOON_SERGEANT", "PLATOON_RUNNER", "PLATOON_MEDIC"]],
│                                                   ["Guide & Security Element", ["PLATOON_GUIDE", "PLATOON_MESSENGER"]]]
│
├── "squadDesignations"       : HashMap          -> Mapeo semántico de escuadras ("SQD_X_Y" -> Nombre):
│     ├── "SQD_1_1" : "1st Rifle Squad"
│     ├── "SQD_1_2" : "2nd Rifle Squad"
│     ├── "SQD_1_3" : "3rd Rifle Squad"
│     ├── "SQD_4_1" : "1st Mortar Section"
│     └── "SQD_4_3" : "1st Machine Gun Section"
│
├── "teamStructure"           : ARRAY of STRINGS -> Nombres de los sub-equipos de fusileros:
│                                                  ["Able Team (Scouts)", "Baker Team (Base of Fire)", "Charlie Team (Maneuver)"]
├── "teamRoles"               : ARRAY of STRINGS -> Roles tácticos de cada sub-equipo:
│                                                  ["ASSAULT", "SUPPORT", "ASSAULT"]
│
├── "platoonFormationSlots"   : HashMap (Opcional) -> Mapeo macro de ranuras de formación (Slot 0..12 -> ID patrón):
│     ├── 0  : "SQD_X_1"         (1st Rifle Squad -> Vanguard / Center)
│     ├── 1  : "SQD_X_2"         (2nd Rifle Squad -> Left Flank)
│     ├── 2  : "SQD_X_3"         (3rd Rifle Squad -> Right Flank)
│     ├── 3  : "SQD_X_4"         (4th Squad / Mortar Section)
│     ├── 4  : "SQD_X_0_TEAM_2"  (Platoon Sergeant & Support)
│     ├── 5  : "SQD_X_Y_TEAM_Z"  (Opcional: Detached Scout / Rear Reserve)
│     ├── 6..8: "SQD_X_Y_TEAM_Z" (Opcional: Forward Advanced Scout Screen)
│     ├── 9  : "SQD_X_0_TEAM_1"  (Attached HQ Command Group / Escort)
│     ├── 10 : "SQD_X_0_TEAM_3"  (Platoon Guide / HQ Security / Rear Anchor)
│     └── 11..12: "SQD_X_Y_TEAM_Z" (Opcional: Outer Flank Security Screens)
│
└── "entities"                : ARRAY of TUPLES (Tupla estándar de 7 u 8 campos por soldado/vehículo):
      │
      └── [
            0: className      (STRING)         -> "SPE_US_Captain", "SPE_US_HMGunner_M2"
            1: offsetXYZ      (ARRAY [X, Y, Z])-> Coordenadas relativas al punto ancla del Capitán: [-60, 36, 0]
            2: relativeDir    (SCALAR)         -> Ángulo relativo de orientación (0 a 360 grados)
            3: varName        (STRING)         -> "HQ_CO_CAPTAIN", "PLT_1_LEADER", "SQD_1_1_LEADER"
            4: groupVar       (STRING)         -> "SQUAD_0_0", "SQUAD_1_1_TEAM_1", "SQUAD_4_3_TEAM_1"
            5: rank           (STRING)         -> "CAPTAIN", "LIEUTENANT", "SERGEANT", "CORPORAL", "PRIVATE"
            6: isVehicle      (BOOLEAN)        -> false (Infantería) | true (Vehículo / Blindado)
            7: customLoadout  (ARRAY Opcional) -> Array nativo getUnitLoadout / setUnitLoadout de Arma 3
          ]
```

---

## 5. Pipeline Operativo y Flujo de Transformación

```
[3DEN Custom Composition (.sqe)]
                │
                ▼ (tools/convert_compositions.ps1)
[Doctrines/Data/*.sqf]  ─────────► Pure Data-Driven HashMap
                │
                ▼ (FTCS_fnc_spawnDoctrine)
      Instanciación en 3D
  (Rotación planar 2D de offsets)
                │
                ├─────────────────────────────────────────┐
                ▼                                         ▼
     FTCS_fnc_applyDoctrine                    FTCS_fnc_parseEditorGroups
(Construye el árbol de Compañía:          (Asocia grupos reales del motor,
   FTCS_Company_Data con HQs,              oficiales individuales y escuadras
   Platoons, Squads y Teams)                a las claves de FTCS_Company_Data)
                │                                         │
                └────────────────────┬────────────────────┘
                                     │
                                     ▼
                          FTCS_fnc_registryInit
                   (Rellena el registro plano por grupo:
                        FTCS_Groups_Registry_Table
                     con estados, slots y geometrías)
                                     │
                                     ▼
                      FTCS_fnc_initUnitInteractions
                 (Asigna AddActions diagéticas en 1ª persona:
                   - Retícula / cursorObject sobre líderes
                   - Invocación de commandingMenu nativo [#USER:]
                   - Inyección de órdenes a Escuadra, Pelotón o Teams)
```

---

## 6. Orquestación Jerárquica de Formaciones (Two-Tier Formation Pipeline)

El sistema de formaciones y movimiento concurrente se orquesta mediante el siguiente flujo modular:

```
[Mando: Menú Nativo o Directiva Táctica]
                 │
                 ▼
FTCS_fnc_formationsApplyPlatoonOrder
(1. Resuelve el Pelotón seleccionado desde FTCS_Company_Data)
(2. Verifica fase operacional activa: si está en Phase 0 DEPLOYMENT/INSPECTION -> Bloquea orden)
(3. Estructura el árbol jerárquico de grupos: Escuadras y sus Sub-Equipos)
(4. Dispara FTCS_fnc_formationsTypePlatoonSet)
                 │
                 ├──► FTCS_fnc_formationsTypePlatoonSet
                 │    (Calcula ranuras macro del Pelotón: 0 a 12)
                 │    (Actualiza "formationPosition" y "relPosition" en FTCS_Groups_Registry_Table)
                 │    │
                 │    └──► FTCS_fnc_formationsTypeSquadSet (Recursivo por Escuadra)
                 │         (Calcula ranuras internas de cada Fireteam: Able, Baker, Charlie)
                 │         (Cada Sub-Equipo se orienta y sigue la estela de su Squad Leader)
                 │
                 ▼
FTCS_fnc_formationsGroupListFollowCommander (Batch Asíncrono)
                 │
                 └──► FTCS_fnc_formationsGroupDoFollowCommander (Hilo Concurrente por Grupo)
                      (Cada grupo ejecuta su navegación continua respetando el estado doctrinal)
```
