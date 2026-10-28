param([string]$Csv, [string]$Template, [string]$Out, [string[]]$Extra = @(), [string]$TempGrid = '')
$inv = [cultureinfo]::InvariantCulture
# záznam letu z CSV alebo XLSX (prvý hárok, prvý riadok = hlavička); čas zjednotený na yyyy/MM/dd HH:mm:ss
function Import-Flight([string]$Path) {
  if ($Path -notlike '*.xlsx') { return Import-Csv $Path }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path))
  try {
    $read = { param($n) $e = $zip.GetEntry($n); if (-not $e) { return $null }; $r = New-Object IO.StreamReader($e.Open()); try { [xml]$r.ReadToEnd() } finally { $r.Close() } }
    $ss = @(); $sst = & $read 'xl/sharedStrings.xml'
    if ($sst) { foreach ($si in $sst.sst.si) { $ss += ($si.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText }) -join '' } }
    $sheet = & $read 'xl/worksheets/sheet1.xml'
    $head = $null
    foreach ($row in $sheet.worksheet.sheetData.row) {
      $vals = @{}
      foreach ($c in $row.c) {
        $v = $c.v; if ($c.t -eq 's') { $v = $ss[[int]$v] } elseif ($c.t -eq 'inlineStr') { $v = $c.is.InnerText }
        $vals[($c.r -replace '\d', '')] = "$v"
      }
      if (-not $head) { $head = $vals; continue }
      $o = [ordered]@{}
      foreach ($k in $head.Keys) { $o[$head[$k]] = $vals[$k] }
      $o.time = $o.time -replace '-', '/'
      [pscustomobject]$o
    }
  } finally { $zip.Dispose() }
}
$rows = Import-Flight $Csv
$t0 = [datetime]::ParseExact($rows[0].time, 'yyyy/MM/dd HH:mm:ss', $inv)
$sb = New-Object System.Text.StringBuilder
foreach ($r in $rows) {
  $t = ([datetime]::ParseExact($r.time, 'yyyy/MM/dd HH:mm:ss', $inv) - $t0).TotalSeconds
  $photo = if ($r.fileName) { '"' + $r.fileName + '"' } else { '0' }
  [void]$sb.Append("[$t,$($r.uav_latitude),$($r.uav_longitude),$($r.methane_concentration),$($r.'relative_altitude(m)'),$($r.'speed(m/s)'),$($r.'distance(m)'),$($r.'windSpeed(m/s)'),""$($r.windDirection)"",$($r.light_intensity),$($r.uav_yaw),$($r.gimbal_pitch),$photo],`n")
}
$data = '{"start":"' + $rows[0].time + '","end":"' + $rows[-1].time + '","id":"' + $rows[0].data_id + '","rows":[' + $sb.ToString().TrimEnd(",`n") + ']}'
# ďalšie záznamy: len body s nameraným CH4
$extra = foreach ($x in $Extra) {
  $xr = Import-Flight $x
  $pts = foreach ($r in $xr) {
    if ([double]::Parse($r.methane_concentration, $inv) -le 0) { continue }
    $photo = if ($r.fileName) { '"' + $r.fileName + '"' } else { '0' }
    "[$($r.uav_latitude),$($r.uav_longitude),$($r.methane_concentration),$($r.'relative_altitude(m)'),$($r.'distance(m)'),""$($r.time.Substring(11))"",$photo]"
  }
  "extra $x : $($xr.Count) rows, $(@($pts).Count) with CH4" | Out-Host
  '{"label":"' + $xr[0].time.Substring(11) + '","rows":[' + (@($pts) -join ",`n") + ']}'
}
# mriežka polôh v palete termo snímky (z TempCode.cs), vložená ako base64
$grid = if ($TempGrid) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($TempGrid)) } else { '' }
$html = [IO.File]::ReadAllText($Template).Replace('__DATA__', $data).Replace('__EXTRA__', '[' + (@($extra) -join ',') + ']').Replace('__TEMPGRID__', $grid)
[IO.File]::WriteAllText($Out, $html, (New-Object System.Text.UTF8Encoding $false))
"written $((Get-Item $Out).Length) bytes, $($rows.Count) rows"
