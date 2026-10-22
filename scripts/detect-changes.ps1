# Step "Detect code changes" (current pipeline): list what changed in this build.
# In the improved pipeline the VCS trigger does this job, so no step is needed.
param(
    [string]$ChangedFilesFile = ''
)
$ErrorActionPreference = 'Stop'

if (-not $ChangedFilesFile -or -not (Test-Path $ChangedFilesFile)) {
    Write-Host "No change list available (manual run or first build)."
    exit 0
}

$changes = @(Get-Content $ChangedFilesFile | Where-Object { $_ -and -not $_.StartsWith('--') })
Write-Host "Files changed in this build: $($changes.Count)"
$changes | ForEach-Object { Write-Host "  $_" }
