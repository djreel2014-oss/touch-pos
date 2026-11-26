$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title = 'Choose the customer CSV or JSON file that has picture web addresses'
$dlg.Filter = 'Customer lists (*.csv;*.json)|*.csv;*.json'
if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }
$out = Join-Path $env:ProgramData 'TouchPOS\Files\CustomerPictures'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$path = $dlg.FileName
if ($path.ToLower().EndsWith('.json')) { $rows = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json } else { $rows = Import-Csv -LiteralPath $path }
if ($rows.customers) { $rows = $rows.customers }
$keys = @('photo_url', 'photoUrl', 'photourl', 'picture', 'picture_url', 'image', 'image_url', 'photo')
$ok = 0
$fail = 0
foreach ($r in @($rows)) {
  $url = $null
  foreach ($k in $keys) { $v = $r.$k; if ($v -and ($v -match '^https?://')) { $url = $v; break } }
  if (-not $url) { continue }
  $name = $r.id
  if (-not $name) { $name = $r.email }
  if (-not $name) { $name = $r.name }
  if (-not $name) { continue }
  $file = ($name -replace '[^A-Za-z0-9@._-]', '_') + '.jpg'
  try {
    Invoke-WebRequest -Uri $url -OutFile (Join-Path $out $file) -UseBasicParsing
    $ok = $ok + 1
    Write-Host ('OK    ' + $name)
  } catch {
    $fail = $fail + 1
    Write-Host ('FAILED ' + $name + '  ' + $_.Exception.Message) -ForegroundColor Red
  }
}
Write-Host ''
Write-Host ($ok.ToString() + ' pictures downloaded, ' + $fail.ToString() + ' failed.')
Write-Host ('Saved in: ' + $out)
Write-Host 'Now open Touch POS: administrator area > Import and export > Import pictures from a folder, and choose that folder.'
Start-Process explorer.exe $out
