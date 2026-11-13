# Step "SonarQube end": run AFTER the build and the tests. Sends the analysis to SonarQube, waits for
# the Quality Gate, and fails the build when it fails (sonar.qualitygate.wait, set in sonar-begin.ps1).
. "$PSScriptRoot\common.ps1"

if (-not $env:SONAR_TOKEN) {
    throw "SONAR_TOKEN is empty. Set the env.SONAR_TOKEN password parameter of this build."
}

Set-Location $RepoRoot
# "end" needs the token too: it uploads the analysis and asks for the Quality Gate.
Invoke-Checked 'dotnet' @('sonarscanner', 'end', "/d:sonar.token=$env:SONAR_TOKEN")
