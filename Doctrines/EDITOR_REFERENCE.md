# FTCS - Guía de Referencia Editor (3DEN) para Generación de Doctrinas

> **Fuente de verdad:** Documento de Notas FTCS (sección 8) + `Functions\Core\fn_applyDoctrine.sqf` + `Functions\Core\fn_parseEditorGroups.sqf` + `Functions\Spawning\fn_spawnDoctrine.sqf`.
>
> Este documento es la guía obligatoria para diseñar composiciones en el editor de Arma 3 que el conversor traducirá a ficheros SQF de doctrina bajo `Doctrines\Data\`.

---

## 1. Concepto clave: la unidad de diseño es el TEAM, no el SQUAD

En FTCS la estructura táctica real es:

```
Compañía (PLT_0 / SQD_0_0)
└── Pelotón X (SQD_X_0 = HQ del pelotón)
    ├── Escuadra 1 (SQD_X_1)  ← contenedor lógico del backend
    │   ├── SQD_X_1_TEAM_1   ← grupo físico de Arma (variable de grupo del editor)
    │   ├── SQD_X_1_TEAM_2   ← grupo físico de Arma
    │   ├── SQD_X_1_TEAM_3   ← (opcional)
    │   └── SQD_X_1_TEAM_4   ← (opcional)
    ├── Escuadra 2 (SQD_X_2) ...
    └── Escuadra 4 (SQD_X_4)  ← ej. sección de morteros: MONO-TEAM, sin subdivisión
```

- **Cada TEAM = un grupo físico de Arma en el editor** (soldados encuadrados en el mismo grupo). Es la unidad que el jugador selecciona, mueve y ordena. Su variable de grupo es `SQD_X_Y_TEAM_N`.
- **El SQUAD es un contenedor lógico** que agrupa 1–4 teams. Se forma automáticamente: todos los teams cuyo ID comparte el par `X_Y` pertenecen a la misma escuadra.
- **Un squad mono-team** (morteros, ametralladoras pesadas, apoyo) es simplemente un grupo único `SQD_X_Y_TEAM_1`: el backend lo detecta y lo trata como sección unificada sin dividirlo.
- **Variable de GRUPO** (panel del grupo): la asignación del team → `SQD_X_Y_TEAM_N`.
- **Variable de UNIDAD** (panel de la unidad): la asignación del rol dentro del team/squad (líder, médico, RTO...).

### Nomenclatura unificada (una sola capa)

| Prefijo | Capa | Qué es | Quién lo usa |
|---|---|---|---|
| `SQD_X_Y_TEAM_N` | Variable de GRUPO del editor | El grupo físico instanciado en el mundo. El parser (`fn_parseEditorGroups.sqf`) lo normaliza a `SQD_X_Y` + team y lo registra en el ORBAT. El ID del team en el backend es **exactamente el mismo** | **El editor** (así se escribe) y el motor de spawn |
| `SQD_X_Y` | Backend lógico | Nodo del ORBAT en `FTCS_Company_Data` / `squadsRegistry`, derivado automáticamente del prefijo de las variables del editor | El backend (menús, órdenes, registry) |
| `SQD_X_Y_LEADER` | Variable de UNIDAD del editor | Rol del líder de escuadra | **El editor** (variable de unidad del líder) |

> **Nomenclatura unificada:** editor y backend usan el mismo formato `SQD_X_Y_TEAM_N`. No existe una capa de prefijos distinta: la variable de grupo que escribes en el editor es literalmente el ID del team en el backend. El parser acepta `SQUAD_` como prefijo legacy por compatibilidad, pero el formato canónico es `SQD_`.

> **Regla de oro:** todas las unidades de un mismo team llevan la **misma variable de grupo** `SQD_X_Y_TEAM_N`. Si la dejas vacía, el motor intenta deducirla del prefijo del `varName` (`HQ_`, `PLT_X_`, `SQD_X_Y_`), y si tampoco la hay, colapsa la unidad en `SQUAD_1_1`.

---

## 2. Nomenclatura de Grupos (Variable de GRUPO en el editor)

| Estructura | Variable de grupo | Grupos físicos | Notas |
|---|---|---|---|
| HQ de Compañía | `SQD_0_0_TEAM_1` ... `SQD_0_0_TEAM_3` | 2–3 grupos | Team 1: Mando y Comunicaciones · Team 2: Liderazgo, Estafetas y Sanidad · Team 3 (opcional): Logística/Especializado |
| HQ de Pelotón X | `SQD_X_0_TEAM_1`, `SQD_X_0_TEAM_2` | 2 grupos | Team 1: Elemento de Mando (líder + RTO) · Team 2: Elemento de Apoyo (sargento + estafeta + médico) |
| Escuadra X_Y | `SQD_X_Y_TEAM_1` ... `SQD_X_Y_TEAM_4` | 1–4 grupos | Máximo 4 teams por escuadra, más el sargento independiente si la doctrina lo define |
| Escuadra mono-team (morteros/apoyo) | `SQD_X_Y_TEAM_1` (único) | 1 grupo | Sección unificada; el backend NO la subdivide |

**Reglas de los sufijos:**
- El primer número `X` = pelotón (0 = HQ compañía, 1–3 = pelotones).
- El segundo número `Y` = escuadra dentro del pelotón (0 = HQ del pelotón, 1–4 = escuadras de combate).
- `TEAM_N` = team N-ésimo dentro de esa escuadra (1–4).

**Ejemplo de compañía completa (3 pelotones, escuadras de 2 teams):**
- `SQD_0_0_TEAM_1` → HQ Cía: mando y comunicaciones
- `SQD_0_0_TEAM_2` → HQ Cía: liderazgo, estafetas y sanidad
- `SQD_1_0_TEAM_1` → HQ Pelotón 1: elemento de mando
- `SQD_1_0_TEAM_2` → HQ Pelotón 1: elemento de apoyo
- `SQD_1_1_TEAM_1`, `SQD_1_1_TEAM_2` → Escuadra 1 del pelotón 1 (2 fire teams)
- `SQD_1_4_TEAM_1` → Sección de morteros del pelotón 1 (mono-team)
- `SQD_2_0_TEAM_1`, ... → Pelotón 2 (idéntico patrón)
- `SQD_3_0_TEAM_1`, ... → Pelotón 3 (idéntico patrón)

> El ID de squad `SQD_X_Y` y el ID de team `SQD_X_Y_TEAM_N` se derivan automáticamente de estas variables; no hay que crear nada más.

---

## 3. Variables de UNIDAD por Rol

> Solo llevan variable de unidad los líderes y roles especiales. El resto de miembros de un team **van sin variable** (vacía).

### 3.1 HQ de Compañía (teams `SQD_0_0_TEAM_1/2/3`)

| Rol | Team | Variable de unidad | Rango |
|---|---|---|---|
| Capitán (**jugador en modo Compañía**) | Team 1 | `HQ_CO_CAPTAIN` | CAPTAIN |
| Teniente Ejecutivo (XO) | Team 1 | `HQ_XO_LIEUTENANT` | LIEUTENANT |
| Primer Sargento | Team 1 | `HQ_FIRST_SERGEANT` | SERGEANT |
| Sargento de Comunicaciones | Team 2 | `HQ_COMM_SERGEANT` | SERGEANT |
| Operador de radio (RTO SCR-300) | Team 2 | `HQ_RADIO_OPERATOR` | PRIVATE |
| Mensajero A | Team 2 | `HQ_MESSENGER_1` | PRIVATE |
| Mensajero B | Team 2 | `HQ_MESSENGER_2` | PRIVATE |
| Médico de compañía | Team 2 | `HQ_MEDIC` | PRIVATE |

### 3.2 HQ de Pelotón (teams `SQD_X_0_TEAM_1/2`)

| Rol | Team | Variable de unidad | Rango |
|---|---|---|---|
| Teniente (**jugador en modo Pelotón**, solo X=1) | Team 1 | `PLT_1_LEADER` | LIEUTENANT |
| Operador de radio de pelotón | Team 1 | `PLT_X_RTO` | PRIVATE |
| Sargento de pelotón | Team 2 | `PLT_X_SERGEANT` | SERGEANT |
| Corredor / estafeta | Team 2 | `PLT_X_1RUNNER` | PRIVATE |
| Médico de pelotón | Team 2 | `PLT_MEDIC_X` | PRIVATE |

> En modo Pelotón el jugador ocupa el slot `PLT_1_LEADER`. Los HQ de pelotones 2 y 3 solo se despliegan en modo Compañía.

### 3.3 Escuadras de Combate (teams `SQD_X_Y_TEAM_N`)

| Rol | Team | Variable de unidad | Rango |
|---|---|---|---|
| Líder de escuadra (Sargento, suele ir en el Team 1) | Team 1 | `SQD_X_Y_LEADER` | SERGEANT |
| Suboficial / segundo (opcional) | Team 2 | `SQD_X_Y_ASSIST` | CORPORAL |
| Resto de miembros | todos | *(vacía)* | PRIVATE |

> **Crítico:** la variable del líder (`SQD_X_Y_LEADER`) debe llevar el mismo `X_Y` que sus teams (`SQD_X_Y_TEAM_N`). El motor usa ese prefijo para vincular unidades sin variable de grupo a la escuadra correcta.

### 3.4 Secciones Mono-Team (morteros, MG pesadas, apoyo)

| Rol | Variable de unidad | Rango |
|---|---|---|
| Líder de sección | `SQD_X_Y_LEADER` | SERGEANT |
| Resto | *(vacía)* | PRIVATE |

El backend las registra como escuadra unificada **sin sub-teams** — no las subdividas en el editor.

---

## 4. Unidades de Apoyo (fuera de la jerarquía de teams)

| Tipo | Ubicación de spawn | Notas |
|---|---|---|
| Artillería / morteros estáticos | Marcador del editor (`ftcs_artillery`) | Spawn automático en la marca |
| Blindados móviles (StuG, etc.) | Junto a la zona de despliegue | Offset lateral respecto a la dirección de avance |
| Transportes | Offset de la composición | Integrados en el grupo correspondiente |

Los vehículos se detectan por clase; el conversor los marca con `isVehicle = true` (7º campo). La variable de unidad (si procede) va en el vehículo, no en su dotación.

---

## 5. Reglas Críticas del Despliegue

1. **Variable de grupo `SQD_X_Y_TEAM_N` obligatoria** en todas las unidades de un team. Vacía = riesgo de colapso en `SQUAD_1_1`.
2. **Variables de unidad únicas**: nunca reutilizar nombres de clase de items/armas como `varName` (ej. `B_SPE_US_M36_MGunner` es inválido).
3. **Filtro por escalón:**
   - Modo **Pelotón**: solo se despliegan el HQ de compañía (`SQD_0_0_*`), el 1er pelotón completo (`SQD_1_*`) y variables `HQ_*` / `PLT_1_*`.
   - Modo **Compañía**: se despliega todo.
4. **Slots del jugador:** `HQ_CO_CAPTAIN` (capitán) y `PLT_1_LEADER` (teniente). El jugador se teletransporta a esa posición y toma el mando de su team/grupo.
5. **Rango:** asígnalo en el editor según las tablas (CAPTAIN/LIEUTENANT/SERGEANT/CORPORAL/PRIVATE).
6. **Límite estructural:** máximo **4 teams por escuadra** de combate + sargento independiente; HQs con 2–3 teams según las tablas.

---

## 6. Checklist Antes de Exportar

- [ ] Cada team es un grupo físico con variable `SQD_X_Y_TEAM_N` correcta
- [ ] Escuadras con 1–4 teams; secciones de morteros/apoyo en un único team
- [ ] Líder de escuadra con variable `SQD_X_Y_LEADER` coincidente con el `X_Y` de sus teams
- [ ] Roles HQ con variables `HQ_*` / `PLT_X_*` según las tablas
- [ ] Sin variables de unidad duplicadas ni basadas en clases de items
- [ ] Rangos coherentes con las tablas (CAPTAIN/LIEUTENANT/SERGEANT/CORPORAL/PRIVATE)
- [ ] Composición guardada como Custom Composition (`composition.sqe`)
- [ ] Tras convertir: verificar que el SQF generado tiene `groupVar` relleno en todas las entidades (5º campo) y ningún `varName` duplicado

---

## 7. El fichero de doctrina es AUTOCONTENIDO (estructura embebida)

Tras generar el fichero SQF en `Doctrines\Data\`, el fichero debe contener **toda** la estructura organizativa — no solo las entidades. `fn_configDoctrines.sqf` es el sistema antiguo (Método 1: unidades pre-colocadas con variables del editor de misión) y **no aporta estructura a las doctrinas por composición**.

El HashMap doctrinal generado por la tool incluye el esqueleto organizativo, que el diseñador **revisa y completa tras la conversión**:

| Clave | Contenido | Ejemplo |
|---|---|---|
| `platoonNames` | Nombre de cada pelotón (incl. "Company HQ") | `"1st Airborne Platoon"` |
| `squadsPerPlatoon` | Nº de escuadras por pelotón (1–4) | `4` |
| `squadDesignations` | **Identidad semántica de cada squad** (HashMap `SQD_X_Y` → nombre) | `"SQD_1_4": "Mortar Section"` |
| `teamStructure` | Nombres de teams por escuadra | `"Scout Team", "Rifle Team A"...` |
| `teamRoles` | Rol táctico por team (ASSAULT/SUPPORT) | `"ASSAULT"...` |
| `companyHQRoles` / `platoonHQRoles` / `platoonHQTeamStructure` | Roles y sub-teams de los HQs | — |
| `isMechanized` / `transportAsset` | Transporte orgánico | — |

**Respuesta a la pregunta del squad:** el nombre del squad completo ("1st Rifle Squad", "Mortar Section") **no se asigna en el editor** — el squad no existe como objeto del editor. Se declara en `squadDesignations` del fichero de doctrina. El editor define la geometría y jerarquía (teams); el fichero define la identidad semántica (squads).

Registro final:

1. Añade el nombre del fichero (sin `.sqf`) a `Doctrines\Data\Doctrines_Registry.sqf`.
2. Asegúrate de que el HashMap interno tiene `"doctrineID"` con la clave canónica (ej. `"US_AIRBORNE"`).
3. El desplegable del menú de despliegue se rellena automáticamente desde el registro — no hay lista fija que editar.

---

*Última revisión: 2026-10-31 · Tupla de entidades: 7 campos `[className, offsetXYZ, relativeDir, varName, groupVar, rank, isVehicle]` (Opción A confirmada). Nomenclatura unificada `SQD_X_Y_TEAM_N`: la variable de grupo del editor es literalmente el ID del team en el backend (formato canónico `SQD_`; `SQUAD_` aceptado como legacy por el parser). El fichero de doctrina es autocontenido (Método 2); `fn_configDoctrines.sqf` solo aplica al Método 1.*
