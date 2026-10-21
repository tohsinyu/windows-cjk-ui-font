# Known pitfalls

Each entry: symptom → cause → fix.

## Font selection and rendering

**Chinese in one line is partly thin and partly bold.**
The Segoe UI FontLink chain starts with a font that lacks some characters. Depending on the build, the chain can start with Microsoft JhengHei UI (no simplified-only characters such as 记录详资) or with Tahoma → Meiryo UI (Japanese). Missing glyphs fall through to the next font. A full-coverage CJK font registered as Segoe UI removes the dependency on the chain.

**Chinese is consistently smaller than Latin.**
Microsoft JhengHei UI and YaHei UI have a smaller face than Segoe UI at the same size. Scaling (Accessibility → Text size, Display → Scale) enlarges both equally and does not help. Only a different CJK font does.

**A Traditional Chinese font shows simplified text in mixed fonts.**
TC fonts that follow the Big5 repertoire lack simplified-only characters. Sarasa UI TC includes them (using Taiwan-style component forms), so it renders mixed content in one font.

## Registry approaches that do not work

**FontSubstitutes `Segoe UI → X` changes some apps but not Explorer.**
FontSubstitutes is GDI-only. Explorer's file list, XAML and DirectWrite applications ignore it. Rebuilding the font and repointing `HKLM\...\Fonts` works for both engines. Do not combine it with a `Segoe UI` FontSubstitutes value; leave that value absent.

**After a FontLink edit, all Chinese becomes garbage glyphs.**
The FontLink entry pointed at a font installed per-user (`%LOCALAPPDATA%\Microsoft\Windows\Fonts`, registered under HKCU). System-wide FontLink only resolves files in `C:\Windows\Fonts`. Install fonts for all users before referencing them anywhere under HKLM.

**After a restore, Chinese renders in unexpected fonts.**
The Segoe UI FontLink value had been overwritten with one junk string such as `@{value=System.Object[]; Count=15}`. In Windows PowerShell 5.1, `,$array | ConvertTo-Json` wraps arrays as `{"value":[...],"Count":n}`; reading that back and casting to `[string[]]` yields a single string. Serialize with `ConvertTo-Json -InputObject ([string[]]$chain)`, and validate on restore (count of at least 2, unwrap `.value`) before writing. To repair an existing damage, rewrite the chain from the backup's `value` list.

## Font files

**"Font in use" when uninstalling.**
The font is referenced by the current UI. Revert the registry, restart, then uninstall.

## Verification tools

**GDI+ `AddFontFile` throws "File not found" on files that exist.** The path is longer than about 260 characters. Test from a short path.

**WPF `GlyphTypeface` throws a NullReferenceException on files in `C:\Windows\Fonts`.** Test the staged copies instead, or inspect installed copies with fontTools.

**`python -I` → `No module named fontTools`.** `-I` disables user site-packages. Use `-P -E`.

**Console `UnicodeEncodeError` when printing CJK.** Set `PYTHONIOENCODING=utf-8`, and `PYTHONUTF8=1` for tools that read UTF-8 text files with the default encoding.

## Running scripts

**`.\script.ps1` is not recognized.** An elevated PowerShell starts in `C:\WINDOWS\system32`. Use the full path: `& "C:\path\to\stage\install.ps1"`.

**Staged folder disappeared.** Downloads folders are often cleaned automatically. Stage in a folder that is not. If the Documents known folder is redirected to OneDrive, `C:\Users\<name>\Documents` can be a separate, unsynced folder that Explorer's "Documents" does not show.

## Startup task

**Task exists, LastTaskResult 0x1, no log file.**
`icacls <dir> /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' ... /T` applied folder-only inheritance flags to files, which failed silently with `/Q` and left the files with an empty DACL, so even SYSTEM could not read `autocheck.ps1`. Set the ACL on the folder only, then run `icacls "<dir>\*" /reset /T` so files inherit it. Repair for an existing install: `icacls "C:\ProgramData\SegoeUI-Sarasa\*" /reset /T /Q`.

**Non-elevated shell: "task not found", or access denied reading the ProgramData script.** Expected, since SYSTEM tasks are hidden from standard tokens. Check from an elevated shell with `Get-ScheduledTaskInfo 'SegoeUI-Sarasa autocheck'`.

**Everything reverted after a Windows update.**
Feature updates and Insider flights reset `HKLM\...\Fonts`, FontSubstitutes and the FontLink order; rebuilt files in `C:\Windows\Fonts` survive. The startup task re-applies at the first boot after the update, and one more restart shows the result. Without the task, rerun `install.ps1` (and `step4-variable.ps1` if used).

## Browsers

**Web pages still use other fonts.** Pages choose fonts in CSS. Set the browser's default fonts to Segoe UI. Firefox can additionally disallow page-chosen fonts, at the cost of broken icon fonts; Chromium-based browsers have no such switch.
