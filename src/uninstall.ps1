$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
$path = $MyInvocation.MyCommand.Path
$dir = Split-Path -Parent $path
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + $path + '"')
  exit
}
$r = [System.Windows.Forms.MessageBox]::Show('Remove Touch POS from this computer?', 'Touch POS Uninstall', 'YesNo', 'Question')
if ($r -ne 'Yes') { exit }
try { $hk = [IO.File]::ReadAllText((Join-Path $env:ProgramData 'TouchPOS\helper.key')).Trim(); (New-Object Net.WebClient).DownloadString('http://127.0.0.1:47615/quit?k=' + $hk) | Out-Null; Start-Sleep -Milliseconds 500 } catch { }
$d = [System.Windows.Forms.MessageBox]::Show('Also delete ALL saved sales, customers, products and settings (the shared data folder)?' + [Environment]::NewLine + 'Choose No to keep them for a future install.', 'Touch POS Uninstall', 'YesNo', 'Warning')
foreach ($f in @('Desktop', 'CommonDesktopDirectory', 'Programs', 'CommonPrograms')) {
  $p = [Environment]::GetFolderPath($f)
  if ($p) {
    Remove-Item -LiteralPath (Join-Path $p 'Touch POS.lnk') -Force
    Remove-Item -LiteralPath (Join-Path $p 'Touch POS Kiosk.lnk') -Force
    Remove-Item -LiteralPath (Join-Path $p 'Touch POS Fetch Pictures.lnk') -Force
    Remove-Item -LiteralPath (Join-Path $p 'Uninstall Touch POS.lnk') -Force
  }
}
foreach ($v in @('Registry64', 'Registry32')) { try { $hk = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', $v); $hk.DeleteSubKeyTree('Software\Microsoft\Windows\CurrentVersion\Uninstall\TouchPOS', $false) } catch { } }
if ($d -eq 'Yes') { Remove-Item -LiteralPath (Join-Path $env:ProgramData 'TouchPOS') -Recurse -Force }
Start-Process -FilePath 'cmd.exe' -WindowStyle Hidden -ArgumentList ('/c ping 127.0.0.1 -n 4 >nul & rd /s /q "' + $dir + '"')
[System.Windows.Forms.MessageBox]::Show('Touch POS has been removed.', 'Touch POS Uninstall') | Out-Null
