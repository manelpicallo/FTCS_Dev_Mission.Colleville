continue
$c = Get-Content 'C:\Users\Usuario\Documents\Arma 3 - Other Profiles\PLAYER%201\compositions\FTCS_SPE_German_Sturmgrenadier_Company\composition.sqe' -Raw
$matches = [regex]::Matches($c, 'type="([^"]+)";')
$matches | ForEach-Object { $_.Groups[1].Value } | Group-Object | Select-Object Name, Count | Format-Table -AutoSize
