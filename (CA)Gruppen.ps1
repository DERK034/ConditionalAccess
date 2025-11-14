#Install-Module Microsoft.Graph -Scope CurrentUser
#Install-Module Microsoft.Graph -AllowClobber -Force

#Connect-MgGraph -Scopes "User.Read.All" -TenantId "<Tenant-ID oder -Domain>"

# Verbindung zu Microsoft Graph
#Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.Read.All"
Connect-MgGraph -Scopes "User.Read.All" -TenantId b736bd25-cf0c-47a9-bdb2-012e28649dc4

# Funktion zur Erstellung statischer Gruppen
function New-Group {
    param (
        [string]$DisplayName,
        [string]$Description
    )

    $params = @{
        DisplayName     = $DisplayName
        Description     = $Description
        GroupTypes      = @()
        MailEnabled     = $false
        MailNickname    = ($DisplayName -replace '\s+', '').ToLower()
        SecurityEnabled = $true
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
    $eingabe = $eingabe.Trim()

    if ($eingabe -match "^x$") {
        return "custom"
    }

    foreach ($teil in $eingabe -split ",") {
        $teil = $teil.Trim()

        if ($teil -match "^\d+-\d+$") {
            $start, $end = $teil -split "-"
            $nummern += $start..$end
        } elseif ($teil -match "^\d+$") {
            $nummern += [int]$teil
        } elseif ($teil -match "^alle$" -or $teil -match "^\*$") {
            return "alle"
        }
    }

    return $nummern | Sort-Object -Unique
}

# Gruppendefinitionen
$gruppen = @(
    @{ DisplayName = "M365_CA_Innendienst";       Description = "Bedingter Zugriff - Gruppe für Geofencing - interne Mitarbeiter" },
    @{ DisplayName = "M365_CA_Deutschland";       Description = "Bedingter Zugriff - Gruppe für Geofencing - Mitarbeiterzugriff aus Deutschland" },
    @{ DisplayName = "M365_CA_Roaming";           Description = "Bedingter Zugriff - Gruppe für Geofencing - flexibler Mitarbeiterzugriff nach Länderliste" },
    @{ DisplayName = "M365_CA_Serviceaccounts";   Description = "Bedingter Zugriff - Gruppe für Geofencing - Serviceaccounts" }
)

# Interaktive Auswahl
Write-Host "`nWähle die Gruppen aus, die du erstellen möchtest:`n"

$gruppen | ForEach-Object -Begin { $i = 1 } -Process {
    Write-Host "$i) $($_.DisplayName)  —  $($_.Description)"
    $_.Index = $i
    $i++
}

Write-Host "`nx) Eigene benutzerdefinierte Gruppe erstellen"

# Eingabe des Benutzers
$auswahl = Read-Host "`nGib die Nummern oder Bereiche ein (z. B. 1-3,5 oder alle), oder 'x' für eigene Gruppe"
$nummern = Parse-Auswahl $auswahl

# Benutzerdefinierte Gruppe
if ($nummern -eq "custom") {
    $customName = Read-Host "📝 Gib den Anzeigenamen (DisplayName) deiner Gruppe ein"
    $customDesc = Read-Host "📝 Gib eine Beschreibung ein"

    if ([string]::IsNullOrWhiteSpace($customName)) {
        Write-Host "⚠️ Kein gültiger Anzeigename. Vorgang abgebrochen." -ForegroundColor Yellow
        return
    }

    New-Group -DisplayName $customName -Description $customDesc
    return
}

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
    New-Group -DisplayName $g.DisplayName -Description $g.Description
}
