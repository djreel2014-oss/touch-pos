# Builds dist\Setup-TouchPOS-<version>.cmd: a cmd header, the installer script, then a base64 zip of the program files.
# The version comes from $ver in src\installer_exe.ps1, so each version gets its own installer and older ones are kept.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools\Build-Setup.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$installer = [IO.File]::ReadAllText((Join-Path $src 'installer_exe.ps1'))
if ($installer -notmatch "\`$ver = '([0-9]+\.[0-9]+\.[0-9]+)'") { throw 'Could not find the version ($ver) in installer_exe.ps1' }
$version = $Matches[1]

$core = @('app\index.html', 'app\lib\desktop-shim.js', 'app\lib\qrcode.min.js', 'app\lib\jszip.min.js', 'app\lib\pdf-lib.min.js', 'icon.ico', 'Start-TouchPOS.cmd', 'Uninstall.cmd', 'uninstall.ps1', 'README.txt')
foreach ($n in $core) { if (-not (Test-Path -LiteralPath (Join-Path $src $n))) { throw "Missing file: src\$n" } }

# Every file in src goes in, except the installer itself and test data kept in src\Data.
$files = Get-ChildItem -LiteralPath $src -Recurse -File | ForEach-Object { $_.FullName.Substring($src.Length + 1) } |
  Where-Object { $_ -ne 'installer_exe.ps1' -and $_ -notlike 'Data\*' } | Sort-Object

# Zip the program files with forward-slash entry names.
$ms = New-Object System.IO.MemoryStream
$zip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Create, $true)
foreach ($n in $files) {
  $e = $zip.CreateEntry(($n -replace '\\', '/'), [System.IO.Compression.CompressionLevel]::Optimal)
  $w = $e.Open()
  $bytes = [IO.File]::ReadAllBytes((Join-Path $src $n))
  $w.Write($bytes, 0, $bytes.Length)
  $w.Close()
}
$zip.Dispose()
$b64 = [Convert]::ToBase64String($ms.ToArray(), [Base64FormattingOptions]::InsertLineBreaks)

$header = @'
@echo off
set "TPSELF=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:TPSELF);$m='##PS'+'START';$a=$t.IndexOf($m)+$m.Length;$b=$t.IndexOf('##PS'+'END',$a);Invoke-Expression $t.Substring($a,$b-$a)"
exit /b
'@
$out = $header + "`r`n##PSSTART`r`n" + $installer.TrimEnd() + "`r`n##PSEND`r`n##PAYLOAD`r`n" + $b64 + "`r`n##PAYEND`r`n"
$target = Join-Path $dist ('Setup-TouchPOS-' + $version + '.cmd')
[IO.File]::WriteAllText($target, ($out -replace "(?<!`r)`n", "`r`n"), (New-Object System.Text.ASCIIEncoding))
Write-Host ('Built ' + $target + ' (' + $files.Count + ' files, ' + [int]((Get-Item -LiteralPath $target).Length / 1KB) + ' KB)')
