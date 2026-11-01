# ==============================================================================
# FTCS - ALINEADOR Y REESTRUCTURADOR DE FORMACION PARA COMPOSICIONES (3DEN)
# ==============================================================================
# Toma una Custom Composition (composition.sqe), calcula su centro geometrico y
# reordena a todos los soldados en la FORMACION DOCTRINAL NATIVA EN FILA (Column):
#   - 3 Pelotones espaciados en linea de vanguardia a retaguardia
#   - Scouts en vanguardia (+35m), Rifle Team A inmediatamente detrás (+26m),
#     Rifle Team B (+15m) y BAR Support (+0m, 15m detrás)
#   - Platoon HQ (Mando en -12m, Apoyo en -20m) y Morteros en -32m de su propio pelotón
#   - Company HQ en retaguardia profunda de mando (-48m)
#   - Cada soldado dentro de su grupo/team se alinea a exactamente 2.0 metros detrás (-Y)
#     en formación nativa de columna de Arma 3 (cero movimiento de reubicación de IA).
# ==============================================================================

param (
    [string]$AutoSelection = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   FTCS - ALINEADOR GEOMETRICO DE COMPOSICIONES EN FILA" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Determinar carpetas de composiciones de Arma 3
$docsFolder = [Environment]::GetFolderPath("MyDocuments")
$compositionsPaths = @(
    "$docsFolder\Arma 3 - Other Profiles\PLAYER%201\compositions",
    "$docsFolder\Arma 3 - Other Profiles\PLAYER 1\compositions",
    "$docsFolder\Arma 3\compositions"
)

$validCompositionDir = $null
foreach ($path in $compositionsPaths) {
    if (Test-Path $path) {
        $validCompositionDir = $path
        break
    }
}

if (-not $validCompositionDir) {
    Write-Host "[ERROR] No se encontro ninguna carpeta de composiciones de Arma 3." -ForegroundColor Red
    Read-Host "Presiona Enter para salir..."
    exit
}

# Buscar carpetas que contengan composition.sqe
$ftcsCompositions = Get-ChildItem -Path $validCompositionDir -Directory -Filter "FTCS*" | Sort-Object LastWriteTime -Descending

if ($ftcsCompositions.Count -eq 0) {
    Write-Host "[AVISO] No se encontraron composiciones FTCS en: $validCompositionDir" -ForegroundColor Yellow
    exit
}

Write-Host "Composiciones detectadas en el perfil:" -ForegroundColor Green
for ($i = 0; $i -lt $ftcsCompositions.Count; $i++) {
    $comp = $ftcsCompositions[$i]
    $sqeExists = Test-Path (Join-Path $comp.FullName "composition.sqe")
    $status = if ($sqeExists) { "[OK]" } else { "[Falta composition.sqe]" }
    Write-Host (" [{0,2}] {1,-42} {2}" -f ($i + 1), $comp.Name, $status)
}

Write-Host ""
Write-Host " [ 0] Salir" -ForegroundColor Gray
Write-Host ""

$selection = if ($AutoSelection -ne "") {
    $AutoSelection
}
else {
    Read-Host "Selecciona el numero de la composicion a alinear [1-$($ftcsCompositions.Count), 0]"
}

if ($selection -eq "0" -or [string]::IsNullOrWhiteSpace($selection)) {
    Write-Host "Operacion cancelada." -ForegroundColor Yellow
    exit
}

$idx = [int]$selection - 1
if ($idx -lt 0 -or $idx -ge $ftcsCompositions.Count) {
    Write-Host "[ERROR] Seleccion no valida." -ForegroundColor Red
    exit
}

$targetComp = $ftcsCompositions[$idx]
$sqeFile = Join-Path $targetComp.FullName "composition.sqe"

if (-not (Test-Path $sqeFile)) {
    Write-Host "[ERROR] No existe composition.sqe en $($targetComp.FullName)" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "Procesando y alineando: $($targetComp.Name)..." -ForegroundColor Cyan

# Copia de seguridad automatica previa
$backupFile = "$sqeFile.bak"
Copy-Item -Path $sqeFile -Destination $backupFile -Force
Write-Host " -> Copia de seguridad creada: $backupFile" -ForegroundColor DarkGray

$rawLines = [System.IO.File]::ReadAllLines($sqeFile, [System.Text.Encoding]::UTF8)

# Centros doctrinales de grupos (relativos al punto ancla, frente hacia +Y / Norte):
$groupCenters = @{
    # HQ DE COMPAÑÍA (Retaguardia general)
    "SQUAD_0_0"        = @(   0.0, -48.0 )

    # 1er PELOTÓN (Flanco Izquierdo, X = -55m)
    "SQUAD_1_1_TEAM_2" = @( -70.0, +35.0 )  # Scouts vanguardia
    "SQUAD_1_1_TEAM_1" = @( -70.0, +26.0 )  # Rifle Team A (Sargento)
    "SQUAD_1_1_TEAM_3" = @( -70.0, +15.0 )  # Rifle Team B
    "SQUAD_1_1_TEAM_4" = @( -70.0, 0.0 )  # BAR Support (15m detrás)
    "SQUAD_1_2_TEAM_2" = @( -55.0, +35.0 )  # Scouts vanguardia
    "SQUAD_1_2_TEAM_1" = @( -55.0, +26.0 )  # Rifle Team A (Sargento)
    "SQUAD_1_2_TEAM_3" = @( -55.0, +15.0 )  # Rifle Team B
    "SQUAD_1_2_TEAM_4" = @( -55.0, 0.0 )  # BAR Support
    "SQUAD_1_3_TEAM_2" = @( -40.0, +35.0 )  # Scouts vanguardia
    "SQUAD_1_3_TEAM_1" = @( -40.0, +26.0 )  # Rifle Team A (Sargento)
    "SQUAD_1_3_TEAM_3" = @( -40.0, +15.0 )  # Rifle Team B
    "SQUAD_1_3_TEAM_4" = @( -40.0, 0.0 )  # BAR Support
    "SQUAD_1_0_TEAM_1" = @( -55.0, -12.0 )  # Plt 1 HQ - Mando
    "SQUAD_1_0_TEAM_2" = @( -55.0, -20.0 )  # Plt 1 HQ - Apoyo
    "SQUAD_1_4_TEAM_1" = @( -55.0, -32.0 )  # Mortero 1er Plt

    # 2º PELOTÓN (Centro, X = 0m)
    "SQUAD_2_1_TEAM_2" = @( -15.0, +35.0 )
    "SQUAD_2_1_TEAM_1" = @( -15.0, +26.0 )
    "SQUAD_2_1_TEAM_3" = @( -15.0, +15.0 )
    "SQUAD_2_1_TEAM_4" = @( -15.0, 0.0 )
    "SQUAD_2_2_TEAM_2" = @(   0.0, +35.0 )
    "SQUAD_2_2_TEAM_1" = @(   0.0, +26.0 )
    "SQUAD_2_2_TEAM_3" = @(   0.0, +15.0 )
    "SQUAD_2_2_TEAM_4" = @(   0.0, 0.0 )
    "SQUAD_2_3_TEAM_2" = @( +15.0, +35.0 )
    "SQUAD_2_3_TEAM_1" = @( +15.0, +26.0 )
    "SQUAD_2_3_TEAM_3" = @( +15.0, +15.0 )
    "SQUAD_2_3_TEAM_4" = @( +15.0, 0.0 )
    "SQUAD_2_0_TEAM_1" = @(   0.0, -12.0 )
    "SQUAD_2_0_TEAM_2" = @(   0.0, -20.0 )
    "SQUAD_2_4_TEAM_1" = @(   0.0, -32.0 )

    # 3er PELOTÓN (Flanco Derecho, X = +55m)
    "SQUAD_3_1_TEAM_2" = @( +40.0, +35.0 )
    "SQUAD_3_1_TEAM_1" = @( +40.0, +26.0 )
    "SQUAD_3_1_TEAM_3" = @( +40.0, +15.0 )
    "SQUAD_3_1_TEAM_4" = @( +40.0, 0.0 )
    "SQUAD_3_2_TEAM_2" = @( +55.0, +35.0 )
    "SQUAD_3_2_TEAM_1" = @( +55.0, +26.0 )
    "SQUAD_3_2_TEAM_3" = @( +55.0, +15.0 )
    "SQUAD_3_2_TEAM_4" = @( +55.0, 0.0 )
    "SQUAD_3_3_TEAM_2" = @( +70.0, +35.0 )
    "SQUAD_3_3_TEAM_1" = @( +70.0, +26.0 )
    "SQUAD_3_3_TEAM_3" = @( +70.0, +15.0 )
    "SQUAD_3_3_TEAM_4" = @( +70.0, 0.0 )
    "SQUAD_3_0_TEAM_1" = @( +55.0, -12.0 )
    "SQUAD_3_0_TEAM_2" = @( +55.0, -20.0 )
    "SQUAD_3_4_TEAM_1" = @( +55.0, -32.0 )

    # 4º PELOTÓN - WEAPONS PLATOON (Apoyo Pesado Orgánico, Flanco Derecho Separado)
    # 3er Pelotón abarca X de +40m a +70m. Colocamos el Weapons Platoon centrado en X = +115m:
    # Deja 30m de espacio libre con el 3er Pelotón. Ametralladoras en vanguardia (+25m) y Morteros en retaguardia (-32m).
    "SQUAD_4_0_TEAM_1" = @( +115.0, -12.0 )  # Plt 4 HQ - Mando
    "SQUAD_4_0_TEAM_2" = @( +115.0, -20.0 )  # Plt 4 HQ - Apoyo
    "SQUAD_4_1_TEAM_1" = @( +105.0, -32.0 )  # 1st Mortar Section (60mm)
    "SQUAD_4_2_TEAM_1" = @( +125.0, -32.0 )  # 2nd Mortar Section (60mm)
    "SQUAD_4_3_TEAM_1" = @( +105.0, +20.0 )  # 1st Machine Gun Section (M2/M1919)
    "SQUAD_4_4_TEAM_1" = @( +125.0, +20.0 )  # 2nd Machine Gun Section (M2/M1919)
}

# Localizar la coordenada del mundo real base del ancla (Capitán)
$baseWorldX = 0.0
$baseWorldZ = 0.0
$baseWorldY = 0.0
$foundAnchor = $false

for ($i = 0; $i -lt $rawLines.Length; $i++) {
    if ($rawLines[$i] -match 'name="HQ_CO_CAPTAIN";') {
        for ($k = [Math]::Max(0, $i - 10); $k -lt [Math]::Min($rawLines.Length, $i + 15); $k++) {
            if ($rawLines[$k] -match 'position\[\]=\{([^}]+)\};') {
                $c = $rawLines[$k].Split('{},') | Where-Object { $_ -match '^[0-9.-]+$' } | ForEach-Object { [double]$_ }
                if ($c.Count -ge 3) {
                    $baseWorldX = $c[0]
                    $baseWorldZ = $c[1]
                    $baseWorldY = $c[2]
                    $foundAnchor = $true
                    break
                }
            }
        }
        break
    }
}

if (-not $foundAnchor) {
    # Si no tiene HQ_CO_CAPTAIN, tomar la primera posición encontrada como origen
    for ($i = 0; $i -lt $rawLines.Length; $i++) {
        if ($rawLines[$i] -match 'position\[\]=\{([^}]+)\};') {
            $c = $rawLines[$i].Split('{},') | Where-Object { $_ -match '^[0-9.-]+$' } | ForEach-Object { [double]$_ }
            if ($c.Count -ge 3) {
                $baseWorldX = $c[0]
                $baseWorldZ = $c[1]
                $baseWorldY = $c[2]
                break
            }
        }
    }
}

Write-Host (" -> Coordenada base del mundo detectada: [{0:F2}, {1:F2}]" -f $baseWorldX, $baseWorldY) -ForegroundColor DarkGray

# Mapear los grupos exactos por rango de bloques
class UnitSlot {
    [int]$ObjLine = 0
    [int]$PosLine = 0
    [string]$VarName = ""
    [string]$Rank = ""
    [int]$Priority = 0
}

class GrpBlock {
    [string]$Name = ""
    [int]$Start = 0
    [int]$End = 0
    [System.Collections.Generic.List[UnitSlot]]$Units = [System.Collections.Generic.List[UnitSlot]]::new()
}

$groups = [System.Collections.Generic.List[GrpBlock]]::new()
$cur = $null

for ($i = 0; $i -lt $rawLines.Length; $i++) {
    $l = $rawLines[$i].Trim()

    if ($l -eq 'dataType="Group";') {
        if ($cur -ne $null) { $cur.End = $i - 1 }
        $cur = [GrpBlock]::new()
        $cur.Start = $i
        $groups.Add($cur)
    }

    if ($cur -ne $null -and $l -eq 'dataType="Object";') {
        $slot = [UnitSlot]::new()
        $slot.ObjLine = $i

        for ($k = $i; $k -lt [Math]::Min($rawLines.Length, $i + 35); $k++) {
            if ($rawLines[$k] -match '^\s*position\[\]=\{([^}]+)\};' -and $slot.PosLine -eq 0) {
                $slot.PosLine = $k
            }
            if ($rawLines[$k] -match '^\s*name="([^"]+)";' -and $slot.VarName -eq "") {
                $slot.VarName = $matches[1]
            }
            if ($rawLines[$k] -match '^\s*rank="([^"]+)";' -and $slot.Rank -eq "") {
                $slot.Rank = $matches[1]
            }
        }

        # Calcular prioridad jerarquica táctica para garantizar que los comandantes
        # y líderes vayan SIEMPRE a la cabeza de la columna:
        # 1. Por variable de rol estándar
        $prio = 10
        $vUpper = $slot.VarName.ToUpper()
        if ($vUpper -match 'HQ_CO_CAPTAIN|CO_CAPTAIN') { $prio = 100 }
        elseif ($vUpper -match 'HQ_XO_LIEUTENANT|XO_LIEUTENANT') { $prio = 90 }
        elseif ($vUpper -match 'PLT_[0-9]_LEADER') { $prio = 100 }
        elseif ($vUpper -match 'HQ_FIRST_SERGEANT|FIRST_SERGEANT') { $prio = 80 }
        elseif ($vUpper -match 'PLT_[0-9]_SERGEANT') { $prio = 80 }
        elseif ($vUpper -match 'SQD_[0-9]_[0-9]_LEADER') { $prio = 100 }
        elseif ($vUpper -match 'COMM_SERGEANT') { $prio = 70 }
        elseif ($vUpper -match 'RADIO_OPERATOR|PLT_[0-9]_RADIO_OPERATOR|PLT_[0-9]_RTO') { $prio = 60 }
        elseif ($vUpper -match 'MESSENGER_1|PLT_[0-9]_RUNNER') { $prio = 50 }
        elseif ($vUpper -match 'MESSENGER_2') { $prio = 48 }
        elseif ($vUpper -match 'MESSENGER_3') { $prio = 46 }
        elseif ($vUpper -match 'MESSENGER_4') { $prio = 44 }
        elseif ($vUpper -match 'MESSENGER_5') { $prio = 42 }
        elseif ($vUpper -match 'MESSENGER_6') { $prio = 40 }
        elseif ($vUpper -match 'MEDIC|PLT_[0-9]_MEDIC') { $prio = 30 }
        else {
            # 2. Por rango militar del motor si no tiene variable especifica
            switch ($slot.Rank.ToUpper()) {
                "CAPTAIN"    { $prio = 95 }
                "LIEUTENANT" { $prio = 90 }
                "SERGEANT"   { $prio = 80 }
                "CORPORAL"   { $prio = 70 }
                default      { $prio = 10 }
            }
        }
        $slot.Priority = $prio

        if ($slot.PosLine -gt 0) {
            $cur.Units.Add($slot)
        }
    }
}
if ($cur -ne $null) { $cur.End = $rawLines.Length - 1 }

foreach ($g in $groups) {
    for ($k = $g.Start; $k -le $g.End; $k++) {
        if ($rawLines[$k] -match '^\s*name="([^"]+)";') {
            $cand = $matches[1]
            if ($cand -match 'SQUAD|squad') {
                $g.Name = $cand
                break
            }
        }
    }
}

# Reemplazar con precisión absoluta cada soldado en fila nativa
$out = [string[]]::new($rawLines.Length)
[System.Array]::Copy($rawLines, $out, $rawLines.Length)
$totalRep = 0

foreach ($g in $groups) {
    $name = $g.Name
    if (-not $groupCenters.ContainsKey($name)) {
        Write-Host "  [!] Grupo omitido (sin centro definido): '$name'" -ForegroundColor Yellow
        continue
    }
    $center = $groupCenters[$name]

    # Ordenar las unidades de este grupo jerárquicamente por prioridad descendente
    # para que Capitán / Teniente / Sargentos queden al frente de la fila ($idx = 0)
    $sortedUnits = $g.Units | Sort-Object Priority -Descending

    for ($idx = 0; $idx -lt $sortedUnits.Count; $idx++) {
        $u = $sortedUnits[$idx]
        $lineIdx = $u.PosLine
        
        # En fila nativa: Líder en [0, 0], subordinados exactamente 2 metros detrás en Y (-Y)
        $offX = 0.0
        $offY = - ($idx * 2.0)

        $newX = [Math]::Round(($baseWorldX + $center[0] + $offX), 4)
        $newY = [Math]::Round(($baseWorldY + $center[1] + $offY), 4)
        $newZ = [Math]::Round($baseWorldZ, 4)

        $orig = $rawLines[$lineIdx]
        $indent = ($orig -replace '[^\t].*', '').Length
        $tabStr = "`t" * $indent
        $out[$lineIdx] = '{0}position[]={{{1},{2},{3}}};' -f $tabStr, $newX, $newZ, $newY
        $totalRep++
    }
}

Write-Host " -> Soldados alineados con precision: $totalRep" -ForegroundColor Green
[System.IO.File]::WriteAllLines($sqeFile, $out, [System.Text.Encoding]::UTF8)

# Si existe en el perfil default de Arma 3, sincronizarlo tambien
$defaultDest = "$docsFolder\Arma 3\compositions\$($targetComp.Name)\composition.sqe"
if (Test-Path (Split-Path -Parent $defaultDest)) {
    [System.IO.File]::WriteAllLines($defaultDest, $out, [System.Text.Encoding]::UTF8)
    Write-Host " -> Sincronizado en perfil general de Arma 3." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Alineacion completada con exito." -ForegroundColor Green
Write-Host "Archivo sobrescrito: $sqeFile" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Consejo: Ahora puedes ejecutar Convertir_Composiciones.bat para" -ForegroundColor Yellow
Write-Host "generar el archivo .sqf de doctrina con la formacion alineada." -ForegroundColor Yellow
Write-Host ""

if ($AutoSelection -eq "") {
    Read-Host "Presiona Enter para cerrar esta ventana..."
}
