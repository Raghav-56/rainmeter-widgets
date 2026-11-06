# Rainmeter widgets

Two Windows desktop widgets, with their Lua, PowerShell and C# source.

| Folder | Widget |
| --- | --- |
| [MementoMori](MementoMori/README.md) | Life in weeks, a configurable age horizon, and daytime/sleep countdowns. |
| [CLIProxyAccounts](CLIProxyAccounts/README.md) | Codex quota windows and account status from a compatible custom CLIProxyAPI v8 management API. |

Requires Windows and an existing [Rainmeter](https://www.rainmeter.net/) installation. The accounts helper uses Windows PowerShell 5.1 and the built-in .NET Framework C# compiler.

This repository is a source copy. Creating it does not install, relocate, refresh or restart any widget. Follow each widget's instructions only when you intend to deploy a change.

## Private data

No installed settings, protected keys, account snapshots, logs, shortcuts, binaries, backups or Rainmeter layouts are included. Memento Mori uses the example birth date 1 January 2000. Set your own date in your local installation.

The accounts helper accepts a management key at installation as a SecureString and stores it using Windows CurrentUser DPAPI outside this repository. Never commit a real key, private endpoint, account response, screenshot containing account details, or runtime directory. Ignore rules are a safeguard, not a substitute for reviewing staged files.

## Source and attribution

Memento Mori was imported from an existing local widget. CLIProxyAccounts was extracted from the `desktop/rainmeter` directory of the Raghav-56/CLIProxyAPI custom fork. Its existing MIT notice is retained in [CLIProxyAccounts/LICENSE](CLIProxyAccounts/LICENSE). The extracted copy has a generic endpoint fixture, explicit Rainmeter installation selection, and no machine-specific SSH key-import option. The original checkout and installed widgets remain separate from this repository.

Rainmeter itself is a separate dependency and is not redistributed here. No additional license has been assigned to the Memento Mori source.

## Offline checks

Run these from this repository in Windows PowerShell. They use temporary fixtures rather than the installed helper or live accounts:

```powershell
powershell.exe -NoProfile -File .\CLIProxyAccounts\Test.ps1
powershell.exe -NoProfile -File .\CLIProxyAccounts\TestQuotaRefresh.ps1
```