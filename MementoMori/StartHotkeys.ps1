$ErrorActionPreference='Stop'
$config=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'settings.json') | ConvertFrom-Json
$rainmeter=Join-Path $config.RainmeterDirectory 'Rainmeter.exe'
if (!(Test-Path -LiteralPath $rainmeter)) {throw 'Configured Rainmeter executable was not found.'}
$ready=New-Object Threading.EventWaitHandle($false,[Threading.EventResetMode]::ManualReset,'Local\MementoMori.Hotkey.Ready')
try {
    Start-Process -FilePath (Join-Path $PSScriptRoot 'MementoMoriHotkeys.exe') -ArgumentList ('"'+$rainmeter+'"') -WindowStyle Hidden
    if (!$ready.WaitOne(5000)) {throw 'Ctrl+Alt+M registration failed; inspect the installed Hotkey.log.'}
} finally {$ready.Dispose()}
