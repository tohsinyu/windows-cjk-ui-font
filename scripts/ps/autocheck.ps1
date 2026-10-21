# Runs at startup as SYSTEM (installed by install-autotask.ps1).
# If a Windows update reset the Segoe UI registry entries, point them back at the Sarasa rebuilds.
# Missing font files are restored from the private copy next to this script.

$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$log     = Join-Path $root 'autocheck.log'
$fontKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$fontDir = Join-Path $env:WINDIR 'Fonts'

function Log($msg) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" -Encoding UTF8 }

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

# Legacy dialog fonts (file properties, old Control Panel, Run box...) -> Segoe UI, i.e. Sarasa.
$subKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes'
$subs = [ordered]@{
    'MS Shell Dlg'   = 'Segoe UI'
    'MS Shell Dlg 2' = 'Segoe UI'
}

try {
    # Keep the log small.
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 256KB) {
        Get-Content $log -Tail 200 | Set-Content $log -Encoding UTF8
    }

    foreach ($f in $map.Values) {
        $target = Join-Path $fontDir $f
        if (-not (Test-Path $target)) {
            $copy = Join-Path $root "fonts\$f"
            if (-not (Test-Path $copy)) { Log "ERROR $f missing from Fonts and from the private copy; nothing changed."; return }
            Copy-Item $copy $target
            Log "Restored missing file $f"
        }
    }

    $cur = Get-ItemProperty $fontKey
    $changed = @()
    foreach ($k in $map.Keys) {
        if ($cur.$k -ne $map[$k]) {
            Set-ItemProperty -Path $fontKey -Name $k -Value $map[$k] -Type String
            $changed += "$k ($($cur.$k) -> $($map[$k]))"
        }
    }

    $curSub = Get-ItemProperty $subKey
    foreach ($k in $subs.Keys) {
        if ($curSub.$k -ne $subs[$k]) {
            Set-ItemProperty -Path $subKey -Name $k -Value $subs[$k] -Type String
            $changed += "$k ($($curSub.$k) -> $($subs[$k]))"
        }
    }

    # Segoe UI Variable stand-ins, only once step4-variable.ps1 has turned them on.
    $varMapFile = Join-Path $root 'variable_map.json'
    if ((Test-Path (Join-Path $root 'variable.enabled')) -and (Test-Path $varMapFile)) {
        $varEntries = @((Get-Content $varMapFile -Raw | ConvertFrom-Json).PSObject.Properties)
        $varMissing = @($varEntries | Where-Object { -not (Test-Path (Join-Path $fontDir $_.Value)) })
        if ($varMissing) {
            Log "WARN Segoe UI Variable stand-ins missing from Fonts ($($varMissing.Count) files); variable part skipped."
        } else {
            $cur = Get-ItemProperty $fontKey
            if ($null -ne $cur.'Segoe UI Variable (TrueType)') {
                Remove-ItemProperty -Path $fontKey -Name 'Segoe UI Variable (TrueType)'
                $changed += "Segoe UI Variable (TrueType) removed"
            }
            foreach ($e in $varEntries) {
                if ($cur.($e.Name) -ne $e.Value) {
                    Set-ItemProperty -Path $fontKey -Name $e.Name -Value $e.Value -Type String
                    $changed += "$($e.Name) -> $($e.Value)"
                }
            }
        }
    }

    if ($changed) {
        Log "Re-applied after reset; takes full effect after the next restart: $($changed -join '; ')"
    } else {
        Log "OK, nothing to do."
    }
} catch {
    Log "ERROR $($_.Exception.Message)"
}
