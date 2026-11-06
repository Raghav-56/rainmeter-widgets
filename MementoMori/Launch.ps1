param([switch]$TogglePrivacy)
$ErrorActionPreference='Stop'
$config=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'settings.json') | ConvertFrom-Json
$rainmeter=Join-Path $config.RainmeterDirectory 'Rainmeter.exe'
if (!(Test-Path -LiteralPath $rainmeter)) {throw 'Configured Rainmeter executable was not found.'}
& (Join-Path $PSScriptRoot 'StartHotkeys.ps1')
if ($TogglePrivacy) {$argsText='!Toggle "MementoMori"'} else {$argsText='!ActivateConfig "MementoMori" "Meter.ini"'}
$process=Start-Process -FilePath $rainmeter -ArgumentList $argsText -WindowStyle Hidden -PassThru
try {if (!$process.WaitForExit(10000) -or $process.ExitCode -ne 0) {throw 'Rainmeter control command failed.'}} finally {$process.Dispose()}
