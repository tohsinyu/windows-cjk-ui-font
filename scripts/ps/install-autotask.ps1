# Install the startup task that keeps Segoe UI pointed at Sarasa after Windows updates.
# Run in an elevated PowerShell. Remove it with restore.ps1.

$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Please run this script as Administrator." }

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$root     = Join-Path $env:ProgramData 'SegoeUI-Sarasa'
$taskName = 'SegoeUI-Sarasa autocheck'

$fonts = @(Get-ChildItem (Join-Path $env:WINDIR 'Fonts') -Filter 'SegoeUI-Sarasa-*.ttf')
if ($fonts.Count -ne 12) { throw "Expected 12 SegoeUI-Sarasa-*.ttf in C:\Windows\Fonts, found $($fonts.Count). Nothing changed." }

# 1. Private copy of the script and fonts in ProgramData, so cleaning Downloads/Documents cannot break the task.
New-Item -ItemType Directory -Force (Join-Path $root 'fonts') | Out-Null
Copy-Item (Join-Path $here 'autocheck.ps1') $root -Force
foreach ($f in $fonts) { Copy-Item $f.FullName (Join-Path $root 'fonts') -Force }

# 2. The task runs as SYSTEM, so only SYSTEM and Administrators may change these files.
# Set the rule on the folder only, then make every file inherit it ((OI)(CI) flags are invalid on files).
icacls $root /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' 'Users:(OI)(CI)RX' /Q | Out-Null
icacls "$root\*" /reset /T /Q | Out-Null

# 3. Startup task.
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$root\autocheck.ps1`""
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
    -Description 'Re-points Segoe UI to the Sarasa UI TC rebuilds if a Windows update reset it. Log: C:\ProgramData\SegoeUI-Sarasa\autocheck.log' -Force | Out-Null

# 4. Run once now so the current state is checked too.
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 5
Write-Host "Task '$taskName' installed. Latest log lines:"
Get-Content (Join-Path $root 'autocheck.log') -Tail 3 -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Restart the computer only if the log says 'Re-applied'."
