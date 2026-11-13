<#
.SYNOPSIS
    Script para enlazar misiones de Arma 3 (cualquier terreno) con el repositorio
    principal del proyecto FTCS (versionado en GitHub).
#>

# ---------------------------------------------------------------------------
# 0. Configuracion FIJA: rutas del repo y de las misiones
# ---------------------------------------------------------------------------
$RepoRoot = "C:\Users\Usuario\Desktop\Arma_3_code\FTCS_Development"
$MissionsRoot = "C:\Users\Usuario\Documents\Arma 3 - Other Profiles\PLAYER%201\missions"

# Carpetas y ficheros compartidos del repo -> Junction / HardLink
$SharedItems = @(
    "Functions",
    "Doctrines",
    "tools",
    "UI",
    "description.ext",
    "init.sqf",
    "LinkMission.bat"
)

# Ficheros EXCLUSIVOS de cada mision -> se copian como ficheros reales locales
$LocalFiles = @(
    "mission.sqm"
)

# ---------------------------------------------------------------------------
# 1. Validar rutas base
# ---------------------------------------------------------------------------
Clear-Host
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   FTCS - ENLAZADOR DE MISIONES AL REPOSITORIO PRINCIPAL" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repositorio (fuente compartida): $RepoRoot"
Write-Host "Carpeta de misiones del perfil:  $MissionsRoot"
Write-Host ""

if (-not (Test-Path $RepoRoot)) {
    Write-Host "[ERROR] No existe el repositorio: $RepoRoot" -ForegroundColor Red
    Pause; Exit 1
}
if (-not (Test-Path $MissionsRoot)) {
    Write-Host "[ERROR] No existe la carpeta de misiones: $MissionsRoot" -ForegroundColor Red
    Pause; Exit 1
}

# ---------------------------------------------------------------------------
# 2. Listar misiones existentes y elegir destino (menu numerado)
# ---------------------------------------------------------------------------
$missions = @(Get-ChildItem $MissionsRoot -Directory | Sort-Object Name)
$linked = @()
for ($i = 0; $i -lt $missions.Count; $i++) {
    $m = $missions[$i]
    foreach ($item in $SharedItems) {
        $p = Join-Path $m.FullName $item
        if (Test-Path $p) {
            $it = Get-Item $p -Force
            if ($it.LinkType -and ((Split-Path -Parent $it.Target) -eq $RepoRoot)) { $linked += $i; break }
        }
    }
}

Write-Host "Misiones disponibles:" -ForegroundColor Cyan
Write-Host ""
for ($i = 0; $i -lt $missions.Count; $i++) {
    $tag = if ($linked -contains $i) { "[ENLAZADA]" } else { "           " }
    Write-Host ("  {0,2}) {1} {2}" -f ($i + 1), $tag, $missions[$i].Name)
}
Write-Host ("  {0,2}) [NUEVA] Escribir el nombre de una mision manualmente" -f ($missions.Count + 1))
Write-Host ""

$sel = Read-Host "Selecciona la mision a enlazar [1-$($missions.Count + 1)]"
$nombreMision = $null
if ($sel -match '^\d+$') {
    $idx = [int]$sel - 1
    if ($idx -ge 0 -and $idx -lt $missions.Count) { $nombreMision = $missions[$idx].Name }
    elseif ($idx -eq $missions.Count) { $nombreMision = Read-Host "Nombre exacto de la NUEVA mision (ej. FTCS_Dev_Mission.Altis)" }
}
if ([string]::IsNullOrWhiteSpace($nombreMision)) {
    Write-Host "[ERROR] Seleccion no valida." -ForegroundColor Red; Pause; Exit 1
}
$rutaDestino = Join-Path $MissionsRoot $nombreMision

# ---------------------------------------------------------------------------
# 3. Pedir/validar el mission.sqm local de esa mision
# ---------------------------------------------------------------------------
$missionSqmOrigen = Join-Path $rutaDestino "mission.sqm"
if (-not (Test-Path $missionSqmOrigen)) {
    $resp = Read-Host "No existe $missionSqmOrigen. Ruta completa del mission.sqm de ESTA mision (Enter para abortar)"
    if ([string]::IsNullOrWhiteSpace($resp) -or -not (Test-Path $resp)) {
        Write-Host "[ERROR] mission.sqm no encontrado. Abre antes la mision en Eden y guardala." -ForegroundColor Red
        Pause; Exit 1
    }
    $missionSqmOrigen = $resp
}

# ---------------------------------------------------------------------------
# 4. Preparar la carpeta destino SIN destruir nada silenciosamente
# ---------------------------------------------------------------------------
if (-not (Test-Path $rutaDestino)) {
    New-Item -ItemType Directory -Path $rutaDestino -Force | Out-Null
    Write-Host "[OK] Carpeta de mision creada: $rutaDestino" -ForegroundColor Green
} else {
    # Un junction se elimina solo con su metodo nativo (nunca -Recurse, que en
    # PowerShell 5.1 puede atravesar el enlace y borrar el repo).
    Write-Host "[INFO] La carpeta de mision ya existe: $rutaDestino" -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# 5. Crear los enlaces compartidos (uno por item compartido del repo)
# ---------------------------------------------------------------------------
Write-Host ""
foreach ($item in $SharedItems) {
    $src = Join-Path $RepoRoot $item
    $dst = Join-Path $rutaDestino $item
    if (-not (Test-Path $src)) {
        Write-Host "[SKIP] No existe en el repo (se omite): $item" -ForegroundColor DarkYellow
        continue
    }
    if (Test-Path $dst) {
        $existing = Get-Item $dst -Force
        $isLink = $existing.LinkType -ne $null
        if ($isLink) {
            # Reposicionar el enlace de forma segura (solo el enlace, nunca su contenido)
            $existing.Delete()
            Write-Host "[RELINK] Enlace anterior reposicionado: $item" -ForegroundColor DarkYellow
        } else {
            # Elemento REAL: pedir confirmacion antes de sustituirlo
            $resp = Read-Host "[?] '$item' existe como elemento REAL en la mision. Sustituirlo por un enlace al repo? (s/N)"
            if ($resp -notmatch "^[sS]") { Write-Host "[SKIP] Se conserva el elemento real: $item" -ForegroundColor DarkYellow; continue }
            if ($existing.PSIsContainer) { Remove-Item $dst -Recurse -Force } else { $existing.Delete() }
            Write-Host "[REPLACED] Elemento real sustituido por enlace: $item" -ForegroundColor DarkYellow
        }
    }
    $srcItem = Get-Item $src -Force
    if ($srcItem.PSIsContainer) {
        New-Item -ItemType Junction -Path $dst -Target $src -ErrorAction Stop | Out-Null
    } else {
        # Ficheros compartidos: hardlink para mantenerlos sincronizados
        New-Item -ItemType HardLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
    }
    Write-Host "[LINK] $item -> $src" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 6. Copiar los ficheros locales de la mision (por-terreno, NO compartidos)
# ---------------------------------------------------------------------------
Write-Host ""
foreach ($file in $LocalFiles) {
    $dst = Join-Path $rutaDestino $file
    if ((Resolve-Path $missionSqmOrigen).Path -eq (Resolve-Path $dst -ea SilentlyContinue)) {
        Write-Host "[OK] $file ya existe en la mision (se conserva)" -ForegroundColor Green
        continue
    }
    Copy-Item -Path $missionSqmOrigen -Destination $dst -Force
    Write-Host "[COPIA] $file (fichero local de esta mision, no versionado por el repo)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 7. Resumen final
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   ENLACE COMPLETADO" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Mision:        $rutaDestino"
Write-Host "Codigo compartido (Junctions/HardLinks) -> $RepoRoot"
Write-Host "Ficheros por-mision (copia local): mission.sqm"
Write-Host ""
Write-Host "IMPORTANTE: el mission.sqm es LOCAL de esta mision y NO viaja con el repo."
Write-Host "Cada terreno nuevo: 1) crea la mision vacia en Eden y guardala, 2) ejecuta"
Write-Host "LinkMission.bat del repositorio y elige esa mision en el menu." -ForegroundColor Yellow
Write-Host ""
Pause
