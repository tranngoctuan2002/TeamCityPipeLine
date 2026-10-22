# Improved pipeline, deploy build: take the versioned artifact from the CI build,
# apply the configuration for this environment, and deploy it to the IIS site folder.
param(
    [Parameter(Mandatory = $true)][string]$ArtifactDir,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$Environment,
    [string]$ApiKey = ''
)
$ErrorActionPreference = 'Stop'

$zip = Get-ChildItem -Path $ArtifactDir -Filter 'DemoApp.Web.*.zip' | Select-Object -First 1
if (-not $zip) {
    throw "No DemoApp.Web.*.zip found in '$ArtifactDir'. Check the artifact dependency."
}

$version = $zip.BaseName.Substring('DemoApp.Web.'.Length)
Write-Host "Deploying version $version to $Environment ($TargetPath)"
Write-Host "##teamcity[buildNumber '$version']"
Write-Host "##teamcity[setParameter name='env.DEPLOYED_VERSION' value='$version']"

$staging = Join-Path $env:TEMP ("cicd-demo-" + [guid]::NewGuid())
Expand-Archive -Path $zip.FullName -DestinationPath $staging

# Configuration per environment: the artifact is the same everywhere, only these values change.
$configPath = Join-Path $staging 'Web.config'
[xml]$config = Get-Content $configPath
foreach ($setting in $config.configuration.appSettings.add) {
    if ($setting.key -eq 'Environment') { $setting.value = $Environment }
    if ($setting.key -eq 'ApiKey') { $setting.value = $ApiKey }
}
$config.configuration.'system.web'.compilation.SetAttribute('debug', 'false')
$config.Save($configPath)

New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
$offline = Join-Path $TargetPath 'app_offline.htm'
Set-Content -Path $offline -Value '<h1>Deploying a new version, back in a moment.</h1>'

robocopy $staging $TargetPath /MIR /XF app_offline.htm /NFL /NDL /NJH /NJS /NP | Out-Null
$copyResult = $LASTEXITCODE
Remove-Item $offline -Force
Remove-Item $staging -Recurse -Force

# robocopy: exit codes 0-7 mean success, 8 and above mean failure.
if ($copyResult -ge 8) {
    throw "robocopy failed with exit code $copyResult"
}

Write-Host "Deployed $version to $Environment"
exit 0
