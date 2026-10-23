# Improved pipeline, deploy build: take the versioned artifact from the CI build,
# apply the configuration for this environment, and deploy it to the IIS site folder.
param(
    [Parameter(Mandatory = $true)][string]$ArtifactDir,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$Environment,
    # From the TeamCity password parameter env.DEMO_API_KEY (an env var keeps it off the command line).
    [string]$ApiKey = $env:DEMO_API_KEY
)
$ErrorActionPreference = 'Stop'

if (-not $ApiKey) {
    throw "ApiKey for $Environment is empty. Set the env.DEMO_API_KEY password parameter of this deploy build (see docs/pipeline.md)."
}

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

# /R /W: robocopy's default is 1,000,000 retries 30 s apart, so one locked file would hang the build.
robocopy $staging $TargetPath /MIR /XF app_offline.htm /R:3 /W:5 /NFL /NDL /NJH /NJS /NP | Out-Null
$copyResult = $LASTEXITCODE
Remove-Item $staging -Recurse -Force

# robocopy: exit codes 0-7 mean success, 8 and above mean failure.
# On failure app_offline.htm stays, so users never get a half-copied site; re-run or roll back.
if ($copyResult -ge 8) {
    throw "robocopy failed with exit code $copyResult. The site stays offline (app_offline.htm) until a deploy succeeds."
}
Remove-Item $offline -Force

Write-Host "Deployed $version to $Environment"
exit 0
