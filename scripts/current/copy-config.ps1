# CURRENT pipeline, step "Copy config": overwrite the published Web.config with a file kept in Git.
# This mirrors today's pipeline on purpose. Problems it shows:
#   - the config (and any secret in it) lives in the repository as a plain file
#   - one fixed file per server, so the same build cannot be promoted between environments
param(
    [string]$PublishDir = 'out\publish'
)
. "$PSScriptRoot\..\common.ps1"

$source = Join-Path $RepoRoot 'config\current\Web.config'
$target = Join-Path (Join-Path $RepoRoot $PublishDir) 'Web.config'
Copy-Item -Path $source -Destination $target -Force
Write-Host "Copied $source -> $target"
