# Step "Install NuGet": restore all packages for the solution.
. "$PSScriptRoot\common.ps1"

$msbuild = Get-MSBuildPath
Invoke-Checked $msbuild @((Join-Path $RepoRoot 'DemoApp.sln'), '/t:Restore', '/v:m', '/nologo')
