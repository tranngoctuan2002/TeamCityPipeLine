# Step "Build with MSBuild": compile the solution and publish the web app to a folder.
#   -Version     stamps the TeamCity build number into the app (improved pipeline only)
#   -PublishDir  folder the web app is published to (relative to the repo root)
param(
    [string]$Configuration = 'Release',
    [string]$Version = '',
    [string]$PublishDir = 'out\publish'
)
. "$PSScriptRoot\common.ps1"

$msbuild = Get-MSBuildPath

if ($Version) {
    $assemblyInfo = Join-Path $RepoRoot 'src\DemoApp.Web\Properties\AssemblyInfo.cs'
    $content = Get-Content $assemblyInfo -Raw
    $content = $content -replace 'AssemblyInformationalVersion\("[^"]*"\)', "AssemblyInformationalVersion(`"$Version`")"
    Set-Content -Path $assemblyInfo -Value $content -Encoding UTF8
    Write-Host "Version stamped: $Version"
}

Invoke-Checked $msbuild @(
    (Join-Path $RepoRoot 'DemoApp.sln'),
    "/p:Configuration=$Configuration",
    '/m', '/v:m', '/nologo'
)

$publishPath = Join-Path $RepoRoot $PublishDir
if (Test-Path $publishPath) {
    Remove-Item $publishPath -Recurse -Force
}

Invoke-Checked $msbuild @(
    (Join-Path $RepoRoot 'src\DemoApp.Web\DemoApp.Web.csproj'),
    "/p:Configuration=$Configuration",
    '/p:DeployOnBuild=true',
    '/p:WebPublishMethod=FileSystem',
    '/p:DeployDefaultTarget=WebPublish',
    "/p:PublishUrl=$publishPath",
    '/p:DeleteExistingFiles=true',
    '/v:m', '/nologo'
)

Write-Host "Published to $publishPath"
