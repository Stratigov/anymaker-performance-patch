[CmdletBinding()]
param(
    [ValidateSet('Balanced', 'Simulation', 'Mild', 'CityExperimental', 'Original')]
    [string]$Profile,

    [string]$GameDirectory,

    [ValidateSet(30, 40, 50, 60)]
    [int]$TickRate = 60,

    [switch]$ListProfiles
)

$ErrorActionPreference = 'Stop'

$expectedHash = 'BBF8F28A93817C688D128577D9866DC719EC2471DF12C56B8B8AE04659300A90'
$expectedLength = 34527725
$tickOffset = 14057013
$midRadiusOffset = 14064241
$nearRadiusOffset = 14064461

$profiles = [ordered]@{
    Balanced = [ordered]@{
        NearRadius = 64.0
        MidRadius = 768.0
        Description = 'Recommended: good simulation headroom without changing the medium-distance radius.'
    }
    Simulation = [ordered]@{
        NearRadius = 64.0
        MidRadius = 768.0
        Description = 'Legacy radius profile retained for compatibility; select tick rate separately.'
    }
    Mild = [ordered]@{
        NearRadius = 128.0
        MidRadius = 768.0
        Description = 'Smaller visual compromise, but less performance improvement.'
    }
    CityExperimental = [ordered]@{
        NearRadius = 64.0
        MidRadius = 384.0
        Description = 'Experimental city profile; distant world data may appear later.'
    }
    Original = [ordered]@{
        Description = 'Restore the verified original file from the backup.'
    }
}

function Show-Profiles {
    Write-Host 'Available profiles:'
    $index = 1
    foreach ($name in $profiles.Keys) {
        Write-Host ("  {0}. {1}: {2}" -f $index, $name, $profiles[$name].Description)
        $index++
    }
    Write-Host 'Tick rate is selected separately with -TickRate: 30, 40, 50 or 60 (default: 60).'
}

if ($ListProfiles) {
    Show-Profiles
    exit 0
}

# When GameDirectory is not provided, ask the user instead of searching the PowerShell working folder.
$promptForGameDirectory = [string]::IsNullOrWhiteSpace($GameDirectory)
$tickRateWasProvided = $PSBoundParameters.ContainsKey('TickRate')
$patchFailed = $false

try {
    if ($promptForGameDirectory) {
        Write-Host 'Anymaker Performance Patch'
        Write-Host 'Find the installation folder in Steam: Anymaker > Properties > Installed Files > Browse.'
        Write-Host 'Paste the main game folder path, not the bin subfolder.'
        while ($true) {
            $enteredPath = Read-Host 'Enter the full path to the Anymaker folder'
            if ($null -eq $enteredPath) {
                throw 'No game directory was provided.'
            }
            $enteredPath = $enteredPath.Trim().Trim([char]34).Trim([char]39).Trim()
            if (-not $enteredPath) {
                Write-Host 'Please enter a folder path.' -ForegroundColor Yellow
                continue
            }
            if (-not (Test-Path -LiteralPath $enteredPath -PathType Container)) {
                Write-Host "Folder does not exist: $enteredPath" -ForegroundColor Yellow
                continue
            }
            $candidateFile = Join-Path $enteredPath 'bin\game.gcl'
            if (-not (Test-Path -LiteralPath $candidateFile -PathType Leaf)) {
                Write-Host "Could not find bin\game.gcl in: $enteredPath" -ForegroundColor Yellow
                continue
            }
            $GameDirectory = (Resolve-Path -LiteralPath $enteredPath).Path
            Write-Host "Game directory: $GameDirectory"
            break
        }
    }

    $profileWasSelectedInteractively = -not $Profile
    if ($profileWasSelectedInteractively) {
        Show-Profiles
        $selection = Read-Host 'Choose profile number'
        $names = @($profiles.Keys)
        $number = 0
        if (-not [int]::TryParse($selection, [ref]$number) -or $number -lt 1 -or $number -gt $names.Count) {
            throw 'Invalid profile selection.'
        }
        $Profile = $names[$number - 1]
    }

    if ($profileWasSelectedInteractively -and $Profile -ne 'Original' -and -not $tickRateWasProvided) {
        $tickSelection = Read-Host 'Choose tick rate: 30, 40, 50 or 60 [60]'
        if ($tickSelection) {
            $selectedTickRate = 0
            if (-not [int]::TryParse($tickSelection, [ref]$selectedTickRate) -or
                $selectedTickRate -notin @(30, 40, 50, 60)) {
                throw 'Invalid tick rate. Choose 30, 40, 50 or 60.'
            }
            $TickRate = $selectedTickRate
        }
    }

    $gameFile = Join-Path $GameDirectory 'bin\game.gcl'
    $backupFile = "$gameFile.original-v0.2.0"

    if (-not (Test-Path -LiteralPath $gameFile -PathType Leaf)) {
        throw "Could not find: $gameFile"
    }

    $currentHash = (Get-FileHash -LiteralPath $gameFile -Algorithm SHA256).Hash
    $backupIsValid = $false
    if (Test-Path -LiteralPath $backupFile -PathType Leaf) {
        $backupIsValid = ((Get-FileHash -LiteralPath $backupFile -Algorithm SHA256).Hash -eq $expectedHash)
        if (-not $backupIsValid) {
            throw "The backup exists but does not match the supported original: $backupFile"
        }
    }

    if ($currentHash -eq $expectedHash) {
        if (-not $backupIsValid) {
            Copy-Item -LiteralPath $gameFile -Destination $backupFile
            $backupIsValid = $true
            Write-Host "Created verified backup: $backupFile"
        }
    } elseif (-not $backupIsValid) {
        throw 'Unsupported or already modified game.gcl, and no verified original backup was found.'
    }

    if ($Profile -eq 'Original') {
        Copy-Item -LiteralPath $backupFile -Destination $gameFile -Force
        $restoredHash = (Get-FileHash -LiteralPath $gameFile -Algorithm SHA256).Hash
        if ($restoredHash -ne $expectedHash) {
            throw 'Restore verification failed.'
        }
        Write-Host 'Original game.gcl restored successfully.'
    } else {
        $bytes = [IO.File]::ReadAllBytes($backupFile)
        if ($bytes.Length -ne $expectedLength) {
            throw 'Unexpected original file length.'
        }
        if ([BitConverter]::ToInt32($bytes, $tickOffset) -ne 60) {
            throw 'Original tick-rate constant was not found at the expected offset.'
        }
        if ([BitConverter]::ToDouble($bytes, $midRadiusOffset) -ne 768.0) {
            throw 'Original medium-radius constant was not found at the expected offset.'
        }
        if ([BitConverter]::ToDouble($bytes, $nearRadiusOffset) -ne 256.0) {
            throw 'Original near-radius constant was not found at the expected offset.'
        }

        $settings = $profiles[$Profile]
        [Array]::Copy([BitConverter]::GetBytes([int]$TickRate), 0, $bytes, $tickOffset, 4)
        [Array]::Copy([BitConverter]::GetBytes([double]$settings.MidRadius), 0, $bytes, $midRadiusOffset, 8)
        [Array]::Copy([BitConverter]::GetBytes([double]$settings.NearRadius), 0, $bytes, $nearRadiusOffset, 8)

        $temporaryFile = "$gameFile.performance-patch.tmp"
        [IO.File]::WriteAllBytes($temporaryFile, $bytes)

        $verifyBytes = [IO.File]::ReadAllBytes($temporaryFile)
        if ([BitConverter]::ToInt32($verifyBytes, $tickOffset) -ne $TickRate -or
            [BitConverter]::ToDouble($verifyBytes, $midRadiusOffset) -ne $settings.MidRadius -or
            [BitConverter]::ToDouble($verifyBytes, $nearRadiusOffset) -ne $settings.NearRadius) {
            Remove-Item -LiteralPath $temporaryFile -Force
            throw 'Patched-file verification failed.'
        }

        Copy-Item -LiteralPath $temporaryFile -Destination $gameFile -Force
        Remove-Item -LiteralPath $temporaryFile -Force

        Write-Host "Applied profile: $Profile"
        Write-Host "Server tick rate: $TickRate"
        Write-Host "Near high-detail/physics radius: $($settings.NearRadius)"
        Write-Host "Medium server radius: $($settings.MidRadius)"
        Write-Host 'Save files and game executables were not modified.'
    }

} catch {
    $patchFailed = $true
    Write-Host ''
    Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No successful patch installation was confirmed.' -ForegroundColor Yellow
} finally {
    # Users launching the patch interactively can see the result before the window closes.
    if ($promptForGameDirectory) {
        try { [void](Read-Host 'Press Enter to close') } catch { }
    }
}

if ($patchFailed) { exit 1 }
