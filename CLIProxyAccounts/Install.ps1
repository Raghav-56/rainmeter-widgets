[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$BaseUrl,[string]$RainmeterDirectory,[Security.SecureString]$ManagementKey)
& "$PSScriptRoot\..\Manage.ps1" install -Widget CLIProxyAccounts -BaseUrl $BaseUrl -RainmeterDirectory $RainmeterDirectory -ManagementKey $ManagementKey -WhatIf:$WhatIfPreference