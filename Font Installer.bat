<# : batch part - runs the PowerShell below
@echo off
set "FONTROOT=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText('%~f0'))"
echo.
pause
exit /b
#>
# Font Installer: put this file in any folder with new fonts / zips and double-click it.
# Unzips, deletes zips, installs fonts for your user, and moves them to "already downloaded".
$ErrorActionPreference = 'Stop'
$root = $env:FONTROOT.TrimEnd('\')
$dest = Join-Path $root 'already downloaded'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type @"
using System; using System.Runtime.InteropServices;
public class FontApi {
  [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResource(string f);
  [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, UIntPtr w, IntPtr l, uint f, uint t, out UIntPtr r);
}
"@
$fontExt = '.otf', '.ttf', '.ttc'

# 1) Extract zips into a folder per zip (skip mac junk), then delete the zip
$extracted = @()
Get-ChildItem -LiteralPath $root -Filter *.zip -File | ForEach-Object {
  $name = ($_.BaseName -replace '\s*\(\d+\)$', '').Trim()
  $out = Join-Path $root $name
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $zip = [IO.Compression.ZipFile]::OpenRead($_.FullName)
  foreach ($e in $zip.Entries) {
    if ($e.FullName -like '__MACOSX*' -or $e.Name -eq '' -or $e.Name -eq '.DS_Store') { continue }
    [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $out $e.Name), $true)
  }
  $zip.Dispose()
  Remove-Item -LiteralPath $_.FullName
  $extracted += $out
  Write-Host "Extracted + deleted zip: $($_.Name)"
}

# 2) Install fonts for current user (no admin needed)
$userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
New-Item -ItemType Directory -Force -Path $userFonts | Out-Null
$reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }

$loose = Get-ChildItem -LiteralPath $root -File | Where-Object { $fontExt -contains $_.Extension.ToLower() }
$inFolders = $extracted | ForEach-Object { Get-ChildItem -LiteralPath $_ -File } | Where-Object { $fontExt -contains $_.Extension.ToLower() }
$all = @($loose) + @($inFolders)
# If a font ships as both OTF and TTF, install only the OTF
$toInstall = $all | Where-Object {
  -not ($_.Extension -ieq '.ttf' -and (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($_.FullName, '.otf'))))
}

$ok = 0; $skip = 0; $fail = 0
foreach ($f in $toInstall) {
  try {
    $target = Join-Path $userFonts $f.Name
    if ((Test-Path -LiteralPath $target) -or (Test-Path -LiteralPath (Join-Path $env:WINDIR "Fonts\$($f.Name)"))) { $skip++; Write-Host "Already installed: $($f.Name)"; continue }
    Copy-Item -LiteralPath $f.FullName -Destination $target
    $type = if ($f.Extension -ieq '.otf') { 'OpenType' } else { 'TrueType' }
    New-ItemProperty -Path $reg -Name "$($f.BaseName) ($type)" -Value $target -PropertyType String -Force | Out-Null
    [void][FontApi]::AddFontResource($target)
    $ok++; Write-Host "Installed: $($f.Name)"
  } catch { $fail++; Write-Host "FAILED: $($f.Name) - $($_.Exception.Message)" -ForegroundColor Red }
}
$r = [UIntPtr]::Zero
[void][FontApi]::SendMessageTimeout([IntPtr]0xffff, 0x1D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r)

# 3) Move installed font files / extracted font folders into "already downloaded"
function Move-NoClobber($src) {
  $name = Split-Path $src -Leaf
  $t = Join-Path $dest $name; $i = 2
  while (Test-Path -LiteralPath $t) {
    $base = [IO.Path]::GetFileNameWithoutExtension($name); $ext = [IO.Path]::GetExtension($name)
    if ((Get-Item -LiteralPath $src).PSIsContainer) { $base = $name; $ext = '' }
    $t = Join-Path $dest "$base ($i)$ext"; $i++
  }
  Move-Item -LiteralPath $src -Destination $t
}
if ($fail -eq 0) {
  $loose | ForEach-Object { Move-NoClobber $_.FullName }
  $extracted | ForEach-Object { Move-NoClobber $_ }
  Write-Host "Moved files into 'already downloaded'"
} else { Write-Host "Some installs failed - nothing moved." -ForegroundColor Yellow }

Write-Host ""
Write-Host "DONE  installed=$ok  already=$skip  failed=$fail" -ForegroundColor Green
