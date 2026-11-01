param (
    [string]$TargetDir = "C:\Users\Usuario\Documents\Arma 3 - Other Profiles\PLAYER%201\compositions\FTCS_SPE_US_Army_Rifle_Company"
)

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$headerContent = @"
version=54;
name="FTCS_SPE_US_Army_Rifle_Company";
author="manipic";
category="EdSubcat_Default";
requiredAddons[]=
{
	"WW2_SPE_Assets_c_Characters_Americans_c_US_Army",
	"WW2_SPE_Assets_c_Characters_Americans_U1_c_US_Army",
	"WW2_SPE_Assets_c_Characters_Americans_c_US_Army_Gear",
	"WW2_SPE_Core_c_EditorPreviews_c",
	"WW2_SPE_Assets_c_Weapons_InfantryWeapons_c",
	"A3_Weapons_F",
	"WW2_Assets_c_Weapons_InfantryWeapons_c",
	"WW2_SPE_Assets_c_Weapons_Recoil_c",
	"WW2_SPE_Assets_c_Weapons_Sounds_c",
	"cba_jam_spe",
	"ace_compat_spe",
	"WW2_SPE_Core_c_Core_c_Eventhandlers"
};
"@
[System.IO.File]::WriteAllText("$TargetDir\header.sqe", $headerContent, [System.Text.Encoding]::UTF8)

# Posiciones base relativas (Mapeo idéntico al escalón táctico de FTCS)
# HQ en centro: [0, Y, 0]
# Platoon 1 (Rifle): X = -55
# Platoon 2 (Rifle): X = 0, adelantado en Y
# Platoon 3 (Rifle): X = +55
# Platoon 4 (Weapons Platoon): X = -25 (entre PLT 1 y 2) o en retaguardia/flanco táctico
# O bien:
# Platoon 1: X = -60
# Platoon 2: X = -20
# Platoon 3: X = +20
# Platoon 4: X = +60

# Armar SQE estructural
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('version=54;')
[void]$sb.AppendLine('center[]={4200.0,100.0,800.0};')
[void]$sb.AppendLine('class items')
[void]$sb.AppendLine('{')
[void]$sb.AppendLine('	items=1;')
[void]$sb.AppendLine('	class Item0')
[void]$sb.AppendLine('	{')
[void]$sb.AppendLine('		dataType="Layer";')
[void]$sb.AppendLine('		name="FTCS_SPE_US_Army_Rifle_Company";')
[void]$sb.AppendLine('		class Entities')
[void]$sb.AppendLine('		{')

$groups = [System.Collections.Generic.List[hashtable]]::new()
$globalId = 100

# Helper para agregar grupo
function Add-Group($groupName, $side, $units) {
    $g = @{
        Name  = $groupName
        Side  = "Independent"
        Units = $units
    }
    $groups.Add($g)
}

# -------------------------------------------------------------
# COMPANY HQ (SQUAD_0_0)
# -------------------------------------------------------------
$hqUnits = @(
    @{ Type = "SPE_US_Captain"; Rank = "CAPTAIN"; Name = "HQ_CO_CAPTAIN"; Pos = @(0, 0, 0) },
    @{ Type = "SPE_US_First_Lieutenant"; Rank = "LIEUTENANT"; Name = "HQ_XO_LIEUTENANT"; Pos = @(0, -2, 0) },
    @{ Type = "SPE_US_First_Sergeant"; Rank = "SERGEANT"; Name = "HQ_FIRST_SERGEANT"; Pos = @(0, -4, 0) },
    @{ Type = "SPE_US_Sergeant"; Rank = "SERGEANT"; Name = "HQ_COMM_SERGEANT"; Pos = @(0, -6, 0) },
    @{ Type = "SPE_US_Radioman"; Rank = "PRIVATE"; Name = "HQ_RADIO_OPERATOR"; Pos = @(0, -8, 0) },
    @{ Type = "SPE_US_Rifleman"; Rank = "CORPORAL"; Name = "HQ_MESSENGER_1"; Pos = @(0, -10, 0) },
    @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = "HQ_MESSENGER_2"; Pos = @(0, -12, 0) },
    @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = "HQ_MESSENGER_3"; Pos = @(0, -14, 0) },
    @{ Type = "SPE_US_Medic"; Rank = "PRIVATE"; Name = "HQ_MEDIC"; Pos = @(0, -16, 0) }
)
Add-Group "SQUAD_0_0" "Guerrila" $hqUnits

# -------------------------------------------------------------
# RIFLE PLATOONS 1, 2, 3
# Platoon 1: BaseX = -60
# Platoon 2: BaseX = -20
# Platoon 3: BaseX = +20
# -------------------------------------------------------------
$riflePlatoonBases = @(-60, -20, 20)

for ($p = 1; $p -le 3; $p++) {
    $pX = $riflePlatoonBases[$p - 1]
    # Platoon 1 = First Lieutenant (senior platoon leader), Platoons 2 y 3 = Second Lieutenant
    $pltLeaderClass = if ($p -eq 1) { "SPE_US_First_Lieutenant" } else { "SPE_US_Second_Lieutenant" }

    # Platoon HQ: SQUAD_P_0_TEAM_1 (Command Element) y SQUAD_P_0_TEAM_2 (Support Element)
    $pltHq1 = @(
        @{ Type = $pltLeaderClass; Rank = "LIEUTENANT"; Name = "PLT_${p}_LEADER"; Pos = @($pX, 36, 0) },
        @{ Type = "SPE_US_Radioman"; Rank = "CORPORAL"; Name = "PLT_${p}_RADIO_OPERATOR"; Pos = @($pX, 34, 0) }
    )
    Add-Group "SQUAD_${p}_0_TEAM_1" "Guerrila" $pltHq1

    $pltHq2 = @(
        @{ Type = "SPE_US_Sergeant"; Rank = "SERGEANT"; Name = "PLT_${p}_SERGEANT"; Pos = @($pX, 28, 0) },
        @{ Type = "SPE_US_Medic"; Rank = "PRIVATE"; Name = "PLT_${p}_MEDIC"; Pos = @($pX, 24, 0) },
        @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = "PLT_${p}_RUNNER"; Pos = @($pX, 26, 0) }
    )
    Add-Group "SQUAD_${p}_0_TEAM_2" "Guerrila" $pltHq2

    # 3 Rifle Squads por pelotón (SQD_P_1, SQD_P_2, SQD_P_3)
    # Cada squad tiene 3 teams: Able (TEAM_1), Baker (TEAM_2), Charlie (TEAM_3)
    $squadOffsetsY = @(74, 60, 46)
    for ($s = 1; $s -le 3; $s++) {
        $sY = $squadOffsetsY[$s - 1]

        # Able Team (Scouts + Squad Leader) -> SQUAD_P_S_TEAM_1
        $t1 = @(
            @{ Type = "SPE_US_SquadLead"; Rank = "SERGEANT"; Name = "SQD_${p}_${s}_LEADER"; Pos = @(($pX - 5), $sY, 0) },
            @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX - 5), ($sY + 4), 0) },
            @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX - 5), ($sY + 6), 0) }
        )
        Add-Group "SQUAD_${p}_${s}_TEAM_1" "Guerrila" $t1

        # Baker Team (BAR Base of Fire) -> SQUAD_P_S_TEAM_2
        $t2 = @(
            @{ Type = "SPE_US_Autorifleman"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX + 5), $sY, 0) },
            @{ Type = "SPE_US_Rifleman_AmmoBearer"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX + 5), ($sY - 2), 0) },
            @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX + 5), ($sY - 4), 0) }
        )
        Add-Group "SQUAD_${p}_${s}_TEAM_2" "Guerrila" $t2

        # Charlie Team (Maneuver Element: Assist Lead + Riflemen) -> SQUAD_P_S_TEAM_3
        $t3 = @(
            @{ Type = "SPE_US_Assist_SquadLead"; Rank = "CORPORAL"; Name = ""; Pos = @($pX, ($sY - 2), 0) },
            @{ Type = "SPE_US_Grenadier"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX - 2), ($sY - 4), 0) },
            @{ Type = "SPE_US_Grenadier"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX + 2), ($sY - 4), 0) },
            @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX - 1), ($sY - 6), 0) },
            @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = ""; Pos = @(($pX + 1), ($sY - 6), 0) },
            @{ Type = "SPE_US_Medic"; Rank = "PRIVATE"; Name = ""; Pos = @($pX, ($sY - 8), 0) }
        )
        Add-Group "SQUAD_${p}_${s}_TEAM_3" "Guerrila" $t3
    }
}

# -------------------------------------------------------------
# WEAPONS PLATOON (PLATOON 4)
# BaseX = +60
# -------------------------------------------------------------
$wpnX = 60

# Platoon 4 HQ
$p4Hq1 = @(
    @{ Type = "SPE_US_Second_Lieutenant"; Rank = "LIEUTENANT"; Name = "PLT_4_LEADER"; Pos = @($wpnX, 36, 0) },
    @{ Type = "SPE_US_Radioman"; Rank = "CORPORAL"; Name = "PLT_4_RADIO_OPERATOR"; Pos = @($wpnX, 34, 0) }
)
Add-Group "SQUAD_4_0_TEAM_1" "Guerrila" $p4Hq1

$p4Hq2 = @(
    @{ Type = "SPE_US_Sergeant"; Rank = "SERGEANT"; Name = "PLT_4_SERGEANT"; Pos = @($wpnX, 28, 0) },
    @{ Type = "SPE_US_Medic"; Rank = "PRIVATE"; Name = "PLT_4_MEDIC"; Pos = @($wpnX, 24, 0) },
    @{ Type = "SPE_US_Rifleman"; Rank = "PRIVATE"; Name = "PLT_4_RUNNER"; Pos = @($wpnX, 26, 0) }
)
Add-Group "SQUAD_4_0_TEAM_2" "Guerrila" $p4Hq2

# Squad 4_1: 1st Mortar Section (Unified)
$s41 = @(
    @{ Type = "SPE_US_SquadLead"; Rank = "SERGEANT"; Name = "SQD_4_1_LEADER"; Pos = @(($wpnX - 5), 18, 0) },
    @{ Type = "SPE_US_Mortar_Gunner"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX - 5), 16, 0) },
    @{ Type = "SPE_US_Mortar_AGunner"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX - 5), 14, 0) },
    @{ Type = "SPE_US_Mortar_AmmoBearer"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX - 5), 12, 0) }
)
Add-Group "SQUAD_4_1_TEAM_1" "Guerrila" $s41

# Squad 4_2: 2nd Mortar Section (Unified)
$s42 = @(
    @{ Type = "SPE_US_SquadLead"; Rank = "SERGEANT"; Name = "SQD_4_2_LEADER"; Pos = @(($wpnX + 5), 18, 0) },
    @{ Type = "SPE_US_Mortar_Gunner"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX + 5), 16, 0) },
    @{ Type = "SPE_US_Mortar_AGunner"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX + 5), 14, 0) },
    @{ Type = "SPE_US_Mortar_AmmoBearer"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX + 5), 12, 0) }
)
Add-Group "SQUAD_4_2_TEAM_1" "Guerrila" $s42

# Squad 4_3: 1st Machine Gun Section (Unified M2/M1919 - 5 men)
$s43 = @(
    @{ Type = "SPE_US_Assist_SquadLead"; Rank = "CORPORAL"; Name = "SQD_4_3_LEADER"; Pos = @(($wpnX - 5), 52, 0) },
    @{ Type = "SPE_US_HMGunner_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX - 5), 50, 0) },
    @{ Type = "SPE_US_AHMGunner_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX - 5), 48, 0) },
    @{ Type = "SPE_US_HMG_AmmoBearer_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX - 5), 46, 0) },
    @{ Type = "SPE_US_HMG_AmmoBearer_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX - 5), 44, 0) }
)
Add-Group "SQUAD_4_3_TEAM_1" "Guerrila" $s43

# Squad 4_4: 2nd Machine Gun Section (Unified M2/M1919 - 5 men)
$s44 = @(
    @{ Type = "SPE_US_Assist_SquadLead"; Rank = "CORPORAL"; Name = "SQD_4_4_LEADER"; Pos = @(($wpnX + 5), 52, 0) },
    @{ Type = "SPE_US_HMGunner_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX + 5), 50, 0) },
    @{ Type = "SPE_US_AHMGunner_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX + 5), 48, 0) },
    @{ Type = "SPE_US_HMG_AmmoBearer_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX + 5), 46, 0) },
    @{ Type = "SPE_US_HMG_AmmoBearer_M2"; Rank = "PRIVATE"; Name = ""; Pos = @(($wpnX + 5), 44, 0) }
)
Add-Group "SQUAD_4_4_TEAM_1" "Guerrila" $s44

# Escribir items en SQE
[void]$sb.AppendLine("			items=$($groups.Count);")

for ($gIdx = 0; $gIdx -lt $groups.Count; $gIdx++) {
    $grp = $groups[$gIdx]
    [void]$sb.AppendLine("			class Item$gIdx")
    [void]$sb.AppendLine('			{')
    [void]$sb.AppendLine('				dataType="Group";')
    [void]$sb.AppendLine('				side="Independent";')
    [void]$sb.AppendLine('				class Entities')
    [void]$sb.AppendLine('				{')
    [void]$sb.AppendLine("					items=$($grp.Units.Count);")

    for ($uIdx = 0; $uIdx -lt $grp.Units.Count; $uIdx++) {
        $u = $grp.Units[$uIdx]
        $globalId++
        [void]$sb.AppendLine("					class Item$uIdx")
        [void]$sb.AppendLine('					{')
        [void]$sb.AppendLine('						dataType="Object";')
        [void]$sb.AppendLine('						class PositionInfo')
        [void]$sb.AppendLine('						{')
        [void]$sb.AppendLine("							position[]={$($u.Pos[0]),$($u.Pos[2]),$($u.Pos[1])};")
        [void]$sb.AppendLine('						};')
        [void]$sb.AppendLine('						side="Independent";')
        [void]$sb.AppendLine('						flags=5;')
        [void]$sb.AppendLine('						class Attributes')
        [void]$sb.AppendLine('						{')
        [void]$sb.AppendLine('							skill=0.55;')
        [void]$sb.AppendLine("							rank=`"$($u.Rank)`";")
        if ($u.Name -ne "") {
            [void]$sb.AppendLine("							name=`"$($u.Name)`";")
        }
        [void]$sb.AppendLine('						};')
        [void]$sb.AppendLine("						id=$globalId;")
        [void]$sb.AppendLine("						type=`"$($u.Type)`";")
        [void]$sb.AppendLine('					};')
    }

    [void]$sb.AppendLine('				};')
    [void]$sb.AppendLine('				class Attributes')
    [void]$sb.AppendLine('				{')
    [void]$sb.AppendLine("					name=`"$($grp.Name)`";")
    [void]$sb.AppendLine('				};')
    [void]$sb.AppendLine("				id=$($globalId + 1000);")
    [void]$sb.AppendLine('			};')
}

[void]$sb.AppendLine('		};')
[void]$sb.AppendLine('	};')
[void]$sb.AppendLine('};')

[System.IO.File]::WriteAllText("$TargetDir\composition.sqe", $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Composición generada exitosamente en $TargetDir con $($groups.Count) grupos."
