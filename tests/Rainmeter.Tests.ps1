$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. "$root\tools\Deployment.ps1"
$testRoot=Join-Path $env:TEMP ('rainmeter-control-test-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$oldLog=$env:WIDGET_TEST_LOG;$oldSkins=$env:WIDGET_TEST_SKINS;$oldFail=$env:WIDGET_TEST_FAIL
try {
    $code=@'
using System;
using System.IO;
using System.Text.RegularExpressions;
internal static class Fixture {
    static int Main(string[] args) {
        string raw = Environment.CommandLine;
        int start = raw[0] == '"' ? raw.IndexOf('"', 1)+1 : raw.IndexOf(' ');
        if (start < 0 || raw.Substring(start).TrimStart().StartsWith("\"!")) return 9;
        File.AppendAllText(Environment.GetEnvironmentVariable("WIDGET_TEST_LOG"), String.Join("|", args)+"\n");
        if (Environment.GetEnvironmentVariable("WIDGET_TEST_FAIL") == "exit") return 7;
        if (args.Length == 4 && args[0] == "!CommandMeasure" && Environment.GetEnvironmentVariable("WIDGET_TEST_FAIL") != "silent") {
            string nonce = Regex.Match(args[2], "[a-f0-9]{32}").Value;
            string resources = Path.Combine(Environment.GetEnvironmentVariable("WIDGET_TEST_SKINS"), args[3], "@Resources");
            Directory.CreateDirectory(resources);
            File.WriteAllText(Path.Combine(resources, "Deployment.ready"), nonce);
        }
        return 0;
    }
}
'@
    $cs=Join-Path $testRoot 'Fixture.cs';[IO.File]::WriteAllText($cs,$code)
    $exe=Join-Path $testRoot 'Rainmeter.exe'
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe ('/out:'+$exe) $cs
    if($LASTEXITCODE -ne 0){throw 'Fixture compilation failed'}
    $env:WIDGET_TEST_LOG=Join-Path $testRoot 'commands.txt'
    $env:WIDGET_TEST_SKINS=Join-Path $testRoot 'Skins'
    $env:WIDGET_TEST_FAIL=''
    $context=[pscustomobject]@{RainmeterDirectory=$testRoot;SkinRoot=$env:WIDGET_TEST_SKINS}
    Start-SelectedWidgets $context @('MementoMori','CLIProxyAccounts')
    $commands=@(Get-Content -LiteralPath $env:WIDGET_TEST_LOG)
    if($commands.Count -ne 6 -or $commands[2] -notmatch '^!CommandMeasure\|Clock\|DeploymentCheck' -or $commands[5] -notmatch '^!CommandMeasure\|ReadSnapshot\|DeploymentCheck'){throw 'Incorrect Rainmeter control protocol'}
    Write-Output 'PASS: native Rainmeter control receives correctly quoted per-skin activation, refresh and readiness commands'
    if(Test-Path -LiteralPath (Join-Path $env:WIDGET_TEST_SKINS 'MementoMori\@Resources\Deployment.ready')){throw 'Readiness nonce was not consumed'}
    Write-Output 'PASS: readiness confirms a fresh nonce and removes the runtime acknowledgement'
    $env:WIDGET_TEST_FAIL='silent';$failed=$false
    try{Start-SelectedWidgets $context @('MementoMori')}catch{$failed=$true}
    if(!$failed){throw 'Silent load failure was accepted'}
    Write-Output 'PASS: a successful control-process exit without skin initialization fails readiness'
    $env:WIDGET_TEST_FAIL='exit';$failed=$false
    try{Invoke-RainmeterCommand $exe @('!Refresh','MementoMori')}catch{$failed=$true}
    if(!$failed){throw 'Native command failure was accepted'}
    Write-Output 'PASS: a failing Rainmeter control process is rejected'
} finally {
    $env:WIDGET_TEST_LOG=$oldLog;$env:WIDGET_TEST_SKINS=$oldSkins;$env:WIDGET_TEST_FAIL=$oldFail
    $resolved=[IO.Path]::GetFullPath($testRoot)
    if (!$resolved.StartsWith(([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'rainmeter-control-test-*') {throw 'Unsafe test cleanup path'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
