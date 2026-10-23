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

# DemoApp.Core and DemoApp.Tests are SDK-style projects: MSBuild needs the .NET SDK resolver,
# which only the ".NET SDK" component of Build Tools installs (a standalone dotnet SDK is not enough).
$msbuildBin = $msbuild.Substring(0, $msbuild.IndexOf('\Bin\') + '\Bin'.Length)
$sdkResolver = Join-Path $msbuildBin 'SdkResolvers\Microsoft.DotNet.MSBuildSdkResolver'
if (-not (Test-Path $sdkResolver)) {
    throw "MSBuild cannot build SDK-style projects ($sdkResolver is missing). Add the '.NET SDK' component to Build Tools."
}
Write-Host "SDK resolver : $sdkResolver"

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnet) {
    throw ".NET SDK (dotnet) not found. It is needed to restore the SDK-style projects and run the tests."
}
Write-Host "dotnet  : $($dotnet.Source)"

# Hand the MSBuild path to the next steps.
Write-Host "##teamcity[setParameter name='env.MSBUILD_PATH' value='$msbuild']"
