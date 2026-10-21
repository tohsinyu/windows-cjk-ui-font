# Step 4: replace Segoe UI Variable (Start, Settings, taskbar, Explorer toolbar...) with Sarasa stand-ins.
# The stock SegUIVar.ttf file stays in C:\Windows\Fonts; only its registry entry is swapped.
# Run in an elevated PowerShell, then restart. Undo with restore.ps1.

$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Please run this script as Administrator." }

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$src     = Join-Path $here 'variable'
$root    = Join-Path $env:ProgramData 'SegoeUI-Sarasa'
$fontKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$fontDir = Join-Path $env:WINDIR 'Fonts'
$stockName = 'Segoe UI Variable (TrueType)'

$mapFile = Join-Path $src 'registry_map.json'
if (-not (Test-Path $mapFile)) { throw "registry_map.json not found in $src" }
$map = Get-Content $mapFile -Raw | ConvertFrom-Json
$entries = @($map.PSObject.Properties)
if ($entries.Count -ne 20) { throw "Expected 20 fonts in registry_map.json, found $($entries.Count)." }
foreach ($e in $entries) { if (-not (Test-Path (Join-Path $src $e.Value))) { throw "Missing $($e.Value) in $src" } }
if (-not (Test-Path $root)) { throw "Startup task folder $root not found. Run install-autotask.ps1 first." }

# 1. Restore point.
try {
    Checkpoint-Computer -Description 'Before Segoe UI Variable -> Sarasa' -RestorePointType MODIFY_SETTINGS
    Write-Host "Restore point created."
} catch {
    Write-Warning "Could not create a restore point: $($_.Exception.Message)"
    $answer = Read-Host "Continue without a restore point? (y/N)"
    if ($answer -ne 'y') { return }
}

# 2. Remember the stock entry (once).
$backup = Join-Path $here 'variable_backup.json'
if (-not (Test-Path $backup)) {
    @{ $stockName = (Get-ItemProperty $fontKey).$stockName } | ConvertTo-Json | Set-Content $backup -Encoding UTF8
}

# 3. Copy the stand-ins into C:\Windows\Fonts.
foreach ($e in $entries) {
    $target = Join-Path $fontDir $e.Value
    if (-not (Test-Path $target)) { Copy-Item (Join-Path $src $e.Value) $target }
}

# 4. Swap the registry: drop the variable font, register the 20 static fonts.
if ($null -ne (Get-ItemProperty $fontKey).$stockName) { Remove-ItemProperty -Path $fontKey -Name $stockName }
foreach ($e in $entries) { Set-ItemProperty -Path $fontKey -Name $e.Name -Value $e.Value -Type String }
Write-Host "Segoe UI Variable now points to the Sarasa stand-ins."

# 5. Let the startup task keep this after Windows updates.
Copy-Item $mapFile (Join-Path $root 'variable_map.json') -Force
Set-Content (Join-Path $root 'variable.enabled') 'on' -Encoding ASCII
& (Join-Path $here 'install-autotask.ps1')
Write-Host ""
Write-Host "Restart the computer now."
