[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Position=0)][ValidateSet('install','adopt','status','update','rollback','verify','sync')][string]$Command='status',
    [ValidateSet('All','MementoMori','CLIProxyAccounts')][string]$Widget='All',
    [string]$RainmeterDirectory,[string]$SkinDirectory,[string]$BaseUrl,
    [Security.SecureString]$ManagementKey,[string]$BirthDate,
    [ValidateRange(1,150)][int]$ReferenceAge=60,[string]$Message,
    [string]$StateRoot=(Join-Path $env:LOCALAPPDATA 'RainmeterWidgets')
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\tools\Deployment.ps1"
if ($Command -eq 'verify') { & "$PSScriptRoot\tools\Verify.ps1"; return }
if ($Command -eq 'status') { Get-DeploymentStatus $StateRoot; return }
if ($Command -eq 'sync') {
    if (!$Message) { throw 'Supply -Message for the Git commit.' }
    if ($PSCmdlet.ShouldProcess('installed widgets and origin','Verify, deploy, commit and push source')) {
        & "$PSScriptRoot\tools\Verify.ps1"
        Publish-WidgetSource -Root $PSScriptRoot -StateRoot $StateRoot -Message $Message -Widget $Widget
    }
    return
}
if ($Command -eq 'install' -and !$PSBoundParameters.ContainsKey('Widget') -and !$WhatIfPreference) {
    $answer=Read-Host 'Install MementoMori, CLIProxyAccounts, or All [All]'
    if ($answer) {
        if ($answer -notin @('All','MementoMori','CLIProxyAccounts')) { throw 'Unknown widget selection.' }
        $Widget=$answer
    }
}
$options=@{Root=$PSScriptRoot;StateRoot=$StateRoot;Widget=$Widget;RainmeterDirectory=$RainmeterDirectory;SkinDirectory=$SkinDirectory;BaseUrl=$BaseUrl;ManagementKey=$ManagementKey;BirthDate=$BirthDate;ReferenceAge=$ReferenceAge}
if ($Command -eq 'rollback') {
    if ($PSCmdlet.ShouldProcess('last widget deployment','Restore backed-up code, preserving personal settings')) { Undo-WidgetDeployment $StateRoot }
    return
}
if (!$PSCmdlet.ShouldProcess('selected widgets',"$Command source; preserve private settings")) {
    Show-DeploymentPlan @options -Adopt:($Command -eq 'adopt')
    return
}
Invoke-WidgetDeployment @options -Adopt:($Command -eq 'adopt') -Installing:($Command -eq 'install')
