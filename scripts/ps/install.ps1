# Point "Segoe UI" (12 weights) and the legacy dialog fonts at the rebuilds in this folder,
# then install the startup task that keeps it that way after Windows updates.
# Original segoeui*.ttf files are left untouched; only registry pointers change.
# Run in an elevated PowerShell, then restart. Undo with restore.ps1.

$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Please run this script as Administrator." }

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$fontKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$subKey  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes'
$fontDir = Join-Path $env:WINDIR 'Fonts'
$backup  = Join-Path $here 'registry_backup.json'

$map = [ordered]@{
    'Segoe UI (TrueType)'                  = 'SegoeUI-Sarasa-Regular.ttf'
    'Segoe UI Bold (TrueType)'             = 'SegoeUI-Sarasa-Bold.ttf'
    'Segoe UI Italic (TrueType)'           = 'SegoeUI-Sarasa-Italic.ttf'
    'Segoe UI Bold Italic (TrueType)'      = 'SegoeUI-Sarasa-BoldItalic.ttf'
    'Segoe UI Light (TrueType)'            = 'SegoeUI-Sarasa-Light.ttf'
    'Segoe UI Light Italic (TrueType)'     = 'SegoeUI-Sarasa-LightItalic.ttf'
    'Segoe UI Semilight (TrueType)'        = 'SegoeUI-Sarasa-Semilight.ttf'
    'Segoe UI Semilight Italic (TrueType)' = 'SegoeUI-Sarasa-SemilightItalic.ttf'
    'Segoe UI Semibold (TrueType)'         = 'SegoeUI-Sarasa-Semibold.ttf'
    'Segoe UI Semibold Italic (TrueType)'  = 'SegoeUI-Sarasa-SemiboldItalic.ttf'
    'Segoe UI Black (TrueType)'            = 'SegoeUI-Sarasa-Black.ttf'
    'Segoe UI Black Italic (TrueType)'     = 'SegoeUI-Sarasa-BlackItalic.ttf'
}

foreach ($f in $map.Values) {
    if (-not (Test-Path (Join-Path $here $f))) { throw "Missing $f next to this script. Nothing changed." }
}

# 1. Restore point (needs System Protection on C:).
try {
    Checkpoint-Computer -Description 'Before Segoe UI -> Sarasa' -RestorePointType MODIFY_SETTINGS
    Write-Host "Restore point created."
} catch {
    Write-Warning "Could not create a restore point: $($_.Exception.Message)"
    $answer = Read-Host "Continue without a restore point? (y/N)"
    if ($answer -ne 'y') { return }
}

# 2. Back up current values once, so a re-run never overwrites the true originals.
if (-not (Test-Path $backup)) {
    $cur = Get-ItemProperty $fontKey
    $curSub = Get-ItemProperty $subKey
    $saved = [ordered]@{}
    foreach ($k in $map.Keys) { $saved[$k] = $cur.$k }
    $saved['FontSubstitutes:MS Shell Dlg']   = $curSub.'MS Shell Dlg'
    $saved['FontSubstitutes:MS Shell Dlg 2'] = $curSub.'MS Shell Dlg 2'
    $saved | ConvertTo-Json | Set-Content $backup -Encoding UTF8
    Write-Host "Registry backed up to $backup"
}

# 3. Copy the rebuilds under their own names (originals stay in place).
foreach ($f in $map.Values) {
    $target = Join-Path $fontDir $f
    if (-not (Test-Path $target)) { Copy-Item (Join-Path $here $f) $target }
}

# 4. Repoint Segoe UI and the legacy dialog fonts.
foreach ($k in $map.Keys) {
    Set-ItemProperty -Path $fontKey -Name $k -Value $map[$k] -Type String
}
Set-ItemProperty -Path $subKey -Name 'MS Shell Dlg'   -Value 'Segoe UI' -Type String
Set-ItemProperty -Path $subKey -Name 'MS Shell Dlg 2' -Value 'Segoe UI' -Type String
Write-Host "Segoe UI and MS Shell Dlg now point to the rebuilds."

# 5. Startup task.
& (Join-Path $here 'install-autotask.ps1')
Write-Host ""
Write-Host "Restart the computer now."
