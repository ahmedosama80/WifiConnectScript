<#
.SYNOPSIS
    Attempt to force Windows to connect to a saved Wi-Fi profile.

.DESCRIPTION
    Use -ProfileName to try a specific saved profile.
    Use -TryAny to iterate all saved profiles until a connection succeeds.
    The script will retry each attempt a configurable number of times.

.EXAMPLE
    .\ForceWiFiConnect.ps1 -ProfileName "HomeNetwork"
    .\ForceWiFiConnect.ps1 -TryAny -RetryCount 3 -DelayBetweenSeconds 5
#>

param(
    [string]$ProfileName,
    [switch]$TryAny,
    [int]$RetryCount = 3,
    [int]$DelayBetweenSeconds = 5,
    [int]$ConnectWaitSeconds = 20
)

function Get-WlanInterfaceName {
    $raw = netsh wlan show interfaces 2>$null
    if (-not $raw) { return $null }
    foreach ($line in $raw) {
        if ($line -match '^\s*Name\s*:\s*(.+)$') {
            return $matches[1].Trim()
        }
    }
    return $null
}

function Get-SavedProfiles {
    $raw = netsh wlan show profiles 2>$null
    if (-not $raw) { return @() }
    $raw | ForEach-Object {
        if ($_ -match 'All User Profile\s*:\s*(.+)$') { $matches[1].Trim() }
    }
}

function Get-ConnectedSSID {
    $raw = netsh wlan show interfaces 2>$null
    if (-not $raw) { return $null }
    $ssid = $null; $state = $null
    foreach ($line in $raw) {
        if ($line -match '^\s*State\s*:\s*(.+)$') { $state = $matches[1].Trim() }
        if ($line -match '^\s*SSID\s*:\s*(.+)$') { $ssid = $matches[1].Trim() }
    }
    if ($state -eq 'connected') { return $ssid } else { return $null }
}

function Try-ConnectProfile {
    param($profile, $interface, $retryCount, $delay, $connectWait)
    for ($i = 1; $i -le $retryCount; $i++) {
        Write-Host "Attempt $i/$retryCount -> connecting to profile '$profile' on interface '$interface'..."
        # Use netsh to connect
        $cmd = "netsh wlan connect name=`"$profile`" interface=`"$interface`""
        $out = Invoke-Expression $cmd 2>&1
        Start-Sleep -Seconds 1

        $stopwatch = [diagnostics.stopwatch]::StartNew()
        while ($stopwatch.Elapsed.TotalSeconds -lt $connectWait) {
            $connected = Get-ConnectedSSID
            if ($connected -and $connected -eq $profile) {
                Write-Host "Connected to '$profile'." -ForegroundColor Green
                return $true
            }
            Start-Sleep -Seconds 1
        }
        Write-Host "Attempt $i failed to connect to '$profile'." -ForegroundColor Yellow
        if ($i -lt $retryCount) { Start-Sleep -Seconds $delay }
    }
    return $false
}

# --- main ---
if (-not ([bool](net session 2>$null))) {
    # Not necessarily fatal; checking typical admin requirement message.
    # We won't force-check admin; we just warn.
    Write-Warning "For best results run PowerShell as Administrator."
}

$interface = Get-WlanInterfaceName
if (-not $interface) {
    Write-Error "No wireless interface found (or 'netsh wlan show interfaces' returned nothing). Exiting."
    exit 2
}

$profiles = Get-SavedProfiles
if ($profiles.Count -eq 0) {
    Write-Error "No saved Wi‑Fi profiles found. Exiting."
    exit 3
}

$targets = @()
if ($ProfileName) {
    if ($profiles -contains $ProfileName) {
        $targets = ,$ProfileName
    } else {
        Write-Error "Profile '$ProfileName' not found among saved profiles."
        Write-Host "Available profiles:" -ForegroundColor Cyan
        $profiles | ForEach-Object { Write-Host "  $_" }
        exit 4
    }
} elseif ($TryAny) {
    # try all saved profiles in same order listed by netsh
    $targets = $profiles
} else {
    Write-Host "No -ProfileName or -TryAny given. Defaulting to trying the first saved profile."
    $targets = $profiles[0]
}

$success = $false
foreach ($p in $targets) {
    if (Try-ConnectProfile -profile $p -interface $interface -retryCount $RetryCount -delay $DelayBetweenSeconds -connectWait $ConnectWaitSeconds) {
        $success = $true
        break
    } else {
        Write-Host "Failed to connect to profile '$p' after retries." -ForegroundColor Red
    }
}

if ($success) {
    Write-Host "Done: connected." -ForegroundColor Green
    exit 0
} else {
    Write-Error "Unable to connect to any attempted saved profile."
    exit 1
}
