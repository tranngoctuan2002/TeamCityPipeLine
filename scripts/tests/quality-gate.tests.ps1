# Self-check for quality-gate.ps1: clean configs pass, hard-coded secrets fail.
# Run: powershell -File scripts\tests\quality-gate.tests.ps1   (exit code 0 = all cases OK)
# No $ErrorActionPreference = 'Stop' here: in Windows PowerShell 5.1 the gate's stderr would abort this script.
$gate = Join-Path $PSScriptRoot '..\quality-gate.ps1'

$cases = @(
    @{ Expect = 'pass'; Name = 'empty ApiKey';            Xml = '<appSettings><add key="ApiKey" value="" /></appSettings>' },
    @{ Expect = 'pass'; Name = 'non-secret setting';      Xml = '<appSettings><add key="Environment" value="Staging" /></appSettings>' },
    @{ Expect = 'pass'; Name = 'integrated security';     Xml = '<connectionStrings><add name="Db" connectionString="Server=.;Database=App;Integrated Security=true" /></connectionStrings>' },
    @{ Expect = 'pass'; Name = 'password placeholder';    Xml = '<connectionStrings><add name="Db" connectionString="Server=.;User Id=app;Password=%DB_PASSWORD%" /></connectionStrings>' },
    @{ Expect = 'fail'; Name = 'ApiKey with value';       Xml = '<appSettings><add key="ApiKey" value="abc123" /></appSettings>' },
    @{ Expect = 'fail'; Name = 'api_key with value';      Xml = '<appSettings><add key="payment.api_key" value="abc123" /></appSettings>' },
    @{ Expect = 'fail'; Name = 'SmtpPassword with value'; Xml = '<appSettings><add key="SmtpPassword" value="hunter2" /></appSettings>' },
    @{ Expect = 'fail'; Name = 'Pwd in connection';       Xml = '<connectionStrings><add name="Db" connectionString="Server=.;Uid=sa;Pwd=hunter2" /></connectionStrings>' }
)

$failed = 0
foreach ($case in $cases) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('gate-test-' + [guid]::NewGuid())
    New-Item $dir -ItemType Directory | Out-Null
    Set-Content -Path (Join-Path $dir 'Web.config') -Value "<configuration>$($case.Xml)</configuration>"

    & powershell -NoProfile -ExecutionPolicy Bypass -File $gate -Path $dir *> $null
    $actual = if ($LASTEXITCODE -eq 0) { 'pass' } else { 'fail' }
    Remove-Item $dir -Recurse -Force

    $ok = $actual -eq $case.Expect
    if (-not $ok) { $failed++ }
    Write-Host ('{0} {1,-25} expected {2}, got {3}' -f $(if ($ok) { 'OK  ' } else { 'FAIL' }), $case.Name, $case.Expect, $actual)
}

if ($failed -gt 0) { throw "$failed quality gate case(s) wrong" }
Write-Host "All $($cases.Count) quality gate cases OK"
