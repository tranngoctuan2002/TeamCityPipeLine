# Step "SonarQube begin": must run BEFORE the build, so the scanner can hook into MSBuild.
#   -HostUrl     the SonarQube server, as seen from the agent
#   -ProjectKey  the project key in SonarQube
#   -Version     the build number; a new value per build is what lets SonarQube tell new code from old
# The token comes from the TeamCity password parameter env.SONAR_TOKEN and is passed to the scanner
# explicitly (/d:sonar.token). TeamCity masks the value in the build log.
param(
    [Parameter(Mandatory = $true)][string]$HostUrl,
    [Parameter(Mandatory = $true)][string]$ProjectKey,
    [Parameter(Mandatory = $true)][string]$Version
)
. "$PSScriptRoot\common.ps1"

if (-not $env:SONAR_TOKEN) {
    throw "SONAR_TOKEN is empty. Set the env.SONAR_TOKEN password parameter of this build."
}

# The scanner keeps its state in .sonarqube\ under the current folder: begin and end must share it.
Set-Location $RepoRoot
Invoke-Checked 'dotnet' @('tool', 'restore')
Invoke-Checked 'dotnet' @(
    'sonarscanner', 'begin',
    "/k:$ProjectKey",
    "/v:$Version",
    "/d:sonar.host.url=$HostUrl",
    '/d:sonar.qualitygate.wait=true',
    "/d:sonar.token=$env:SONAR_TOKEN"
)
