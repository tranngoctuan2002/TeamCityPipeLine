# CURRENT pipeline, step "Copy artifact to hosting server": mirror the build output onto the site folder.
# This mirrors today's pipeline on purpose. Problems it shows:
#   - nothing is stored or versioned, so there is no previous build to roll back to
#   - nothing checks the site after the copy
param(
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [string]$PublishDir = 'out\publish'
)
. "$PSScriptRoot\..\common.ps1"

$source = Join-Path $RepoRoot $PublishDir
New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null

robocopy $source $TargetPath /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

Write-Host "Copied $source -> $TargetPath"
exit 0
