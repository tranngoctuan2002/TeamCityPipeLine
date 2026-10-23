# Step "Unit tests" (improved pipeline): run the NUnit tests against the Release build of the previous step.
# Results go to TestResults\*.trx; the "XML report processing" build feature shows them on the Tests tab.
param(
    [string]$Configuration = 'Release'
)
. "$PSScriptRoot\common.ps1"

Invoke-Checked 'dotnet' @(
    'test', (Join-Path $RepoRoot 'tests\DemoApp.Tests\DemoApp.Tests.csproj'),
    '-c', $Configuration,
    '--no-build',
    '--logger', 'trx',
    '--results-directory', (Join-Path $RepoRoot 'TestResults')
)
