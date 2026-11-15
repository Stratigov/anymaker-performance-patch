[CmdletBinding()]
param(
    [ValidateSet('Balanced', 'Simulation', 'Mild', 'CityExperimental', 'Original')]
    [string]$Profile,

    [string]$GameDirectory = (Get-Location).Path,

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
        TickRate = 40
        NearRadius = 64.0
        MidRadius = 768.0
        Description = 'Recommended: good simulation headroom without changing the medium-distance radius.'
    }
    Simulation = [ordered]@{
        TickRate = 30
        NearRadius = 64.0
        MidRadius = 768.0
        Description = 'Maximum simulation headroom; AI and physics update less frequently.'
    }
    Mild = [ordered]@{
        TickRate = 50
        NearRadius = 128.0
        MidRadius = 768.0
        Description = 'Smaller visual compromise, but less performance improvement.'
    }
    CityExperimental = [ordered]@{
        TickRate = 40
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
}

if ($ListProfiles) {
    Show-Profiles
    exit 0
}

if (-not $Profile) {
    Show-Profiles
    $selection = Read-Host 'Choose profile number'
    $names = @($profiles.Keys)
    $number = 0
    if (-not [int]::TryParse($selection, [ref]$number) -or $number -lt 1 -or $number -gt $names.Count) {
        throw 'Invalid profile selection.'
    }
    $Profile = $names[$number - 1]
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
    exit 0
}

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
[Array]::Copy([BitConverter]::GetBytes([int]$settings.TickRate), 0, $bytes, $tickOffset, 4)
[Array]::Copy([BitConverter]::GetBytes([double]$settings.MidRadius), 0, $bytes, $midRadiusOffset, 8)
[Array]::Copy([BitConverter]::GetBytes([double]$settings.NearRadius), 0, $bytes, $nearRadiusOffset, 8)

$temporaryFile = "$gameFile.performance-patch.tmp"
[IO.File]::WriteAllBytes($temporaryFile, $bytes)

$verifyBytes = [IO.File]::ReadAllBytes($temporaryFile)
if ([BitConverter]::ToInt32($verifyBytes, $tickOffset) -ne $settings.TickRate -or
    [BitConverter]::ToDouble($verifyBytes, $midRadiusOffset) -ne $settings.MidRadius -or
    [BitConverter]::ToDouble($verifyBytes, $nearRadiusOffset) -ne $settings.NearRadius) {
    Remove-Item -LiteralPath $temporaryFile -Force
    throw 'Patched-file verification failed.'
}

Copy-Item -LiteralPath $temporaryFile -Destination $gameFile -Force
Remove-Item -LiteralPath $temporaryFile -Force

Write-Host "Applied profile: $Profile"
Write-Host "Server tick rate: $($settings.TickRate)"
Write-Host "Near high-detail/physics radius: $($settings.NearRadius)"
Write-Host "Medium server radius: $($settings.MidRadius)"
Write-Host 'Save files and game executables were not modified.'

