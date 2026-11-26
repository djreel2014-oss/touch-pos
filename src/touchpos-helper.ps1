# Touch POS helper: keeps the data in a SQLite database and downloads customer pictures.
# Started hidden by Start-TouchPOS.cmd. It listens on 127.0.0.1 only and needs the key from helper.key.
# Uses winsqlite3.dll, the SQLite engine built into Windows 10 and 11, so nothing extra is installed.
# It opens the Touch POS window itself once the database is ready (settings come from TP_* variables).
$ErrorActionPreference = 'Stop'
$port = 47615
if ($env:TP_PORT) { $port = [int]$env:TP_PORT }  # only for testing; the app always uses 47615
$helperVersion = '1.5.0'

$dataDir = $env:TP_DATA
if (-not $dataDir) { $dataDir = Join-Path $env:ProgramData 'TouchPOS' }
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
$keyFile = Join-Path $dataDir 'helper.key'
if (-not (Test-Path -LiteralPath $keyFile)) { [IO.File]::WriteAllText($keyFile, [guid]::NewGuid().ToString('N')) }
$key = ([IO.File]::ReadAllText($keyFile)).Trim()
$logFile = Join-Path $dataDir 'helper.log'
function Write-Log($text) { try { Add-Content -LiteralPath $logFile -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $text) } catch { } }

function Open-Window($withKey) {
  if (-not $env:TP_BR) { return }
  $url = $env:TP_URL
  if ($withKey) { $url = $url + '?k=' + $key }
  $url = $url + $env:TP_HASH
  Start-Process -FilePath $env:TP_BR -ArgumentList ('--app="' + $url + '" ' + $env:TP_ARGS)
}

# Is a helper already running? Then just open the window.
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
try { $listener.Start() } catch {
  Open-Window $true
  exit 0
}

try {
  Add-Type -AssemblyName System.Web
  Add-Type -AssemblyName System.Web.Extensions
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WinSqlite {
  const string D = "winsqlite3.dll";
  [DllImport(D, CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] public static extern int sqlite3_open16(string file, out IntPtr db);
  [DllImport(D, CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] public static extern int sqlite3_prepare16_v2(IntPtr db, string sql, int bytes, out IntPtr stmt, IntPtr tail);
  [DllImport(D, CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] public static extern int sqlite3_bind_text16(IntPtr stmt, int index, string value, int bytes, IntPtr destructor);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_bind_blob(IntPtr stmt, int index, byte[] value, int bytes, IntPtr destructor);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_bind_int64(IntPtr stmt, int index, long value);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_bind_null(IntPtr stmt, int index);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_step(IntPtr stmt);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_finalize(IntPtr stmt);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_column_count(IntPtr stmt);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_column_type(IntPtr stmt, int col);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern IntPtr sqlite3_column_text16(IntPtr stmt, int col);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern IntPtr sqlite3_column_blob(IntPtr stmt, int col);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_column_bytes(IntPtr stmt, int col);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern long sqlite3_column_int64(IntPtr stmt, int col);
  [DllImport(D, CallingConvention = CallingConvention.StdCall)] public static extern IntPtr sqlite3_errmsg16(IntPtr db);
}
'@

  $script:db = [IntPtr]::Zero
  $dbFile = Join-Path $dataDir 'touchpos.db'
  if ([WinSqlite]::sqlite3_open16($dbFile, [ref]$script:db) -ne 0) { throw ('Cannot open the database ' + $dbFile) }
  $TRANSIENT = [IntPtr](-1)

  function Invoke-Sql([string]$sql, [object[]]$params) {
    # Runs one statement. Returns rows as arrays (text as strings, blobs as byte arrays, integers as Int64).
    $st = [IntPtr]::Zero
    if ([WinSqlite]::sqlite3_prepare16_v2($script:db, $sql, -1, [ref]$st, [IntPtr]::Zero) -ne 0) {
      throw ('SQL error: ' + [Runtime.InteropServices.Marshal]::PtrToStringUni([WinSqlite]::sqlite3_errmsg16($script:db)))
    }
    try {
      $i = 1
      foreach ($p in $params) {
        if ($null -eq $p) { [void][WinSqlite]::sqlite3_bind_null($st, $i) }
        elseif ($p -is [byte[]]) { [void][WinSqlite]::sqlite3_bind_blob($st, $i, $p, $p.Length, $TRANSIENT) }
        elseif ($p -is [int] -or $p -is [long]) { [void][WinSqlite]::sqlite3_bind_int64($st, $i, [long]$p) }
        else { [void][WinSqlite]::sqlite3_bind_text16($st, $i, [string]$p, -1, $TRANSIENT) }
        $i++
      }
      $rows = New-Object System.Collections.ArrayList
      while ($true) {
        $rc = [WinSqlite]::sqlite3_step($st)
        if ($rc -eq 101) { break }
        if ($rc -ne 100) { throw ('SQL error: ' + [Runtime.InteropServices.Marshal]::PtrToStringUni([WinSqlite]::sqlite3_errmsg16($script:db))) }
        $n = [WinSqlite]::sqlite3_column_count($st)
        $row = New-Object object[] $n
        for ($c = 0; $c -lt $n; $c++) {
          switch ([WinSqlite]::sqlite3_column_type($st, $c)) {
            1 { $row[$c] = [WinSqlite]::sqlite3_column_int64($st, $c) }
            3 { $row[$c] = [Runtime.InteropServices.Marshal]::PtrToStringUni([WinSqlite]::sqlite3_column_text16($st, $c)) }
            4 {
              $len = [WinSqlite]::sqlite3_column_bytes($st, $c)
              $bytes = New-Object byte[] $len
              if ($len -gt 0) { [Runtime.InteropServices.Marshal]::Copy([WinSqlite]::sqlite3_column_blob($st, $c), $bytes, 0, $len) }
              $row[$c] = $bytes
            }
            default { $row[$c] = $null }
          }
        }
        [void]$rows.Add($row)
      }
      return , $rows
    } finally { [void][WinSqlite]::sqlite3_finalize($st) }
  }

  [void](Invoke-Sql 'PRAGMA busy_timeout=5000' @())
  [void](Invoke-Sql 'PRAGMA journal_mode=WAL' @())
  [void](Invoke-Sql 'CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)' @())
  [void](Invoke-Sql 'CREATE TABLE IF NOT EXISTS customers (id TEXT PRIMARY KEY, pos INTEGER, name TEXT, email TEXT, phone TEXT, photo_url TEXT, photo BLOB, photo_type TEXT, data TEXT NOT NULL, updated INTEGER)' @())
  [void](Invoke-Sql 'CREATE INDEX IF NOT EXISTS customers_name ON customers(name)' @())
  [void](Invoke-Sql 'CREATE INDEX IF NOT EXISTS customers_email ON customers(email)' @())
  $script:ready = $true
  Write-Log ('Helper ' + $helperVersion + ' started, database ' + $dbFile)
} catch {
  Write-Log ('Helper could not start: ' + $_.Exception.Message)
  $listener.Stop()
  Open-Window $false
  exit 1
}

$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = [int]::MaxValue
$json.RecursionLimit = 1000
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$allowedKeys = @('p', 'c', 's', 't', 'y', 'v', 'u', 'l')

function Get-Customers {
  $rows = Invoke-Sql 'SELECT data, photo, photo_type FROM customers ORDER BY pos, rowid' @()
  if ($rows.Count -eq 0) { return $null }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('[')
  $first = $true
  foreach ($r in $rows) {
    if (-not $first) { [void]$sb.Append(',') }
    $first = $false
    $photo = ''
    if ($r[1] -is [byte[]] -and $r[1].Length -gt 0) {
      $type = $r[2]; if (-not $type) { $type = 'image/jpeg' }
      $photo = 'data:' + $type + ';base64,' + [Convert]::ToBase64String($r[1])
    }
    [void]$sb.Append('{"photo":"').Append($photo).Append('"')
    $data = [string]$r[0]
    if ($data.Length -gt 2) { [void]$sb.Append(',').Append($data.Substring(1)) } else { [void]$sb.Append('}') }
  }
  [void]$sb.Append(']')
  return $sb.ToString()
}

function Set-Customers([string]$text) {
  $list = $json.DeserializeObject($text)
  if ($null -eq $list) { $list = @() }
  $now = [long]([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalMilliseconds
  [void](Invoke-Sql 'BEGIN' @())
  try {
    [void](Invoke-Sql 'CREATE TEMP TABLE IF NOT EXISTS keep_ids (id TEXT PRIMARY KEY)' @())
    [void](Invoke-Sql 'DELETE FROM keep_ids' @())
    $pos = 0
    foreach ($c in $list) {
      if (-not ($c -is [System.Collections.Generic.Dictionary[string, object]])) { continue }
      $id = [string]$c['id']
      if (-not $id) { continue }
      $photo = $null
      if ($c.ContainsKey('photo')) { $photo = $c['photo']; [void]$c.Remove('photo') }
      $name = [string]$c['name']; $email = [string]$c['email']; $phone = [string]$c['phone']; $purl = [string]$c['photoUrl']
      $data = $json.Serialize($c)
      [void](Invoke-Sql 'INSERT OR IGNORE INTO keep_ids (id) VALUES (?)' @($id))
      if ($photo -eq 'db:keep') {
        $have = Invoke-Sql 'SELECT 1 FROM customers WHERE id = ?' @($id)
        if ($have.Count -gt 0) {
          [void](Invoke-Sql 'UPDATE customers SET pos = ?, name = ?, email = ?, phone = ?, photo_url = ?, data = ?, updated = ? WHERE id = ?' @($pos, $name, $email, $phone, $purl, $data, $now, $id))
          $pos++
          continue
        }
        $photo = ''
      }
      $blob = $null; $type = $null
      if ($photo -is [string] -and $photo -match '^data:(image/[a-zA-Z0-9.+-]+);base64,(.*)$') {
        $type = $Matches[1]
        try { $blob = [Convert]::FromBase64String($Matches[2]) } catch { $blob = $null; $type = $null }
      }
      [void](Invoke-Sql 'INSERT OR REPLACE INTO customers (id, pos, name, email, phone, photo_url, photo, photo_type, data, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)' @($id, $pos, $name, $email, $phone, $purl, $blob, $type, $data, $now))
      $pos++
    }
    [void](Invoke-Sql 'DELETE FROM customers WHERE id NOT IN (SELECT id FROM keep_ids)' @())
    [void](Invoke-Sql 'COMMIT' @())
  } catch {
    try { [void](Invoke-Sql 'ROLLBACK' @()) } catch { }
    throw
  }
}

function Repair-PictureUrl([string]$u) {
  # Share links from Google Drive and Dropbox point at a web page, not the picture itself.
  if ($u -match 'drive\.google\.com/file/d/([^/?#]+)') { return 'https://drive.google.com/uc?export=download&id=' + $Matches[1] }
  if ($u -match 'drive\.google\.com/open\?id=([^&#]+)') { return 'https://drive.google.com/uc?export=download&id=' + $Matches[1] }
  if ($u -match '^https?://(www\.)?dropbox\.com/') { if ($u -match '[?&]dl=0') { return ($u -replace 'dl=0', 'dl=1') } elseif ($u -notmatch '[?&](dl|raw)=') { if ($u.Contains('?')) { return $u + '&dl=1' } else { return $u + '?dl=1' } } }
  return $u
}

function Get-Picture([string]$u) {
  if ($u -notmatch '^https?://') { throw 'Not a web address' }
  $u = Repair-PictureUrl $u
  $req = [System.Net.HttpWebRequest]::Create($u)
  $req.Timeout = 20000
  $req.ReadWriteTimeout = 20000
  $req.AllowAutoRedirect = $true
  $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) TouchPOS/' + $helperVersion
  $req.Accept = 'image/*,*/*;q=0.8'
  try { $resp = $req.GetResponse() } catch [System.Net.WebException] {
    if ($_.Exception.Response) { throw ('The site answered ' + [int]$_.Exception.Response.StatusCode) }
    throw ('Could not reach the site: ' + $_.Exception.Message)
  }
  try {
    $ct = [string]$resp.ContentType
    $in = $resp.GetResponseStream()
    $ms = New-Object System.IO.MemoryStream
    $buf = New-Object byte[] 65536
    while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
      $ms.Write($buf, 0, $n)
      if ($ms.Length -gt 20MB) { throw 'The picture is larger than 20 MB' }
    }
    $bytes = $ms.ToArray()
  } finally { $resp.Close() }
  if ($ct -match '^text/html') { throw 'That address is a web page, not a picture' }
  if ($ct -notmatch '^image/') { $ct = 'application/octet-stream' }
  return @{ type = ($ct -split ';')[0]; bytes = $bytes }
}

function Send-Reply($stream, [int]$code, [string]$type, [byte[]]$body) {
  $reason = @{ 200 = 'OK'; 204 = 'No Content'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found'; 500 = 'Server Error'; 502 = 'Bad Gateway' }[$code]
  if ($null -eq $body) { $body = New-Object byte[] 0 }
  $head = 'HTTP/1.1 ' + $code + ' ' + $reason + "`r`n" +
    'Content-Type: ' + $type + "`r`n" +
    'Content-Length: ' + $body.Length + "`r`n" +
    "Access-Control-Allow-Origin: *`r`nAccess-Control-Allow-Methods: GET, POST, OPTIONS`r`nAccess-Control-Allow-Headers: Content-Type`r`nAccess-Control-Allow-Private-Network: true`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $hb = [Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($hb, 0, $hb.Length)
  if ($body.Length) { $stream.Write($body, 0, $body.Length) }
  $stream.Flush()
}
function Send-Text($stream, [int]$code, [string]$text, [string]$type) {
  if (-not $type) { $type = 'text/plain; charset=utf-8' }
  Send-Reply $stream $code $type $utf8.GetBytes($text)
}

function Read-Request($stream) {
  $ms = New-Object System.IO.MemoryStream
  $buf = New-Object byte[] 65536
  $headEnd = -1
  while ($headEnd -lt 0) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { return $null }
    $ms.Write($buf, 0, $n)
    $all = [Text.Encoding]::GetEncoding(28591).GetString($ms.GetBuffer(), 0, [int]$ms.Length)
    $headEnd = $all.IndexOf("`r`n`r`n")
    if ($headEnd -lt 0 -and $ms.Length -gt 65536) { return $null }
  }
  $lines = $all.Substring(0, $headEnd) -split "`r`n"
  $first = $lines[0] -split ' '
  $len = 0
  foreach ($l in $lines) { if ($l -match '^Content-Length:\s*(\d+)') { $len = [int]$Matches[1] } }
  $start = $headEnd + 4
  while ($ms.Length - $start -lt $len) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { break }
    $ms.Write($buf, 0, $n)
  }
  $body = $utf8.GetString($ms.GetBuffer(), $start, [Math]::Min($len, [int]$ms.Length - $start))
  $uri = [Uri]('http://127.0.0.1' + $first[1])
  return @{ method = $first[0]; path = $uri.AbsolutePath; query = [System.Web.HttpUtility]::ParseQueryString($uri.Query); body = $body }
}

function Invoke-Request($stream, $r) {
  if ($r.method -eq 'OPTIONS') { Send-Reply $stream 204 'text/plain' $null; return }
  if ($r.path -eq '/ping') { Send-Text $stream 200 ('{"app":"touchpos","version":"' + $helperVersion + '"}') 'application/json'; return }
  if ($r.query['k'] -ne $key) { Send-Text $stream 403 'Wrong key'; return }
  switch ($r.path) {
    '/status' {
      $kv = (Invoke-Sql 'SELECT COUNT(*) FROM kv' @())[0][0]
      $cu = (Invoke-Sql 'SELECT COUNT(*) FROM customers' @())[0][0]
      $ph = (Invoke-Sql 'SELECT COUNT(*) FROM customers WHERE photo IS NOT NULL' @())[0][0]
      Send-Text $stream 200 ('{"kv":' + $kv + ',"customers":' + $cu + ',"photos":' + $ph + ',"file":' + $json.Serialize($dbFile) + '}') 'application/json'
    }
    '/get' {
      $n = $r.query['n']
      if ($allowedKeys -notcontains $n) { Send-Text $stream 400 'Unknown key'; return }
      if ($n -eq 'c') { $v = Get-Customers }
      else { $rows = Invoke-Sql 'SELECT v FROM kv WHERE k = ?' @($n); $v = $null; if ($rows.Count) { $v = $rows[0][0] } }
      if ($null -eq $v) { Send-Text $stream 404 'None' } else { Send-Text $stream 200 $v 'application/json' }
    }
    '/set' {
      $n = $r.query['n']
      if ($allowedKeys -notcontains $n) { Send-Text $stream 400 'Unknown key'; return }
      if ($n -eq 'c') { Set-Customers $r.body } else { [void](Invoke-Sql 'INSERT OR REPLACE INTO kv (k, v) VALUES (?, ?)' @($n, $r.body)) }
      Send-Text $stream 200 'Saved'
    }
    '/clear' {
      [void](Invoke-Sql 'DELETE FROM kv' @())
      [void](Invoke-Sql 'DELETE FROM customers' @())
      Write-Log 'All data erased from the app'
      Send-Text $stream 200 'Cleared'
    }
    '/fetch' {
      try { $p = Get-Picture ([string]$r.query['url']); Send-Reply $stream 200 $p.type $p.bytes }
      catch { Send-Text $stream 502 $_.Exception.Message }
    }
    '/quit' { Send-Text $stream 200 'Bye'; $script:running = $false }
    default { Send-Text $stream 404 'Not found' }
  }
}

Open-Window $true
$script:running = $true
while ($script:running) {
  if (-not $listener.Pending()) { Start-Sleep -Milliseconds 15; continue }
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $stream.ReadTimeout = 15000
    $r = Read-Request $stream
    if ($r) {
      try { Invoke-Request $stream $r }
      catch { Write-Log ('Request ' + $r.path + ' failed: ' + $_.Exception.Message); try { Send-Text $stream 500 $_.Exception.Message } catch { } }
    }
  } catch { } finally { $client.Close() }
}
$listener.Stop()
Write-Log 'Helper stopped'
