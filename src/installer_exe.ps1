$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression
$self = $env:TPSELF
$ver = '1.5.0'
$pf = $env:ProgramW6432
if (-not $pf) { $pf = $env:ProgramFiles }
$dir = Join-Path $pf 'Touch POS'
$data = Join-Path $env:ProgramData 'TouchPOS'
if ([Environment]::Is64BitOperatingSystem) { $arch = '64-bit' } else { $arch = '32-bit' }
$nl = [Environment]::NewLine

function Box($text, $buttons, $icon) {
  return [System.Windows.Forms.MessageBox]::Show($text, 'Touch POS Setup', $buttons, $icon)
}
function Find-Browser {
  $bases = @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:ProgramW6432, $env:LOCALAPPDATA)
  foreach ($b in $bases) { if ($b) { $p = Join-Path $b 'Microsoft\Edge\Application\msedge.exe'; if (Test-Path -LiteralPath $p) { return $p } } }
  foreach ($b in $bases) { if ($b) { $p = Join-Path $b 'Google\Chrome\Application\chrome.exe'; if (Test-Path -LiteralPath $p) { return $p } } }
  return $null
}
function New-Lnk($lnk, $target, $arguments, $icon, $workdir, $desc, $style) {
  $ws = New-Object -ComObject WScript.Shell
  $sc = $ws.CreateShortcut($lnk)
  $sc.TargetPath = $target
  $sc.Arguments = $arguments
  $sc.IconLocation = $icon
  $sc.WorkingDirectory = $workdir
  $sc.Description = $desc
  if ($style) { $sc.WindowStyle = $style }
  $sc.Save()
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host '  Asking Windows for permission to install...'
  Start-Process -FilePath $self -Verb RunAs
  exit 0
}
Write-Host ''
Write-Host '  ===== Touch POS setup ====='
Write-Host ('  Windows detected: ' + $arch)
$existing = $false
foreach ($v in @('Registry64', 'Registry32')) {
  try {
    $hk0 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $v)
    if ($hk0.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Uninstall\TouchPOS')) { $existing = $true }
  } catch { }
}
if (Test-Path -LiteralPath (Join-Path $dir 'app\index.html')) { $existing = $true }
if ($existing) {
  $r0 = [System.Windows.Forms.MessageBox]::Show('Touch POS is already installed on this computer.' + $nl + $nl + 'Yes = update it to this version (your data is kept)' + $nl + 'No = uninstall it' + $nl + 'Cancel = do nothing', 'Touch POS Setup', 'YesNoCancel', 'Question')
  if ($r0 -eq 'Cancel') { exit 0 }
  if ($r0 -eq 'No') {
    $un = Join-Path $dir 'uninstall.ps1'
    if (Test-Path -LiteralPath $un) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $un; exit 0 }
    foreach ($f in @('CommonDesktopDirectory', 'CommonPrograms')) {
      $p = [Environment]::GetFolderPath($f)
      foreach ($n in @('Touch POS.lnk', 'Touch POS Kiosk.lnk', 'Touch POS Fetch Pictures.lnk', 'Uninstall Touch POS.lnk')) { Remove-Item -LiteralPath (Join-Path $p $n) -Force -ErrorAction SilentlyContinue }
    }
    foreach ($v in @('Registry64', 'Registry32')) {
      try { $hk1 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $v); $hk1.DeleteSubKeyTree('Software\Microsoft\Windows\CurrentVersion\Uninstall\TouchPOS', $false) } catch { }
    }
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show('Touch POS has been removed. Your data was kept in ' + $data, 'Touch POS Setup') | Out-Null
    exit 0
  }
}
$ask = Box ('Install Touch POS for all Windows users on this computer?' + $nl + $nl + 'Program folder: ' + $dir + $nl + 'Shared data folder: ' + $data) 'OKCancel' 'Question'
if ($ask -ne 'OK') { Write-Host '  Cancelled.'; exit 0 }

try {
  Write-Host '  [1/5] Copying program files...'
  try { $hk = [IO.File]::ReadAllText((Join-Path $env:ProgramData 'TouchPOS\helper.key')).Trim(); (New-Object Net.WebClient).DownloadString('http://127.0.0.1:47615/quit?k=' + $hk) | Out-Null; Start-Sleep -Milliseconds 500 } catch { }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $text = [System.Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($self))
  $m1 = '##PAY' + 'LOAD'
  $m2 = '##PAY' + 'END'
  $a = $text.LastIndexOf($m1) + $m1.Length
  $z = $text.IndexOf($m2, $a)
  $b64 = $text.Substring($a, $z - $a) -replace '\s', ''
  $bytes = [Convert]::FromBase64String($b64)
  $ms = New-Object System.IO.MemoryStream(, $bytes)
  $zip = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
  foreach ($e in $zip.Entries) {
    if ($e.FullName.EndsWith('/')) { continue }
    $dest = Join-Path $dir ($e.FullName -replace '/', '\')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    $in = $e.Open()
    $out = [System.IO.File]::Create($dest)
    $in.CopyTo($out)
    $out.Close()
    $in.Close()
  }
  $zip.Dispose()

  Write-Host '  [2/5] Preparing the shared data folder for all users...'
  $files = Join-Path $data 'Files'
  $prof = Join-Path $data 'Profile'
  $pd = Join-Path $prof 'Default'
  New-Item -ItemType Directory -Force -Path $data | Out-Null
  New-Item -ItemType Directory -Force -Path $files | Out-Null
  New-Item -ItemType Directory -Force -Path $pd | Out-Null
  & icacls.exe $data /grant '*S-1-5-32-545:(OI)(CI)M' /T /C | Out-Null
  $pref = Join-Path $pd 'Preferences'
  try {
    $obj = @{ download = @{ default_directory = $files; prompt_for_download = $false; directory_upgrade = $true }; savefile = @{ default_directory = $files }; plugins = @{ always_open_pdf_externally = $true }; profile = @{ default_content_setting_values = @{ automatic_downloads = 1 } } }
    [IO.File]::WriteAllText($pref, ($obj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
  } catch { Write-Host '  (Browser preferences were in use and not updated. Close Touch POS and run Setup again if receipts ask where to save.)' }

  Write-Host '  [3/5] Creating shortcuts...'
  $icon = Join-Path $dir 'icon.ico'
  $launcher = Join-Path $dir 'Start-TouchPOS.cmd'
  $url = ([Uri](Join-Path $dir 'app\index.html')).AbsoluteUri
  $base = '--user-data-dir="' + $prof + '" --no-first-run --disable-features=Translate'
  $browser = Find-Browser
  $target = Join-Path $env:SystemRoot 'System32\cmd.exe'
  $argsN = '/c ""' + $launcher + '""'
  $argsK = '/c ""' + $launcher + '" kiosk"'
  $desk = [Environment]::GetFolderPath('CommonDesktopDirectory')
  $menu = [Environment]::GetFolderPath('CommonPrograms')
  New-Lnk (Join-Path $desk 'Touch POS.lnk') $target $argsN $icon $dir 'Touch POS'
  New-Lnk (Join-Path $desk 'Touch POS Kiosk.lnk') $target $argsK $icon $dir 'Touch POS (full screen kiosk)'
  New-Lnk (Join-Path $menu 'Touch POS.lnk') $target $argsN $icon $dir 'Touch POS'
  New-Lnk (Join-Path $menu 'Touch POS Kiosk.lnk') $target $argsK $icon $dir 'Touch POS (full screen kiosk)'
  New-Lnk (Join-Path $menu 'Touch POS Fetch Pictures.lnk') (Join-Path $dir 'Fetch-Photos.cmd') '' $icon $dir 'Download customer pictures from web addresses'
  New-Lnk (Join-Path $menu 'Uninstall Touch POS.lnk') (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dir 'uninstall.ps1') + '"') $icon $dir 'Uninstall Touch POS'

  Write-Host '  [4/5] Registering with Windows (Settings > Apps)...'
  if ([Environment]::Is64BitOperatingSystem) { $view = [Microsoft.Win32.RegistryView]::Registry64 } else { $view = [Microsoft.Win32.RegistryView]::Default }
  $hk = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view)
  $key = $hk.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Uninstall\TouchPOS')
  $size = [int]((Get-ChildItem -LiteralPath $dir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1KB)
  $key.SetValue('DisplayName', 'Touch POS')
  $key.SetValue('DisplayVersion', $ver)
  $key.SetValue('Publisher', 'Touch POS')
  $key.SetValue('InstallLocation', $dir)
  $key.SetValue('DisplayIcon', $icon)
  $key.SetValue('UninstallString', ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dir 'uninstall.ps1') + '"'))
  $key.SetValue('NoRemove', 0, [Microsoft.Win32.RegistryValueKind]::DWord)
  $key.SetValue('NoModify', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
  $key.SetValue('NoRepair', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
  $key.SetValue('EstimatedSize', $size, [Microsoft.Win32.RegistryValueKind]::DWord)
  $key.Close()
  if ([Environment]::Is64BitOperatingSystem) { try { $h32 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32); $h32.DeleteSubKeyTree('Software\Microsoft\Windows\CurrentVersion\Uninstall\TouchPOS', $false) } catch { } }

  Write-Host '  [5/5] Done.'
  $msg = 'Touch POS is installed.' + $nl + $nl + 'Use the Touch POS shortcut on the desktop. Start it now?'
  if (-not $browser) { $msg = 'Touch POS is installed, but Microsoft Edge or Google Chrome was not found, so it cannot start yet.' + $nl + 'Edge comes with Windows 10 and 11; install any Windows updates, then use the Touch POS shortcut.' }
  $go = Box $msg 'YesNo' 'Information'
  if ($go -eq 'Yes' -and $browser) { Start-Process -FilePath $launcher }
} catch {
  Write-Host ''
  Write-Host ('  SETUP PROBLEM: ' + $_.Exception.Message) -ForegroundColor Red
  [System.Windows.Forms.MessageBox]::Show('Setup could not finish:' + $nl + $_.Exception.Message, 'Touch POS Setup') | Out-Null
  exit 1
}
exit 0
