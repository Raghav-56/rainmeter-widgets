# CLIProxyAccounts

A 304-pixel Rainmeter widget showing Codex quota windows, reset countdowns, pool observations and optional request diagnostics. It depends on the custom CLIProxyAPI v8 management API implemented in the Raghav-56/CLIProxyAPI fork; compatibility with other releases is not assumed.

## Installation

Use Windows PowerShell 5.1 and a portable Rainmeter installation whose `Rainmeter.ini` has an existing `SkinPath`. Installation changes the selected installation and starts the helper. Do not run it merely to inspect this source repository.

```powershell
$key = Read-Host 'Management key' -AsSecureString
.\Install.ps1 -BaseUrl http://127.0.0.1:8317 -RainmeterDirectory 'C:\Path\To\Rainmeter' -ManagementKey $key
$key = $null
```

Use your existing loopback forward or a private Tailscale HTTPS authority. Redirects and arbitrary public hosts are refused. The repository contains no endpoint or key for a real deployment. `-StartWithWindows` explicitly opts into a Startup shortcut; it is omitted by default.

The helper installs into `%LOCALAPPDATA%\CLIProxyAccounts`. Its `settings.json`, `key.dpapi`, `snapshot.ini`, logs and compiled executable are runtime files and must stay outside Git. The key is protected by Windows CurrentUser DPAPI and user/SYSTEM directory permissions. OAuth substitution remains on the proxy.

The installer copies the skin, compiles the native Ctrl+Alt+Q handler, and starts polling. It preserves unrelated skins. **Details** expands diagnostics; **Hide** and Ctrl+Alt+Q control visibility. The Accounts link opens the validated configured console.

## Behavior

The existing poll reads credentials, routing and recent request observations. When needed it makes bounded quota refresh requests through the management API, using server-side token substitution. It performs no inference and does not select accounts or change routing configuration. Automatic soonest-reset and Home retain server-owned refresh behavior.

Quota timestamps are translated between server and local clocks. Old, malformed and expired observations display unknown values. Snapshot text is restricted before it reaches Rainmeter. A connection indicator alone does not establish usable quota.

## Offline checks

```powershell
powershell.exe -NoProfile -File .\Test.ps1
powershell.exe -NoProfile -File .\TestQuotaRefresh.ps1
```

These checks use synthetic data and temporary files. Live lifecycle tests from the original project are intentionally excluded to avoid accidentally controlling an existing installation during source verification.

## Installed helper controls

Run these only when you intend to control an installed widget:

```powershell
& "$env:LOCALAPPDATA\CLIProxyAccounts\Stop.ps1"
& "$env:LOCALAPPDATA\CLIProxyAccounts\Start.ps1"
& "$env:LOCALAPPDATA\CLIProxyAccounts\StartHotkeys.ps1" -Stop
& "$env:LOCALAPPDATA\CLIProxyAccounts\Uninstall.ps1"
```

The key is retained by default on uninstall. Pass `-RemoveKey` on the initial uninstall invocation to remove it too. Preserve the MIT attribution in `LICENSE` when redistributing this extracted code.