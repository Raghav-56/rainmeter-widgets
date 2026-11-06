# Memento Mori

A Rainmeter life calendar with compact, expanded and mini views. It shows full weeks to a chosen age horizon and the fraction already lived. Daytime counts down to 22:00; the sleep window counts down to 06:00. The horizon is a personal choice, not a prediction.

## Skin

Copy `Skins/MementoMori` into your chosen Rainmeter skin directory, then load `MementoMori/Meter.ini` through Rainmeter. Back up an existing skin before deliberately replacing it.

Edit the `[Variables]` section of your installed `Meter.ini`: `BirthYear`, `BirthMonth`, `BirthDay`, and `ReferenceAge`. The repository uses the example date 1 January 2000 and an age horizon of 60. Refresh the skin after editing. Keep your personal configuration local.

Click **View +**, **Mini** or **Hide** to change views. Drag the card to move it. A hidden skin can be shown through Rainmeter's management window. The skin works locally without network requests.

## Optional privacy hotkey

`MementoMoriHotkeys.cs` implements Ctrl+Alt+M. `Launch.ps1` expects `Rainmeter.exe` and the compiled `MementoMoriHotkeys.exe` beside it in a portable Rainmeter installation. These helpers are optional; loading the skin does not require them.

Compile the handler to a staging directory with the .NET Framework C# compiler:

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ /out:MementoMoriHotkeys.exe .\MementoMoriHotkeys.cs
```

To use it, deliberately copy the compiled handler and `Launch.ps1` beside your portable `Rainmeter.exe`, then run that installed launcher. No startup task or shortcut is created by this repository. Avoid starting a second handler while an existing installation owns Ctrl+Alt+M.