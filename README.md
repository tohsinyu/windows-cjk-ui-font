# windows-cjk-ui-font

Replace the Windows 11 system UI font (Segoe UI, Segoe UI Variable, legacy dialog fonts) with an open-licensed CJK font such as [Sarasa UI](https://github.com/be5invis/Sarasa-Gothic), so Chinese and Japanese text in Explorer, Start, Settings, the taskbar and dialogs is rendered in one consistent font that matches the Latin text.

适用于 Windows 11 的系统界面字体替换工具集：把 Segoe UI / Segoe UI Variable 以及老式对话框字体替换为开源中日韩字体（默认更纱黑体 Sarasa UI），解决中文与英文字号不一致、同一行中文粗细混杂的问题。[中文说明见下方](#中文说明)。

## The problem

Segoe UI and Segoe UI Variable contain no CJK glyphs. When a Han character is needed, Windows walks a per-locale font fallback chain (the `FontLink` registry key). Depending on the installed languages this causes:

- CJK text that renders smaller than the adjacent Latin text (Microsoft JhengHei UI and YaHei UI have a smaller face than Segoe UI).
- Mixed fonts within a single line, because the first font in the chain lacks some characters (for example Japanese or Traditional Chinese fonts missing simplified-only characters) and those fall through to a different font.
- A fallback order that changes between Windows builds.

Windows has no setting for the system UI font, and per-app font settings do not reach Explorer, Start or Settings.

## How it works

Microsoft's font files are never modified or removed. The scripts:

1. Rebuild an open-licensed font under the names Windows already looks up: 12 `Segoe UI` weights and 20 static stand-ins for `Segoe UI Variable` (families Variable, Small, Text, Display × Light, Semilight, Regular, Semibold, Bold).
2. Copy the rebuilds into `C:\Windows\Fonts` under new file names.
3. Repoint the matching values under `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`, and point `MS Shell Dlg` / `MS Shell Dlg 2` at Segoe UI for legacy dialogs.
4. Register a SYSTEM startup task that re-applies the registry values after Windows feature updates, which reset them.

Because the replacement happens at the font-registration level, both GDI and DirectWrite/XAML applications pick it up. (`FontSubstitutes` alone only affects GDI; Explorer ignores it.)

Undo is a registry change: `restore.ps1` removes the startup task and restores the stock values.

## Requirements

- Windows 11 (tested on a 26xxx release build and a 29xxx Insider Dev build).
- Python 3.9+ with [fontTools](https://github.com/fonttools/fonttools) (`pip install --user fonttools`) to generate the fonts.
- A source font whose license permits modification, e.g. SIL OFL fonts such as Sarasa Gothic or Noto Sans CJK. Sarasa UI TC is included in `fonts/`. The OFL requires modified versions to be renamed, which is what the scripts do.
- An elevated PowerShell for the install and restore scripts.

## Usage

```powershell
# 1. Source font: use the bundled fonts/ folder (Sarasa UI TC, unhinted build for high-DPI screens),
#    or download another variant (SC, HC, J, hinted...) from
#    https://github.com/be5invis/Sarasa-Gothic/releases and extract it to <src>.

# 2. Generate the rebuilds (use -P -E, not -I, so user site-packages with fontTools stay visible).
python -P -E scripts/make_segoe.py fonts <stage> --pattern "SarasaUiTC-{style}.ttf" --tag "Sarasa-UI-TC-1.0.42"
python -P -E scripts/make_segoevar.py <stage> <stage>\variable

# 3. Verify naming, weights, style bits and CJK coverage.
python -P -E scripts/check_fonts.py <stage>
python -P -E scripts/check_fonts.py <stage>\variable

# 4. Copy scripts/ps/*.ps1 next to the generated fonts (variable\ stays a subfolder), then, in an
#    elevated PowerShell, using full paths:
Set-ExecutionPolicy -Scope Process Bypass -Force
& "C:\path\to\stage\install.ps1"            # Segoe UI + legacy dialogs + startup task, then restart
& "C:\path\to\stage\step4-variable.ps1"     # optional: Segoe UI Variable (Start, Settings, taskbar...), then restart
```

Keep the stage folder somewhere that is not cleaned automatically (not Downloads). `install.ps1` also keeps a private copy in `C:\ProgramData\SegoeUI-Sarasa` for the startup task.

Read-only status report (no admin needed): `scripts/ps/audit.ps1`.

Undo:

```powershell
& "C:\path\to\stage\restore.ps1"            # then restart
```

If the sign-in screen becomes unusable, force power-off during boot two or three times to enter Windows Recovery, then Troubleshoot → Advanced options → System Restore and pick the restore point the scripts created.

## What is not changed

- Applications that request a specific font by name (Microsoft YaHei UI, JhengHei UI, DengXian, SimSun), including many Chinese apps and Office document defaults.
- Web pages, which choose fonts through CSS. Browser default-font settings can be set to Segoe UI (Edge/Chrome `…://settings/fonts`; Firefox Settings → Fonts → Advanced).
- Emoji and icon fonts (Segoe UI Emoji, Segoe UI Symbol, Segoe Fluent Icons, Segoe MDL2 Assets) which must stay stock.
- Monospace fonts in Windows Terminal and the console.

Known trade-offs: optical sizing of Segoe UI Variable is lost (Small, Text and Display share one design); static fonts for weights the source font lacks borrow the nearest design (Semilight, Black); disk use is roughly 150 MB for the 12 fonts, 250 MB for the 20 variable stand-ins and 150 MB for the ProgramData copy.

## Licensing and fonts

- The code in this repository is MIT licensed.
- The font files in `fonts/` are **Sarasa UI TC (更纱黑体 UI, Traditional Chinese Taiwan, unhinted build), version 1.0.42**, taken unmodified from the official [Sarasa Gothic releases](https://github.com/be5invis/Sarasa-Gothic/releases). They are licensed under the SIL Open Font License 1.1; the license text is in `fonts/OFL.txt`. Sarasa Gothic is © its authors (see the upstream repository).
- The generated Segoe UI / Segoe UI Variable rebuilds are produced locally by the scripts and are not distributed here.
- This project is not affiliated with Microsoft or the authors of Sarasa Gothic.

## Safety

These scripts write to `HKLM`, `C:\Windows\Fonts` and the Task Scheduler. Read them before running, create a restore point (the scripts attempt to), and expect that a failed change can affect the sign-in screen. Provided as is, without warranty.

## Claude skill

`SKILL.md` and `docs/pitfalls.md` also work as a skill for AI coding agents (Claude Code and compatible tools): copy the repository folder into the agent's skills directory.

## 中文说明

**问题**：Segoe UI 没有汉字。需要汉字时，Windows 按语言顺序在字体回退链里找备用字体，结果是中文比英文小一号，或同一行里一部分字是一种字体、另一部分是另一种（第一个备用字体缺某些字，例如缺简体专用字，缺的字落到下一个字体）。Windows 没有修改系统界面字体的设置。

**做法**：不改动、不删除微软的字体文件。脚本把开源字体按 Windows 查找的名字重新生成（12 个 Segoe UI 字重，加 20 个 Segoe UI Variable 静态替身），复制到 `C:\Windows\Fonts`，再改注册表指向它们；老式对话框字体 `MS Shell Dlg` 也指向 Segoe UI；并注册开机任务，在系统大版本更新重置注册表后自动改回。撤销只需运行 `restore.ps1` 并重启。

**用法**：见上方 Usage。仓库的 `fonts/` 目录自带更纱黑体 UI TC（台湾繁体字形，Unhinted 版，v1.0.42，未经修改，采用 SIL OFL 1.1 许可证，许可证全文见 `fonts/OFL.txt`）；想用简体、港式或日文字形，可到更纱黑体官方发布页下载其他版本。高分屏建议选 `Unhinted` 版本。

**不会改变的**：按名字指定字体的软件（微软雅黑 UI、等线、宋体，包括很多国产软件和 Office 文档默认字体）、网页（由 CSS 决定）、Emoji 与图标字体、终端等宽字体。

**注意**：脚本会写入注册表、系统字体目录和计划任务，运行前请先阅读，并创建系统还原点。仅提供原样，不附带任何担保。

## License

MIT, see [LICENSE](LICENSE).
