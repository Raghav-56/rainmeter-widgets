$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path $env:TEMP ('rainmeter-sync-test-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$oldLocal=$env:LOCALAPPDATA;$oldApp=$env:APPDATA
function Assert($Value,[string]$Label){if(!$Value){throw "FAIL: $Label"};Write-Output "PASS: $Label"}
function Rejects([scriptblock]$Action,[string]$Label){$failed=$false;try{& $Action | Out-Null}catch{$failed=$true};Assert $failed $Label}
try {
    $repo=Join-Path $testRoot 'checkout';[void][IO.Directory]::CreateDirectory($repo)
    foreach($name in @('Manage.ps1','tools','tests','MementoMori','CLIProxyAccounts','README.md','.gitignore','.gitattributes','.github')){Copy-Item -LiteralPath (Join-Path $source $name) -Destination $repo -Recurse}
    & git init -q -b main $repo
    & git -C $repo config user.name 'Widget fixture'
    & git -C $repo config user.email 'fixture@example.com'
    & git -C $repo config commit.gpgsign false
    & git -C $repo config core.safecrlf false
    & git -C $repo add -- .
    & git -C $repo commit -q -m fixture
    if($LASTEXITCODE -ne 0){throw 'Fixture initial commit failed'}
    $remote=Join-Path $testRoot 'remote.git'
    & git init -q --bare $remote
    & git -C $repo remote add origin $remote
    $env:LOCALAPPDATA=Join-Path $testRoot 'profile';$env:APPDATA=Join-Path $testRoot 'roaming'
    $rainmeter=Join-Path $testRoot 'Rainmeter';$skins=Join-Path $testRoot 'Skins'
    [void][IO.Directory]::CreateDirectory($rainmeter)
    [IO.File]::WriteAllText((Join-Path $rainmeter 'Rainmeter.exe'),'fixture')
    . (Join-Path $repo 'tools\Deployment.ps1')
    function Start-SelectedWidgets {param($Context,[string[]]$Widgets,[switch]$Restoring)}
    function Start-MementoHandler {}
    function Stop-MementoHandler {}
    function Invoke-RainmeterCommand {param($Executable,$Arguments)}
    $stateRoot=Join-Path $env:LOCALAPPDATA 'RainmeterWidgets'
    Invoke-WidgetDeployment -Root $repo -StateRoot $stateRoot -Widget MementoMori -Installing -RainmeterDirectory $rainmeter -SkinDirectory $skins -BirthDate '2000-01-01' | Out-Null
    $installed=Join-Path $skins 'MementoMori\Meter.ini';$user=Join-Path $skins 'MementoMori\@Resources\User.inc'
    $userHash=Get-WidgetHash $user
    $sourceMeter=Join-Path $repo 'MementoMori\Skins\MementoMori\Meter.ini'
    Add-Content -LiteralPath $sourceMeter -Value '; synced revision'
    $before=Get-WidgetHash $installed
    & git -C $repo add -- MementoMori/Skins/MementoMori/Meter.ini
    Rejects {Publish-WidgetSource -Root $repo -StateRoot $stateRoot -Widget All -Message fixture} 'Sync refuses an existing staged index before deploying'
    Assert ((Get-WidgetHash $installed) -eq $before) 'Rejected sync leaves the installed source unchanged'
    & git -C $repo reset -q
    Publish-WidgetSource -Root $repo -StateRoot $stateRoot -Widget All -Message 'feat: fixture sync' | Out-Null
    $head=& git -C $repo rev-parse HEAD
    $remoteHead=& git --git-dir=$remote rev-parse refs/heads/main
    Assert ($head -eq $remoteHead -and (Get-WidgetHash $installed) -eq (Get-WidgetHash $sourceMeter)) 'Sync deploys the reviewed source and pushes the same commit to origin'
    Assert ((Get-WidgetHash $user) -eq $userHash) 'Sync retains personal settings byte for byte'
    Assert (!(git -C $repo status --porcelain)) 'Successful sync leaves a clean checkout'
    $state=Read-WidgetJson (Join-Path $stateRoot 'state.json')
    Assert ($state.Commit -eq $head.Substring(0,7)) 'Deployment state records the newly published commit'
    Add-Content -LiteralPath $sourceMeter -Value '; retained local revision'
    & git -C $repo remote set-url origin (Join-Path $testRoot 'missing-remote.git')
    Rejects {Publish-WidgetSource -Root $repo -StateRoot $stateRoot -Widget All -Message 'feat: retained fixture'} 'A failed push reports failure without undoing local work'
    Assert ((Get-WidgetHash $installed) -eq (Get-WidgetHash $sourceMeter) -and !(git -C $repo status --porcelain)) 'Push failure retains the deployed source and local commit'
    Write-Output '8 sync checks passed using an isolated local bare Git remote.'
} finally {
    $env:LOCALAPPDATA=$oldLocal;$env:APPDATA=$oldApp
    $resolved=[IO.Path]::GetFullPath($testRoot)
    if (!$resolved.StartsWith(([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'rainmeter-sync-test-*'){throw 'Unsafe test cleanup path'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
