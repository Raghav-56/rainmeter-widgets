param([switch]$TogglePrivacy)
& (Join-Path $env:LOCALAPPDATA 'RainmeterWidgets\MementoMori\Launch.ps1') -TogglePrivacy:$TogglePrivacy
