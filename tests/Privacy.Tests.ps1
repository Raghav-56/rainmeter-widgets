$ErrorActionPreference='Stop'
$testRoot=Join-Path $env:TEMP ('rainmeter-privacy-test-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$source=Split-Path $PSScriptRoot -Parent
function Rejects([scriptblock]$Action,[string]$Label) {$failed=$false;try{& $Action | Out-Null}catch{$failed=$true};if(!$failed){throw "FAIL: $Label"};Write-Output "PASS: $Label"}
try {
    & git init -q $testRoot
    [void][IO.Directory]::CreateDirectory((Join-Path $testRoot 'MementoMori'))
    $file=Join-Path $testRoot 'MementoMori\sample.ini'
    [IO.File]::WriteAllText($file,'BirthYear=2000')
    & "$source\tools\CheckSource.ps1" -Root $testRoot | Out-Null
    foreach($privateName in @('settings.json','User.inc','key.dpapi','snapshot.ini','Rainmeter.ini','leaked.log','secret.pem')) {
        $private=Join-Path $testRoot ('MementoMori\'+$privateName)
        [IO.File]::WriteAllText($private,'fixture')
        Rejects {& "$source\tools\CheckSource.ps1" -Root $testRoot} "Publication rejects $privateName"
        Remove-Item -LiteralPath $private
    }
    [IO.File]::WriteAllText($file,('Authorization=Bearer '+('synthetic' * 5)))
    Rejects {& "$source\tools\CheckSource.ps1" -Root $testRoot} 'Publication rejects an embedded bearer value'
    [IO.File]::WriteAllText($file,('contact=person'+'@private-host.dev'))
    Rejects {& "$source\tools\CheckSource.ps1" -Root $testRoot} 'Publication rejects private account identity'
    [IO.File]::WriteAllText($file,('BaseUrl=https://machine.'+'private-tailnet.ts.net'))
    Rejects {& "$source\tools\CheckSource.ps1" -Root $testRoot} 'Publication rejects a private Tailscale endpoint'
    [IO.File]::WriteAllText($file,'BirthYear=2000')
    & git -C $testRoot add -- MementoMori/sample.ini
    [IO.File]::WriteAllText($file,'Authorization=Bearer '+('synthetic' * 5))
    & git -C $testRoot add -- MementoMori/sample.ini
    [IO.File]::WriteAllText($file,'BirthYear=2000')
    Rejects {& "$source\tools\CheckSource.ps1" -Root $testRoot -Staged} 'Publication inspects staged contents even when the working file was sanitized afterward'
    Write-Output '11 source privacy rejection checks passed.'
} finally {
    $resolved=[IO.Path]::GetFullPath($testRoot)
    if (!$resolved.StartsWith(([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'rainmeter-privacy-test-*') {throw 'Unsafe test cleanup path'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
