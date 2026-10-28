# Shared helpers, dot-sourced by the other scripts.
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Get-MSBuildPath {
    if ($env:MSBUILD_PATH -and (Test-Path $env:MSBUILD_PATH)) {
        return $env:MSBUILD_PATH
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found. Install Visual Studio Build Tools 2022 on this agent."
    }

    $msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' |
        Select-Object -First 1
    if (-not $msbuild) {
        throw "MSBuild.exe not found. Install the MSBuild component of Visual Studio Build Tools."
    }

    # Prefer the 64-bit MSBuild: a 32-bit one run as SYSTEM restores NuGet packages into the
    # redirected SysWOW64 profile, where the 64-bit compiler cannot find them (CS0006).
    $msbuild64 = Join-Path (Split-Path $msbuild) 'amd64\MSBuild.exe'
    if (Test-Path $msbuild64) {
        return $msbuild64
    }
    return $msbuild
}

function Invoke-Checked {
    param([string]$Exe, [string[]]$Arguments)

    Write-Host "> $Exe $($Arguments -join ' ')"
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Exe failed with exit code $LASTEXITCODE"
    }
}
