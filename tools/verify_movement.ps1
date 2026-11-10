$files = @("Functions\Movement\fn_movementBoundTeams.sqf", "Functions\Movement\fn_mvSquadAdvanceToPoint.sqf", "Functions\Movement\fn_mvTeamMarchLoop.sqf", "Functions\Interactions\fn_applyCommandToTarget.sqf", "Functions\Formations\fn_squadOrderApply.sqf", "Functions\Core\fn_registryInit.sqf")

function Get-StrippedCode([string]$raw) {
    $sb = New-Object System.Text.StringBuilder
    $i = 0; $n = $raw.Length
    $inBlock = $false; $inLine = $false; $inStr = $false
    while ($i -lt $n) {
        $c = $raw[$i]
        $next = if ($i + 1 -lt $n) { $raw[$i + 1] } else { [char]' ' }
        if ($inBlock) { if ($c -eq '*' -and $next -eq '/') { $inBlock = $false; $i += 2 } else { $i++ }; continue }
        if ($inLine) { if ($c -eq "`n") { $inLine = $false }; $i++; continue }
        if ($inStr) { if ($c -eq '"') { if ($next -eq '"') { $i += 2 } else { $inStr = $false; $i++ } } else { $i++ }; continue }
        if ($c -eq '/' -and $next -eq '*') { $inBlock = $true; $i += 2; continue }
        if ($c -eq '/' -and $next -eq '/') { $inLine = $true; $i += 2; continue }
        if ($c -eq '"') { $inStr = $true; $i++; continue }
        [void]$sb.Append($c); $i++
    }
    return $sb.ToString()
}

foreach ($f in $files) {
    if (-not (Test-Path $f)) { Write-Host "MISSING: $f" -ForegroundColor Red; continue }
    $c = Get-StrippedCode (Get-Content -Path $f -Raw)
    $ob = ([regex]::Matches($c, '\{')).Count; $cb = ([regex]::Matches($c, '\}')).Count
    $obr = ([regex]::Matches($c, '\[')).Count; $cbr = ([regex]::Matches($c, '\]')).Count
    $op = ([regex]::Matches($c, '\(')).Count; $cp = ([regex]::Matches($c, '\)')).Count
    $status = if ($ob -eq $cb -and $obr -eq $cbr -and $op -eq $cp) { "OK" } else { "MISMATCH" }
    Write-Host "$status -> $f | Braces: $ob/$cb | Brackets: $obr/$cbr | Parens: $op/$cp"
}
