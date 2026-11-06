$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse) {
    $tokens=$null;$parseErrors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)
    if ($parseErrors.Count) {throw "PowerShell syntax error in $($file.Name)."}
}
& "$PSScriptRoot\CheckSource.ps1" -Root $root
foreach ($relative in @('CLIProxyAccounts\Test.ps1','CLIProxyAccounts\TestQuotaRefresh.ps1','tests\Deployment.Tests.ps1','tests\Privacy.Tests.ps1','tests\Rainmeter.Tests.ps1','tests\Sync.Tests.ps1')) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $relative)
    if ($LASTEXITCODE -ne 0) {throw "Verification failed: $relative"}
}
if (Get-Command python -ErrorAction SilentlyContinue) {
    $hasLupa=$false
    try {& python -c 'import importlib.util,sys; sys.exit(0 if importlib.util.find_spec("lupa") else 1)' 2>$null;$hasLupa=$LASTEXITCODE -eq 0} catch {$hasLupa=$false}
    if ($hasLupa) {
        & python (Join-Path $root 'tests\Lua.Tests.py')
        if ($LASTEXITCODE -ne 0) {throw 'Lua verification failed.'}
    } else {Write-Output 'Lua tests skipped: install the optional pinned dependency with python -m pip install -r tests/requirements.txt.'}
} else {Write-Output 'Lua tests skipped: optional Python dependency is unavailable.'}
Write-Output 'Verification completed. Installed widgets and their real credentials were not used by the test fixtures.'
