# Step "Check the tool": fail fast if the agent is missing what the build needs.
. "$PSScriptRoot\common.ps1"

$msbuild = Get-MSBuildPath
Write-Host "MSBuild : $msbuild"

$msbuildRoot = $msbuild.Substring(0, $msbuild.IndexOf('\MSBuild\') + '\MSBuild'.Length)
$webTargets = Get-ChildItem -Path $msbuildRoot -Recurse -Filter 'Microsoft.WebApplication.targets' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $webTargets) {
    throw "Microsoft.WebApplication.targets not found. Add the 'Web development build tools' workload to Build Tools."
}
Write-Host "Web targets : $($webTargets.FullName)"

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnet) {
    throw ".NET SDK (dotnet) not found. It is needed to restore the SDK-style projects and run the tests."
}
Write-Host "dotnet  : $($dotnet.Source)"

# Hand the MSBuild path to the next steps.
Write-Host "##teamcity[setParameter name='env.MSBUILD_PATH' value='$msbuild']"
