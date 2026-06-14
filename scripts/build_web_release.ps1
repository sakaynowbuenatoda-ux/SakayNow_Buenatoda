$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot ".env"

function Get-DotEnvValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Test-Path -LiteralPath $envFile)) {
        return ""
    }

    $line = Get-Content -LiteralPath $envFile |
        Where-Object {
            $trimmed = $_.Trim()
            $trimmed.StartsWith("$Name=") -and -not $trimmed.StartsWith("#")
        } |
        Select-Object -First 1

    if (-not $line) {
        return ""
    }

    $value = $line.Substring($line.IndexOf("=") + 1).Trim()
    if ($value.Length -ge 2) {
        $first = $value[0]
        $last = $value[$value.Length - 1]
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }

    return $value
}

Set-Location -LiteralPath $projectRoot

$webApiKey = Get-DotEnvValue "GOOGLE_MAPS_WEB_API_KEY"
if ([string]::IsNullOrWhiteSpace($webApiKey)) {
    $webApiKey = Get-DotEnvValue "GOOGLE_SERVICES_API_KEY"
}

if ([string]::IsNullOrWhiteSpace($webApiKey)) {
    throw "Missing GOOGLE_MAPS_WEB_API_KEY or GOOGLE_SERVICES_API_KEY in .env."
}

Write-Host "Building Flutter web release with a compile-time Google Maps key."
flutter build web --release `
    --dart-define="GOOGLE_MAPS_WEB_API_KEY=$webApiKey" `
    --dart-define="GOOGLE_SERVICES_API_KEY=$webApiKey"
