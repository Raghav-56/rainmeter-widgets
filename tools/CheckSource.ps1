param([string]$Root=(Split-Path $PSScriptRoot -Parent),[switch]$Staged)
$ErrorActionPreference='Stop'
$paths=@(& git -C $Root ls-files --cached --others --exclude-standard)
if ($LASTEXITCODE -ne 0) {throw 'Source verification requires a Git checkout.'}
if ($Staged) {$paths=@(& git -C $Root diff --cached --name-only --diff-filter=ACMR)}
$blockedNames='(?i)(?:^|/)(?:User\.inc|settings\.json|state\.json|pending\.json|key\.dpapi|snapshot\.ini|Rainmeter\.ini|Rainmeter\.data|Rainmeter\.stats|\.rainmeter-widgets|\.env(?:\..*)?)$|\.(?:exe|dll|lnk|log|pem|pfx|key|bak|zip)$|(?:^|/)(?:backups|staging|repair-[^/]+)(?:/|$)'
$patterns=@(
    '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16})',
    '\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
    '(?i)(?:api[_-]?key|password|client[_-]?secret|access[_-]?token|refresh[_-]?token)\s*[:=]\s*["''][A-Za-z0-9+/=_-]{24,}["'']',
    '(?i)Bearer\s+[A-Za-z0-9_./+=-]{20,}',
    '(?i)[A-Z]:\\Users\\(?!Public(?:\\|$))[^\\\s"'']+',
    '(?i)\b(?!proxy\.example-tailnet\.ts\.net\b)[a-z0-9-]+\.[a-z0-9-]+\.ts\.net'
)
foreach ($path in @($paths | Sort-Object -Unique)) {
    if ($path -match $blockedNames) {throw "Private/runtime file in publishable source: $path"}
    if ($path -notmatch '(?i)^(Manage\.ps1|README\.md|\.gitignore|\.gitattributes|(?:MementoMori|CLIProxyAccounts|tools|tests|\.github)/)') {throw "Unrecognized publishable path: $path. Review it before extending the source allow-list."}
    if ($path -match '(?i)(^|/)CheckSource\.ps1$') {
        # Regex definitions intentionally describe credentials; inspect known-token
        # formats here too, but don't match the definitions against themselves.
        $filePatterns=$patterns[0..2]
    } else {$filePatterns=$patterns}
    if ($Staged) {$text=(& git -C $Root show (':'+$path)) -join "`n"} else {$text=[IO.File]::ReadAllText((Join-Path $Root $path))}
    foreach ($pattern in $filePatterns) {if ($text -match $pattern) {throw "Possible private value in $path. Publication blocked; inspect locally."}}
    foreach ($match in [regex]::Matches($text,'[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})')) {
        if ($match.Groups[1].Value -notmatch '(^|\.)(example\.(com|org|net)|invalid|test)(\.|$)' -and $match.Groups[1].Value -ne 'proxy.example-tailnet.ts.net') {throw "Possible private email in $path. Publication blocked."}
    }
}
Write-Output ('Source privacy check passed for '+$paths.Count+' files. No private/runtime files or recognized credential patterns found.')
