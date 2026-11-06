# Rainmeter widgets

Two Windows widgets with one setup and update workflow:

| Widget | What it shows |
| --- | --- |
| MementoMori | Life in weeks, a chosen age horizon, and daytime/sleep countdowns. |
| CLIProxyAccounts | Codex quota windows and account status from the compatible custom CLIProxyAPI v8 management API. |

## Set up on another machine

Install [Rainmeter](https://www.rainmeter.net/), then run these commands in Windows PowerShell 5.1:

```powershell
git clone https://github.com/Raghav-56/rainmeter-widgets.git
cd rainmeter-widgets
.\Manage.ps1 install
```

Choose either widget or both. Setup prompts for a birth date when installing Memento Mori and a private proxy URL and hidden management key when installing CLIProxyAccounts. Hotkey handlers compile locally using Windows' .NET Framework compiler. Python is not required for installation.

Rainmeter is detected from the running process or common installation paths. Its configured skin directory is detected from its portable or per-user settings. If detection needs help:

```powershell
.\Manage.ps1 install -Widget MementoMori -RainmeterDirectory 'C:\Program Files\Rainmeter' -SkinDirectory 'C:\Path\To\Rainmeter\Skins'
```

CLIProxyAccounts requires the account-management API of the [custom CLIProxyAPI fork](https://github.com/Raghav-56/CLIProxyAPI). A stock proxy installation is not assumed compatible. Use an existing loopback forward or private Tailscale HTTPS URL. The management key is entered locally and protected with Windows CurrentUser DPAPI; it never belongs in a command argument or Git.

## Change code and update your installation

Edit the source in this checkout, then:

```powershell
.\Manage.ps1 update -WhatIf             # Preview; no writes or restarts
.\Manage.ps1 sync -Message 'feat: adjust the widget layout'
```

`sync` verifies source and tests, deploys selected installed widgets, then commits and pushes source to the current branch's origin. It refuses an already-staged Git index, recognized secret patterns, private/runtime files and edits made directly to installed code. It never pulls, merges, force-pushes or uploads local settings. Review your source edits before running it.

If you prefer separate deployment and publishing:

```powershell
.\Manage.ps1 verify
.\Manage.ps1 update                    # Local deployment only
# Review, commit and push with your normal Git workflow.
```

A failed push keeps your local deployment and commit. Resolve the Git/network error and retry `git push`. Installation and Git hosting cannot form one atomic transaction.

On another machine, update a clean checkout with `git pull --ff-only`, then run `.\Manage.ps1 update`. Each machine retains its own settings and credentials.

## Adopt an existing installation

```powershell
.\Manage.ps1 adopt                     # Record existing files; no widget changes
.\Manage.ps1 update -WhatIf
.\Manage.ps1 update
```

Use `-Widget MementoMori` or `-Widget CLIProxyAccounts` to adopt one widget. Adoption records the current installed code as a baseline. The first update extracts Memento Mori's existing date, age horizon, colors and ShowToday preference into its private `User.inc`. Existing account settings and the protected key are checked and retained byte for byte.

A recognized older Memento Mori portable launcher forwards to the managed launcher, preserving its existing shortcuts. The previous launcher is backed up. Rainmeter itself and unrelated skins are not moved or replaced.

## Status and recovery

```powershell
.\Manage.ps1 status
.\Manage.ps1 rollback
```

Status reports each widget's source/deployment agreement and direct installation edits. Update stages and builds first, backs up replaced code, verifies copied hashes and asks each loaded Rainmeter skin for a fresh readiness acknowledgement. Repeating an unchanged update does nothing. If readiness fails, previous code is restored. A process interruption leaves a recovery journal; run `rollback` before updating again.

Rollback restores the last deployment's code. It preserves personal settings and credentials, and refuses to overwrite subsequent direct code edits. It does not rewrite Git history. To deploy a different source revision afterward, use your normal Git checkout/revert workflow and run update.

## What stays local

| Data | Location | Update behavior |
| --- | --- | --- |
| Memento birth date, horizon, colors and display preference | Installed skin's `@Resources/User.inc` | Created or imported once; never overwritten. |
| Proxy endpoint and selected Rainmeter paths | `%LOCALAPPDATA%\CLIProxyAccounts\settings.json` | Preserved. |
| Protected management key | `%LOCALAPPDATA%\CLIProxyAccounts\key.dpapi` | Preserved; configure separately on each machine. |
| Memento launcher settings | `%LOCALAPPDATA%\RainmeterWidgets\MementoMori\settings.json` | Preserved. |
| Deployment state and rollback snapshots | `%LOCALAPPDATA%\RainmeterWidgets` | Local, protected, outside Git. |
| Rainmeter layout, positions and startup entries | Existing Rainmeter/Windows locations | Not replaced by the updater. |

Edit personal configuration in its installed local file, then refresh the affected skin. Edit widget code in this repository. If you accidentally edit installed code, status detects it and update stops so you can copy and review your changes first.

Rainmeter can save layout changes when a skin is refreshed. Fresh installation rescans Rainmeter's skin list; normal updates refresh only widgets whose installed code changed. Each skin starts its own hotkey handler on load. Existing Windows startup choices are preserved; enable Rainmeter's own start-with-Windows option if desired.

## Verification

```powershell
.\Manage.ps1 verify
```

Offline tests use synthetic accounts, temporary Windows profiles, temporary DPAPI storage and a fake Rainmeter executable. They test clean setup, configuration preservation, direct-edit rejection, idempotency, failed builds, failed readiness, rollback, interrupted deployment recovery and publication privacy checks. They do not use your installed widgets or real credentials.

Optional Lua 5.1 tests require Python and `python -m pip install -r tests/requirements.txt`. They run automatically when that dependency is present. Windows CI includes them.

## Source and attribution

CLIProxyAccounts was extracted from `desktop/rainmeter` in the Raghav-56/CLIProxyAPI custom fork. This repository now maintains the widget; the proxy repository remains the server source. Preserve the existing [MIT notice](CLIProxyAccounts/LICENSE) when redistributing its code. Memento Mori was imported from a local widget and has no additional license assigned. Rainmeter is a separate dependency and is not redistributed.