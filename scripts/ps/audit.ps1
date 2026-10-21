# Read-only report of everything that decides which font the Windows UI uses. No admin needed.

$nt = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

"=== Segoe UI / Segoe UI Variable registry targets ==="
(Get-ItemProperty "$nt\Fonts").PSObject.Properties |
    Where-Object { $_.Name -like 'Segoe UI*' -and $_.Name -notmatch 'Emoji|Symbol|Historic' } |
    ForEach-Object { "{0,-42} => {1}" -f $_.Name, $_.Value }

"=== FontSubstitutes ==="
$s = Get-ItemProperty "$nt\FontSubstitutes"
foreach ($k in 'Segoe UI', 'MS Shell Dlg', 'MS Shell Dlg 2') { "{0,-16} => [{1}]" -f $k, $s.$k }

"=== FontLink: first two fallbacks ==="
$sl = Get-ItemProperty "$nt\FontLink\SystemLink"
foreach ($f in 'Segoe UI', 'Tahoma', 'Microsoft Sans Serif') {
    $v = $sl.$f
    "{0,-22}: {1}" -f $f, $(if ($v) { ($v | Select-Object -First 2) -join ' | ' } else { '(none)' })
}

"=== WindowMetrics faces (current user) ==="
$wm = Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics'
foreach ($f in 'IconFont', 'CaptionFont', 'SmCaptionFont', 'MenuFont', 'StatusFont', 'MessageFont') {
    "{0,-14}: {1}" -f $f, [Text.Encoding]::Unicode.GetString($wm.$f[28..91]).TrimEnd([char]0)
}

"=== Rebuilt font files in C:\Windows\Fonts ==="
"SegoeUI-Sarasa-*:    " + @(Get-ChildItem "$env:WINDIR\Fonts" -Filter 'SegoeUI-Sarasa-*.ttf').Count + " (expect 12)"
"SegoeUIVar-Sarasa-*: " + @(Get-ChildItem "$env:WINDIR\Fonts" -Filter 'SegoeUIVar-Sarasa-*.ttf').Count + " (expect 20 after step 4)"

"=== Startup task ==="
$log = "$env:ProgramData\SegoeUI-Sarasa\autocheck.log"
if (Test-Path $log) { Get-Content $log -Tail 3 } else { "no log (task not installed, or not run yet)" }
"(SYSTEM tasks are invisible to non-elevated shells; check with Get-ScheduledTaskInfo from an elevated one.)"

"=== Firefox ==="
Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\*\prefs.js" -ErrorAction SilentlyContinue | ForEach-Object {
    "[$($_.Directory.Name)]"
    Select-String -Path $_.FullName -Pattern '"font\.name\.|use_document_fonts' | ForEach-Object { "  $($_.Line)" }
}

foreach ($b in @(@{ n = 'Edge'; p = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" }, @{ n = 'Chrome'; p = "$env:LOCALAPPDATA\Google\Chrome\User Data" })) {
    "=== $($b.n) ==="
    if (-not (Test-Path $b.p)) { "  no profile"; continue }
    Get-ChildItem $b.p -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'Preferences') } | ForEach-Object {
        try {
            $fonts = (Get-Content (Join-Path $_.FullName 'Preferences') -Raw -Encoding UTF8 | ConvertFrom-Json).webkit.webprefs.fonts
            "  [$($_.Name)] " + $(if ($fonts) { $fonts | ConvertTo-Json -Compress -Depth 4 } else { '(default)' })
        } catch { "  [$($_.Name)] unreadable" }
    }
}
