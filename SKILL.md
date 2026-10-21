---
name: windows-cjk-ui-font
description: Replace the Windows 11 system UI font (Segoe UI, Segoe UI Variable, legacy MS Shell Dlg dialogs) with an open-source CJK font such as Sarasa UI (更纱黑体) or Noto Sans CJK, so Chinese/Japanese text in Explorer, Start, Settings, taskbar and dialogs matches the Latin text in size and style. Use this whenever someone reports mismatched, too-small or mixed thin/bold Chinese characters in Windows, wants to change or customize the Windows system font, asks why fonts reverted after a Windows update, or wants to undo such a change, even if Segoe UI is never mentioned.
---

# Windows CJK UI font replacement

Windows 11 renders UI text with Segoe UI / Segoe UI Variable, which contain no CJK glyphs. Han characters come from a per-locale fallback chain, so on some installs Chinese renders smaller than Latin text or in two fonts at once. Settings has no option to change this. This skill swaps the system UI fonts for registry-registered rebuilds of an open-source CJK font, fixing size, weight and consistency wherever the system font is used.

Microsoft's font files are never overwritten. Renamed copies are added under new file names and `HKLM\...\Fonts` registry values are repointed, so undo is a registry change.

## Guidelines

- **Scripts that write HKLM, `C:\Windows\Fonts`, `C:\ProgramData` or the Task Scheduler are run by the person who owns the machine**, in an elevated PowerShell. The agent prepares them and may run read-only checks, approved downloads and font generation in user-writable folders.
- **Source fonts must permit modification.** OFL fonts (Sarasa Gothic, Noto/Source Han Sans) do, and require modified versions to be renamed, which the scripts do. Sarasa UI TC (unhinted, 1.0.42) is bundled in `fonts/` with its license in `fonts/OFL.txt`.
- **Installed fonts that belong to the machine owner are left alone** unless removal is explicitly requested.
- **State the exact file, source and size before downloading** and wait for approval.
- **Stage files outside Downloads** (often cleaned automatically) and outside OneDrive-redirected Documents, e.g. `C:\Users\<name>\Documents\SegoeUI-Sarasa` (check `[Environment]::GetFolderPath('MyDocuments')`). Tell the owner the full path.

## Workflow

### 1. Audit (read-only)

Run `scripts/ps/audit.ps1` (no admin needed). It reports Segoe UI / Segoe UI Variable registry targets, FontSubstitutes, FontLink chains, WindowMetrics faces, browser font preferences and the startup task. Run it again at the end to show what changed and what is still stock.

Check the display too (`Get-CimInstance Win32_VideoController`). High-DPI panels (about 200 ppi or more, e.g. a 14" 2.8K or 4K laptop screen) suit the **Unhinted** build; 96–150 % scaling on 1080p-class panels suits the hinted build.

### 2. Choose and download the font

Default: **Sarasa UI** from `github.com/be5invis/Sarasa-Gothic/releases` (latest release via `https://api.github.com/repos/be5invis/Sarasa-Gothic/releases/latest`).

| Variant | Asset prefix | Glyph standard |
|---|---|---|
| Traditional, Taiwan | `SarasaUiTC-TTF` | Taiwan forms, still covers all simplified characters |
| Simplified | `SarasaUiSC-TTF` | Mainland forms |
| Hong Kong | `SarasaUiHC-TTF` | HK forms |
| Japanese | `SarasaUiJ-TTF` | Japanese forms |

Add `-Unhinted` for high-DPI. Download into its own new empty folder and extract with `tar -xf <archive.7z> -C <empty dir>` (Windows' bsdtar reads 7z). Expect 10 TTFs: Regular, Bold, Italic, BoldItalic, Light, LightItalic, SemiBold, SemiBoldItalic, ExtraLight, ExtraLightItalic.

### 3. Generate the rebuilds

Python plus fontTools are required (`pip install --user fonttools`). Run Python with **`-P -E`**, not `-I`: `-I` also disables user site-packages, where fontTools lives, while `-P` still keeps the extracted folder off `sys.path`.

```powershell
python -P -E scripts/make_segoe.py <extracted_dir> <stage_dir> --pattern "SarasaUiTC-{style}.ttf" --tag "Sarasa-UI-TC-<version>"
python -P -E scripts/make_segoevar.py <stage_dir> <stage_dir>\variable
python -P -E scripts/check_fonts.py <stage_dir>
python -P -E scripts/check_fonts.py <stage_dir>\variable
```

- `make_segoe.py` writes 12 `SegoeUI-Sarasa-*.ttf` covering every Segoe UI text weight in the registry (Regular, Bold, Italic, BoldItalic, Light, Semilight, Semibold, Black and their italics). Missing source weights borrow the nearest design.
- `make_segoevar.py` writes 20 `SegoeUIVar-Sarasa-*.ttf`: families `Segoe UI Variable`, `… Small`, `… Text`, `… Display` × Light/Semilight/Regular/Semibold/Bold, plus `registry_map.json`. The stock font is one variable file with 15 named instances; static stand-ins lose optical sizing but resolve every family and weight the shell requests. GDI legacy names are cut at 31 characters on purpose, matching the stock FontLink keys (`Segoe UI Variable Small Semilig`, …).
- `check_fonts.py` prints name IDs, weight class, style bits, remaining name-record languages and test-character coverage.

Verify with Windows' own engines from a short path (GDI+ fails on paths over about 260 characters; WPF `GlyphTypeface` fails on files inside `C:\Windows\Fonts`, so test the staged copies):

```powershell
Add-Type -AssemblyName System.Drawing, PresentationCore
Get-ChildItem <stage_dir>\*.ttf | % { $c=New-Object System.Drawing.Text.PrivateFontCollection; $c.AddFontFile($_.FullName); $g=New-Object Windows.Media.GlyphTypeface ([Uri]$_.FullName); "{0}  GDI={1}  DWrite={2}/{3}" -f $_.Name,$c.Families[0].Name,$g.FamilyNames['en-us'],$g.FaceNames['en-us'] }
```

Every file must report the intended family and weight in both engines before the install scripts are handed over.

### 4. Stage the scripts

Copy everything in `scripts/ps/` into the stage folder next to the 12 fonts (the `variable\` subfolder holds the 20). Syntax-check each script with `[System.Management.Automation.Language.Parser]::ParseFile`.

### 5. Run order (elevated PowerShell, each prefixed with `Set-ExecutionPolicy -Scope Process Bypass -Force;`)

1. `install.ps1`: restore point, backup, copies the 12 fonts, repoints the 12 Segoe UI values, points `MS Shell Dlg` / `MS Shell Dlg 2` at Segoe UI (legacy dialogs such as file Properties, the Run box and the old Control Panel), then installs the startup task. Restart.
2. Browsers (manual): Edge `edge://settings/fonts`, Chrome `chrome://settings/fonts` → Standard/Serif/Sans-serif = Segoe UI. Firefox Settings → Fonts → Advanced, for each of Simplified Chinese / Traditional Chinese / Latin set Serif and Sans-serif = Segoe UI. Unticking Firefox's "Allow pages to choose their own fonts" forces it everywhere but breaks icon fonts (buttons show boxes or words); explain the trade-off.
3. `step4-variable.ps1`, only after step 1 is confirmed good: restore point, copies the 20 fonts, removes the `Segoe UI Variable (TrueType)` value (the stock `SegUIVar.ttf` file stays), registers the 20, enables the variable part of the startup task. Restart. This affects Start, Settings, taskbar, notification center, Explorer's address bar, toolbar and tabs, and possibly the sign-in screen, so the recovery path below should be known before running it.

Undo everything: `restore.ps1`, then restart. It removes the startup task first (otherwise it would re-apply at next boot) and restores stock Segoe UI and Segoe UI Variable values and the stock Shell Dlg substitutes.

If the sign-in screen is unusable: force power-off during boot two or three times → Windows Recovery → Troubleshoot → Advanced options → System Restore → pick the restore point the script created.

### 6. Persistence across Windows updates

Feature updates (and every Insider Dev/Canary flight, which is an in-place upgrade) reset the Fonts registry key, FontSubstitutes and sometimes the FontLink order; the font files survive. `install-autotask.ps1` (called by `install.ps1`) copies `autocheck.ps1` and the 12 fonts into `C:\ProgramData\SegoeUI-Sarasa`, restricts that folder to SYSTEM/Administrators (Users read-only) and registers a SYSTEM startup task. `autocheck.ps1` restores missing files, re-applies reset values and logs to `C:\ProgramData\SegoeUI-Sarasa\autocheck.log`. A reset is fixed at the first boot after the update and fully visible after one more restart.

To check the task from an elevated shell: `Get-ScheduledTaskInfo 'SegoeUI-Sarasa autocheck'` (LastTaskResult 0x0) and the log. A non-elevated shell cannot see SYSTEM tasks; "task not found" there is not a failure.

## What this does not change

- Fonts that applications request by name: Microsoft YaHei UI, JhengHei UI, DengXian, SimSun. Many Chinese apps and Office document defaults keep their own fonts and are changed inside each app.
- Web pages, which choose fonts via CSS and web fonts; browser settings only affect pages that do not specify one.
- Emoji and icon fonts (Segoe UI Emoji, Segoe UI Symbol, Segoe Fluent Icons, Segoe MDL2 Assets), which must stay stock or icons break.
- Monospace fonts (Terminal, console); Sarasa Mono is a separate download.
- Optical sizing of Segoe UI Variable is lost. With Sarasa TC, simplified characters use Taiwan-style component forms.
- Disk use: about 150 MB (12 fonts) + 250 MB (20 variable stand-ins) in `C:\Windows\Fonts`, plus about 150 MB for the ProgramData copy.

## Troubleshooting

See `docs/pitfalls.md` for every failure mode documented so far, with cause and fix: per-user font installs, FontSubstitutes versus DirectWrite, corrupted FontLink chains, icacls on files, scheduled task exit code 0x1, scripts not found from `C:\WINDOWS\system32`, and more.
