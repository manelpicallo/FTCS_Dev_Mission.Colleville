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

    # Estado del parser
    $currentGroup = ""
    $inEntity = $false
    $currentDataType = ""
    $currentType = ""
    $currentPos = @(0.0, 0.0, 0.0)
    $currentAngles = @(0.0, 0.0, 0.0)
    $currentName = ""
    $currentRank = "PRIVATE"
    $isVehicle = $false

    for ($i = 0; $i -lt $rawLines.Count; $i++) {
        $line = $rawLines[$i].Trim()

        if ($line -match 'class\s+CustomAttributes') {
            # Saltar bloques de CustomAttributes dentro de las entidades
            $inCustomAttributes = $true
            continue
        }

        if ($line -match 'class\s+Item\d+') {
            $inEntity = $true
            $currentDataType = ""
            $currentType = ""
            $currentPos = @(0.0, 0.0, 0.0)
            $currentAngles = @(0.0, 0.0, 0.0)
            $currentName = ""
            $currentRank = "PRIVATE"
            $isVehicle = $false
            continue
        }

        if ($line -match 'dataType="([^"]+)";') {
            $currentDataType = $matches[1]
            if ($currentDataType -eq "Group") {
                # Se abre un nuevo grupo
            }
            continue
        }

        if ($line -match 'name="([^"]+)";') {
            $var = $matches[1]
            if ($currentDataType -eq "Group") {
                $currentGroup = $var
                [void]$detectedGroups.Add($var)
            } else {
                $currentName = $var
            }
            continue
        }

        if ($line -match '^\s*type="([^"]+)";') {
            $val = $matches[1]
            # Ignorar tipos internos de atributos como STRING, SCALAR
            if ($val -notmatch '^(STRING|SCALAR|BOOLEAN|ARRAY)$') {
                $currentType = $val
                # Detectar prefijo del mod a partir de la clase (ej: SPE_, LIB_, IFA3_)
                if ($currentType -match '^([A-Za-z0-9]+)_') {
                    $prefix = $matches[1]
                    if ($prefix -in @("SPE", "LIB", "WW2", "IFA3", "fow")) {
                        [void]$detectedMods.Add($prefix)
                    }
                }
            }
            continue
        }

        if ($line -match 'rank="([^"]+)";') {
            $currentRank = $matches[1]
            continue
        }

        if ($line -match 'position\[\]=\{([^}]+)\};') {
            $coords = $matches[1].Split(',') | ForEach-Object { [double]$_.Trim() }
            if ($coords.Count -ge 3) {
                $currentPos = @($coords[0], $coords[2], $coords[1]) # [X, Y, Z] (En Arma Z es elevación, Y es norte en 2D)
            }
            continue
        }

        if ($line -match 'angles\[\]=\{([^}]+)\};') {
            $angles = $matches[1].Split(',') | ForEach-Object { [double]$_.Trim() }
            if ($angles.Count -ge 2) {
                $currentAngles = $angles
            }
            continue
        }

        # Cuando encontramos el cierre de la entidad o atributos
        if ($line -eq '};' -and $currentType -ne "") {
            $relDir = 0.0
            if ($currentAngles.Count -ge 2) {
                $relDir = [Math]::Round(($currentAngles[1] * (180.0 / [Math]::PI)), 1)
                if ($relDir -lt 0) { $relDir += 360.0 }
            }

            $isVeh = ($currentDataType -eq "Object" -and ($currentType -match "Car|Truck|Tank|Wheeled|APC|Armored|Jeep|Willys|Kübel|Kubel|Sdkfz|Halftrack"))

            $entityEntry = @{
                Type       = $currentType
                Offset     = $currentPos
                RelDir     = $relDir
                VarName    = $currentName
                GroupVar   = $currentGroup
                Rank       = $currentRank
                IsVehicle  = $isVeh
            }
            [void]$detectedEntities.Add($entityEntry)
            $currentType = ""
        }
    }

    Write-Host (" -> Total entidades leídas: {0} (Grupos: {1})" -f $detectedEntities.Count, $detectedGroups.Count) -ForegroundColor Green

    # Normalizar offsets relativos respecto al centro (primer líder / capitán o promedio)
    $anchorX = 0.0
    $anchorY = 0.0
    $anchorZ = 0.0

    # Buscar capitán o líder como punto de anclaje
    $anchorObj = $detectedEntities | Where-Object { $_.VarName -match "CAPTAIN|LEADER|HQ" } | Select-Object -First 1
    if ($anchorObj) {
        $anchorX = $anchorObj.Offset[0]
        $anchorY = $anchorObj.Offset[1]
        $anchorZ = $anchorObj.Offset[2]
    } elseif ($detectedEntities.Count -gt 0) {
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
    
    # Required mods
    $modsArray = @()
    foreach ($m in $detectedMods) { $modsArray += "`"$m`"" }
    $modsStr = $modsArray -join ", "
    [void]$sqfBuilder.AppendLine("    [`"requiredMods`", [$modsStr]],")
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
