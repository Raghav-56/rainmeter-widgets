. "$PSScriptRoot\Core.ps1"
$now=[DateTimeOffset]::Parse('2026-11-03T12:00:00Z')
$script:checks=0
function Assert($Condition,[string]$Label) {
    if (!$Condition) { throw "FAIL: $Label" }
    $script:checks++; Write-Output "PASS: $Label"
}
function Quota([DateTimeOffset]$At) {
    [pscustomobject]@{observed_at=$At.ToString('o');signals=[pscustomobject]@{
        'X-Codex-Allowed'='true';'X-Codex-Limit-Reached'='false'
        'X-Codex-Primary-Used-Percent'='29';'X-Codex-Primary-Window-Minutes'='300';'X-Codex-Primary-Reset-At'=$now.AddHours(4).ToUnixTimeSeconds()
        'X-Codex-Secondary-Used-Percent'='34';'X-Codex-Secondary-Window-Minutes'='10080';'X-Codex-Secondary-Reset-At'=$now.AddDays(6).ToUnixTimeSeconds()
    }}
}
$script:credentials=[pscustomobject]@{files=@(1..3 | ForEach-Object {
    [pscustomobject]@{id="fixture-$_";name="fixture-$_.json";auth_index="fixture-index-$_";provider='codex';account_type='oauth';runtime_only=$false;disabled=$false;unavailable=$false;quota=(Quota $now.AddSeconds(-301));id_token=[pscustomobject]@{plan_type='plus'}}
})}
$route=[pscustomobject]@{mode='manual';auth_id='fixture-1';strategy='soonest-reset';home_enabled=$false;applied=$true}
$recent=[pscustomobject]@{requests=@()}
$before=New-WidgetSnapshot $credentials $route $recent $now
Assert ($before.SelectedQuotaState -eq 'stale' -and $before.PrimaryRemaining -eq '' -and $before.SecondaryRemaining -eq '' -and $before.PoolUnknown -eq 3) 'Exact idle symptom: connected manual Plus with both bars unknown and three unknown accounts'
$script:reads=New-Object Collections.Generic.List[string]
$script:fail=$false
function Invoke-ManagementRead($Base,$Endpoint,$Key,$StopFile,$QuotaAccount) {
    $script:reads.Add($Endpoint)
    if ($Endpoint -eq 'requests/api-call') {
        if ($script:fail) { throw 'Management read failed' }
        $QuotaAccount.quota=Quota $now
        return [pscustomobject]@{status_code=200}
    }
    return $script:credentials
}
$attempts=@{}
$updated=Update-WidgetQuotas $credentials $route $now $attempts 'http://127.0.0.1:8317' 'fixture-key' 'fixture-stop'
$after=New-WidgetSnapshot $updated $route $recent $now
Assert ($after.SelectedQuotaState -eq 'available' -and $after.PrimaryRemaining -eq 71 -and $after.SecondaryRemaining -eq 66 -and $after.PrimaryDuration -eq 300 -and $after.SecondaryDuration -eq 10080 -and $after.PoolAvailable -eq 3) 'Existing poll recovers meaningful quotas without traffic or routing changes'
Assert (($reads -join ',') -eq 'requests/api-call,requests/api-call,requests/api-call,credentials') 'One serial bounded refresh per stale account followed by canonical reread'
Assert ($route.mode -eq 'manual' -and $route.auth_id -eq 'fixture-1' -and $route.strategy -eq 'soonest-reset') 'Manual routing remains unchanged even with soonest-reset preference saved'
$reads.Clear()
[void](Update-WidgetQuotas $credentials $route $now.AddSeconds(15) $attempts 'base' 'key' 'stop')
Assert ($reads.Count -eq 0) 'Fresh passive data avoids redundant probes'
foreach($row in $credentials.files) { $row.quota=Quota $now.AddSeconds(-301) }
$reads.Clear(); $script:fail=$true
[void](Update-WidgetQuotas $credentials $route $now.AddSeconds(60) $attempts 'base' 'key' 'stop')
Assert ($reads.Count -eq 4) 'Failed ordinary quota reads do not stop subsequent accounts or passive reread'
$reads.Clear()
[void](Update-WidgetQuotas $credentials $route $now.AddSeconds(75) $attempts 'base' 'key' 'stop')
Assert ($reads.Count -eq 0) 'Failures are retried at most once per minute in the same loop'
$route.mode='automatic'; $route.strategy='soonest-reset'; $reads.Clear()
[void](Update-WidgetQuotas $credentials $route $now.AddSeconds(120) $attempts 'base' 'key' 'stop')
Assert ($reads.Count -eq 0) 'Automatic soonest-reset leaves refresh ownership to the server'
$route.mode='manual'; $route.home_enabled=$true
[void](Update-WidgetQuotas $credentials $route $now.AddSeconds(120) $attempts 'base' 'key' 'stop')
Assert ($reads.Count -eq 0) 'Home ownership is respected'
$route.home_enabled=$false; $credentials.files[0].disabled=$true
$credentials.files[1] | Add-Member -NotePropertyName requires_sign_in -NotePropertyValue $true
$credentials.files[2].account_type='api_key'; $reads.Clear()
[void](Update-WidgetQuotas $credentials $route $now.AddSeconds(120) $attempts 'base' 'key' 'stop')
Assert ($reads.Count -eq 0) 'Disabled, sign-in-required and API-key accounts are never probed'
$credentials.files[0].disabled=$false
$body=Get-QuotaReadBody $credentials.files[0] | ConvertFrom-Json
Assert ($body.method -eq 'GET' -and $body.url -eq 'https://chatgpt.com/backend-api/wham/usage' -and $body.header.Authorization -ceq 'Bearer $TOKEN$' -and $body.auth_index -eq 'fixture-index-1') 'Fixed upstream quota GET uses server token substitution'
Assert ($null -eq $body.data -and $null -eq $body.proxy_url -and $null -eq $body.header.Host) 'Quota request cannot set inference data, proxy overrides or Host'
$credentials.files[0].quota=Quota $now.AddSeconds(4)
$credentials | Add-Member -NotePropertyName observed_at -NotePropertyValue $now.AddSeconds(5).ToString('o')
$credentials | Add-Member -NotePropertyName WidgetRequestedAt -NotePropertyValue $now.ToString('o')
$clockView=New-WidgetSnapshot $credentials $route $recent $now
Assert ($clockView.SelectedQuotaState -eq 'available' -and $clockView.Observation -eq '1s' -and $clockView.PrimaryRemaining -eq 71) 'Measured server clock ahead does not blank newly observed live quota'
Assert ($clockView.SelectedUntil -eq $now.AddSeconds(299).ToUnixTimeSeconds() -and $clockView.PrimaryReset -eq $now.AddHours(4).AddSeconds(-5).ToUnixTimeSeconds()) 'Freshness and reset deadlines are translated to the Lua reader local clock'
$clockView=New-WidgetSnapshot $credentials $route $recent $now.AddSeconds(301)
Assert ($clockView.SelectedQuotaState -eq 'stale' -and $clockView.PrimaryRemaining -eq '') 'Server clock reference never renews an old quota observation'
$credentials.files[0].quota=Quota $now.AddSeconds(6)
Assert ((New-WidgetSnapshot $credentials $route $recent $now).SelectedQuotaState -eq 'stale') 'Observation future-dated relative to the server remains rejected'
Write-Output "$script:checks quota refresh checks passed"
