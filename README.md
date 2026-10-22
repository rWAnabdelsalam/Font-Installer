# Font Installer

**Stop unzipping. Start designing.**

A one-file tool for Windows that turns a messy folder of downloaded font zips into installed, organized fonts with a single double-click.

Built by a graphic designer who got tired of clicking "Install" one weight at a time.

---

## The problem

Finding the right font already takes long enough. Then you get:

- Zips inside folders inside zips
- `__MACOSX` and `.DS_Store` junk files
- Eight weights per family, each installed by hand
- A Downloads folder where you can't tell which fonts are new and which you already installed

## What it does

Put **Font Installer.bat** in a folder with your new fonts and double-click it. It will:

1. **Unzip** every `.zip` into its own folder, skipping Mac junk files and flattening nested folders
2. **Delete** the zip files once they're extracted
3. **Install** every `.otf`, `.ttf` and `.ttc` font for your Windows user, without admin rights
4. **Skip** fonts that are already installed, and if a font comes as both OTF and TTF, install only the OTF
5. **Move** the installed font files and extracted folders into an `already downloaded` subfolder
6. **Show a summary** of how many fonts were installed, skipped or failed

The installer file stays in the folder, so it's ready for the next batch.

## Usage

1. Download [`Font Installer.bat`](https://github.com/rWAnabdelsalam/Font-Installer/raw/main/Font%20Installer.bat) from this repository
2. Put it in your fonts folder, for example `D:\fonts\new fonts`
3. Download fonts into that folder, as zips or as loose font files
4. Double-click **Font Installer.bat**
5. Read the summary and press any key to close

Restart Photoshop, Illustrator, Figma or any other app that was already open to see the new fonts.

```
new fonts/
├── Font Installer.bat
├── SomeFont.zip            ← before
├── AnotherFont-Bold.otf    ← before
└── already downloaded/     ← after: everything ends up here
    ├── SomeFont/
    └── AnotherFont-Bold.otf
```

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (built into Windows, so nothing to install)

## How it works

### One file, two languages
The `.bat` file is a batch + PowerShell hybrid:

```bat
<# : batch part
@echo off
set "FONTROOT=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText('%~f0'))"
pause
exit /b
#>
```

- **cmd** reads the first line as a label, runs the batch lines, launches PowerShell on the same file, and exits before reaching the PowerShell code.
- **PowerShell** reads everything between `<#` and `#>` as a block comment and runs the rest.

`FONTROOT` holds the folder the file is in, which is why the tool works in any folder.

### Extraction
It uses .NET's `System.IO.Compression.ZipFile` to go through each archive's entries. It skips `__MACOSX` and `.DS_Store` entries and extracts the rest into one folder per zip.

### Installation (per user, no admin)
For each font, it:

1. Copies the file to `%LOCALAPPDATA%\Microsoft\Windows\Fonts`
2. Registers it under `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts` so it's still there after a restart
3. Calls `AddFontResource` (gdi32) so the font works right away
4. Sends `WM_FONTCHANGE` to all windows so open apps see the change

### Safety
- Every install is wrapped in `try/catch`. If **any** install fails, nothing gets moved, so you can see what went wrong.
- Moves never overwrite anything. If a file with the same name is already there, it gets a number, like `Font (2).otf`.
- Only zips, font files and the folders extracted from zips are touched. Other files in the folder are left alone.

## Uninstalling a font
Go to **Settings → Personalization → Fonts**, click the font, and choose **Uninstall**.

## Credits
Created by **Rwan Abdelsalam**, graphic designer and a programmer.
Built with help from [Claude](https://claude.ai) by Anthropic.

## License
Released under the [MIT License](LICENSE).
"# Font-Installer" 
