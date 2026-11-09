# SQF balance checker: strips block comments, line comments and string literals
# before counting braces/brackets/parens, avoiding false positives from prose
# like "// 1) ..." or format strings "(S%1)".

$files = @(
    "description.ext",
    "init.sqf",
    "UI\FTCS_DeployDialog.hpp",
    "Functions\Core\fn_loadDoctrineData.sqf",
    "Functions\Spawning\fn_spawnDoctrine.sqf",
    "Functions\Spawning\fn_openDeployMenu.sqf",
    "Functions\Spawning\fn_initDeployMenu.sqf",
    "Functions\Spawning\fn_deployPreviewMarkerUpdate.sqf",
    "Functions\Spawning\fn_deploySupportCombosPopulate.sqf",
    "Functions\Spawning\fn_executeDeployment.sqf",
    "Functions\Spawning\fn_spawnSupportUnit.sqf",
    "Functions\Interactions\fn_initCommandingMenus.sqf",
    "Functions\Interactions\fn_applyCommandToTarget.sqf",
    "Functions\Interactions\fn_openSubordinateMenu.sqf",
    "Functions\Interactions\fn_initUnitInteractions.sqf",
    "Functions\Formations\fn_formationsApplyPlatoonOrder.sqf",
    "Functions\Formations\fn_formationsTypePlatoonSet.sqf",
    "Functions\Formations\fn_formationsTypeSquadSet.sqf",
    "Functions\Formations\fn_formationsGroupDoFollowCommander.sqf",
    "Functions\Formations\fn_formationsGroupListFollowCommander.sqf",
    "Functions\Formations\fn_formationsPaceSquadGet.sqf",
    "Functions\Formations\fn_formationsCurrentPositionSet.sqf",
    "Functions\Formations\fn_formationsLiveSlotsDebugWorker.sqf",
    "Functions\Formations\fn_formationsRoadColumnSet.sqf",
    "Functions\Formations\fn_formationsGroupFollowRoad.sqf",
    "Functions\Formations\fn_formationsRoadCompactColumn.sqf",
    "Functions\Formations\fn_roadEdgeModeToggle.sqf",
    "Functions\Formations\fn_trailColumnSet.sqf",
    "Functions\Formations\fn_formationsTrailCompactColumn.sqf",
    "Functions\Formations\fn_marchStuckWatchdog.sqf",
    "Functions\Formations\fn_formationsGroupFollowTrail.sqf",
    "Functions\Roads\fn_trailAdvanceAnchor.sqf",
    "Functions\Roads\fn_roadFindSegment.sqf",
    "Functions\Roads\fn_roadBuildPath.sqf",
    "Functions\Roads\fn_roadGetPointsBehind.sqf",
    "Functions\Roads\fn_roadPathExtend.sqf",
    "Functions\Roads\fn_roadAdvanceAnchor.sqf",
    "Functions\Roads\fn_roadReanchor.sqf",
    "Functions\Squads\fn_squadTarget3DScan.sqf",
    "Functions\Squads\fn_squadOrderApply.sqf",
    "Functions\Targeting\fn_targetScan.sqf",
    "Functions\Targeting\fn_targetMark.sqf",
    "Functions\Targeting\fn_targetGet.sqf",
    "Functions\Targeting\fn_targetClear.sqf",
    "Functions\Core\fn_registryInit.sqf",
    "Functions\Groups\fn_groupSetAwareMode.sqf",
    "Functions\Groups\fn_groupSetStance.sqf",
    "Functions\Groups\fn_groupSetROE.sqf",
    "Functions\Groups\fn_groupSetSpeed.sqf",
    "Functions\Groups\fn_commanderStanceSyncWorker.sqf",
    "Functions\Groups\fn_platoonSetOperationalPhase.sqf",
    "Functions\Core\fn_applyDoctrine.sqf",
    "Doctrines\Data\101_US_Para_Company_V2_1.sqf",
    "Doctrines\Data\SPE_German_Sturmgrenadier_Company.sqf",
    "Doctrines\Data\SPE_US_Army_Rifle_Company.sqf",
    "Doctrines\Data\Doctrines_Registry.sqf",
    "Doctrines\Data\Support_Registry.sqf",
    "Doctrines\Data\Support_Artillery.sqf",
    "Doctrines\Data\Support_Artillery_German.sqf",
    "Doctrines\Data\Support_Armor.sqf",
    "Doctrines\Data\Support_Armor_German.sqf",
    "Doctrines\Data\Support_Artillery_Soviet.sqf",
    "Doctrines\Data\Support_Artillery_Japanese.sqf",
    "Doctrines\Data\Support_Armor_Japanese.sqf"
)

function Get-StrippedCode([string]$raw) {
    $sb = New-Object System.Text.StringBuilder
    $i = 0; $n = $raw.Length
    $inBlock = $false; $inLine = $false; $inStr = $false
    while ($i -lt $n) {
        $c = $raw[$i]
        $next = if ($i + 1 -lt $n) { $raw[$i + 1] } else { [char]' ' }
        if ($inBlock) {
            if ($c -eq '*' -and $next -eq '/') { $inBlock = $false; $i += 2 } else { $i++ }
            continue
        }
        if ($inLine) {
            if ($c -eq "`n") { $inLine = $false; [void]$sb.Append("`n") }
            $i++
            continue
        }
        if ($inStr) {
            if ($c -eq '"') {
                if ($next -eq '"') { $i += 2 } else { $inStr = $false; $i++ }
            } else { $i++ }
            continue
        }
        if ($c -eq '/' -and $next -eq '*') { $inBlock = $true; $i += 2; continue }
        if ($c -eq '/' -and $next -eq '/') { $inLine = $true; $i += 2; continue }
        if ($c -eq '"') { $inStr = $true; $i++; continue }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
}

foreach ($f in $files) {
    if (-not (Test-Path $f)) {
        Write-Host "MISSING: $f" -ForegroundColor Red
        continue
    }
    $c = Get-StrippedCode (Get-Content -Path $f -Raw)
    $ob = ([regex]::Matches($c, '\{')).Count
    $cb = ([regex]::Matches($c, '\}')).Count
    $obr = ([regex]::Matches($c, '\[')).Count
    $cbr = ([regex]::Matches($c, '\]')).Count
    $op = ([regex]::Matches($c, '\(')).Count
    $cp = ([regex]::Matches($c, '\)')).Count

    $status = if ($ob -eq $cb -and $obr -eq $cbr -and $op -eq $cp) { "OK" } else { "MISMATCH" }
    Write-Host "$status -> $f | Braces: $ob/$cb | Brackets: $obr/$cbr | Parens: $op/$cp"
}
