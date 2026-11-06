# Memento Mori

A life-in-weeks calendar with compact, expanded and mini views. The horizon is a personal choice, not a prediction. Daytime counts down to 22:00 and the sleep window to 06:00.

From the repository root:

```powershell
.\Manage.ps1 install -Widget MementoMori
```

Setup asks for your birth date and creates `@Resources/User.inc` in the installed skin. Change `BirthYear`, `BirthMonth`, `BirthDay`, `ReferenceAge` or colors in that local file and refresh the skin. The repository defaults are examples. Updates preserve your file and the widget's ShowToday preference.

Click **View +**, **Mini** or **Hide** to change views. Ctrl+Alt+M hides or restores the widget. The hotkey handler starts when the skin loads. Rainmeter's management window can also restore a hidden skin. The widget makes no network requests.

The managed launcher and locally compiled C# handler live under `%LOCALAPPDATA%\RainmeterWidgets\MementoMori`. They read the selected Rainmeter path from local settings, so Rainmeter need not sit beside them. A recognized older launcher is migrated to a forwarding script so existing shortcuts still work.

Change code in this directory and use the shared [update workflow](../README.md#change-code-and-update-your-installation). Do not put your real date or installed settings in the repository.