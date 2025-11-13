# Verbindung zu Microsoft Graph
Connect-MgGraph -TenantId bd7fdd05-725d-4fbf-bf49-b4eb3694bd62 -Scopes "Group.ReadWrite.All", "Directory.Read.All"

# Funktion zur Erstellung dynamischer Gruppen
function New-DynamicGroup {
    param (
        [string]$DisplayName,
        [string]$Description,
        [string]$MembershipRule
    )

    $params = @{
        DisplayName                    = $DisplayName
        Description                    = $Description
        GroupTypes                     = @("DynamicMembership")
        MailEnabled                    = $false
        MailNickname                   = ($DisplayName -replace '\s+', '').ToLower()
        SecurityEnabled                = $true
        MembershipRule                 = $MembershipRule
        MembershipRuleProcessingState = "On"
    }

    try {
        Write-Host "📦 Erstelle Gruppe: $DisplayName ..."
        New-MgGroup @params
        Write-Host "✔️ Gruppe '$DisplayName' erfolgreich erstellt." -ForegroundColor Green
    } catch {
        Write-Host "❌ Fehler beim Erstellen von '$DisplayName': $_" -ForegroundColor Red
    }
}

# Funktion zur Verarbeitung der Auswahl (mit Bereichs- und Einzelnummern)
function Parse-Auswahl ($eingabe) {
    $nummern = @()

    foreach ($teil in $eingabe -split ",") {
        $teil = $teil.Trim()

        # Wenn der Teil ein Bereich ist (z. B. 1-3)
        if ($teil -match "^\d+-\d+$") {
            $start, $end = $teil -split "-"
            $nummern += $start..$end
        }
        # Wenn der Teil eine einzelne Zahl ist (z. B. 1)
        elseif ($teil -match "^\d+$") {
            $nummern += [int]$teil
        }
        # Falls "alle" eingegeben wird, alle Gruppen auswählen
        elseif ($teil -match "^alle$" -or $teil -match "^\*$") {
            return "alle"
        }
    }

    return $nummern | Sort-Object -Unique
}

# Dynamische Gruppendefinitionen
$gruppen = @(
    @{
        DisplayName = "DYN_GERÄT_Windows10"
        Description = "Dynamische Windows 10 Geräte in Intune"
        Rule = '(device.deviceOSType -contains "Windows") and (device.managementType -contains "MDM") and (device.deviceTrustType -contains "ServerAD") and (device.deviceOSVersion -startsWith "10.0.19")'
    },
    @{
        DisplayName = "DYN_GERÄT_Windows11"
        Description = "Dynamische Windows 11 Geräte in Intune"
        Rule = '(device.deviceOSType -contains "Windows") and (device.managementType -contains "MDM") and (device.deviceTrustType -contains "ServerAD") and ((device.deviceOSVersion -startsWith "10.0.22") or (device.deviceOSVersion -startsWith "10.0.26"))'
    },
    @{
        DisplayName = "DYN_GERÄT_WindowsServer"
        Description = "Dynamische Windows Server Geräte in Intune oder Microsoft Defender"
        Rule = '(device.deviceOSType -match "Windows Server") and (device.managementType -contains "MicrosoftSense")'
    },
    @{
        DisplayName = "DYN_GERÄT_AutoPilot"
        Description = "Dynamische Windows Geräte mit AutoPilot"
        Rule = '(device.devicePhysicalIDs -any (_ -startsWith "[ZTDid]"))'
    },
    @{
        DisplayName = "DYN_GERÄT_BYOD_iOS"
        Description = "Dynamische private Apple Geräte in Intune"
        Rule = '((device.deviceOSType -match "IPhone") or (device.deviceOSType -match "IPad")) and (device.managementType -match "MDM") and (device.deviceOwnership -match "Personal")'
    },
    @{
        DisplayName = "DYN_GERÄT_CORP_iOS"
        Description = "Dynamische Unternehmens-Apple Geräte in Intune"
        Rule = '((device.deviceOSType -match "IPhone") or (device.deviceOSType -match "IPad")) and (device.managementType -match "MDM") and (device.deviceOwnership -match "Company")'
    },
    @{
        DisplayName = "DYN_GERÄT_BYOD_Android"
        Description = "Dynamische Unternehmens-Android Geräte in Intune"
        Rule = '(device.deviceOSType -startsWith "Android") and (device.managementType -match "GoogleCloudDevice") and (device.deviceOwnership -match "Company")'
    },
    @{
        DisplayName = "DYN_GERÄT_CORP_Android"
        Description = "Dynamische private Android Geräte in Intune"
        Rule = '(device.deviceOSType -match "Android") and (device.managementType -match "MDM") and (device.deviceOwnership -match "Personal")'
    },
    @{
        DisplayName = "DYN_GERÄT_macOS"
        Description = "Dynamische macOS Geräte in Intune"
        Rule = '(device.deviceOSType -contains "Mac") and (device.managementType -contains "MDM")'
    }
)

# Interaktive Auswahl
Write-Host "`nWähle die Gruppen aus, die du erstellen möchtest:`n"

$gruppen | ForEach-Object -Begin { $i = 1 } -Process {
    Write-Host "$i) $($_.DisplayName)  —  $($_.Description)"
    $_.Index = $i
    $i++
}

# Eingabe des Benutzers
$auswahl = Read-Host "`nGib die Nummern oder Bereiche ein (z. B. 1-3,5,7 oder alle)"
$nummern = Parse-Auswahl $auswahl

# Prüfen, ob "alle" gewählt wurde
if ($nummern -eq "alle") {
    $nummern = $gruppen | ForEach-Object { $_.Index }
}

# Nur ausgewählte Gruppen erstellen
$ausgewaehlt = $gruppen | Where-Object { $nummern -contains $_.Index }

if ($ausgewaehlt.Count -eq 0) {
    Write-Host "⚠️ Keine gültigen Gruppen ausgewählt. Skript beendet." -ForegroundColor Yellow
    return
}

# Erstellung der ausgewählten Gruppen
foreach ($g in $ausgewaehlt) {
    New-DynamicGroup -DisplayName $g.DisplayName -Description $g.Description -MembershipRule $g.Rule
}
