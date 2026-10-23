param([string]$Path)
# Vypíše obsah všetkých hárkov XLSX ako riadky buniek (bez Excelu)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($Path)
function ReadEntry($name) {
  $e = $zip.Entries | Where-Object { $_.FullName -eq $name }
  if (-not $e) { return $null }
  $r = New-Object IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close(); [xml]$t
}
$ss = @()
$sst = ReadEntry 'xl/sharedStrings.xml'
if ($sst) { foreach ($si in $sst.sst.si) { $ss += ($si.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText }) -join '' } }
$wb = ReadEntry 'xl/workbook.xml'
$rels = ReadEntry 'xl/_rels/workbook.xml.rels'
foreach ($s in $wb.workbook.sheets.sheet) {
  $rid = $s.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  $target = ($rels.Relationships.Relationship | Where-Object { $_.Id -eq $rid }).Target
  $target = 'xl/' + ($target -replace '^/?xl/', '')
  "===== sheet: $($s.name) ($target)"
  $sh = ReadEntry $target
  foreach ($row in $sh.worksheet.sheetData.row) {
    $cells = foreach ($c in $row.c) {
      $v = $c.v
      if ($c.t -eq 's') { $v = $ss[[int]$v] } elseif ($c.t -eq 'inlineStr') { $v = $c.is.InnerText }
      "$($c.r)=$v"
    }
    $cells -join ' | '
  }
}
$zip.Dispose()
