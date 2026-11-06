# CLIProxyAccounts

A 304-pixel widget showing Codex quota windows, reset countdowns, pool observations and optional request diagnostics. Requires the custom CLIProxyAPI v8 account-management API from the Raghav-56/CLIProxyAPI fork.

From the repository root:

```powershell
.\Manage.ps1 install -Widget CLIProxyAccounts
```

Setup prompts for your private proxy URL and management key. It detects Rainmeter, compiles the native Ctrl+Alt+Q handler and installs the skin. An existing loopback forward or private Tailscale HTTPS authority is required; redirects and arbitrary public hosts are refused.

The helper and private `settings.json`, `key.dpapi`, `snapshot.ini` and logs live under `%LOCALAPPDATA%\CLIProxyAccounts`. The key uses Windows CurrentUser DPAPI. Existing credentials, endpoint and installation paths survive updates and rollback. Configure credentials separately on each machine.

**Details** expands diagnostics. **Hide** and Ctrl+Alt+Q control visibility. The Accounts link opens the validated configured console. The skin starts its helper and hotkey handler when loaded.

The existing poll reads credentials, routing and recent request observations. Bounded quota refresh requests use server-side token substitution. The helper performs no inference and does not select accounts or change routing configuration. Automatic soonest-reset and Home retain server-owned refresh behavior. Expired or invalid observations display unknown values.

Use the shared [update and recovery workflow](../README.md). The older `Install.ps1` now forwards to the shared installer. This widget is maintained here; server API changes remain in CLIProxyAPI. Its existing MIT attribution is retained in `LICENSE`.