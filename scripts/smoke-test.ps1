# Step "Smoke test" (improved pipeline): after a deploy, check the site really works
# and runs the version we just deployed.
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [string]$ExpectedVersion = $env:DEPLOYED_VERSION,
    [int]$Attempts = 10,
    [int]$DelaySeconds = 3
)
$ErrorActionPreference = 'Stop'

if (-not $ExpectedVersion) {
    throw "No version to expect: pass -ExpectedVersion, or run this after deploy.ps1 (it sets env.DEPLOYED_VERSION)."
}

$healthUrl = $Url.TrimEnd('/') + '/Health.ashx'
# Exact match: "OK 1.0.12" must not pass when we expect 1.0.1.
$expected = "OK $ExpectedVersion"
Write-Host "Smoke test: $healthUrl (expecting '$expected')"

for ($i = 1; $i -le $Attempts; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 15
        $body = $response.Content.Trim()
        if ($response.StatusCode -eq 200 -and $body -eq $expected) {
            Write-Host "Smoke test passed: $body"
            exit 0
        }
        Write-Host "Attempt ${i}: unexpected answer '$body'"
    }
    catch {
        Write-Host "Attempt ${i}: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $DelaySeconds
}

throw "Smoke test failed after $Attempts attempts: $healthUrl"
