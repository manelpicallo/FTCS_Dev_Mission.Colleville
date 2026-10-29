$files = @(
    "description.ext",
    "init.sqf",
    "UI\FTCS_DeployDialog.hpp",
    "Functions\Spawning\fn_spawnDoctrine.sqf",
    "Functions\Spawning\fn_openDeployMenu.sqf",
    "Functions\Spawning\fn_initDeployMenu.sqf",
    "Functions\Spawning\fn_executeDeployment.sqf",
    "Functions\Spawning\fn_spawnSupportUnit.sqf",
    "Doctrines\Data\101_US_Para_Company.sqf",
    "Doctrines\Data\Support_Artillery.sqf",
    "Doctrines\Data\Support_Armor.sqf"
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
