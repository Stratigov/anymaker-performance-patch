# Anymaker v0.2.0 server-simulation performance patch

This package patches constants in your own `bin/game.gcl`. It does not contain game files, saves, account data, usernames or machine-specific paths. It supports only the Anymaker v0.2.0 file with SHA-256 `BBF8F28A93817C688D128577D9866DC719EC2471DF12C56B8B8AE04659300A90` and refuses to modify any other build. The check applies only to `bin/game.gcl`; differences in `game.exe`, launchers, Steam emulators or DLL files do not matter. If a repack also modified `game.gcl`, the patcher will refuse it because its offsets cannot be assumed safe.

Long or heavily explored saves can saturate the single Server thread when populated city zones become active. The patch reduces how much high-detail world and local physics the server processes around the player. The server tick rate is selected separately from the radius profile. The default is the game's original 60 ticks per second. A lower rate can provide more CPU headroom, but AI decisions, physics, tick-based timers and automation can become less precise or update less often.

## Profiles

`Balanced` is the recommended tested radius profile. It uses a near high-detail/physics radius of 64 while retaining the original medium radius.

`Simulation` uses radius 64. It is retained for compatibility with previous commands; tick rate is now selected independently.

`Mild` uses radius 128. It changes less, but may not provide enough relief for very large saves.

`CityExperimental` uses near radius 64 and medium radius 384. It may reduce city-loading spikes, but distant world data may appear later and this profile requires more testing.

`Original` restores the verified original file from the backup created by the patcher.

## Tick rate

Use `-TickRate` to select 30, 40, 50 or 60 ticks per second. If the option is omitted, the patcher uses 60, the game's original rate. This keeps the original simulation timing while still applying the selected radius profile.

For a heavy world, 40 ticks per second is a useful performance compromise: each server update gets more CPU time, at the cost of less frequent simulation updates. Lower rates can affect fast physics, AI response, tick-based timers and automation, so test them on a copied save.

## Installation

Close the game. Extract this package anywhere, open PowerShell and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-Anymaker.ps1 -GameDirectory "C:\Path\To\Anymaker" -Profile Balanced -TickRate 60
```

If no profile is supplied, the script displays interactive profile and tick-rate selections. Press Enter at the tick-rate prompt to keep the default of 60:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-Anymaker.ps1 -GameDirectory "C:\Path\To\Anymaker"
```

To use the 40-tick performance compromise with the Balanced radius profile:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-Anymaker.ps1 -GameDirectory "C:\Path\To\Anymaker" -Profile Balanced -TickRate 40
```

To restore the original:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Patch-Anymaker.ps1 -GameDirectory "C:\Path\To\Anymaker" -Profile Original
```

The first successful run creates `bin\game.gcl.original-v0.2.0`. Keep this backup. The script never modifies saves, `game.exe` or DLL files. It always builds a selected profile from the verified original backup, so profiles can be changed without stacking patches.

Test on a copied save first. Lower radii can cause delayed activation or visible pop-in, and lower tick rates may affect AI response, fast collisions, tick-based cooldowns, timers and automation. The workaround targets server-side simulation delay; it does not fix a separate saturated Main/render thread or guarantee higher FPS.
