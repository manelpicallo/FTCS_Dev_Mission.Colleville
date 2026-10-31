# ==============================================================================
# FTCS - CONVERSOR DE CUSTOM COMPOSITIONS (3DEN) A DOCTRINAS FTCS
# ==============================================================================

param (
    [string]$AutoSelection = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "      FTCS - CONVERSOR DE COMPOSICIONES A DOCTRINAS" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Determinar rutas
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$missionRoot = Split-Path -Parent $scriptRoot
if (-not (Test-Path "$missionRoot\description.ext")) {
    $missionRoot = Get-Location
}

$outputFolder = Join-Path $missionRoot "Doctrines\Data"
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
}

# Localizar carpetas de composiciones de Arma 3
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
    Write-Host "[ERROR] No se encontró ninguna carpeta de composiciones de Arma 3." -ForegroundColor Red
    Write-Host "Buscado en: $compositionsPaths" -ForegroundColor DarkGray
    Read-Host "Presiona Enter para salir..."
    exit
}

Write-Host "Buscando composiciones en: $validCompositionDir" -ForegroundColor DarkGray
Write-Host ""

# Buscar carpetas que comiencen por FTCS
$ftcsCompositions = Get-ChildItem -Path $validCompositionDir -Directory -Filter "FTCS*" | Sort-Object LastWriteTime -Descending

if ($ftcsCompositions.Count -eq 0) {
    Write-Host "[AVISO] No se encontraron composiciones que comiencen por 'FTCS*' en el perfil." -ForegroundColor Yellow
    Write-Host "Asegúrate de haber guardado la composición en el 3DEN Editor con un nombre como 'FTCS_US_Airborne'." -ForegroundColor DarkYellow
    Write-Host ""
    $resp = Read-Host "¿Deseas ver TODAS las composiciones guardadas? (S/N)"
    if ($resp -match "^[sSyY]") {
        $ftcsCompositions = Get-ChildItem -Path $validCompositionDir -Directory | Sort-Object LastWriteTime -Descending
    } else {
        exit
    }
}

Write-Host "Composiciones encontradas:" -ForegroundColor Green
for ($i = 0; $i -lt $ftcsCompositions.Count; $i++) {
    $comp = $ftcsCompositions[$i]
    $sqeExists = Test-Path (Join-Path $comp.FullName "composition.sqe")
    $status = if ($sqeExists) { "[OK]" } else { "[Falta composition.sqe]" }
    Write-Host (" [{0,2}] {1,-35} ({2:dd/MM/yyyy HH:mm}) {3}" -f ($i + 1), $comp.Name, $comp.LastWriteTime, $status)
}

Write-Host ""
Write-Host " [ T] Convertir TODAS las composiciones válidas" -ForegroundColor Cyan
Write-Host " [ 0] Salir" -ForegroundColor Gray
Write-Host ""

$selection = if ($AutoSelection -ne "") {
    $AutoSelection
} else {
    Read-Host "Selecciona el número de la composición a convertir [1-$($ftcsCompositions.Count), T, 0]"
}

if ($selection -eq "0" -or [string]::IsNullOrWhiteSpace($selection)) {
    Write-Host "Operación cancelada." -ForegroundColor Yellow
    exit
}

$targets = @()
if ($selection -match "^[tT]") {
    $targets = $ftcsCompositions
} else {
    $idx = [int]$selection - 1
    if ($idx -ge 0 -and $idx -lt $ftcsCompositions.Count) {
        $targets = @($ftcsCompositions[$idx])
    } else {
        Write-Host "[ERROR] Selección no válida." -ForegroundColor Red
        exit
    }
}

# Función para parsear un archivo composition.sqe
function Convert-SQEToDoctrineData {
    param (
        [string]$sqeFilePath,
        [string]$compName,
        [string]$outputDir
    )

    if (-not (Test-Path $sqeFilePath)) {
        Write-Host " [!] Archivo no encontrado: $sqeFilePath" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "Procesando '$compName'..." -ForegroundColor Cyan

    $rawLines = Get-Content -Path $sqeFilePath

    # Variables doctrinales por defecto deducidas del nombre
    $cleanName = $compName -replace "^FTCS_", ""
    $doctrineId = $cleanName.ToUpper()
    $companyLetter = "E"
    if ($cleanName -match "(?:_|^)([A-Za-z])(?:_|$)") {
        $companyLetter = $matches[1].ToUpper()
    }

    $detectedEntities = [System.Collections.ArrayList]::new()
    $detectedMods = [System.Collections.Generic.HashSet[string]]::new()
    $detectedGroups = [System.Collections.Generic.HashSet[string]]::new()
    $detectedSide = "WEST"

    # Parser estructural con soporte de herencia jerárquica de grupos.
    # En el formato composition.sqe del 3DEN Editor, los soldados son entidades hijas
    # (nodos Object) contenidas dentro de un bloque 'class Entities' de un nodo padre
    # con dataType="Group". Las variables de grupo (name=...) se declaran en el propio
    # nodo Group o dentro de su sub-bloque 'class Attributes'. Este parser construye
    # el árbol de clases del SQE y propaga automáticamente el groupVar a todas las
    # unidades hijas del grupo, resolviendo el problema de las entidades anónimas.
    class SqNode {
        [string]$Class = ""
        [string]$DataType = ""
        [string]$Name = ""
        [string]$Type = ""
        [string]$Rank = "PRIVATE"
        [double[]]$Pos = @(0.0, 0.0, 0.0)
        [double[]]$Angles = @(0.0, 0.0, 0.0)
        [SqNode]$Parent = $null
        [System.Collections.Generic.List[SqNode]]$Children = [System.Collections.Generic.List[SqNode]]::new()
    }

    $root = [SqNode]::new()
    $root.Class = "Root"
    $current = $root

    for ($i = 0; $i -lt $rawLines.Count; $i++) {
        $line = $rawLines[$i].Trim()

        # Omitir CustomAttributes (no contienen entidades ni nombres relevantes)
        if ($line -match '^class\s+CustomAttributes') {
            # Saltar el bloque CustomAttributes buscando su cierre balanceado
            $depth = 1
            for ($k = $i + 1; $k -lt $rawLines.Count; $k++) {
                $subLine = $rawLines[$k].Trim()
                if ($subLine -match '^class\s+') { $depth++ }
                if ($subLine -eq '};') {
                    $depth--
                    if ($depth -eq 0) { $i = $k; break }
                }
            }
            continue
        }

        if ($line -match '^class\s+([A-Za-z0-9_]+)') {
            $newNode = [SqNode]::new()
            $newNode.Class = $matches[1]
            $newNode.Parent = $current
            $current.Children.Add($newNode)
            $current = $newNode
            continue
        }

        if ($line -eq '};') {
            if ($current.Parent) {
                $current = $current.Parent
            }
            continue
        }

        if ($line -match '^dataType="([^"]+)";') {
            $current.DataType = $matches[1]
            continue
        }

        if ($line -match '^name="([^"]+)";') {
            $current.Name = $matches[1]
            continue
        }

        if ($line -match '^\s*type="([^"]+)";') {
            $val = $matches[1]
            if ($val -notmatch '^(STRING|SCALAR|BOOLEAN|ARRAY)$') {
                $current.Type = $val
                if ($val -match '^([A-Za-z0-9]+)_') {
                    $prefix = $matches[1]
                    if ($prefix -in @("SPE", "LIB", "WW2", "IFA3", "fow")) {
                        [void]$detectedMods.Add($prefix)
                    }
                }
            }
            continue
        }

        if ($line -match '^rank="([^"]+)";') {
            $current.Rank = $matches[1]
            continue
        }

        if ($line -match '^side="([^"]+)";') {
            $sideVal = $matches[1].ToUpper()
            if ($sideVal -in @("WEST", "EAST", "GUER", "RESISTANCE", "IND", "INDEPENDENT")) {
                $detectedSide = switch ($sideVal) {
                    "GUER"        { "RESISTANCE" }
                    "IND"         { "RESISTANCE" }
                    "INDEPENDENT" { "RESISTANCE" }
                    default       { $sideVal }
                }
            }
            continue
        }

        if ($line -match '^position\[\]=\{([^}]+)\};') {
            $coords = $matches[1].Split(',') | ForEach-Object { [double]$_.Trim() }
            if ($coords.Count -ge 3) {
                $current.Pos = @($coords[0], $coords[2], $coords[1]) # [X, Y, Z]
            }
            continue
        }

        if ($line -match '^angles\[\]=\{([^}]+)\};') {
            $coords = $matches[1].Split(',') | ForEach-Object { [double]$_.Trim() }
            if ($coords.Count -ge 2) {
                $current.Angles = $coords
            }
            continue
        }
    }

    # Normalizar offsets relativos respecto al primer líder / capitán encontrado en el árbol
    $anchorX = 0.0
    $anchorY = 0.0
    $anchorZ = 0.0

    function Find-Anchor([SqNode]$node) {
        if ($node.DataType -eq "Object" -and $node.Type -ne "") {
            $uName = $node.Name
            if ($uName -eq "") {
                $attr = $node.Children | Where-Object { $_.Class -eq "Attributes" } | Select-Object -First 1
                if ($attr -and $attr.Name -ne "") { $uName = $attr.Name }
            }
            if ($uName -match "CAPTAIN|LEADER|HQ") {
                if ($node.Pos.Count -ge 3 -and ($node.Pos[0] -ne 0.0 -or $node.Pos[1] -ne 0.0 -or $node.Pos[2] -ne 0.0)) {
                    return $node.Pos
                }
                $posChild = $node.Children | Where-Object { $_.Class -eq "PositionInfo" -and ($_.Pos[0] -ne 0.0 -or $_.Pos[1] -ne 0.0 -or $_.Pos[2] -ne 0.0) } | Select-Object -First 1
                if ($posChild) { return $posChild.Pos }
            }
        }
        foreach ($child in $node.Children) {
            $res = Find-Anchor $child
            if ($res) { return $res }
        }
        return $null
    }

    $anchorPos = Find-Anchor $root
    if ($anchorPos) {
        $anchorX = $anchorPos[0]
        $anchorY = $anchorPos[1]
        $anchorZ = $anchorPos[2]
    }

    # Recorrido recursivo del árbol: propaga el GroupVar desde el Group padre a las unidades
    function Walk-Tree([SqNode]$node, [string]$currentGroupVar) {
        $effGroupVar = $currentGroupVar

        if ($node.DataType -eq "Group") {
            # El nombre del grupo puede estar en el propio nodo o en su hijo 'Attributes'
            $gName = $node.Name
            if ($gName -eq "") {
                $attr = $node.Children | Where-Object { $_.Class -eq "Attributes" } | Select-Object -First 1
                if ($attr -and $attr.Name -ne "") {
                    $gName = $attr.Name
                }
            }
            if ($gName -ne "") {
                $effGroupVar = $gName
                [void]$detectedGroups.Add($gName)
            }
        }

        # Si es un objeto (soldado o vehículo) con tipo de clase válido
        if ($node.DataType -eq "Object" -and $node.Type -ne "") {
            # El nombre de la unidad puede estar en el propio nodo o en su hijo 'Attributes'
            $uName = $node.Name
            if ($uName -eq "") {
                $attr = $node.Children | Where-Object { $_.Class -eq "Attributes" } | Select-Object -First 1
                if ($attr -and $attr.Name -ne "") {
                    $uName = $attr.Name
                }
            }

            # Filtrar artefactos del 3DEN: no confundir nombres de clase de items/mochilas con varNames
            if ($uName -match '^B_SPE_|^SPE_|^LIB_|^WW2_') {
                $uName = ""
            }

            # Si este nodo no tiene Pos directamente, buscar en sus hijos (ej: class PositionInfo)
            $effPos = $node.Pos
            if ($effPos[0] -eq 0.0 -and $effPos[1] -eq 0.0 -and $effPos[2] -eq 0.0) {
                $posChild = $node.Children | Where-Object { $_.Class -eq "PositionInfo" -and ($_.Pos[0] -ne 0.0 -or $_.Pos[1] -ne 0.0 -or $_.Pos[2] -ne 0.0) } | Select-Object -First 1
                if ($posChild) { $effPos = $posChild.Pos }
            }

            # Si este nodo no tiene Angles directamente, buscar en sus hijos (ej: class PositionInfo)
            $effAngles = $node.Angles
            if ($effAngles.Count -lt 2 -or ($effAngles[0] -eq 0.0 -and $effAngles[1] -eq 0.0)) {
                $posChild = $node.Children | Where-Object { $_.Class -eq "PositionInfo" -and $_.Angles.Count -ge 2 } | Select-Object -First 1
                if ($posChild) { $effAngles = $posChild.Angles }
            }

            $relDir = 0.0
            if ($effAngles.Count -ge 2) {
                $relDir = [Math]::Round(($effAngles[1] * (180.0 / [Math]::PI)), 1)
                if ($relDir -lt 0) { $relDir += 360.0 }
            }

            $isVeh = ($node.Type -match "Car|Truck|Tank|Wheeled|APC|Armored|Jeep|Willys|Kübel|Kubel|Sdkfz|Halftrack")

            $entityEntry = @{
                Type       = $node.Type
                Offset     = $effPos
                RelDir     = $relDir
                VarName    = $uName
                GroupVar   = $effGroupVar
                Rank       = $node.Rank
                IsVehicle  = $isVeh
            }
            [void]$detectedEntities.Add($entityEntry)
        }

        foreach ($child in $node.Children) {
            Walk-Tree $child $effGroupVar
        }
    }

    Walk-Tree $root ""

    Write-Host (" -> Total entidades leídas: {0} (Grupos: {1})" -f $detectedEntities.Count, $detectedGroups.Count) -ForegroundColor Green

    # Si no se encontró líder/capitán como ancla, usar la primera entidad leída
    if (-not $anchorPos -and $detectedEntities.Count -gt 0) {
        $anchorX = $detectedEntities[0].Offset[0]
        $anchorY = $detectedEntities[0].Offset[1]
        $anchorZ = $detectedEntities[0].Offset[2]
    }

    # Generar contenido SQF puro (Data-Driven HashMap)
    $sqfBuilder = [System.Text.StringBuilder]::new()
    [void]$sqfBuilder.AppendLine("/*")
    [void]$sqfBuilder.AppendLine("    ================================================================================")
    [void]$sqfBuilder.AppendLine("    FTCS DOCTRINE DATA TEMPLATE: $cleanName")
    [void]$sqfBuilder.AppendLine("    Generated automatically from 3DEN Composition: $compName")
    [void]$sqfBuilder.AppendLine("    Architecture: Pure Data-Driven HashMap (Arma 3 & Enfusion / Arma 4 compatible)")
    [void]$sqfBuilder.AppendLine("    ================================================================================")
    [void]$sqfBuilder.AppendLine("*/")
    [void]$sqfBuilder.AppendLine("")
    [void]$sqfBuilder.AppendLine("createHashMapFromArray [")
    [void]$sqfBuilder.AppendLine("    [`"doctrineID`", `"$doctrineId`"],")
    [void]$sqfBuilder.AppendLine("    [`"companyLetter`", `"$companyLetter`"],")
    $sideStr = $detectedSide.ToLower()
    [void]$sqfBuilder.AppendLine("    [`"side`", $sideStr],")
    
    # Required mods
    $modsArray = @()
    foreach ($m in $detectedMods) { $modsArray += "`"$m`"" }
    $modsStr = $modsArray -join ", "
    [void]$sqfBuilder.AppendLine("    [`"requiredMods`", [$modsStr]],")
    [void]$sqfBuilder.AppendLine("")
    [void]$sqfBuilder.AppendLine('    // === SELF-CONTAINED ORGANIZATIONAL STRUCTURE (designer-reviewed) ===')
    [void]$sqfBuilder.AppendLine('    // The composition encodes hierarchy (SQD_X_Y_TEAM_N group variables) and')
    [void]$sqfBuilder.AppendLine('    // unit roles. Semantic identity of squads/platoons/teams is declared here:')
    [void]$sqfBuilder.AppendLine('    // edit these values after conversion; they feed FTCS_fnc_applyDoctrine directly.')
    [void]$sqfBuilder.AppendLine('    ["platoonNames", ["Company HQ", "1st Platoon", "2nd Platoon", "3rd Platoon"]],')
    [void]$sqfBuilder.AppendLine('    ["squadsPerPlatoon", 4],')
    [void]$sqfBuilder.AppendLine('    ["isMechanized", false],')
    [void]$sqfBuilder.AppendLine('    ["transportAsset", ""],')
    [void]$sqfBuilder.AppendLine('    ["companyHQRoles", ["CO_CAPTAIN", "XO_LIEUTENANT", "FIRST_SERGEANT", "COMM_SERGEANT", "RADIO_OPERATOR", "MESSENGER_1", "MESSENGER_2", "COMPANY_MEDIC"]],')
    [void]$sqfBuilder.AppendLine('    ["platoonHQRoles", ["PLATOON_LEADER", "PLATOON_SERGEANT", "PLATOON_RTO", "PLATOON_RUNNER", "PLATOON_MEDIC"]],')
    [void]$sqfBuilder.AppendLine('    ["platoonHQTeamStructure", [["Command Element", ["PLATOON_LEADER", "PLATOON_RTO"]], ["Support Element", ["PLATOON_SERGEANT", "PLATOON_RUNNER", "PLATOON_MEDIC"]]]],')
    [void]$sqfBuilder.AppendLine('    ["squadDesignations", createHashMapFromArray [')
    [void]$sqfBuilder.AppendLine('        ["SQD_1_1", "1st Rifle Squad"],')
    [void]$sqfBuilder.AppendLine('        ["SQD_1_2", "2nd Rifle Squad"],')
    [void]$sqfBuilder.AppendLine('        ["SQD_1_3", "3rd Rifle Squad"],')
    [void]$sqfBuilder.AppendLine('        ["SQD_1_4", "Mortar Section"]')
    [void]$sqfBuilder.AppendLine('    ]],')
    [void]$sqfBuilder.AppendLine('    ["teamStructure", ["Scout Team", "Rifle Team A", "Rifle Team B", "BAR Support Team"]],')
    [void]$sqfBuilder.AppendLine('    ["teamRoles", ["ASSAULT", "ASSAULT", "ASSAULT", "SUPPORT"]],')
    [void]$sqfBuilder.AppendLine("    [`"entities`", [")

    for ($j = 0; $j -lt $detectedEntities.Count; $j++) {
        $ent = $detectedEntities[$j]
        # Calcular offset relativo exacto
        $relX = [Math]::Round(($ent.Offset[0] - $anchorX), 2)
        $relY = [Math]::Round(($ent.Offset[1] - $anchorY), 2)
        $relZ = [Math]::Round(($ent.Offset[2] - $anchorZ), 2)

        $comma = if ($j -lt ($detectedEntities.Count - 1)) { "," } else { "" }
        $lineOut = "        [`"{0}`", [{1}, {2}, {3}], {4}, `"{5}`", `"{6}`", `"{7}`", {8}]{9}" -f `
            $ent.Type, $relX, $relY, $relZ, $ent.RelDir, $ent.VarName, $ent.GroupVar, $ent.Rank, ($ent.IsVehicle.ToString().ToLower()), $comma
        [void]$sqfBuilder.AppendLine($lineOut)
    }

    [void]$sqfBuilder.AppendLine("    ]]")
    [void]$sqfBuilder.AppendLine("];")

    $outputFile = Join-Path $outputDir "$cleanName.sqf"
    [System.IO.File]::WriteAllText($outputFile, $sqfBuilder.ToString(), [System.Text.Encoding]::UTF8)

    Write-Host " [V] Guardado exitosamente en: $outputFile" -ForegroundColor Green
}

# Ejecutar conversión en los objetivos
foreach ($t in $targets) {
    $sqe = Join-Path $t.FullName "composition.sqe"
    Convert-SQEToDoctrineData -sqeFilePath $sqe -compName $t.Name -outputDir $outputFolder
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Proceso completado con éxito." -ForegroundColor Yellow
Write-Host "Los archivos de datos están listos en: Doctrines\Data\" -ForegroundColor DarkCyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
if ($AutoSelection -eq "") {
    Read-Host "Presiona Enter para cerrar esta ventana..."
}
