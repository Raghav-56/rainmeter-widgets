param([switch]$TogglePrivacy)

$ErrorActionPreference = 'Stop'
$taskExecutable = Join-Path $PSScriptRoot 'Rainmeter.exe'
$taskProcess = Get-Process -Name Rainmeter -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $taskExecutable } | Select-Object -First 1
$taskWasRunning = $null -ne $taskProcess
if (-not $taskProcess) {
    $taskProcess = Start-Process -FilePath $taskExecutable -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
    if (-not $taskProcess.WaitForInputIdle(10000)) { throw 'Rainmeter did not become ready.' }
}
$taskHotkeyExecutable = Join-Path $PSScriptRoot 'MementoMoriHotkeys.exe'
Start-Process -FilePath $taskHotkeyExecutable -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
if ($TogglePrivacy -and $taskWasRunning) {
    Start-Process -FilePath $taskExecutable -ArgumentList '!Toggle "MementoMori"' -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -Wait
} else {
    Start-Process -FilePath $taskExecutable -ArgumentList '!ActivateConfig "MementoMori" "Meter.ini"' -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -Wait
    Start-Process -FilePath $taskExecutable -ArgumentList '!Show "MementoMori"' -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -Wait
}
