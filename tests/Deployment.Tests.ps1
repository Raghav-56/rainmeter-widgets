$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path $env:TEMP ('rainmeter-deployment-test-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$originalLocal=$env:LOCALAPPDATA
$originalApp=$env:APPDATA
$script:checks=0
function Assert($Value,[string]$Label) {if (!$Value) {throw "FAIL: $Label"};$script:checks++;Write-Output "PASS: $Label"}
function Rejects([scriptblock]$Action,[string]$Label) {$failed=$false;try{& $Action | Out-Null}catch{$failed=$true};Assert $failed $Label}
try {
    $repo=Join-Path $testRoot 'checkout'
    [void][IO.Directory]::CreateDirectory($repo)
    foreach($name in @('Manage.ps1','tools','MementoMori','CLIProxyAccounts')) {Copy-Item -LiteralPath (Join-Path $source $name) -Destination $repo -Recurse}
    $env:LOCALAPPDATA=Join-Path $testRoot 'profile'
    $env:APPDATA=Join-Path $testRoot 'roaming'
    $rainmeter=Join-Path $testRoot 'Rainmeter'
    $skins=Join-Path $testRoot 'Skins'
    [void][IO.Directory]::CreateDirectory($rainmeter)
    [IO.File]::WriteAllText((Join-Path $rainmeter 'Rainmeter.exe'),'fixture')
    [IO.File]::WriteAllText((Join-Path $rainmeter 'Rainmeter.ini'),"[Rainmeter]`r`nSkinPath=$skins`r`n[Unrelated]`r`nActive=1`r`nWindowX=123`r`n")
    $layoutHash=(Get-FileHash -LiteralPath (Join-Path $rainmeter 'Rainmeter.ini')).Hash
    $stateRoot=Join-Path $env:LOCALAPPDATA 'RainmeterWidgets'
    . (Join-Path $repo 'tools\Deployment.ps1')
    $script:starts=0;$script:stops=0;$script:failStart=$false
    # The lifecycle boundary is mocked. All planning, builds, backups, copies,
    # state transitions, DPAPI writes and file verification are real.
    function Start-SelectedWidgets {param($Context,[string[]]$Widgets,[switch]$Restoring);$script:starts++;if($script:failStart){$script:failStart=$false;throw 'Fixture readiness failure'}}
    function Start-MementoHandler {}
    function Stop-MementoHandler {}
    function Stop-AccountHelper {$script:stops++}
    function Invoke-RainmeterCommand {param([string]$Executable,[string[]]$Arguments)}
    $options=@{Root=$repo;StateRoot=$stateRoot;RainmeterDirectory=$rainmeter;SkinDirectory=$skins;Widget='MementoMori';BirthDate='1999-03-14';ReferenceAge=75}
    $preview=& (Join-Path $repo 'Manage.ps1') install -Widget MementoMori -RainmeterDirectory $rainmeter -SkinDirectory $skins -StateRoot $stateRoot -WhatIf
    Assert (!(Test-Path -LiteralPath $stateRoot) -and !(Test-Path -LiteralPath $skins)) 'WhatIf creates no state, skin, build, prompt or private files'
    Invoke-WidgetDeployment @options -Installing | Out-Null
    $user=Join-Path $skins 'MementoMori\@Resources\User.inc'
    $meter=Join-Path $skins 'MementoMori\Meter.ini'
    Assert ((Get-Content -Raw -LiteralPath $user) -match 'BirthYear=1999' -and (Get-Content -Raw -LiteralPath $user) -match 'ReferenceAge=75') 'Fresh Memento setup uses supplied personal settings'
    Assert ((Get-Content -Raw -LiteralPath $meter) -match '@Include=#@#User.inc') 'Installed skin loads separate private settings'
    Assert (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'RainmeterWidgets\MementoMori\MementoMoriHotkeys.exe')) 'Fresh setup compiles the optional native handler locally'
    Assert ((Read-WidgetJson (Join-Path $stateRoot 'state.json')).Widgets.Count -eq 1) 'Selecting one widget installs only that widget'
    $userHash=Get-WidgetHash $user
    $stateHash=Get-WidgetHash (Join-Path $stateRoot 'state.json')
    $startCount=$script:starts
    $preview=& (Join-Path $repo 'Manage.ps1') update -StateRoot $stateRoot -WhatIf
    Assert ((Get-WidgetHash (Join-Path $stateRoot 'state.json')) -eq $stateHash -and $script:starts -eq $startCount) 'WhatIf also works on an existing installation without changing files or processes'
    $update=@{Root=$repo;StateRoot=$stateRoot;Widget='All'}
    Invoke-WidgetDeployment @update | Out-Null
    Assert ((Get-WidgetHash (Join-Path $stateRoot 'state.json')) -eq $stateHash -and $script:starts -eq $startCount) 'Repeated update is a no-op without refresh or state rewrite'
    Add-Content -LiteralPath $meter -Value '; direct installation edit'
    $drift=Get-WidgetHash $meter
    Rejects {Invoke-WidgetDeployment @update} 'Update refuses installed edits before changing files'
    Assert ((Get-WidgetHash $meter) -eq $drift -and (Get-WidgetHash $user) -eq $userHash) 'Rejected drift preserves installed edits and personal settings'
    Copy-Item -LiteralPath (Join-Path $repo 'MementoMori\Skins\MementoMori\Meter.ini') -Destination $meter -Force
    $originalCode=Get-WidgetHash $meter
    $sourceMeter=Join-Path $repo 'MementoMori\Skins\MementoMori\Meter.ini'
    Add-Content -LiteralPath $sourceMeter -Value '; new widget revision'
    Invoke-WidgetDeployment @update | Out-Null
    Assert ((Get-WidgetHash $meter) -eq (Get-WidgetHash $sourceMeter) -and (Get-WidgetHash $meter) -ne $originalCode) 'Repository change deploys to the installed widget'
    Assert ((Get-WidgetHash $user) -eq $userHash) 'Normal update preserves personal settings byte for byte'
    Undo-WidgetDeployment $stateRoot | Out-Null
    Assert ((Get-WidgetHash $meter) -eq $originalCode -and (Get-WidgetHash $user) -eq $userHash) 'Rollback restores previous code while retaining personal settings'
    $script:failStart=$true
    Rejects {Invoke-WidgetDeployment @update} 'A failed readiness check fails the deployment'
    Assert ((Get-WidgetHash $meter) -eq $originalCode -and !(Test-Path -LiteralPath (Join-Path $stateRoot 'pending.json'))) 'Failed deployment automatically restores previous code and clears recovery journal'
    Assert ((Get-WidgetHash $user) -eq $userHash) 'Failed deployment preserves private settings'
    $state=Read-WidgetJson (Join-Path $stateRoot 'state.json')
    $rollbackState=Get-WidgetHash (Join-Path $stateRoot 'state.json')
    $sourceCs=Join-Path $repo 'MementoMori\MementoMoriHotkeys.cs'
    $savedCs=Get-Content -Raw -LiteralPath $sourceCs
    Add-Content -LiteralPath $sourceCs -Value 'invalid c sharp'
    $startCount=$script:starts
    Rejects {Invoke-WidgetDeployment @update} 'Compilation failure occurs before stopping or replacing installed code'
    Assert ((Get-WidgetHash $meter) -eq $originalCode -and $script:starts -eq $startCount -and (Get-WidgetHash (Join-Path $stateRoot 'state.json')) -eq $rollbackState) 'Build failure leaves installed code, processes and deployment state intact'
    [IO.File]::WriteAllText($sourceCs,$savedCs)
    # Add accounts to an existing one-widget profile, without starting a real helper.
    $key=ConvertTo-SecureString 'synthetic-fixture-not-a-real-credential' -AsPlainText -Force
    Invoke-WidgetDeployment -Root $repo -StateRoot $stateRoot -Widget CLIProxyAccounts -Installing -BaseUrl 'http://127.0.0.1:8317' -ManagementKey $key | Out-Null
    $accountRoot=Join-Path $env:LOCALAPPDATA 'CLIProxyAccounts'
    $settings=Join-Path $accountRoot 'settings.json';$keyFile=Join-Path $accountRoot 'key.dpapi'
    $settingsHash=Get-WidgetHash $settings;$keyHash=Get-WidgetHash $keyFile
    Assert ((Get-Content -Raw -LiteralPath $keyFile) -notmatch 'synthetic-fixture') 'Fresh accounts setup protects its key with CurrentUser DPAPI'
    Assert ((Read-WidgetJson (Join-Path $stateRoot 'state.json')).Widgets.Count -eq 2) 'Installing second widget retains the first selection'
    Assert ((Read-WidgetJson (Join-Path $stateRoot 'state.json')).SourceHashes.MementoMori -ne (Get-WidgetSourceHashes $repo @('MementoMori'))['MementoMori']) 'Updating one widget does not falsely mark the other deployed'
    Add-Content -LiteralPath (Join-Path $repo 'CLIProxyAccounts\CLIProxyAccounts\Accounts.ini') -Value '; changed account layout'
    Invoke-WidgetDeployment -Root $repo -StateRoot $stateRoot -Widget CLIProxyAccounts | Out-Null
    Assert ((Get-WidgetHash $settings) -eq $settingsHash -and (Get-WidgetHash $keyFile) -eq $keyHash) 'Account update preserves endpoint, paths and protected key byte for byte'
    Undo-WidgetDeployment $stateRoot | Out-Null
    Assert ((Get-WidgetHash $settings) -eq $settingsHash -and (Get-WidgetHash $keyFile) -eq $keyHash) 'Account rollback preserves endpoint, paths and protected key'
    Assert ((Get-WidgetHash (Join-Path $rainmeter 'Rainmeter.ini')) -eq $layoutHash) 'All operations preserve Rainmeter layout and unrelated skin entries'
    $foreign=Join-Path $testRoot 'foreign-state'
    Rejects {Invoke-WidgetDeployment -Root $repo -StateRoot $foreign -Widget MementoMori -RainmeterDirectory $rainmeter -SkinDirectory $skins -Installing -BirthDate '1990-01-01'} 'Install refuses to overwrite an existing unmanaged skin'
    $installedHash=Get-WidgetHash $meter
    $startsBefore=$script:starts
    Invoke-WidgetDeployment -Root $repo -StateRoot $foreign -Widget MementoMori -RainmeterDirectory $rainmeter -SkinDirectory $skins -Adopt | Out-Null
    Assert ((Get-WidgetHash $meter) -eq $installedHash -and $script:starts -eq $startsBefore) 'Adoption records an existing installation without changing it or restarting anything'
    $outside=Join-Path $repo 'private-state'
    Rejects {Invoke-WidgetDeployment -Root $repo -StateRoot $outside -Widget MementoMori -RainmeterDirectory $rainmeter -SkinDirectory $skins -Adopt} 'Private deployment state cannot be stored in the checkout'
    Assert (!(Test-Path -LiteralPath $outside)) 'Rejected checkout state creates no files'
    # Simulate a process dying after a partial replacement and recover via journal.
    Invoke-WidgetDeployment -Root $repo -StateRoot $foreign -Widget MementoMori | Out-Null
    $latest=Read-WidgetJson (Join-Path $foreign 'state.json')
    $journal=Read-WidgetJson (Join-Path $latest.LastBackup 'journal.json')
    Write-WidgetJson @{Backup=$latest.LastBackup} (Join-Path $foreign 'pending.json')
    Add-Content -LiteralPath $meter -Value '; interrupted file copy'
    Rejects {Invoke-WidgetDeployment -Root $repo -StateRoot $foreign -Widget MementoMori} 'Interrupted deployment prevents a second update'
    Undo-WidgetDeployment $foreign | Out-Null
    Assert ((Get-WidgetHash $meter) -eq $installedHash -and !(Test-Path -LiteralPath (Join-Path $foreign 'pending.json'))) 'Crash recovery restores journaled source and clears pending state'
    $env:LOCALAPPDATA=Join-Path $testRoot 'retry-profile'
    $retryState=Join-Path $env:LOCALAPPDATA 'RainmeterWidgets'
    $retrySkins=Join-Path $testRoot 'retry-skins'
    $retry=@{Root=$repo;StateRoot=$retryState;Widget='MementoMori';RainmeterDirectory=$rainmeter;SkinDirectory=$retrySkins;BirthDate='1995-04-15';ReferenceAge=70;Installing=$true}
    $script:failStart=$true
    Rejects {Invoke-WidgetDeployment @retry} 'A failed first installation reports failure'
    $retryUser=Join-Path $retrySkins 'MementoMori\@Resources\User.inc'
    $retryHash=Get-WidgetHash $retryUser
    Invoke-WidgetDeployment @retry | Out-Null
    Assert ((Get-WidgetHash $retryUser) -eq $retryHash -and (Test-Path -LiteralPath (Join-Path $retryState 'state.json'))) 'Retry after failed first install succeeds and retains personal settings'
    Write-Output "$script:checks deployment checks passed. All runtime paths were isolated temporary fixtures."
} finally {
    $env:LOCALAPPDATA=$originalLocal;$env:APPDATA=$originalApp
    $resolved=[IO.Path]::GetFullPath($testRoot)
    if (!$resolved.StartsWith(([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'rainmeter-deployment-test-*') {throw 'Unsafe test cleanup path'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
