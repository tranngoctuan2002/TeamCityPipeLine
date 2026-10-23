# Step "Quality gate" (improved pipeline): checks that FAIL the build, not just report.
# Gate 1: no hard-coded secrets in application config files under src/.
#   (config/current/ is not scanned: the old pipeline still needs its fake key; see docs/pipeline.md)
# Add more gates here as the team adopts them, for example:
#   - dotCover coverage threshold (TeamCity build feature + failure condition)
#   - SonarQube quality gate (SonarScanner for MSBuild)
#   - OWASP Dependency-Check for vulnerable NuGet packages
# Self-check: scripts/tests/quality-gate.tests.ps1
param(
    [string]$Path = ''
)
. "$PSScriptRoot\common.ps1"

if (-not $Path) { $Path = Join-Path $RepoRoot 'src' }

$secretKey = '(?i)(password|passwd|pwd|secret|api[-_.]?key|token|credential)'
$secretInConnection = '(?i)\b(password|pwd)\s*=\s*[^;%\s]'

$problems = @()

Get-ChildItem -Path $Path -Recurse -Include '*.config' | ForEach-Object {
    $file = $_
    $name = $file.FullName.Replace("$RepoRoot\", '')
    [xml]$xml = Get-Content $file.FullName
    foreach ($setting in $xml.SelectNodes('//appSettings/add')) {
        if ($setting.key -match $secretKey -and $setting.value) {
            $problems += "${name}: '$($setting.key)' has a hard-coded value"
        }
    }
    foreach ($connection in $xml.SelectNodes('//connectionStrings/add')) {
        if ($connection.connectionString -match $secretInConnection) {
            $problems += "${name}: connection string '$($connection.name)' contains a password"
        }
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  $_" }
    throw "Quality gate failed: $($problems.Count) hard-coded secret(s). Move them to TeamCity password parameters."
}

Write-Host "Quality gate passed: no hard-coded secrets in $Path\**\*.config"
