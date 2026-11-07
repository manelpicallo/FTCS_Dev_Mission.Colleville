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
    "Functions\Roads\fn_roadFindSegment.sqf",
    "Functions\Roads\fn_roadBuildPath.sqf",
    "Functions\Roads\fn_roadGetPointsBehind.sqf",
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
    "Doctrines\Data\Support_Armor_Soviet.sqf",
    "Doctrines\Data\Support_Artillery_Japanese.sqf",
    "Doctrines\Data\Support_Armor_Japanese.sqf"
)

foreach ($f in $files) {
    if (-not (Test-Path $f)) {
        Write-Host "MISSING: $f" -ForegroundColor Red
        continue
    }
    $c = Get-Content -Path $f -Raw
    $ob = ([regex]::Matches($c, '\{')).Count
    $cb = ([regex]::Matches($c, '\}')).Count
    $okB = ($ob -eq $cb)

    $obr = ([regex]::Matches($c, '\[')).Count
    $cbr = ([regex]::Matches($c, '\]')).Count
    
    $op = ([regex]::Matches($c, '\(')).Count
    $cp = ([regex]::Matches($c, '\)')).Count

    $status = if ($ob -eq $cb -and $obr -eq $cbr -and $op -eq $cp) { "OK" } else { "MISMATCH" }
    Write-Host "$status -> $f | Braces: $ob/$cb | Brackets: $obr/$cbr | Parens: $op/$cp"
}
