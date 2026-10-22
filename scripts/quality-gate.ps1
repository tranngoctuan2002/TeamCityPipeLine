# Step "Quality gate" (improved pipeline): checks that FAIL the build, not just report.
# Gate 1: no hard-coded secrets in application config files under src/.
# Add more gates here as the team adopts them, for example:
#   - dotCover coverage threshold (TeamCity build feature + failure condition)
#   - SonarQube quality gate (SonarScanner for MSBuild)
#   - OWASP Dependency-Check for vulnerable NuGet packages
. "$PSScriptRoot\common.ps1"

$problems = @()

Get-ChildItem -Path (Join-Path $RepoRoot 'src') -Recurse -Include '*.config' | ForEach-Object {
    $file = $_
    [xml]$xml = Get-Content $file.FullName
    $settings = $xml.SelectNodes('//appSettings/add')
    foreach ($setting in $settings) {
        $looksSecret = $setting.key -match '(?i)(password|secret|apikey|token)'
        if ($looksSecret -and $setting.value) {
            $problems += "$($file.FullName.Substring($RepoRoot.Length + 1)): '$($setting.key)' has a hard-coded value"
        }
    }
    $connections = $xml.SelectNodes('//connectionStrings/add')
    foreach ($connection in $connections) {
        if ($connection.connectionString -match '(?i)password\s*=\s*[^;%]+') {
            $problems += "$($file.FullName.Substring($RepoRoot.Length + 1)): connection string '$($connection.name)' contains a password"
        }
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  $_" }
    throw "Quality gate failed: $($problems.Count) hard-coded secret(s). Move them to TeamCity password parameters."
}

Write-Host "Quality gate passed: no hard-coded secrets in src/**/*.config"
