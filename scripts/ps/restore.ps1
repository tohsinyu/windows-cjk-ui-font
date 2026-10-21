# Point the Segoe UI registry entries back to the stock Windows 11 files
# and remove the startup autocheck task (otherwise it would switch back on the next boot).
# Run in an elevated PowerShell, then restart.

$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Please run this script as Administrator." }

$fontKey  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$taskName = 'SegoeUI-Sarasa autocheck'

$stock = [ordered]@{
    'Segoe UI (TrueType)'                  = 'segoeui.ttf'
    'Segoe UI Bold (TrueType)'             = 'segoeuib.ttf'
    'Segoe UI Italic (TrueType)'           = 'segoeuii.ttf'
    'Segoe UI Bold Italic (TrueType)'      = 'segoeuiz.ttf'
    'Segoe UI Light (TrueType)'            = 'segoeuil.ttf'
    'Segoe UI Light Italic (TrueType)'     = 'seguili.ttf'
    'Segoe UI Semilight (TrueType)'        = 'segoeuisl.ttf'
    'Segoe UI Semilight Italic (TrueType)' = 'seguisli.ttf'
    'Segoe UI Semibold (TrueType)'         = 'seguisb.ttf'
    'Segoe UI Semibold Italic (TrueType)'  = 'seguisbi.ttf'
    'Segoe UI Black (TrueType)'            = 'seguibl.ttf'
    'Segoe UI Black Italic (TrueType)'     = 'seguibli.ttf'
}

$missing = @($stock.Values | Where-Object { -not (Test-Path (Join-Path $env:WINDIR "Fonts\$_")) })
if ($missing) { throw "Stock files missing from C:\Windows\Fonts, nothing changed: $($missing -join ', ')" }

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed startup task '$taskName'."
}

foreach ($k in $stock.Keys) {
    Set-ItemProperty -Path $fontKey -Name $k -Value $stock[$k] -Type String
}

# Segoe UI Variable: drop the stand-ins, bring back the stock variable font.
$flag = Join-Path $env:ProgramData 'SegoeUI-Sarasa\variable.enabled'
if (Test-Path $flag) { Remove-Item $flag -Force }
(Get-ItemProperty $fontKey).PSObject.Properties | Where-Object { $_.Value -like 'SegoeUIVar-Sarasa-*' } | ForEach-Object {
    Remove-ItemProperty -Path $fontKey -Name $_.Name
}
if (Test-Path (Join-Path $env:WINDIR 'Fonts\SegUIVar.ttf')) {
    Set-ItemProperty -Path $fontKey -Name 'Segoe UI Variable (TrueType)' -Value 'SegUIVar.ttf' -Type String
}

# Legacy dialog fonts back to the Windows defaults.
$subKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes'
Set-ItemProperty -Path $subKey -Name 'MS Shell Dlg'   -Value 'Microsoft Sans Serif' -Type String
Set-ItemProperty -Path $subKey -Name 'MS Shell Dlg 2' -Value 'Tahoma' -Type String

Write-Host "Restored. Restart the computer."
Write-Host "Optional cleanup after restart: C:\ProgramData\SegoeUI-Sarasa and C:\Windows\Fonts\SegoeUI-Sarasa-*.ttf"
