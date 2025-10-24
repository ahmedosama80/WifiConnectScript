# ForceWiFiConnect.ps1

Forces Windows 10 to reconnect to saved Wi-Fi when auto-connect fails.

## Quick Use
```powershell
powershell -File "ForceWiFiConnect.ps1"
Runs the script with default options — tries to reconnect using the first saved Wi-Fi profile.

Examples
powershell
Copy code
# Connect to a specific saved profile
powershell -File "ForceWiFiConnect.ps1" -ProfileName "HomeNetwork"

# Try all saved profiles until connected
powershell -File "ForceWiFiConnect.ps1" -TryAny -RetryCount 3 -DelayBetweenSeconds 5
Parameters
Parameter	Description
-ProfileName	Name of the saved Wi-Fi profile to connect to.
-TryAny	Tries all saved Wi-Fi profiles until a connection succeeds.
-RetryCount	Number of retries per profile (default: 3).
-DelayBetweenSeconds	Delay between retries (default: 5 seconds).
-ConnectWaitSeconds	Wait time per attempt before giving up (default: 20 seconds).

Notes
Run PowerShell as Administrator for best results.

Uses built-in netsh wlan commands — no external dependencies.
