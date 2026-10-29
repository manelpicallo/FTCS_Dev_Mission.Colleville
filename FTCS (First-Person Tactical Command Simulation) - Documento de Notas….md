# FTCS (First-Person Tactical Command Simulation) - Documento de Notas y Diseño del Proyecto

## 0. INSTRUCCIONES PARA LA IA (LEER ANTES DE HACER NADA)

**Rol:** Eres un programador experto en SQF (Arma 3) y en Enforce Script (Enfusion / Arma Reforger). Trabajas en el proyecto FTCS, cuyo diseño completo está en este documento. Este documento es la fuente de verdad del proyecto.

**Reglas obligatorias de código:**

1. **Comentarios existentes:**
   - NUNCA elimines, resumas ni acortes comentarios existentes sin motivo.
   - Si modificas código y su comentario deja de describirlo con exactitud, **reescribe ese comentario** para que refleje el nuevo comportamiento. No dejes comentarios obsoletos ni añadas uno nuevo al lado del viejo: debe haber un único comentario correcto por bloque.
   - Si eliminas por completo un bloque de código, puedes eliminar su comentario, pero indícalo en el resumen final.
   - Los comentarios de código que no tocas se conservan tal cual, sin retocar su redacción.
   - Todos los comentarios nuevos o reescritos se escriben en **inglés**.
2. **Esquemas ASCII de las cabeceras:**
   - NUNCA los elimines ni los simplifiques.
   - Solo puedes modificarlos si la arquitectura o el flujo de esa función cambia de forma explícita. En ese caso, actualiza el esquema para que coincida con el nuevo funcionamiento y avísame de que lo has hecho.
   - Si cambias la función pero el esquema sigue siendo válido, déjalo exactamente igual.
3. **Compatibilidad con Enfusion:** Todo el código debe ser modular, desacoplado y portable a Enforce Script. Separa lógica y datos (arquitectura data-driven), evita duplicar código (DRY) y evita construcciones SQF difíciles de migrar sin justificarlo. Usa la versión estable actual de Arma 3 y sus comandos nativos, incluido `HashMap`; no propongas alternativas con arrays anidados para sustituirlo.
4. **Cambios mínimos:** Modifica solo lo que se te pide. No reescribas, renombres ni reorganices código no relacionado con la tarea.
5. **Nomenclatura:** Respeta los nombres existentes (prefijo `FTCS_`, variables estándar como `SQUAD_X_Y`, `PLT_X_LEADER`, `HQ_CO_CAPTAIN`, etc.).

**Validación contra este documento:**

- Antes de proponer o modificar código, comprueba que el cambio cumple las especificaciones de este documento.
- Si lo que se te pide contradice el documento, o ves una incoherencia entre el código y el diseño, **AVÍSAME ANTES de continuar**, explica el conflicto y propón alternativas. No lo resuelvas por tu cuenta en silencio.
- Si algo no está definido en el documento, no lo inventes: pregúntame.
- Si un cambio exige actualizar este documento, indícamelo explícitamente.

**Forma de trabajar:**

- Si falta contexto (archivos, funciones relacionadas), pídelo en lugar de suponerlo.
- Entrega el código completo de las funciones modificadas, no fragmentos con "..." que omitan partes.
- Al final de cada respuesta, indica qué comentarios o esquemas ASCII has reescrito o eliminado y por qué. Si no has tocado ninguno, confírmalo.
- Responde en español; el código y sus comentarios, en inglés.

---

## 1. Definición, Alcance y Arquitectura (Compatibilidad con Enfusion / Arma 4)

- **Nombre y Enfoque del Proyecto:** Simulación táctica de combate orientada a la lógica backend, gestión táctica y propagación de órdenes.
- **Compatibilidad Estricta con Enfusion / Arma Reforger (Arma 4):** Todo el diseño de datos, nomenclatura y lógica del sistema se desarrolla de forma modular y desacoplada para asegurar una migración limpia y directa a Enforce Script en el motor Enfusion.
- **Ambientación Histórica:** Simulación enfocada inicialmente en combate táctico de la Segunda Guerra Mundial (WWII), adaptable a futuros escenarios.
- **Directrices de Mantenimiento de Código y Comentarios:** Las reglas completas y obligatorias están en el Punto 0. Resumen:

  - **Comentarios:** No se eliminan sin motivo. Si el código cambia, se reescribe el comentario afectado para que haya un único comentario correcto por bloque. Siempre en inglés.
  - **Esquemas ASCII:** Nunca se eliminan ni se simplifican. Solo se modifican si la arquitectura o el flujo de la función cambia de forma explícita.
- **Hoja de Ruta de Mando y Escalabilidad (Foco Inicial en Teniente):**

  - **Etapa A (Inicial - Pelotón Único):** El jugador asume el rol de teniente al mando de un único pelotón. El desarrollo se centra en la IA táctica propia de los escuadrones y en la interacción física en primera persona.
  - **Etapa B (Escalado - Compañía Completa):** En el futuro, al escalar a nivel de compañía (rol de capitán), el sistema coordinará múltiples pelotones y la IA asumirá el rol del teniente de pelotón.

## 2. Elementos Tácticos Clave a Marcar en el Mapa (Doctrina Militar)

Para que el pelotón y las IAs sepan qué hacer, el mapa táctico permite registrar y transmitir en estructuras de datos los siguientes elementos:

- **Assembly Area (AA) / Zona de Reunión:** Punto de concentración inicial donde la unidad se organiza, revisa equipos y espera la orden de avance (utilizado como punto de spawn o reagrupamiento inicial).
- **Line of Departure (LD) / Línea de Partida:** Referencia lineal en el terreno que marca el inicio oficial del avance coordinado (actúa como trigger lógico para pasar a estado "Avanzando").
- **Axis of Advance / Eje de Avance:** Vector o pasillo principal de progresión de la infantería para evitar fuego amigo.
- **Direction of Advance (Dirección General del Pelotón):** Vector global de progresión asignado a todo el pelotón para alinear el esfuerzo táctico general.
- **Objective (OBJ) / Objetivo Principal:** Hito físico o posición enemiga que debe ser tomada, despejada y consolidada.
- **Support by Fire (SBF) / Posición de Apoyo de Fuego:** Ubicación táctica elevada o con cobertura para ametralladoras pesadas y morteros para enmascarar el asalto.
- **No-Fire Areas / Zonas Prohibidas (Minas / Exclusión):** Áreas de exclusión absoluta (avoid nodes) que el pathfinding evitará rodeándolas.
- **Fallback Points / Puntos de Repliegue:** Rutas y posiciones defensivas secundarias hacia las cuales retirarse de forma ordenada.
- **Casualty Collection Point (CCP) / Punto de Evacuación de Heridos:** Zona segura designada para la recogida y triaje de bajas.

## 3. Fases de Planificación y Trazado de la OPORD

- **Fase 1 (FTCS_Phase = "PLANNING" - Reconocimiento y Preparación):**

  - Las escuadras (IA) permanecen estáticas en la Zona de Reunión (Assembly Area - AA) en formación defensiva.
  - El teniente realiza el reconocimiento previo y, mediante la interacción física con los mandos, abre el mapa para estructurar las directrices.
- **Fase 2 (FTCS_Phase = "EXECUTING" - Orden de Ejecución):**

  - Tras definir las órdenes específicas sobre el mapa, se emite la orden de ejecución. Las IAs reactivan su movimiento y ejecutan de forma autónoma la táctica desde el backend.

## 4. Estructura de Datos y Backend (Gestión de Doctrinas)

- **Definición de Doctrinas y Configuración Inicial:** En la estructura de datos y backend tendremos definidas unas doctrinas que se aplicarán con una configuración inicial del usuario.
- **Método 1 (Variables y Nombres Estándar en Editor):** Si el usuario ha puesto variables determinadas conocidas por nosotros en las unidades y selecciona una doctrina dentro de un menú disponible, el sistema asociará esa doctrina utilizando los nombres que ya tienen esas variables. Esto permite tener diferentes doctrinas operando con una configuración estándar definida por el usuario en el editor.
- **Método 2 (Generación mediante Compositions de Arma):** Las doctrinas también se pueden guardar previamente mediante una integración donde el diseñador pasa al sistema doctrinas con las unidades indicadas a través de *compositions* de Arma. El script leerá dichos ficheros y generará archivos SQF separados para cada doctrina; cuando el usuario la seleccione, el sistema se encargará de respawnear las unidades tal y como estaban configuradas en los archivos de *compositions* creados previamente.
- **Control de Mods de la Segunda Guerra Mundial:** El sistema utilizará tres o cuatro mods principales de la Segunda Guerra Mundial y realizará una comprobación previa. En caso de que el usuario no disponga de alguno de los mods requeridos por la doctrina seleccionada, el sistema emitirá una alerta indicándole exactamente qué mod le falta.

## 5. Sistema de Interacción, Menús y Mapa Táctico Contextual

- **Interacción Física:** Emisión de órdenes mediante interacción directa in-game (interacción con el sargento de pelotón para abrir el mapa táctico).
- **Acciones Contextuales por Rol:** Diferenciación entre los menús y capacidades disponibles según la posición de mando (Teniente de Pelotón vs. Capitán de Compañía).
- **Renderizado del Mapa Táctico:** Dibujo de símbolos militares y vectores directamente sobre la interfaz de mapa mediante la captación de eventos de usuario.

## 6. Mecanizaciones de Inmersión, Comunicaciones y Liderazgo Directo

- **Graduación de Distancias y Propagación:** Transmisión de órdenes físicas a viva voz en corta distancia vs. uso de RTO/Radio a larga distancia.
- **Desarrollo e Inclusión de la Función de Mensajeros NPC:** Se integra explícitamente el sistema de estafetas o mensajeros a pie como pilar fundamental de comunicaciones y transmisión de órdenes en combate cuando no se dispone de radios o el mando opera en vanguardia, evitando transmisiones instantáneas e implementando la lógica de desplazamiento táctico e inteligente en zonas de riesgo.
- **Métodos de Interacción y Emisión de Órdenes a Escuadrones y Pelotones:**

  - **Órdenes Generales a través del Sargento:** Para dar una orden genérica a todo el pelotón o a los diferentes escuadrones, se interactúa físicamente sobre el sargento. El sargento enviará los mensajeros necesarios de los que disponga para transmitir dichas órdenes.
  - **Reunión de Líderes de Escuadrón y Mapa Táctico (Opción A):** Es posible reunir físicamente a los *squad leaders* y abrir el mapa táctico frente a ellos. En este escenario, las órdenes se transmiten de forma inmediata a los cuatro escuadrones, tras lo cual cada *squad leader* se desplaza a su ubicación para iniciar la maniobra táctica decidida.
  - **Interacción Individual con Líder de Escuadrón (Opción B):** Si nos situamos específicamente delante del líder de un escuadrón concreto y abrimos el mapa, las órdenes se restringen y se transmiten exclusivamente a ese escuadrón en particular, simulando de forma realista las conversaciones directas de mando en primera persona.
  - **Restricción de Acciones por Rol y Jurisdicción:** El Teniente de Pelotón solo despliega menús interactivos de órdenes sobre las unidades y líderes de su propia demarcación orgánica; si se acerca a unidades ajenas no aparecen menús de mando, mientras que al interactuar con el Cuartel General superior (Capitán/HQ) se despliega un menú de subordinado para solicitar apoyos o reportar estado.
- **Moral y Cohesión de Escuadra:** Ponderación dinámica de la efectividad de la IA en función de la cercanía del líder de escuadra y las bajas sufridas.

## 7. Definición de Funciones Genéricas de Combate (Funciones Independientes)

- **Función 1: Sistema de Cobertura Dinámica y Análisis Geográfico**

  - **Análisis Geográfico y de Objetos del Terreno:** Funciones backend encargadas de examinar la malla de elevaciones de la superficie y los objetos estáticos del mapa para calcular puntos seguros de cobertura geométrica.
  - **Determinación del Vector de Amenaza:** Las unidades calculan el origen de la amenaza en función de la procedencia del fuego o, por defecto, orientándose respecto a la dirección de avance establecida.
  - **Diferenciación de Respuesta a Amenazas (Balas vs. Explosivos):**

    - Mediante el uso de controladores de eventos y monitores del entorno (como el manejo de impactos o eventos del tipo nearFire), el sistema discierne si el ataque proviene de fuego ligero de fusilería o de fuego indirecto / artillería con munición explosiva.
    - La IA adapta automáticamente su reacción defensiva (búsqueda de cobertura vertical ante disparos directos frente a dispersión y búsqueda de planicie/zanja o trinchera ante caída de proyectiles explosivos).
  - **Optimización de Validación Espacial:** Comprobación de colisión estricta en las funciones de cálculo de cobertura para evitar que la IA asigne posiciones en colisiones geométricas inválidas o muros destruidos.
- **Función 2: Posicionamiento y Cálculo Automático de Ametralladoras Pesadas (Support by Fire / Defilade)**

  - **Enfoque Específico:** Función dedicada en exclusiva a equipos de ametralladoras pesadas de la Segunda Guerra Mundial (MG42, Browning M1919, etc.).
  - **Modo Manual o Automático:** El jugador puede designar manualmente el punto exacto de la posición de apoyo (SBF) o indicar únicamente la zona/edificio/enemigo a batir para que el algoritmo backend busque y elija automáticamente la posición táctica óptima.
  - **Cálculo Táctico de Línea de Visión (LoS) y Desenfilada (Defilade):** La función calcula un punto ventajoso que garantice línea de visión directa (Line of Sight) sobre el objetivo a batir, priorizando la desenfilada (defilade) y el uso de micro-relieves o vegetación para que la dotación de la ametralladora pueda batir el sector sin exponerse prematuramente al fuego directo enemigo.
  - **Persistencia y Priorización de Órdenes de Supresión:** Las directrices de fuego de apoyo asignadas a las ametralladoras en SBF mantendrán prioridad absoluta frente a micro-movimientos evasivos menores, garantizando la continuidad de la supresión sobre el objetivo designado.
- **Función 3: Sistema de Amunicionamiento Automático de Unidades Desplegables**

  - **Enfoque Específico:** Solución a la deficiencia nativa de la IA de Arma 3, donde los componentes de un grupo dotados de munición compatible no transfieren automáticamente los cargadores o proyectiles a las armas estáticas o desplegables (como ametralladoras pesadas o morteros) cuando estas se quedan vacías.
  - **Gestión Dinámica de Reparto:** El sistema monitoriza en segundo plano las reservas de munición de las armas desplegables de apoyo. En el momento en que el arma se queda sin municiones, los amunicionadores o miembros del grupo designados distribuyen y transfieren automáticamente la munición correspondiente al arma de disparo, asegurando la continuidad ininterrumpida del fuego de apoyo (ametralladoras, morteros u otras armas desplegables).
- **Función 4: Sistema Inteligente de Despliegue y Gestión de Mensajeros**

  - **Enfoque Específico:** Simulación de comunicaciones reales en un contexto de la Segunda Guerra Mundial donde no se disponía de radios, utilizando unidades con la propiedad y rol de mensajero (*estafetas*).
  - **Interacción y Emisión de Órdenes:** El jugador (teniente, comandante o líder de unidad) interactúa mediante el menú de ADD ACTION sobre la unidad de mensajero para asignarle una orden táctica (por ejemplo, basada en un despliegue de mapa).
  - **Navegación Autónoma y Ciclo de Misión:** El mensajero se desplaza de forma autónoma hacia el escuadrón o líder de destino específico, llega al punto para entregar la orden / ejecutar la planificación y posteriormente realiza el trayecto de vuelta a su posición de origen.
  - **Desplazamiento Táctico e Inteligente en Combate:** Para evitar que el mensajero se comporte como un autómata o camine en línea recta (*move to* directo) exponiendo su vida en medio del campo de batalla, la función incluye un análisis constante de la situación: evalúa zonas de fuego activo, busca coberturas de forma dinámica cuando atraviesa áreas peligrosas, adopta posturas defensivas si es atacado en tránsito y garantiza un desplazamiento táctico seguro en lugar de cruzar al descubierto como un zombi.

## 8. Definición Doctrinal, Reconocimiento del Editor, Respawneo Doctrinal y Estructuras de Apoyo

- **Menú Inicial de Selección Doctrinal y Traducción de *Compositions*:** Al iniciar la partida con el mod activo, se despliega un menú inicial con un desplegable donde el jugador selecciona la doctrina que desea utilizar. Previamente, las doctrinas se estructuran como *compositions* de Arma que el sistema traduce a ficheros SQF ejecutables para ensamblar toda la lógica de datos y realizar el respawneo aplicando un control estricto de compatibilidad y verificación de los mods de la Segunda Guerra Mundial necesarios.
- **Lógica Geográfica de Respawn para Tropas Principales:**

  - Si el editor de la misión ha establecido una marca específica en forma de recuadro en el terreno, el respawneo de las unidades doctrinales se efectúa automáticamente sobre dicha zona.
  - Si no existe ninguna marca previa del editor, el sistema permite que el jugador seleccione e indique directamente el punto de emplazamiento inicial.
- **Respawn de Cuarteles Generales de Compañía (*Company HQ*):** Independientemente de que el nivel operativo de la misión sea de pelotón, se incluye obligatoriamente el respawneo del Cuartel General de la compañía mediante un archivo SQF derivado de *compositions* para garantizar la comunicación superior. Su posición se determina mediante una marca específica designada por el editor de la misión o, en su defecto, indicada de forma interactiva por el jugador.
- **Despliegue de Unidades de Apoyo y Activos Externos:**

  - **Unidades Fijas y Estáticas (Secciones de Morteros / Artillería):** Al tratarse de elementos estáticos, su respawneo se realiza de forma automática en una zona de despliegue específica previamente delimitada mediante una marca en el terreno por el editor de la misión.
  - **Unidades Móviles (Cañones de Asalto / Vehículos tipo StuG III):** Al tratarse de elementos dinámicos con capacidad de desplazamiento autónomo, se integran y respawnean directamente en la misma área general de respawn asignada a las unidades de infantería de la doctrina correspondiente.
- **Estructura Modular en Headquarters (HQ Sub-Teams):**

  - Los Cuarteles Generales de Compañía (PLT_0) y de Pelotón (SQD_X_0) se estructuran mediante sub-equipos flexibles (*Teams*) de mínimo dos secciones ampliables a una tercera:

    1. **Team 1:** Elemento de Mando y Comunicaciones Directas.
    2. **Team 2:** Elemento de Liderazgo, Estafetas/Mensajeros y Apoyo Sanitario.
    3. **Team 3:** Elemento opcional ampliable para soporte logístico o especializado según la doctrina.

  > **Nota de nomenclatura (pendiente de confirmar):** `PLT_0` designa el HQ de compañía y `SQD_X_0` el HQ de pelotón, aunque en el resto del documento `PLT_` es pelotón y `SQD_` es escuadra. Si hay un conflicto con el código, la IA debe avisar antes de renombrar nada.
- **Arquitectura del Motor Genérico de Spawn Doctrinal (Data-Driven Architecture & Enfusion Portability):**

  - **Filosofía de Diseño (Desacoplamiento Código/Datos):** Para garantizar compatibilidad total con Enforce Script (Arma 4/Enfusion) y evitar la duplicación de código procedural (violación DRY), **no se crean funciones SQF separadas por cada doctrina**. En su lugar, el sistema implementa un único componente motor genérico (`FTCS_fnc_spawnDoctrine`) que consume plantillas de datos puros (`HashMap` / `Struct`).
  - **Pipeline de Creación y Conversión de Doctrinas:**

    1. *Diseño Visual:* El diseñador compone libremente la fuerza en el 3DEN Editor de Arma 3 (infantería, armas estáticas, morteros, transportes, blindados) y asigna las variables estándar (`SQUAD_X_Y`, `PLT_X_LEADER`, `HQ_CO_CAPTAIN`, etc.).
    2. *Exportación Nativa:* Se guarda como Custom Composition en el editor (`composition.sqe`).
    3. *Traducción a Datos Puros:* Un script o convertidor extrae los `addons[]` y entidades del `.sqe` a un archivo de datos estructurado (ej. `Doctrines/Data/US_Airborne.sqf`).
  - **Estructura de Datos de una Doctrina (Doctrinal Data Template):**
    Cada archivo doctrinal devuelve un `HashMap` con la siguiente especificación:

    - `"doctrineID"`: [String] Clave identificadora (ej. `"US_AIRBORNE"`).
    - `"companyLetter"`: [String] Letra de compañía (ej. `"E"`).
    - `"requiredMods"`: [Array de Strings] Clases de `CfgPatches` requeridas (ej. `["WW2_Core", "WW2_Assets"]`).
    - `"entities"`: [Array de Arrays] Lista de entidades a spawnear con la tupla:
      `[className, [offsetX, offsetY, offsetZ], relativeDir, varName, squadRole, rank, isVehicle, initialCrewRoles]`
  - **Lógica de Ejecución del Motor Genérico (`FTCS_fnc_spawnDoctrine`):**

    - **Paso 1 (Verificación de Compatibilidad de Mods):** Itera sobre `"requiredMods"` comprobando `isClass (configFile >> "CfgPatches" >> _x)`. Si falta alguno, interrumpe el despliegue con alerta visual detallando los addons ausentes.
    - **Paso 2 (Transformación Geométrica Espacial):** Recibe la posición de anclaje (Assembly Area / coordenada seleccionada en mapa) y el vector de avance (`FTCS_Platoon_Advance_Direction`). Aplica rotación trigonométrica en 2D a los offsets relativos para orientar a todo el contingente en la dirección táctica sin deformar la formación original de la composición.
    - **Paso 3 (Instanciación y Asignación de Roles):** Spawnea soldados y vehículos (`createUnit` / `createVehicle`), ejecuta `setVehicleVarName` y registra los objetos en `missionNamespace`.
    - **Paso 4 (Auto-enlace con el Backend):** Dispara en cadena la secuencia de inicialización del core:
      `FTCS_fnc_applyDoctrine` -> `FTCS_fnc_parseEditorGroups` -> `FTCS_fnc_initCompanyCommand` -> `FTCS_fnc_syncGroupNames` -> `FTCS_fnc_registryInit` -> `FTCS_fnc_initUnitInteractions`.
