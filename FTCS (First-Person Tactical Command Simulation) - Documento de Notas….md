# FTCS (First-Person Tactical Command Simulation) - Documento de Notas y Diseño del Proyecto

## 0. INSTRUCCIONES PARA LA IA (LEER ANTES DE HACER NADA)

**Rol:** Eres un programador experto en SQF (Arma 3) y en Enforce Script (Enfusion / Arma Reforger). Trabajas en el proyecto FTCS, cuyo diseño completo está en este documento. Este documento es la fuente de verdad del proyecto.

**Reglas obligatorias de código:**

1. **Principio de Responsabilidad Única (SRP):**
   - Cada función debe realizar una única tarea clara y específica. Si una función supera las 200-250 líneas de código ejecutable, debe ser refactorizada en subfunciones más pequeñas, excepto si es una funcion.Las fuciones deben de ser reutilizables en el proyecto, por tanto debes valorar siempre si esa funcion tendra utiliad en algun otro de los puntos descriptivos donde se explica el alcance del proyecto.
   - Quedan estrictamente prohibidas las funciones anidadas profundas o los bloques de código monolíticos que mezclen lógica de IA, gestión de UI, efectos de red y control de estado en un mismo bloque.
2. **Estructura y Aislamiento de Archivos (SQF / Enforce Script):**
   - Diseña siempre pensando en la compilación modular a través de `CfgFunctions` (en SQF) o clases limpias (en Enforce). Cada función lógica debe residir en su propio archivo independiente con nomenclatura estándar (ej. `fn_spawnTacticalComposition.sqf`).
   - Evita el uso excesivo de variables globales ocultas. Toda función debe recibir sus dependencias o parámetros de entrada de forma explícita mediante `params` (o firmas tipadas) y devolver resultados claros.
3. **Desacoplamiento de Capas:**
   - La lógica de simulación/cálculo táctico debe estar completamente desacoplada de la interfaz de usuario (Rsc / Dialogs) y de los manejadores de eventos (EventHandlers).
   - Utiliza patrones orientados a eventos o colas de mensajes ligeras cuando los módulos deban comunicarse entre sí, evitando dependencias circulares directas entre sistemas (ej. el sistema de moral no debe llamar directamente a la UI de comandos, sino emitir un evento o actualizar una estructura de datos central).
4. **Diseño Orientado a la Portabilidad (Arma 3 a Arma 4):**
   - Escribe el código SQF emulando buenas prácticas de programación estructurada y modular que faciliten una futura traducción limpia a Enforce Script (clases, métodos cohesivos, tipado lógico documentado en comentarios).
5. **Comentarios existentes:**
   - NUNCA elimines, resumas ni acortes comentarios existentes sin motivo.
   - Si modificas código y su comentario deja de describirlo con exactitud, **reescribe ese comentario** para que refleje el nuevo comportamiento. No dejes comentarios obsoletos ni añadas uno nuevo al lado del viejo: debe haber un único comentario correcto por bloque.
   - Si eliminas por completo un bloque de código, puedes eliminar su comentario, pero indícalo en el resumen final.
   - Los comentarios de código que no tocas se conservan tal cual, sin retocar su redacción.
   - Todos los comentarios nuevos o reescritos se escriben en **inglés**.
6. **Esquemas ASCII de las cabeceras:**
   - NUNCA los elimines ni los simplifiques.
   - Solo puedes modificarlos si la arquitectura o el flujo de esa función cambia de forma explícita. En ese caso, actualiza el esquema para que coincida con el nuevo funcionamiento y avísame de que lo has hecho.
   - Si cambias la función pero el esquema sigue siendo válido, déjalo exactamente igual.
7. **Compatibilidad con Enfusion:** Todo el código debe ser modular, desacoplado y portable a Enforce Script. Separa lógica y datos (arquitectura data-driven), evita duplicar código (DRY) y evita construcciones SQF difíciles de migrar sin justificarlo. Usa la versión estable actual de Arma 3 y sus comandos nativos, incluido `HashMap`; no propongas alternativas con arrays anidados para sustituirlo.
8. **Cambios mínimos:** Modifica solo lo que se te pide. No reescribas, renombres ni reorganices código no relacionado con la tarea.
9. **Nomenclatura:** Respeta los nombres existentes (prefijo `FTCS_`, variables estándar como `SQUAD_X_Y`, `PLT_X_LEADER`, `HQ_CO_CAPTAIN`, etc.).
10. **Alcance Estricto de Ficheros de Código (`functions`):** Dentro de la carpeta de funciones (`functions`), la IA solo debe analizar, leer o modificar aquellas funciones que estén explícitamente listadas o referenciadas en el fichero `description.ext` (o `description.txt`). Cualquier otro archivo de código fuera de ese listado debe ser estrictamente ignorado para evitar análisis o modificaciones innecesarias de módulos en desuso. (Los directorios de datos como `Doctrines\Data\` y la documentación sí pueden examinarse libremente).
11. **Idioma y Localización de Componentes:**
   - Todos los **menús, interfaces de usuario (UI), textos en pantalla, acciones del motor (AddAction / UserActions), código y comentarios** se escriben estrictamente en **inglés**.
   - Los únicos elementos que se redactan y mantienen en **castellano** son:
     - Las herramientas y scripts externos generados en la carpeta `tools/` (ej. scripts de PowerShell, batch files, utilidades de conversión).
     - Este propio **documento de diseño y notas** (`FTCS (First-Person Tactical Command Simulation) - Documento de Notas….md`).
     - La comunicación y respuestas directas con el usuario en el chat.
12. **Mapeo Obligatorio de Facciones y Bandos en el Motor (Arma 3 / WWII):**
   - **BLUFOR (`west`):** Eje / Axis $\rightarrow$ Alemania (*Wehrmacht / Waffen-SS*) e Imperio del Japón (*IJA*).
   - **OPFOR (`east`):** Unión Soviética / URSS $\rightarrow$ Ejército Rojo (*Red Army*).
   - **INDEPENDENT / GUERRILLA (`resistance` / `independent`):** Aliados Occidentales $\rightarrow$ Estados Unidos (*US Army, US Airborne, US Rangers*) y Gran Bretaña (*British Army, Parachute Regt*).
   - En composiciones 3DEN (`composition.sqe`), los grupos de unidades aliadas deben declararse con `side="Independent";` o `side="Guerrila";` (que el motor y el conversor mapean a `resistance`), nunca como `West`.
   - Las plantillas doctrinales (`Doctrines/Data/*.sqf`) deben declarar obligatoriamente:
     - Aliados: `["side", resistance]`
     - Eje: `["side", west]`
     - Soviéticos: `["side", east]`
   - En `init.sqf` la diplomacia del motor (`setFriend`) debe garantizar cohesión interna y hostilidades históricas estrictas para evitar fuego amigo al desplegar facciones aliadas.
13. **Sincronización Obligatoria de la Estructura de Menús (`FTCS_Menu_Structure_Reference`):**
   - La IA debe mirarse siempre el documento `FTCS_Menu_Structure_Reference` para que lo actualice obligatoriamente siempre que toque algo referente al tema de ese fichero, que son los menús e interfaces de comando, manteniendo rigurosamente el formato original del fichero con las modificaciones oportunas.
14. **Aviso Obligatorio de Recompilación de `CfgFunctions` (`description.ext`):**
   - Cuando la IA genere o cree una nueva función y la añada al fichero `description.ext` (o modifique las clases de `CfgFunctions`), es **estrictamente obligatorio avisar al programador al final de la respuesta** con una línea destacada y clara indicando que se ha añadido una nueva función.
   - Debe advertirse explícitamente que es **imprescindible salir de la misión, pasar por el editor 3DEN y volver a entrar (o recargar)**, ya que un simple reinicio (*Restart*) in-game no recompila `description.ext` ni carga funciones nuevas en el motor de Arma 3.
15. **Control Centralizado de IA, Órdenes y Reglas de Enfrentamiento (ROE):**
   - Queda estrictamente prohibido aplicar mas de tres comandos nativos directos de Arma 3 que alteren el comportamiento de IA (movimiento, combate, posturas, velocidad, reglas de enfrentamiento / ROE o emisión de órdenes tácticas de líderes a unidades o grupos) de forma aislada o descontrolada.
   - Cualquier cambio en la conducta, movimiento o directivas de unidades o grupos debe ejecutarse obligatoriamente a través de **funciones prefijadas/estandarizadas del proyecto**.
   - Estas funciones son las únicas responsables de aplicar los comandos y registrar/sincronizar de manera consistente el estado operativo tanto a nivel de soldado individual como de grupo. 
   Si se necesita alterar este punto, es obligatorio preguntar al programador antes de ejecutar cualquier modificacion de este supuesto.

**Validación contra este documento:**

- Antes de proponer o modificar código, comprueba que el cambio cumple las especificaciones de este documento.
- Si lo que se te pide contradice el documento, o ves una incoherencia entre el código y el diseño, **AVÍSAME ANTES de continuar**, explica el conflicto y propón alternativas. No lo resuelvas por tu cuenta en silencio.
- Si algo no está definido en el documento, no lo inventes: pregúntame.
- Si un cambio exige actualizar este documento, indícamelo explícitamente.
- **Sincronización Obligatoria de la Estructura de Datos:** La especificación y el árbol formal de todas las tablas de hash y modelos de datos del proyecto (`FTCS_Company_Data`, `FTCS_Groups_Registry_Table`, plantillas doctrinales, tuplas y estados) residen en el fichero `FTCS_Data_Structure_Reference.md`. Si cualquier tarea modifica, amplía o altera campos, estructuras o enumeraciones en el código backend, **la IA debe actualizar obligatoriamente dicho fichero `FTCS_Data_Structure_Reference.md`** para mantenerlo siempre como referencia técnica viva y exacta.
- **Sincronización Obligatoria de la Estructura de Menús:** La arquitectura, jerarquía y definición de los menús e interfaces de comando del proyecto residen en el documento `FTCS_Menu_Structure_Reference`. La IA debe mirarse siempre el documento `FTCS_Menu_Structure_Reference` para que lo actualice obligatoriamente siempre que toque o modifique cualquier aspecto referente al tema de ese fichero (menús e interfaces de comando), manteniendo rigurosamente el formato original del fichero con las modificaciones oportunas.
- **Base de Conocimiento Técnica Obligatoria (`FTCS_Programming_Lessons.md`):** El fichero `FTCS_Programming_Lessons.md` (raíz del proyecto) es la base de conocimiento viva del proyecto: registra cada hallazgo técnico verificado de programación (quirks del motor de Arma, errores de parseo SQF, causas raíz de bugs resueltos, patrones de depuración), numerado y fechado. La IA debe **leerlo COMPLETO antes de programar o depurar cualquier código del proyecto**, **aplicar sus lecciones** (son hallazgos ya probados en el motor, no hipótesis) y **añadir una nueva entrada numerada** cada vez que se descubra y verifique un nuevo hallazgo técnico, para que cualquier IA (o programador) que arranque desde cero disponga inmediatamente de todo el conocimiento acumulado.
- **Registro de Cambios Estructurales y de Diseño para IA (`FTCS_Programming_Lessons.md`, sección de arquitectura):** Además de los hallazgos de programación, cuando una tarea implique un **cambio estructural importante del software** (nueva capa o sistema, cambio en el flujo de órdenes o en el ciclo de vida de datos, reorganización de módulos) o la **incorporación de un mecanismo crucial para entender el funcionamiento del proyecto** (por ejemplo: la estructura de datos y su ciclo de vida, el modelo de registro/hash central, la propagación de órdenes entre niveles), la IA debe añadir en ese mismo fichero una **entrada de tipo "Architecture / Design Note"** redactada como **guía directa para una IA** (orientada a consumo automático: invariantes que no se pueden romper, contratos entre módulos, qué leer y en qué orden para entender el sistema). Este registro es **distinto y complementario** a la documentación de diseño existente orientada a intervención humana: aquella explica el *qué* y el *por qué* para el programador; esta nota explica el *cómo funciona y cómo no romperlo* para la IA que programa sobre ello. Ambos tipos de entrada conviven numerados y fechados en el mismo fichero.

**Forma de trabajar:**

- Si falta contexto (archivos, funciones relacionadas), pídelo en lugar de suponerlo.
- Entrega el código completo de las funciones modificadas, no fragmentos con "..." que omitan partes.
- Al final de cada respuesta, indica qué comentarios o esquemas ASCII has reescrito o eliminado y por qué. Si no has tocado ninguno, confírmalo.
- Si has añadido o registrado alguna función nueva en `description.ext`, incluye OBLIGATORIAMENTE una línea destacada de aviso indicando al programador que se ha añadido una nueva función y que debe salir al editor 3DEN y volver a entrar a la misión para que el motor recompile `CfgFunctions`.
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
    - `"side"`: [Side] Bando militar de la fuerza (`west`, `east`, `resistance`/`independent`). Detectado automáticamente por el conversor desde la composición.
    - `"requiredMods"`: [Array de Strings] Clases de `CfgPatches` requeridas (ej. `["WW2_Core", "WW2_Assets"]`).
    - `"platoonNames"`: [Array de Strings] Nombres de los pelotones, empezando por `"Company HQ"`.
    - `"squadsPerPlatoon"`: [Number] Escuadras de combate por pelotón (1–4).
    - `"squadDesignations"`: [HashMap] Identidad semántica de cada escuadra (`"SQD_X_Y"` → nombre, ej. `"Mortar Section"`). Los squads mono-team (morteros/apoyo) se detectan por su nombre.
    - `"teamStructure"` / `"teamRoles"`: [Arrays] Nombres y roles tácticos (ASSAULT/SUPPORT) de los teams por escuadra (máx. 4).
    - `"companyHQRoles"` / `"platoonHQRoles"` / `"platoonHQTeamStructure"`: Roles y sub-teams de los HQs.
    - `"isMechanized"` / `"transportAsset"`: Transporte orgánico de la doctrina.
    > **Autonomía estructural:** las doctrinas por composición (Método 2) son **autocontenidas**: toda la estructura organizativa embebe en el fichero y `FTCS_fnc_applyDoctrine` la consume directamente. El registro embebido `FTCS_Doctrines` (`fn_configDoctrines.sqf`, sistema antiguo) solo aplica al Método 1 (unidades pre-colocadas con variables del editor).
    - `"entities"`: [Array de Arrays] Lista de entidades a spawnear con la tupla estándar extensible de 7 u 8 campos:
      `[className, [offsetX, offsetY, offsetZ], relativeDir, varName, groupVar, rank, isVehicle, (opcional) customLoadoutArray]`
      - `groupVar` (5º campo): nombre estándar del grupo contenedor (`SQUAD_X_Y`, `PLT_X_...`, `HQ_...`). Las entidades del mismo `groupVar` se ensamblan en el mismo grupo de Arma.
      - `customLoadoutArray` (8º campo opcional): array íntegro de equipamiento compatible con el comando nativo `setUnitLoadout` de Arma 3 (armas, miras, cargadores, uniforme, chaleco, casco, mochila y accesorios). Extraído automáticamente por el conversor desde el bloque `class Inventory` de la composición para garantizar que las modificaciones visuales y armamentísticas del editor persistan en el juego. Si está ausente o vacío (`[]`), la unidad conserva su loadout nativo por defecto.
      > Decisión de diseño: La tupla conserva total retrocompatibilidad con doctrinas de 7 campos y añade opcionalmente el array de loadout en el 8º campo sin alterar la derivación semántica de roles basada en `varName` y `rank`.
  - **Lógica de Ejecución del Motor Genérico (`FTCS_fnc_spawnDoctrine`):**

    - **Paso 1 (Verificación de Compatibilidad de Mods):** Itera sobre `"requiredMods"` comprobando `isClass (configFile >> "CfgPatches" >> _x)`. Si falta alguno, interrumpe el despliegue con alerta visual detallando los addons ausentes.
    - **Paso 2 (Transformación Geométrica Espacial):** Recibe la posición de anclaje (Assembly Area / coordenada seleccionada en mapa) y el vector de avance (`FTCS_Platoon_Advance_Direction`). Aplica rotación trigonométrica en 2D a los offsets relativos para orientar a todo el contingente en la dirección táctica sin deformar la formación original de la composición.
    - **Paso 3 (Instanciación y Asignación de Roles):** Spawnea soldados y vehículos (`createUnit` / `createVehicle`), ejecuta `setVehicleVarName` y registra los objetos en `missionNamespace`.
    - **Paso 4 (Auto-enlace con el Backend):** Dispara en cadena la secuencia de inicialización del core:
      `FTCS_fnc_applyDoctrine` -> `FTCS_fnc_parseEditorGroups` -> `FTCS_fnc_initCompanyCommand` -> `FTCS_fnc_syncGroupNames` -> `FTCS_fnc_registryInit` -> `FTCS_fnc_initUnitInteractions`.


---

## 9. Arquitectura de Menús de Transmisión de Órdenes e Interfaz Diagética

- **Filosofía de Interfaz Diagética:**
  En FTCS los menús no son elementos flotantes abstractos, sino representaciones directas de las capacidades físicas del avatar del jugador en el entorno 3D. La disponibilidad y el tipo de menú dependen estrictamente del medio de comunicación empleado:
  1. **Voz / Gritos:** Cercanía físico-acústica local.
  2. **Gestos Visuales / Señas:** Línea de visión y orientación espacial.
  3. **Reunión sobre el Mapa Táctico:** Contacto físico o citación presencial de líderes.
  4. **Mensajero / Enlace (Estafeta):** Emisión de despacho escrito o verbal a un corredor.
  5. **Transmisión por Radio:** Red de comunicaciones táctica operada por especialistas.

- **Tipos de Menús e Interacciones Detalladas:**

  - **A. Menú de Voz / Grito Táctico (Proximidad Físico-Acústica):**
    - *Condición de activación:* Pulsación de la tecla de voz / orden rápida a viva voz. No requiere apuntar a una unidad ni enfocar una dirección concreta.
    - *Alcance:* ~15–25 metros (disminuye dinámicamente en combate por ruido ambiental de disparos y detonaciones).
    - *Mecánica táctica:* Afecta a todas las unidades o sub-mandos subordinados situados dentro del radio de audición. Los mandos intermedios (ej. sargento) que escuchen el grito retransmiten automáticamente la orden a sus escuadras adyacentes.

  - **B. Menú de Gestos Visuales y Señales de Mano (Línea de Visión / LOS):**
    - *Condición de activación:* Mantener pulsado el botón de Gestos Tácticos mientras se apunta con la retícula o cámara hacia la dirección/zona de un pelotón o elemento.
    - *Alcance:* ~50–100 metros (requiere línea de visión directa y condiciones de luz adecuadas).
    - *Interfaz de selección:* Al enfocar hacia un grupo o sector, aparece una guía visual sutil (silueta o puntero de gesto).
    - *Catálogo de gestos:*
      1. Señal de Línea / Despliegue en Fila.
      2. Señal de Flanqueo (indicando vector Izquierda / Derecha).
      3. Señal de Alto / Mantener Posición.
      4. Señal de Avance Táctico.
    - *Realismo ambiental:* La presencia de humo denso, niebla o vegetación espesa entre el emisor y los subordinados provocará el fallo de la orden o una probabilidad calculada de malinterpretación táctica por la IA.

  - **C. Menú de Mapa Físico (Conferencia de Mando y Transmisión por Cadena):**
    - *Condición de activación:* Abrir el mapa desplegable en 3D (el personaje sostiene físicamente el mapa con sus manos en primera persona).
    - *Condición de disponibilidad de unidades:* Para poder trazar o transmitir una orden directa en el mapa a un líder específico (ej. Sargento de Pelotón), dicho mando debe estar físicamente junto al jugador (radio de 3–5 metros, simulando la "mesa de mapas").
    - *Citación de mandos:* Si el sargento o líder no se encuentra próximo, el jugador utiliza la acción verbal/gestual para ordenar: *"¡Sargento, al mapa!"*. El líder IA se desplazará físicamente hasta el jugador para incorporarse a la sesión de planeamiento.
    - *Flujo de cadena de mando:*
      1. El comandante traza y asigna un Eje de Avance u Objetivo sobre el mapa para la unidad.
      2. Al confirmar la orden en la interfaz, el avatar del comandante le entrega o muestra el mapa al sargento.
      3. **Delegación de la IA:** El sargento procesa la OPORD recibida y asume de forma autónoma la responsabilidad de desglosar y propagar las sub-órdenes a sus cabos de escuadra empleando sus propios medios (voz, gestos o estafetas).

  - **D. Menú de Despacho por Mensajero / Estafeta (Órdenes a Distancia sin Radio):**
    - *Condición de activación:* Interactuar directamente sobre un subordinado con rol de Mensajero/Estafeta o llamarlo verbalmente (*"¡Mensajero, informe!"*).
    - *Estructura del despacho (OPORD Simplificada):*
      - *Destinatario:* Selección del mando de destino (ej. Líder del 2º Pelotón).
      - *Tipo de acción:* Avanzar / Defender / Sostener / Retirada / Reagrupar.
      - *Ubicación destino:* Punto marcado previamente en mapa o referencia táctica visible.
      - *Política de movimiento:*
        - *Cauteloso / Sigilo:* Progresión por coberturas (velocidad reducida, máxima supervivencia).
        - *Urgente / A toda prisa:* Desplazamiento directo veloz (rápido, elevado riesgo de interceptación).
      - *Respuesta requerida:* Opción para exigir que el mensajero espere confirmación escrita/verbal del destinatario y regrese a la posición de origen.
    - *Agente físico en el mundo:* Si el mensajero resulta abatido durante el tránsito, la orden se pierde irrevocablemente. Si el destinatario ha maniobrado y no es localizado, el mensajero entra en búsqueda local o retorna notificando entrega fallida.

  - **E. Menú de Transmisión por Radio (Red de Comunicaciones Táctica):**
    - *Condición de activación e interacción:*
      1. *Acceso directo:* Acercamiento físico al Radio Operador (RTO) del puesto de mando (HQ Pelotón / Compañía) para abrir la interfaz de red.
      2. *Delegación:* El jugador puede emitir la directriz a su Segundo al Mando (XO / 2iC), quien se desplazará autónomamente hasta el RTO para transmitir la orden por la malla de radio.
    - *Destinatarios según contexto histórico:*
      - *Segunda Guerra Mundial (WWII):* Restringido exclusivamente a Puestos de Mando de Pelotón/Compañía o blindados dotados de transceptores (SCR-300, SCR-536 Walkie-Talkie). Las escuadras de fusileros carentes de equipo no figuran en la red.
      - *Escenarios Modernos / Equipamiento Íntegro:* Si la doctrina equipa a cada líder de escuadra con radio individual, la red se expande automáticamente a todos los escalones.
    - *Vulnerabilidad y orografía:* La baja del RTO o la destrucción del equipo anula este canal hasta su relevo. La efectividad de la señal se degrada por orografía, distancia y contramedidas.

---

## 10. Sistema de Desorientación, Navegación Topográfica y Reposicionamiento (Land Navigation)

- **Separación entre Conciencia Geográfica y Visión Táctica Local:**
  Para preservar el realismo y exigir destrezas auténticas de orientación en el terreno (*Land Navigation*) sin entorpecer el combate inmediato en primera persona, se desacoplan dos niveles operativos:
  1. **Lo que se pierde (Mando Cenital / Mapa Táctico):** Tras desplazamientos prolongados sin verificación topográfica, el comandante pierde la referencia exacta de su cuadrícula. Se desconoce la coordenada de parada de la columna o del puesto de mando.
  2. **Lo que se mantiene (Visión en 1ª Persona / 3D):** La interacción visual y física directa con el entorno 3D permanece inalterada (ojos, binoculares y voz operan con normalidad).
  - *Gestión de órdenes:*
    - *Permitidas siempre:* Órdenes visuales directas en 3D (designar un muro, colina o edificación visible con la vista/prismáticos y ordenar asalto o cobertura a elementos adyacentes).
    - *Bloqueadas al perderse:* Órdenes operativas vía mapa (trazado de rutas hacia cuadrículas lejanas o solicitudes de apoyo de artillería sobre coordenadas), al no existir un vector de origen geográfico fiable.

- **Bucle de Pérdida de Posicionamiento y Degradación:**
  - *Métricas y disparadores:*
    - *Contador de distancia sin verificar:* Cada metro recorrido desde la última fijación topográfica suma puntos a un índice interno de desorientación.
    - *Factores de degradación ambiental:* El índice se acelera según el terreno y visibilidad (bosque denso, niebla, nocturnidad o avance campo a través aceleran la pérdida vs. marchar sobre caminos principales).
  - *Fases de estado del mapa:*
    - *Fase 1 (Posición Fresca / Verificada):* El mapa refleja con precisión nítida la posición del mando y los elementos reportados.
    - *Fase 2 (Posición Estimada / Degradación Gradual):* Los marcadores pierden opacidad progresivamente (aspecto translúcido/grisáceo) y muestran advertencias (*"Posición Estimada / +15 min"*).
    - *Fase 3 (Pérdida Crítica / Sistema Deshabilitado):* Superado el umbral de distancia/tiempo, el mapa táctico se bloquea para órdenes cenitales mostrando el aviso: *"MAPA INOPERATIVO — PÉRDIDA DE POSICIÓN GEOGRÁFICA"*. Las unidades distantes dejan de actualizarse o se sustituyen por áreas de incertidumbre con icono de interrogación (?).

- **Mecánica de Reposicionamiento Topográfico:**
  Para despejar la niebla de orientación, desbloquear el mapa y resincronizar la red de radio, el jugador debe ejecutar un proceso de reorientación topográfica:
  1. *Activación de interfaz:* Seleccionar la opción *"Reorientar Mando"* sobre el mapa bloqueado.
  2. *Lectura del entorno 3D:* Identificar hitos y accidentes geográficos clave en primera persona (cota de elevación, intersección de camino y río, campanario de iglesia, puente, etc.).
  3. *Fijación de Pin en el mapa:* Trasladar la lectura visual al plano topográfico colocando manualmente un *Pin de Posición Estimada*.
  - *Validación por algoritmo de tolerancia:*
    - *Pin correcto (dentro de tolerancia, ej. 50–150m):*
      - Reorientación exitosa.
      - Reactivación inmediata de la interfaz de mapa y de la emisión de órdenes de largo alcance.
      - Sincronización instantánea de las unidades aliadas visibles o conectadas por radio.
    - *Pin incorrecto (fuera de tolerancia):*
      - El sistema rechaza la fijación o conserva el desajuste, forzando al jugador a reanalizar el paisaje o progresar hasta un punto con referencias geográficas más claras.

- **Recuperación y Visibilidad de Unidades Subordinadas:**
  Una vez reorientado el propio mando:
  - *Línea de visión directa (LOS):* Las unidades observables en el campo visual 3D se confirman y sitúan de inmediato sobre el mapa táctico.
  - *Malla de radio (SITREP):* Al recuperar las coordenadas exactas del puesto de mando, los informes de situación (SITREP) recibidos por radio desde unidades distantes vuelven a plotearse con precisión en sus cuadrículas correspondientes.
