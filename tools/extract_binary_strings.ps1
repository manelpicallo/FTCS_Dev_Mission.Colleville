$mChar = Get-ChildItem 'D:\SteamLibrary\steamapps\common\Arma 3\SPE\Addons' -Filter '*characters_germans*' | Select-Object -First 1
Write-Host "Addon: $($mChar.FullName)"
$bytes = [System.IO.File]::ReadAllBytes($mChar.FullName)
# Los nombres en binarized PBO estan en ASCII con null-terminators
$strList = [System.Collections.Generic.List[string]]::new()
$cur = [System.Text.StringBuilder]::new()

for ($i = 0; $i -lt $bytes.Length; $i++) {
    $b = $bytes[$i]
    if (($b -ge 65 -and $b -le 90) -or ($b -ge 97 -and $b -le 122) -or ($b -ge 48 -and $b -le 57) -or ($b -eq 95)) {
        [void]$cur.Append([char]$b)
    }
    else {
        if ($cur.Length -ge 8) {
            $s = $cur.ToString()
            if ($s -match '^SPE_') {
                $strList.Add($s)
            }
        }
        $cur.Clear()
    }
}

Write-Host "Total strings con SPE_ encontrados: $($strList.Count)"
$unique = $strList | Select-Object -Unique | Sort-Object
Write-Host "Total unicos: $($unique.Count)"
$unique | Where-Object { $_ -match 'GER|Sturm|Grenadier|Ober|Unter|Feld|Schuetz|Mortar|mgunner|medic|Haupt|Leut' } | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" }
