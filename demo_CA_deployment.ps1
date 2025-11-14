# ---------------------------------------
# Verbindung zu Microsoft Graph
# ---------------------------------------
Connect-MgGraph -Scopes "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess", "Application.Read.All" -NoWelcome

# Ordnerpfad (Skriptordner)
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# JSON-Dateien laden
$policyFiles = Get-ChildItem -Path $ScriptPath -Filter *.json

if ($policyFiles.Count -eq 0) {
    Write-Host "⚠️ Keine JSON-Dateien im Skriptordner gefunden!" -ForegroundColor Yellow
    exit
}

Write-Host "`nGefundene Conditional Access Vorlagen:`n"

# Index erzeugen
$policies = @()
$i = 1
foreach ($file in $policyFiles) {
    $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json

    $policies += [PSCustomObject]@{
        Index = $i
        FileName = $file.Name
        DisplayName = $json.displayName
        Json = $json
    }

    Write-Host "$i) $($json.displayName)  —  ($($file.Name))"
    $i++
}

# Auswahlfunktion (gleich wie dein Originalcode)
function Parse-Auswahl ($eingabe) {
    $nummern = @()

    foreach ($teil in $eingabe -split ",") {
        $teil = $teil.Trim()

        if ($teil -match "^\d+-\d+$") {
            $start, $end = $teil -split "-"
            $nummern += $start..$end
        }
        elseif ($teil -match "^\d+$") {
            $nummern += [int]$teil
        }
        elseif ($teil -match "^alle$" -or $teil -match "^\*$") {
            return "alle"
        }
    }
    return $nummern | Sort-Object -Unique
}

# Eingabe des Benutzers
$auswahl = Read-Host "`nWelche Richtlinien sollen erstellt werden? (z. B. 1-3,5 oder alle)"
$nummern = Parse-Auswahl $auswahl

if ($nummern -eq "alle") {
    $nummern = $policies.Index
}

$ausgewaehlt = $policies | Where-Object { $nummern -contains $_.Index }

if ($ausgewaehlt.Count -eq 0) {
    Write-Host "⚠️ Keine gültige Auswahl. Skript beendet." -ForegroundColor Yellow
    exit
}

# ---------------------------------------
# Richtlinien erstellen
# ---------------------------------------
foreach ($p in $ausgewaehlt) {
    Write-Host "`n📦 Erstelle CA Policy: $($p.DisplayName) ..."

    try {
        New-MgIdentityConditionalAccessPolicy -BodyParameter $p.Json | Out-Null
        Write-Host "✔️ Richtlinie '$($p.DisplayName)' erfolgreich erstellt." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Fehler beim Erstellen von '$($p.DisplayName)': $_" -ForegroundColor Red
    }
}

Write-Host "`n🎉 Vorgang abgeschlossen!"
