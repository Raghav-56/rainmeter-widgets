function Write-WidgetJson($Value,[string]$Path) {
    $temporary=$Path+'.new'
    [IO.File]::WriteAllText($temporary,($Value | ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary,$Path,[Management.Automation.Language.NullString]::Value) } else { [IO.File]::Move($temporary,$Path) }
}
function Read-WidgetJson([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json) }
    return $null
}
function Get-WidgetHash([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $sha=[Security.Cryptography.SHA256]::Create()
        try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}
    }
    return $null
}
function Resolve-WidgetPath([string]$Path) {
    if (!$Path -or $Path.IndexOfAny([char[]]'"[]#') -ge 0) { throw 'Choose a path without quotes or Rainmeter action characters.' }
    return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path)).TrimEnd('\')
}
function Assert-OutsideCheckout([string]$Path,[string]$Root) {
    $full=Resolve-WidgetPath $Path
    $checkout=(Resolve-WidgetPath $Root)+'\'
    if ($full+'\' -eq $checkout -or $full.StartsWith($checkout,[StringComparison]::OrdinalIgnoreCase)) { throw 'Installations, state and private settings must stay outside the checkout.' }
}
function Enter-DeploymentLock {
    $mutex=New-Object Threading.Mutex($false,('Local\RainmeterWidgets.Deployment.'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value))
    try {try {$locked=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$locked=$true};if(!$locked){throw 'Another widget deployment is running. Wait for it to finish.'};return $mutex} catch {$mutex.Dispose();throw}
}
function Get-SourceFingerprint([string]$Root) {
    $lines=@(Get-ChildItem -LiteralPath (Join-Path $Root 'MementoMori'),(Join-Path $Root 'CLIProxyAccounts'),(Join-Path $Root 'tools') -Recurse -File |
        Where-Object { $_.Extension -in @('.ps1','.cs','.lua','.ini') } | Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Root.Length)+(Get-WidgetHash $_.FullName)
        })
    $lines+=Get-WidgetHash (Join-Path $Root 'Manage.ps1')
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))).Replace('-','') } finally { $sha.Dispose() }
}
function Get-WidgetSourceHashes([string]$Root,[string[]]$Widgets) {
    $hashes=@{}
    foreach ($name in $Widgets) {
        $lines=@(Get-ChildItem -LiteralPath (Join-Path $Root $name) -Recurse -File | Where-Object {$_.Extension -in @('.ps1','.cs','.lua','.ini')} | Sort-Object FullName | ForEach-Object {$_.FullName.Substring($Root.Length)+(Get-WidgetHash $_.FullName)})
        $lines+=Get-WidgetHash (Join-Path $Root 'Manage.ps1')
        $lines+=Get-WidgetHash (Join-Path $Root 'tools\Deployment.ps1')
        $sha=[Security.Cryptography.SHA256]::Create()
        try {$hashes[$name]=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))).Replace('-','')} finally {$sha.Dispose()}
    }
    return $hashes
}
function Get-WidgetSelection([string]$Widget,$State) {
    if ($Widget -ne 'All') { return @($Widget) }
    if ($State) { return @($State.Widgets) }
    return @('MementoMori','CLIProxyAccounts')
}
function Get-InstallContext([string]$Root,[string]$StateRoot,[string]$RainmeterDirectory,[string]$SkinDirectory) {
    Assert-OutsideCheckout $StateRoot $Root
    $state=Read-WidgetJson (Join-Path $StateRoot 'state.json')
    if ($state) {
        if ($RainmeterDirectory -and (Resolve-WidgetPath $RainmeterDirectory) -ne $state.RainmeterDirectory) { throw 'This profile already manages a different Rainmeter installation.' }
        if ($SkinDirectory -and (Resolve-WidgetPath $SkinDirectory) -ne $state.SkinRoot) { throw 'This profile already manages a different skin directory.' }
        $RainmeterDirectory=$state.RainmeterDirectory; $SkinDirectory=$state.SkinRoot
    }
    if (!$RainmeterDirectory) {
        $process=Get-Process Rainmeter -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($process -and $process.Path) { $RainmeterDirectory=Split-Path $process.Path -Parent }
        if (!$RainmeterDirectory) {
            foreach ($candidate in @((Join-Path $env:ProgramFiles 'Rainmeter'),(Join-Path $env:LOCALAPPDATA 'Programs\MementoMori'))) {
                if (Test-Path -LiteralPath (Join-Path $candidate 'Rainmeter.exe')) { $RainmeterDirectory=$candidate; break }
            }
        }
    }
    if (!$RainmeterDirectory) { throw 'Install Rainmeter first, or supply -RainmeterDirectory.' }
    $RainmeterDirectory=Resolve-WidgetPath $RainmeterDirectory
    if (!(Test-Path -LiteralPath (Join-Path $RainmeterDirectory 'Rainmeter.exe'))) { throw 'Rainmeter.exe was not found in the selected directory.' }
    if (!$SkinDirectory) {
        foreach ($ini in @((Join-Path $RainmeterDirectory 'Rainmeter.ini'),(Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'))) {
            if (Test-Path -LiteralPath $ini) {
                foreach ($line in Get-Content -LiteralPath $ini) { if ($line -match '^SkinPath=(.+)$') { $SkinDirectory=$Matches[1]; break } }
            }
            if ($SkinDirectory) { break }
        }
        if (!$SkinDirectory) { $SkinDirectory=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins' }
    }
    $SkinDirectory=Resolve-WidgetPath $SkinDirectory
    Assert-OutsideCheckout $RainmeterDirectory $Root
    Assert-OutsideCheckout $SkinDirectory $Root
    [pscustomobject]@{State=$state;RainmeterDirectory=$RainmeterDirectory;SkinRoot=$SkinDirectory}
}
function Get-WidgetFiles([string]$Root,$Context,[string[]]$Widgets) {
    $list=New-Object Collections.Generic.List[object]
    foreach ($name in $Widgets) {
        $skin=Join-Path $Context.SkinRoot $name
        if ($name -eq 'MementoMori') {
            foreach ($relative in @('Meter.ini','@Resources\Clock.lua','@Resources\Start.ps1')) {
                $list.Add([pscustomobject]@{Widget=$name;Source=(Join-Path $Root ('MementoMori\Skins\MementoMori\'+$relative));Target=(Join-Path $skin $relative);Build=$false})
            }
            foreach ($file in @('Launch.ps1','StartHotkeys.ps1','MementoMoriHotkeys.cs','MementoMoriHotkeys.exe')) {
                $source=Join-Path $Root ('MementoMori\'+$file.Replace('.exe','.cs'))
                $list.Add([pscustomobject]@{Widget=$name;Source=$source;Target=(Join-Path $env:LOCALAPPDATA ('RainmeterWidgets\MementoMori\'+$file));Build=$file.EndsWith('.exe')})
            }
            $legacy=Join-Path $Context.RainmeterDirectory 'Launch.ps1'
            if (Test-Path -LiteralPath $legacy) {
                $legacyText=[IO.File]::ReadAllText($legacy)
                if ($legacyText.Contains('MementoMoriHotkeys.exe') -or $legacyText.Contains('RainmeterWidgets\MementoMori\Launch.ps1')) {
                    $list.Add([pscustomobject]@{Widget=$name;Source=(Join-Path $Root 'MementoMori\LegacyLaunch.ps1');Target=$legacy;Build=$false})
                }
            }
        } else {
            foreach ($relative in @('Accounts.ini','@Resources\Snapshot.lua')) {
                $list.Add([pscustomobject]@{Widget=$name;Source=(Join-Path $Root ('CLIProxyAccounts\CLIProxyAccounts\'+$relative));Target=(Join-Path $skin $relative);Build=$false})
            }
            foreach ($file in @('Core.ps1','Helper.ps1','Start.ps1','StartHotkeys.ps1','Hotkeys.cs','Stop.ps1','OpenConsole.ps1','Uninstall.ps1','CLIProxyAccountsHotkeys.exe')) {
                $sourceFile=$file; if ($file.EndsWith('.exe')) { $sourceFile='Hotkeys.cs' }
                $list.Add([pscustomobject]@{Widget=$name;Source=(Join-Path $Root ('CLIProxyAccounts\'+$sourceFile));Target=(Join-Path $env:LOCALAPPDATA ('CLIProxyAccounts\'+$file));Build=$file.EndsWith('.exe')})
            }
            $list.Add([pscustomobject]@{Widget=$name;Source=(Join-Path $Root 'CLIProxyAccounts\Start.ps1');Target=(Join-Path $skin '@Resources\Start.ps1');Build=$false})
            $list.Add([pscustomobject]@{Widget=$name;Source=(Join-Path $Root 'CLIProxyAccounts\Open.ps1');Target=(Join-Path $skin '@Resources\Open.ps1');Build=$false})
        }
    }
    return $list.ToArray()
}
function Assert-NoInstalledDrift($State,[string[]]$Widgets) {
    if (!$State) { return }
    foreach ($entry in @($State.Files | Where-Object { $_.Widget -in $Widgets })) {
        if ((Get-WidgetHash $entry.Target) -ne $entry.Hash) { throw "Installed code changed: $($entry.Target). Copy your edit into the checkout and review it before updating." }
    }
}
function Get-DeploymentStatus([string]$StateRoot) {
    $state=Read-WidgetJson (Join-Path $StateRoot 'state.json')
    if (!$state) { Write-Output 'No managed installation. Run install for a new setup, or adopt for an existing setup.'; return }
    foreach ($widget in $state.Widgets) {
        $drift=@($state.Files | Where-Object { $_.Widget -eq $widget -and (Get-WidgetHash $_.Target) -ne $_.Hash })
        $hash=(Get-WidgetSourceHashes (Split-Path $PSScriptRoot -Parent) @($widget))[$widget]
        [pscustomobject]@{Widget=$widget;InstalledCode=$(if ($drift.Count) {'Edited or missing'} else {'Unchanged'});Source=$(if ($state.SourceHashes.$widget -eq $hash) {'Deployed'} else {'Update available'});Commit=$state.Commit;RollbackAvailable=[bool]$state.LastBackup;RecoveryRequired=(Test-Path -LiteralPath (Join-Path $StateRoot 'pending.json'))}
    }
}
function Show-DeploymentPlan {
    param($Root,$StateRoot,$Widget,$RainmeterDirectory,$SkinDirectory,$BaseUrl,$ManagementKey,$BirthDate,$ReferenceAge,[switch]$Adopt)
    $context=Get-InstallContext $Root $StateRoot $RainmeterDirectory $SkinDirectory
    $selection=Get-WidgetSelection $Widget $context.State
    Assert-NoInstalledDrift $context.State $selection
    foreach ($file in @(Get-WidgetFiles $Root $context $selection)) {
        [pscustomobject]@{Action=$(if ($Adopt) {'Record existing'} elseif (!(Test-Path -LiteralPath $file.Target)) {'Create'} elseif (!$file.Build -and (Get-WidgetHash $file.Source) -eq (Get-WidgetHash $file.Target)) {'Unchanged'} else {'Build/check update'});Widget=$file.Widget;File=$file.Target}
    }
    Write-Output 'Preview only. No prompts, builds, private-setting writes or Rainmeter commands were performed.'
}
function Read-MementoVariables([string]$Path) {
    $allowed=@('BirthYear','BirthMonth','BirthDay','ReferenceAge','ShowToday','TextColor','MutedColor','AccentColor')
    $values=[ordered]@{}
    if (Test-Path -LiteralPath $Path) {
        $inside=$false
        foreach ($line in Get-Content -LiteralPath $Path) {
            if ($line -match '^\[(.+)\]') { $inside=$Matches[1] -eq 'Variables'; continue }
            if ($inside -and $line -match '^([^=]+)=(.*)$' -and $Matches[1] -in $allowed) { $values[$Matches[1]]=$Matches[2] }
        }
    }
    return $values
}
function New-MementoSettings([string]$Source,[string]$Existing,[string]$BirthDate,[int]$ReferenceAge) {
    $values=Read-MementoVariables $Source
    $personal=Read-MementoVariables $Existing
    foreach ($key in $personal.Keys) { $values[$key]=$personal[$key] }
    if ($BirthDate) {
        $date=[DateTime]::ParseExact($BirthDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
        $values.BirthYear=$date.Year; $values.BirthMonth=$date.Month; $values.BirthDay=$date.Day; $values.ReferenceAge=$ReferenceAge
    }
    $date=New-Object DateTime ([int]$values.BirthYear),([int]$values.BirthMonth),([int]$values.BirthDay)
    if ([int]$values.ReferenceAge -lt 1 -or [int]$values.ReferenceAge -gt 150) { throw 'Invalid age horizon.' }
    $lines=@('[Variables]')
    foreach ($key in $values.Keys) { $lines+=$key+'='+$values[$key] }
    return ($lines -join "`r`n")+"`r`n"
}
function Invoke-RainmeterCommand([string]$Executable,[string[]]$Arguments) {
    if (!$Arguments.Count -or $Arguments[0] -notmatch '^![A-Za-z]+$') {throw 'Invalid Rainmeter control command.'}
    $argsText=$Arguments[0]
    if ($Arguments.Count -gt 1) {$argsText+=' '+(($Arguments[1..($Arguments.Count-1)] | ForEach-Object { '"'+$_+'"' }) -join ' ')}
    $process=Start-Process -FilePath $Executable -ArgumentList $argsText -WindowStyle Hidden -PassThru
    try { if (!$process.WaitForExit(10000)) {$process.Kill();throw 'Rainmeter control command timed out.'};if($process.ExitCode -ne 0){throw 'Rainmeter control command failed.'} } finally { $process.Dispose() }
}
function Stop-AccountHelper {
    $root=Join-Path $env:LOCALAPPDATA 'CLIProxyAccounts'
    if (!(Test-Path -LiteralPath (Join-Path $root 'Helper.ps1'))) { return }
    [IO.File]::WriteAllText((Join-Path $root 'stop'),'stop')
    $mutex=New-Object Threading.Mutex($false,('Local\CLIProxyAccounts-'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value))
    try {
        try { $locked=$mutex.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $locked=$true }
        if (!$locked) { throw 'Account helper did not stop; files were not replaced.' }
        $mutex.ReleaseMutex()
    } finally { $mutex.Dispose() }
}
function Start-SelectedWidgets {
    param($Context,[string[]]$Widgets,[switch]$Restoring)
    foreach ($name in $Widgets) {
        $ini=if ($name -eq 'MementoMori') {'Meter.ini'} else {'Accounts.ini'}
        Invoke-RainmeterCommand (Join-Path $Context.RainmeterDirectory 'Rainmeter.exe') @('!ActivateConfig',$name,$ini)
        Invoke-RainmeterCommand (Join-Path $Context.RainmeterDirectory 'Rainmeter.exe') @('!Refresh',$name)
        if ($Restoring -and (($Context.SourceHashes.$name -eq 'adopted') -or ($Context.State.SourceHashes.$name -eq 'adopted'))) {continue}
        $nonce=[Guid]::NewGuid().ToString('N')
        $marker=Join-Path $Context.SkinRoot "$name\@Resources\Deployment.ready"
        $measure=if ($name -eq 'MementoMori') {'Clock'} else {'ReadSnapshot'}
        Invoke-RainmeterCommand (Join-Path $Context.RainmeterDirectory 'Rainmeter.exe') @('!CommandMeasure',$measure,("DeploymentCheck('"+$nonce+"')"),$name)
        $ready=$false
        for ($attempt=0;$attempt -lt 50;$attempt++) {
            if ((Test-Path -LiteralPath $marker) -and [IO.File]::ReadAllText($marker) -eq $nonce) {$ready=$true;break}
            Start-Sleep -Milliseconds 100
        }
        if (!$ready) {throw "Rainmeter did not confirm $name initialized. Previous code will be restored."}
        Remove-Item -LiteralPath $marker -Force
    }
}
function Start-MementoHandler($Context) {
    $launcher=Join-Path $env:LOCALAPPDATA 'RainmeterWidgets\MementoMori\Launch.ps1'
    if (!(Test-Path -LiteralPath $launcher)) {$launcher=Join-Path $Context.RainmeterDirectory 'Launch.ps1'}
    if (Test-Path -LiteralPath $launcher) {& $launcher}
}
function Restore-DeploymentFiles($Journal,[string]$Backup) {
    foreach ($entry in $Journal.Files) {
        if ($entry.Existed) {
            [void][IO.Directory]::CreateDirectory((Split-Path $entry.Target -Parent))
            Copy-Item -LiteralPath (Join-Path $Backup $entry.BackupFile) -Destination $entry.Target -Force
        } elseif (Test-Path -LiteralPath $entry.Target) { Remove-Item -LiteralPath $entry.Target -Force }
    }
}
function Invoke-WidgetDeployment {
    param($Root,$StateRoot,$Widget,$RainmeterDirectory,$SkinDirectory,$BaseUrl,$ManagementKey,$BirthDate,$ReferenceAge=60,[switch]$Adopt,[switch]$Installing)
    $context=Get-InstallContext $Root $StateRoot $RainmeterDirectory $SkinDirectory
    $selection=if (($Installing -or $Adopt) -and $Widget -eq 'All') {@('MementoMori','CLIProxyAccounts')} else {Get-WidgetSelection $Widget $context.State}
    if (!$Installing -and !$Adopt -and !$context.State) { throw 'Run install or adopt before update.' }
    . (Join-Path $Root 'CLIProxyAccounts\Core.ps1')
    Protect-WidgetDirectory $StateRoot
    $lock=Enter-DeploymentLock
    $stage=$null
    try {
        $context=Get-InstallContext $Root $StateRoot $RainmeterDirectory $SkinDirectory
        if (Test-Path -LiteralPath (Join-Path $StateRoot 'pending.json')) {throw 'An interrupted deployment needs recovery. Run rollback before trying another update.'}
        Assert-NoInstalledDrift $context.State $selection
        $allFiles=@(Get-WidgetFiles $Root $context $selection)
        if ($context.State -and !$Adopt) {
            foreach ($file in $allFiles) {
                if ((Test-Path -LiteralPath $file.Target) -and !@($context.State.Files | Where-Object {$_.Target -eq $file.Target}).Count) {throw "Unmanaged file at deployment destination: $($file.Target). Adopt or relocate it before updating."}
            }
        }
        $newWidgets=@($selection | Where-Object { !$context.State -or $_ -notin $context.State.Widgets })
        if (!$Adopt) {
            foreach ($name in $newWidgets) {
                $existing=Join-Path $context.SkinRoot $name
                $main=if($name -eq 'MementoMori'){'Meter.ini'}else{'Accounts.ini'}
                $retry=(Test-Path -LiteralPath (Join-Path $existing '.rainmeter-widgets')) -and !(Test-Path -LiteralPath (Join-Path $existing $main))
                if ((Test-Path -LiteralPath $existing) -and !$retry) { throw "Existing $name skin found. Run adopt first; install will not overwrite it." }
            }
        } else {
            foreach ($name in $selection) {
                $ini=if ($name -eq 'MementoMori') {'Meter.ini'} else {'Accounts.ini'}
                if (!(Test-Path -LiteralPath (Join-Path $context.SkinRoot "$name\$ini"))) { throw "Cannot adopt missing $name skin." }
            }
        }
        $accountRoot=Join-Path $env:LOCALAPPDATA 'CLIProxyAccounts'
        $accountConfig=Join-Path $accountRoot 'settings.json'
        if ('CLIProxyAccounts' -in $selection) {
            $saved=Read-WidgetJson $accountConfig
            if ($saved) {
                if ((Resolve-WidgetPath $saved.RainmeterDirectory) -ne $context.RainmeterDirectory -or (Resolve-WidgetPath $saved.SkinDirectory) -ne (Join-Path $context.SkinRoot 'CLIProxyAccounts')) { throw 'The existing account helper belongs to a different Rainmeter installation.' }
                if ($BaseUrl -and (Get-PrivateRoot $BaseUrl) -ne $saved.BaseUrl) { throw 'Updates preserve the existing endpoint. Change its local settings explicitly.' }
                if ($ManagementKey) { throw 'A stored credential exists; deployment will not replace it.' }
                if (!(Test-Path -LiteralPath (Join-Path $accountRoot 'key.dpapi'))) { throw 'Existing helper has no protected key. Repair its credential before deployment.' }
            } elseif ($Adopt) { throw 'Existing account helper settings are required for adoption.' }
            else {
                if (!$BaseUrl) { $BaseUrl=Read-Host 'Private proxy root URL' }
                $BaseUrl=Get-PrivateRoot $BaseUrl
                if (!(Test-Path -LiteralPath (Join-Path $accountRoot 'key.dpapi')) -and !$ManagementKey) { $ManagementKey=Read-Host 'Management key' -AsSecureString }
            }
        }
        $initialSource=Get-SourceFingerprint $Root
        $sourceHashes=Get-WidgetSourceHashes $Root $selection
        $outdated=@($selection | Where-Object {!$context.State -or $context.State.SourceHashes.$_ -ne $sourceHashes[$_]})
        if (!$Adopt -and !$outdated.Count -and !$newWidgets.Count) { Write-Output 'Already deployed. No code, configuration or processes changed.'; return }
        if ($Adopt) {
            $records=@($allFiles | Where-Object { Test-Path -LiteralPath $_.Target } | ForEach-Object { [pscustomobject]@{Widget=$_.Widget;Target=$_.Target;Hash=(Get-WidgetHash $_.Target)} })
            if ($context.State) { $records+=@($context.State.Files | Where-Object { $_.Widget -notin $selection }) }
            $widgets=@($selection); if ($context.State) {$widgets+=@($context.State.Widgets)}
            $adoptedHashes=@{};if ($context.State) {foreach($p in $context.State.SourceHashes.PSObject.Properties){$adoptedHashes[$p.Name]=$p.Value}}
            foreach($name in $selection){$adoptedHashes[$name]='adopted'}
            Write-WidgetJson ([ordered]@{Schema=1;RainmeterDirectory=$context.RainmeterDirectory;SkinRoot=$context.SkinRoot;Widgets=@($widgets | Select-Object -Unique);Files=$records;SourceHashes=$adoptedHashes;Commit='adopted';LastBackup=$null}) (Join-Path $StateRoot 'state.json')
            Write-Output 'Adopted existing source hashes. No skin, credential, configuration or process was changed.'
            return
        }
        $stage=Join-Path $StateRoot ('staging\'+[Guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($stage)
        $prepared=New-Object Collections.Generic.List[object]
        $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
        if (!(Test-Path -LiteralPath $compiler)) {$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
        foreach ($file in $allFiles) {
            $preparedPath=$file.Source
            if ($file.Build) {
                $installedSource=Join-Path (Split-Path $file.Target -Parent) (Split-Path $file.Source -Leaf)
                if ((Get-WidgetHash $installedSource) -eq (Get-WidgetHash $file.Source) -and (Test-Path -LiteralPath $file.Target)) { continue }
                $preparedPath=Join-Path $stage ([IO.Path]::GetFileName($file.Target))
                & $compiler /nologo /target:winexe /optimize+ ('/out:'+$preparedPath) $file.Source
                if ($LASTEXITCODE -ne 0) { throw 'Hotkey compilation failed; installation retained.' }
            } else {
                if ((Get-WidgetHash $file.Target) -eq (Get-WidgetHash $file.Source)) { continue }
                if ($file.Source.EndsWith('.ps1')) {
                    $tokens=$null; $parseErrors=$null
                    [void][Management.Automation.Language.Parser]::ParseFile($file.Source,[ref]$tokens,[ref]$parseErrors)
                    if ($parseErrors.Count) {throw 'PowerShell source contains syntax errors; installation retained.'}
                }
            }
            $prepared.Add([pscustomobject]@{Widget=$file.Widget;Source=$preparedPath;Target=$file.Target})
        }
        $userFile=Join-Path $context.SkinRoot 'MementoMori\@Resources\User.inc'
        $userText=$null
        if ('MementoMori' -in $selection -and !(Test-Path -LiteralPath $userFile)) {
            if ('MementoMori' -in $newWidgets -and !$BirthDate) { $BirthDate=Read-Host 'Birth date (yyyy-MM-dd)' }
            $userText=New-MementoSettings (Join-Path $Root 'MementoMori\Skins\MementoMori\Meter.ini') (Join-Path $context.SkinRoot 'MementoMori\Meter.ini') $BirthDate $ReferenceAge
        } elseif ($BirthDate -and 'MementoMori' -notin $newWidgets) { throw 'Personal configuration exists. Edit User.inc locally; deployment preserves it.' }
        $backup=Join-Path $StateRoot ('backups\'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')+'-'+[Guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($backup)
        $journalFiles=@(); $index=0
        foreach ($file in $prepared) {
            $existed=Test-Path -LiteralPath $file.Target
            $backupFile=([string]$index++)+'.bak'
            if ($existed) { Copy-Item -LiteralPath $file.Target -Destination (Join-Path $backup $backupFile) }
            $journalFiles+=[pscustomobject]@{Target=$file.Target;Existed=$existed;BackupFile=$backupFile}
        }
        $accountChanged=@($prepared | Where-Object {$_.Widget -eq 'CLIProxyAccounts' -and $_.Target.StartsWith($accountRoot+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0
        $accountBinary=@($prepared | Where-Object {$_.Target -eq (Join-Path $accountRoot 'CLIProxyAccountsHotkeys.exe')}).Count -gt 0
        $mementoBinary=@($prepared | Where-Object {$_.Widget -eq 'MementoMori' -and $_.Target.EndsWith('.exe')}).Count -gt 0
        $journal=[pscustomobject]@{Files=$journalFiles;PreviousState=$context.State;RainmeterDirectory=$context.RainmeterDirectory;SkinRoot=$context.SkinRoot;Widgets=$selection;AccountChanged=$accountChanged;AccountBinary=$accountBinary;MementoBinary=$mementoBinary}
        Write-WidgetJson $journal (Join-Path $backup 'journal.json')
        Write-WidgetJson @{Backup=$backup} (Join-Path $StateRoot 'pending.json')
        $privateHashes=@{}
        foreach ($path in @($accountConfig,(Join-Path $accountRoot 'key.dpapi'),$userFile)) {if (Test-Path -LiteralPath $path) {$privateHashes[$path]=Get-WidgetHash $path}}
        try {
            if ($accountChanged) {Stop-AccountHelper}
            if ($accountBinary -and (Test-Path -LiteralPath (Join-Path $accountRoot 'StartHotkeys.ps1'))) { & (Join-Path $accountRoot 'StartHotkeys.ps1') -Stop }
            if ($mementoBinary) { Stop-MementoHandler $context.RainmeterDirectory }
            foreach($name in $newWidgets){
                $skin=Join-Path $context.SkinRoot $name
                [void][IO.Directory]::CreateDirectory($skin)
                [IO.File]::WriteAllText((Join-Path $skin '.rainmeter-widgets'),'rainmeter-widgets managed setup')
            }
            if ($userText) { [void][IO.Directory]::CreateDirectory((Split-Path $userFile -Parent)); [IO.File]::WriteAllText($userFile,$userText,(New-Object Text.UTF8Encoding($false))) }
            if ('CLIProxyAccounts' -in $selection -and !(Test-Path -LiteralPath $accountConfig)) {
                Protect-WidgetDirectory $accountRoot
                if ($ManagementKey) {Save-WidgetKey $ManagementKey $accountRoot}
                Write-WidgetJson @{BaseUrl=$BaseUrl;RainmeterDirectory=$context.RainmeterDirectory;SkinDirectory=(Join-Path $context.SkinRoot 'CLIProxyAccounts')} $accountConfig
            }
            foreach ($file in $prepared) {
                [void][IO.Directory]::CreateDirectory((Split-Path $file.Target -Parent))
                Copy-Item -LiteralPath $file.Source -Destination $file.Target -Force
                if ((Get-WidgetHash $file.Source) -ne (Get-WidgetHash $file.Target)) {throw 'Deployed file verification failed.'}
            }
            if ('CLIProxyAccounts' -in $selection) {
                $marker=Join-Path $context.SkinRoot 'CLIProxyAccounts\.cliproxy-widget'
                if (!(Test-Path -LiteralPath $marker)) {[IO.File]::WriteAllText($marker,'CLIProxyAccounts v1')}
            }
            $mementoConfig=Join-Path $env:LOCALAPPDATA 'RainmeterWidgets\MementoMori\settings.json'
            if ('MementoMori' -in $selection -and !(Test-Path -LiteralPath $mementoConfig)) {Write-WidgetJson @{RainmeterDirectory=$context.RainmeterDirectory} $mementoConfig}
            $changedWidgets=@($prepared | ForEach-Object {$_.Widget} | Select-Object -Unique)
            if ($newWidgets.Count) {Invoke-RainmeterCommand (Join-Path $context.RainmeterDirectory 'Rainmeter.exe') @('!RefreshApp')}
            if ($changedWidgets.Count) {Start-SelectedWidgets $context $changedWidgets}
            if ('MementoMori' -in $changedWidgets) { Start-MementoHandler $context }
            foreach ($path in $privateHashes.Keys) { if ((Get-WidgetHash $path) -ne $privateHashes[$path]) {throw 'Private settings changed unexpectedly during deployment.'} }
            if ((Get-SourceFingerprint $Root) -ne $initialSource) {throw 'Source changed during deployment. Previous code will be restored; retry after finishing your edit.'}
            $records=@($allFiles | ForEach-Object { [pscustomobject]@{Widget=$_.Widget;Target=$_.Target;Hash=(Get-WidgetHash $_.Target)} })
            if ($context.State) {$records+=@($context.State.Files | Where-Object {$_.Widget -notin $selection})}
            $widgets=@($selection); if ($context.State) {$widgets+=@($context.State.Widgets)}
            $commit='uncommitted'
            if(Test-Path -LiteralPath (Join-Path $Root '.git')) {$commit=& git -C $Root rev-parse --short HEAD}
            $savedHashes=@{};if ($context.State) {foreach($p in $context.State.SourceHashes.PSObject.Properties){$savedHashes[$p.Name]=$p.Value}}
            foreach($name in $selection){$savedHashes[$name]=$sourceHashes[$name]}
            Write-WidgetJson ([ordered]@{Schema=1;RainmeterDirectory=$context.RainmeterDirectory;SkinRoot=$context.SkinRoot;Widgets=@($widgets | Select-Object -Unique);Files=$records;SourceHashes=$savedHashes;Commit=[string]$commit;LastBackup=$backup}) (Join-Path $StateRoot 'state.json')
            Remove-Item -LiteralPath (Join-Path $StateRoot 'pending.json') -Force
            Write-Output ('Deployed '+($selection -join ', ')+'. Private settings retained; rollback snapshot saved.')
        } catch {
            $originalError=$_
            try {
                if ($accountChanged) {Stop-AccountHelper}
                if ($accountBinary -and (Test-Path -LiteralPath (Join-Path $accountRoot 'StartHotkeys.ps1'))) { & (Join-Path $accountRoot 'StartHotkeys.ps1') -Stop }
                if ($mementoBinary) {Stop-MementoHandler $context.RainmeterDirectory}
                Restore-DeploymentFiles $journal $backup
                if ($context.State) {Write-WidgetJson $context.State (Join-Path $StateRoot 'state.json');Start-SelectedWidgets $context $selection -Restoring}
                elseif(Test-Path -LiteralPath (Join-Path $StateRoot 'state.json')) {Remove-Item -LiteralPath (Join-Path $StateRoot 'state.json')}
                if (!$context.State) {foreach($name in $selection){Invoke-RainmeterCommand (Join-Path $context.RainmeterDirectory 'Rainmeter.exe') @('!DeactivateConfig',$name)}}
                if ('MementoMori' -in $selection) {Start-MementoHandler $context}
                Remove-Item -LiteralPath (Join-Path $StateRoot 'pending.json') -Force
            } catch {throw 'Deployment and restoration failed. Protected rollback files remain under the state directory; inspect before retrying.'}
            throw $originalError
        }
    } finally {
        if ($stage -and (Test-Path -LiteralPath $stage)) {
            $resolved=[IO.Path]::GetFullPath($stage)
            if (!$resolved.StartsWith(([IO.Path]::GetFullPath($StateRoot).TrimEnd('\')+'\staging\'),[StringComparison]::OrdinalIgnoreCase)) {throw 'Invalid staging cleanup path.'}
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
        $lock.ReleaseMutex();$lock.Dispose()
    }
}
function Stop-MementoHandler([string]$RainmeterDirectory) {
    $exe=Join-Path $env:LOCALAPPDATA 'RainmeterWidgets\MementoMori\MementoMoriHotkeys.exe'
    $legacy=if ($RainmeterDirectory) {Join-Path $RainmeterDirectory 'MementoMoriHotkeys.exe'} else {''}
    foreach ($process in @(Get-Process MementoMoriHotkeys -ErrorAction SilentlyContinue)) {
        if ($process.Path -eq $exe -or $process.Path -eq $legacy) {Stop-Process -Id $process.Id; [void]$process.WaitForExit(5000)}
    }
}
function Undo-WidgetDeployment([string]$StateRoot) {
    $state=Read-WidgetJson (Join-Path $StateRoot 'state.json')
    $pending=Read-WidgetJson (Join-Path $StateRoot 'pending.json')
    if (!$pending -and (!$state -or !$state.LastBackup)) {throw 'No deployment rollback is available.'}
    $lock=Enter-DeploymentLock
    try {
        $backup=if ($pending) {$pending.Backup} else {$state.LastBackup}
        if (!([IO.Path]::GetFullPath($backup)).StartsWith(([IO.Path]::GetFullPath($StateRoot).TrimEnd('\')+'\backups\'),[StringComparison]::OrdinalIgnoreCase)) {throw 'Invalid rollback location.'}
        $journal=Read-WidgetJson (Join-Path $backup 'journal.json')
        if (!$pending) {Assert-NoInstalledDrift $state $journal.Widgets}
        if ($journal.AccountChanged) {Stop-AccountHelper}
        $accountRoot=Join-Path $env:LOCALAPPDATA 'CLIProxyAccounts'
        if ($journal.AccountBinary) { & (Join-Path $accountRoot 'StartHotkeys.ps1') -Stop }
        if ($journal.MementoBinary) {Stop-MementoHandler $journal.RainmeterDirectory}
        Restore-DeploymentFiles $journal $backup
        if ($journal.PreviousState) {
            Write-WidgetJson $journal.PreviousState (Join-Path $StateRoot 'state.json')
            Start-SelectedWidgets $journal.PreviousState $journal.Widgets -Restoring
            if ('MementoMori' -in $journal.Widgets) {Start-MementoHandler $journal.PreviousState}
        } else {
            foreach ($name in $journal.Widgets) {Invoke-RainmeterCommand (Join-Path $journal.RainmeterDirectory 'Rainmeter.exe') @('!DeactivateConfig',$name)}
            if(Test-Path -LiteralPath (Join-Path $StateRoot 'state.json')) {Remove-Item -LiteralPath (Join-Path $StateRoot 'state.json')}
        }
        if ($pending) {Remove-Item -LiteralPath (Join-Path $StateRoot 'pending.json') -Force}
        Write-Output 'Previous code restored. Personal settings and credentials retained.'
    } finally {$lock.ReleaseMutex();$lock.Dispose()}
}
function Publish-WidgetSource([string]$Root,[string]$StateRoot,[string]$Message,[string]$Widget) {
    & git -C $Root diff --quiet --cached
    if ($LASTEXITCODE -ne 0) {throw 'The Git index already contains changes. Commit or unstage them before sync.'}
    $branch=& git -C $Root branch --show-current
    $remote=& git -C $Root remote get-url origin
    if (!$branch -or !$remote) {throw 'Sync requires a branch and an origin remote.'}
    & (Join-Path $Root 'tools\CheckSource.ps1') -Root $Root
    $verifiedSource=Get-SourceFingerprint $Root
    Invoke-WidgetDeployment -Root $Root -StateRoot $StateRoot -Widget $Widget
    & git -C $Root add -- Manage.ps1 .gitignore .gitattributes README.md MementoMori CLIProxyAccounts tools tests .github
    if ($LASTEXITCODE -ne 0) {throw 'Git staging failed. Local deployment succeeded.'}
    & (Join-Path $Root 'tools\CheckSource.ps1') -Root $Root -Staged
    if ((Get-SourceFingerprint $Root) -ne $verifiedSource) {throw 'Source changed during sync. Deployment is retained; review your edits before publishing.'}
    & git -C $Root diff --quiet -- Manage.ps1 MementoMori CLIProxyAccounts tools tests
    if ($LASTEXITCODE -ne 0) {throw 'Source changed after staging. Review and retry sync; publication stopped.'}
    & git -C $Root diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        & git -C $Root commit -m $Message
        if ($LASTEXITCODE -ne 0) {throw 'Commit failed. Local deployment succeeded; source remains staged.'}
    }
    & git -C $Root push -u origin $branch
    if ($LASTEXITCODE -ne 0) {throw 'Push failed. Local deployment and commit are retained; retry git push after resolving the error.'}
    $state=Read-WidgetJson (Join-Path $StateRoot 'state.json')
    $state.Commit=[string](& git -C $Root rev-parse --short HEAD)
    Write-WidgetJson $state (Join-Path $StateRoot 'state.json')
}
