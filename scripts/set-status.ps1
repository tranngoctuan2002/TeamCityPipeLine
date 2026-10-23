# Step "Set build status" (deploy builds): show what went where, e.g. "Deployed 1.0.12 to Staging".
# TeamCity only expands {build.status.text} in a status text, so the version comes from deploy.ps1.
param(
    [Parameter(Mandatory = $true)][string]$Environment,
    [string]$Version = $env:DEPLOYED_VERSION
)
$ErrorActionPreference = 'Stop'

Write-Host "##teamcity[buildStatus text='Deployed $Version to $Environment']"
