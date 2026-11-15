# Anymaker v0.2.0 server-simulation performance patch

This package patches constants in your own `bin/game.gcl`. It does not contain game files, saves, account data, usernames or machine-specific paths. It supports only the Anymaker v0.2.0 file with SHA-256 `BBF8F28A93817C688D128577D9866DC719EC2471DF12C56B8B8AE04659300A90` and refuses to modify any other build. The check applies only to `bin/game.gcl`; differences in `game.exe`, launchers, Steam emulators or DLL files do not matter. If a repack also modified `game.gcl`, the patcher will refuse it because its offsets cannot be assumed safe.

Long or heavily explored saves can saturate the single Server thread when populated city zones become active. The patch reduces how much high-detail world and local physics the server processes around the player. Some profiles also lower the server tick rate. The engine derives its delta time from that rate, so ordinary movement remains close to real time, although AI decisions, physics and tick-based timers can become less precise at lower rates.

## Profiles

`Balanced` is the recommended tested profile. It uses 40 server ticks per second and a near high-detail/physics radius of 64 while retaining the original medium radius.

`Simulation` uses 30 ticks and radius 64. It provides more CPU headroom but makes server updates less frequent.

`Mild` uses 50 ticks and radius 128. It changes less, but may not provide enough relief for very large saves.

`CityExperimental` uses 40 ticks, near radius 64 and medium radius 384. It may reduce city-loading spikes, but distant world data may appear later and this profile requires more testing.

`Original` restores the verified original file from the backup created by the patcher.

## Installation

Close the game. Extract this package anywhere, open PowerShell and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-Anymaker.ps1 -GameDirectory "C:\Path\To\Anymaker" -Profile Balanced
```

If no profile is supplied, the script displays an interactive selection menu:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-Anymaker.ps1 -GameDirectory "C:\Path\To\Anymaker"
```

To restore the original:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-Anymaker.ps1 -GameDirectory "C:\Path\To\Anymaker" -Profile Original
```

The first successful run creates `bin\game.gcl.original-v0.2.0`. Keep this backup. The script never modifies saves, `game.exe` or DLL files. It always builds a selected profile from the verified original backup, so profiles can be changed without stacking patches.

Test on a copied save first. Lower radii can cause delayed activation or visible pop-in, and lower tick rates may affect AI response, fast collisions and tick-based cooldowns. The workaround targets server-side simulation delay; it does not fix a separate saturated Main/render thread or guarantee higher FPS.
