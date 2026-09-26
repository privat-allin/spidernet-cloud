# SpiderNet 2.0 — התקנה מקוונת (גרסה עדכנית מהענן). מופעל ע"י SpiderNet-Online-Setup.cmd (כמנהל).
# הטכנאי נכנס עם משתמש מוקד → מורידים את הגרסה מהערוץ שנבחר (רק רכיבים שהשתנו) → מתקינים ל-C:\SpiderNet
# → אופציונלי: חיבור למוקד (קוד חיבור), הצטרפות ל-NetBird (המפתח נמשך מהענן — הטכנאי לא רואה אותו),
#   וסיסמת גישה מרחוק. תיקיית data (מצלמות, אזורים, חוקים, אירועים) לעולם לא נמחקת ולא נדרסת.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, System.IO.Compression.FileSystem

$SITE = "https://privat-allin.github.io/spidernet-cloud"
$DIR = "C:\SpiderNet"
$NETBIRD_URL = "https://pkgs.netbird.io/windows/x64"

# כתובת הפרויקט והמפתח הציבורי — מאותו קובץ שהמוקד משתמש בו (ציבורי ממילא)
$cfgJs = (New-Object Net.WebClient).DownloadString("$SITE/supabase-config.js?" + [DateTime]::Now.Ticks)
$SUPA = ([regex]"url:\s*'([^']+)'").Match($cfgJs).Groups[1].Value
$ANON = ([regex]"anonKey:\s*'([^']+)'").Match($cfgJs).Groups[1].Value

# ---------------- חלון ----------------
$f = New-Object Windows.Forms.Form
$f.Text = "SpiderNet 2.0 — התקנה מקוונת"
$f.Size = New-Object Drawing.Size(560, 700)
$f.StartPosition = "CenterScreen"
$f.RightToLeft = "Yes"; $f.RightToLeftLayout = $true
$f.Font = New-Object Drawing.Font("Segoe UI", 10)
$f.FormBorderStyle = "FixedDialog"; $f.MaximizeBox = $false
$y = 14
function Add-Label($text, [int]$h = 22, $bold = $false) {
  $l = New-Object Windows.Forms.Label; $l.Text = $text; $l.Location = "16,$script:y"; $l.Size = "510,$h"
  if ($bold) { $l.Font = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold) }
  $f.Controls.Add($l); $script:y += $h; return $l
}
function Add-Box($pw = $false, [int]$h = 26, $multi = $false) {
  $t = New-Object Windows.Forms.TextBox; $t.Location = "16,$script:y"; $t.Size = "510,$h"
  if ($pw) { $t.UseSystemPasswordChar = $true }
  if ($multi) { $t.Multiline = $true; $t.ScrollBars = "Vertical" }
  $t.RightToLeft = "No"; $f.Controls.Add($t); $script:y += $h + 8; return $t
}
function Add-Check($text, $checked) {
  $c = New-Object Windows.Forms.CheckBox; $c.Text = $text; $c.Checked = $checked
  $c.Location = "16,$script:y"; $c.Size = "510,24"; $f.Controls.Add($c); $script:y += 26; return $c
}
Add-Label "כניסה עם משתמש מוקד (צוות)" 24 $true | Out-Null
Add-Label "אימייל" | Out-Null;  $email = Add-Box
Add-Label "סיסמה" | Out-Null;   $pass = Add-Box $true
Add-Label "ערוץ גרסה" | Out-Null
$chan = New-Object Windows.Forms.ComboBox; $chan.DropDownStyle = "DropDownList"; $chan.Location = "16,$y"; $chan.Size = "510,26"
[void]$chan.Items.Add("יציב (ללקוחות)"); [void]$chan.Items.Add("בדיקות (מעבדה)"); $chan.SelectedIndex = 1
$f.Controls.Add($chan); $y += 36
Add-Label "קוד חיבור למוקד (לא חובה — מהמוקד: הוספת מכשיר / ⋯ ← קוד חיבור)" | Out-Null
$code = Add-Box $false 48 $true
Add-Label "סיסמת גישה מרחוק לממשק (לא חובה, לפחות 6 תווים)" | Out-Null
$rpass = Add-Box $true
$cNb = Add-Check "הצטרף ל-NetBird (גישה מרחוק מהמוקד)" $true
$cAuto = Add-Check "הפעל את SpiderNet אוטומטית עם כניסה ל-Windows" $true
$cDesk = Add-Check "קיצור דרך בשולחן העבודה" $true
$y += 6
$btn = New-Object Windows.Forms.Button; $btn.Text = "התקן"; $btn.Location = "16,$y"; $btn.Size = "510,36"
$btn.BackColor = [Drawing.Color]::FromArgb(47, 129, 247); $btn.ForeColor = "White"; $btn.FlatStyle = "Flat"
$f.Controls.Add($btn); $y += 44
$bar = New-Object Windows.Forms.ProgressBar; $bar.Location = "16,$y"; $bar.Size = "510,16"; $f.Controls.Add($bar); $y += 22
$log = New-Object Windows.Forms.TextBox; $log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = "Vertical"
$log.Location = "16,$y"; $log.Size = "510,120"; $f.Controls.Add($log)

function Say($msg) { $log.AppendText("$msg`r`n"); [Windows.Forms.Application]::DoEvents() }
function Pump { [Windows.Forms.Application]::DoEvents() }

# ---------------- ענן ----------------
$script:token = ""
function Api($method, $path, $body = $null, $auth = $true) {
  $h = @{ apikey = $ANON }
  if ($auth) { $h.Authorization = "Bearer $script:token" }
  $prm = @{ Method = $method; Uri = "$SUPA$path"; Headers = $h; ContentType = "application/json; charset=utf-8" }
  if ($body -ne $null) { $prm.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress)) }
  return Invoke-RestMethod @prm
}
function Get-Object($path, $out) {
  # curl.exe (מובנה ב-Windows 10+) — מהיר, ורץ ברקע כדי שהחלון לא ייתקע
  $p = Start-Process -FilePath "curl.exe" -NoNewWindow -PassThru -ArgumentList @(
    "-f", "-sS", "-L", "--retry", "3", "-o", "`"$out`"",
    "-H", "`"apikey: $ANON`"", "-H", "`"Authorization: Bearer $script:token`"",
    "`"$SUPA/storage/v1/object/authenticated/releases/$path`"")
  while (-not $p.HasExited) { Start-Sleep -Milliseconds 150; Pump }
  if ($p.ExitCode -ne 0) { throw "הורדה נכשלה: $path (curl $($p.ExitCode))" }
}

function Install-Component($c, $tmp) {
  $zip = Join-Path $tmp "$($c.name).zip"
  $fs = [IO.File]::Create($zip)
  try {
    $i = 0
    foreach ($part in $c.parts) {
      $i++; Say "  מוריד $($c.name) — חלק $i מתוך $($c.parts.Count)..."
      $pf = Join-Path $tmp "part.bin"; Get-Object $part $pf
      $bytes = [IO.File]::ReadAllBytes($pf); $fs.Write($bytes, 0, $bytes.Length); Remove-Item $pf
    }
  } finally { $fs.Close() }
  $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
  if ($hash -ne $c.sha256) { throw "הקובץ שהורד פגום ($($c.name)) — נסה שוב" }
  Say "  מתקין $($c.name)..."
  # מחליפים רק את קבצי התוכנה של הרכיב — data לא נגעים בו
  $targets = @{ runtime = @("python", "licenses", "redist"); models = @("assets"); app = @("app", "web", "SpiderNet.bat", "stop.bat") }
  foreach ($t in $targets[$c.name]) { $p = Join-Path $DIR $t; if (Test-Path $p) { Remove-Item $p -Recurse -Force } }
  [IO.Compression.ZipFile]::ExtractToDirectory($zip, $DIR)
  Remove-Item $zip
}

function Shortcut($path, $target, $icon) {
  $s = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
  $s.TargetPath = $target; $s.WorkingDirectory = $DIR; $s.IconLocation = $icon; $s.Save()
}

$script:done = $false
$btn.Add_Click({
  if ($script:done) { $f.Close(); return }
  $btn.Enabled = $false; $log.Clear(); $bar.Value = 0
  try {
    # 1) כניסה
    Say "מתחבר לענן..."
    $r = Api "POST" "/auth/v1/token?grant_type=password" @{ email = $email.Text.Trim(); password = $pass.Text } $false
    $script:token = $r.access_token
    $staff = Api "GET" "/rest/v1/staff?select=user_id"
    if (-not $staff -or @($staff).Count -eq 0) { throw "המשתמש הזה אינו משתמש מוקד — אין הרשאת התקנה" }
    $bar.Value = 5

    # 2) הגרסה
    $ch = @("stable", "beta")[$chan.SelectedIndex]
    $tmp = Join-Path $env:TEMP "spidernet-setup"; New-Item -ItemType Directory -Force $tmp | Out-Null
    Get-Object "channels/$ch.json" (Join-Path $tmp "m.json")
    $m = Get-Content (Join-Path $tmp "m.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    Say "גרסה $($m.version) (ערוץ $ch)"; if ($m.notes) { Say "  $($m.notes)" }

    # 3) עצירת שרת קיים (שדרוג) והורדת רכיבים שהשתנו בלבד
    New-Item -ItemType Directory -Force $DIR | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $DIR "data") | Out-Null
    if (Test-Path "$DIR\stop.bat") { Say "עוצר את SpiderNet הקיים..."; & cmd /c "`"$DIR\stop.bat`"" | Out-Null }
    $stateFile = Join-Path $DIR "install-state.json"
    $state = @{}
    if (Test-Path $stateFile) { (Get-Content $stateFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value } }
    $names = @("runtime", "models", "app"); $n = 0
    foreach ($name in $names) {
      $c = $m.components.$name
      if ($state[$name] -eq $c.id -and (Test-Path (Join-Path $DIR @{runtime="python";models="assets";app="app"}[$name]))) {
        Say "$name — מעודכן, מדלג"
      } else {
        Say "$name ($([math]::Round($c.size / 1MB)) MB)"
        Install-Component $c $tmp
        $state[$name] = $c.id
        ($state | ConvertTo-Json) | Set-Content $stateFile -Encoding UTF8
      }
      $n++; $bar.Value = 5 + [int](70 * $n / $names.Count)
    }
    (@{ version = $m.version; channel = $ch; installed = (Get-Date -Format "yyyy-MM-dd HH:mm") } | ConvertTo-Json) |
      Set-Content (Join-Path $DIR "version.json") -Encoding UTF8
    & icacls $DIR /grant "*S-1-5-32-545:(OI)(CI)M" /T /C /Q | Out-Null     # משתמש רגיל כותב הגדרות ואירועים

    # 4) רכיבי מיקרוסופט, קיצורי דרך, חומת אש
    $vc = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
    if (-not $vc -or $vc.Installed -ne 1) {
      Say "מתקין רכיבי Microsoft Visual C++..."
      $p = Start-Process "$DIR\redist\vc_redist.x64.exe" -ArgumentList "/install /quiet /norestart" -PassThru
      while (-not $p.HasExited) { Start-Sleep -Milliseconds 200; Pump }
    }
    $ico = "$DIR\assets\spidernet.ico"
    $menu = Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "SpiderNet 2.0"
    New-Item -ItemType Directory -Force $menu | Out-Null
    Shortcut "$menu\SpiderNet 2.0.lnk" "$DIR\SpiderNet.bat" $ico
    Shortcut "$menu\עצירת SpiderNet.lnk" "$DIR\stop.bat" $ico
    $desk = Join-Path ([Environment]::GetFolderPath("CommonDesktopDirectory")) "SpiderNet 2.0.lnk"
    if ($cDesk.Checked) { Shortcut $desk "$DIR\SpiderNet.bat" $ico } elseif (Test-Path $desk) { Remove-Item $desk }
    $auto = Join-Path ([Environment]::GetFolderPath("CommonStartup")) "SpiderNet 2.0.lnk"
    if ($cAuto.Checked) { Shortcut $auto "$DIR\SpiderNet.bat" $ico } elseif (Test-Path $auto) { Remove-Item $auto }
    if (-not (Get-NetFirewallRule -DisplayName "SpiderNet UI (NetBird)" -ErrorAction SilentlyContinue)) {
      New-NetFirewallRule -DisplayName "SpiderNet UI (NetBird)" -Direction Inbound -Action Allow -Protocol TCP `
        -LocalPort 8087 -RemoteAddress 100.64.0.0/10 -Profile Any | Out-Null
    }
    $bar.Value = 80

    # 5) NetBird
    if ($cNb.Checked) {
      $nb = "C:\Program Files\NetBird\netbird.exe"
      if (-not (Test-Path $nb)) {
        Say "מוריד ומתקין NetBird..."
        $exe = Join-Path $tmp "netbird-setup.exe"
        $p = Start-Process "curl.exe" -NoNewWindow -PassThru -ArgumentList @("-f", "-sS", "-L", "-o", "`"$exe`"", $NETBIRD_URL)
        while (-not $p.HasExited) { Start-Sleep -Milliseconds 200; Pump }
        $p = Start-Process $exe -ArgumentList "/S" -PassThru
        while (-not $p.HasExited) { Start-Sleep -Milliseconds 200; Pump }
        Start-Sleep 3
      }
      $st = (& $nb status 2>&1 | Out-String)
      if ($st -notmatch "Management: Connected") {
        $key = (Api "GET" "/rest/v1/app_secrets?name=eq.netbird_setup_key&select=value")[0].value
        if (-not $key) { throw "לא נמצא מפתח NetBird בענן" }
        Say "מצטרף לרשת NetBird..."
        & $nb up --setup-key $key 2>&1 | Out-Null
      }
      $ip = ((& $nb status 2>&1 | Out-String) -split "`n" | Where-Object { $_ -match "NetBird IP:" }) -replace ".*NetBird IP:\s*", ""
      Say "  NetBird: $($ip.Trim())"
    }
    $bar.Value = 88

    # 6) הפעלה (כמשתמש הרגיל, לא כמנהל) + חיבור למוקד וסיסמת גישה מרחוק
    Say "מפעיל את SpiderNet..."
    Start-Process explorer.exe "`"$DIR\SpiderNet.bat`""
    if ($code.Text.Trim() -or $rpass.Text) {
      $up = $false
      for ($i = 0; $i -lt 90 -and -not $up; $i++) {
        try { Invoke-RestMethod "http://127.0.0.1:8087/api/status" -TimeoutSec 2 | Out-Null; $up = $true } catch { Start-Sleep 1; Pump }
      }
      if (-not $up) { throw "SpiderNet לא עלה — בדוק את החלון הממוזער 'SpiderNet Server'" }
      if ($code.Text.Trim()) {
        $b = @{ code = $code.Text.Trim(); enabled = $true } | ConvertTo-Json
        $c = Invoke-RestMethod "http://127.0.0.1:8087/api/central" -Method Post -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($b))
        Say "  מוקד: $(if ($c.status -eq 'ok') { 'מחובר' } else { $c.last_error })"
      }
      if ($rpass.Text) {
        $b = @{ password = $rpass.Text; enabled = $true } | ConvertTo-Json
        Invoke-RestMethod "http://127.0.0.1:8087/api/remote" -Method Post -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($b)) | Out-Null
        Say "  גישה מרחוק: הופעלה"
      }
    }
    $bar.Value = 100
    Say "`r`nההתקנה הסתיימה — SpiderNet $($m.version)"
    $script:done = $true; $btn.Text = "סגור"; $btn.Enabled = $true
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match "400|Invalid login") { $msg = "אימייל או סיסמה שגויים" }
    Say "`r`nשגיאה: $msg"
    $btn.Enabled = $true
  }
})

[void]$f.ShowDialog()
