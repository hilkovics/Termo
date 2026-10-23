param([string]$Path)
$fs = [IO.File]::OpenRead($Path)
$br = New-Object IO.BinaryReader($fs)
"size: {0:N1} MB" -f ($fs.Length / 1MB)
$bo = [Text.Encoding]::ASCII.GetString($br.ReadBytes(2))
if ($bo -ne 'II') { "byte order $bo (big-endian not handled)"; return }
$magic = $br.ReadUInt16()
$big = $magic -eq 43
if ($big) { [void]$br.ReadUInt16(); [void]$br.ReadUInt16(); $ifd = $br.ReadUInt64() } else { $ifd = $br.ReadUInt32() }
"format: " + $(if ($big) { 'BigTIFF' } else { 'TIFF' })
$names = @{256='ImageWidth';257='ImageLength';258='BitsPerSample';259='Compression';262='Photometric';270='ImageDescription';271='Make';272='Model';273='StripOffsets';277='SamplesPerPixel';278='RowsPerStrip';284='PlanarConfig';305='Software';306='DateTime';317='Predictor';320='ColorMap';322='TileWidth';323='TileLength';338='ExtraSamples';339='SampleFormat';700='XMP';33550='ModelPixelScale';33922='ModelTiepoint';34264='ModelTransformation';34665='ExifIFD';34735='GeoKeyDirectory';34736='GeoDoubleParams';34737='GeoAsciiParams';34853='GPSIFD';42112='GDAL_METADATA';42113='GDAL_NODATA'}
$sizes = @{1=1;2=1;3=2;4=4;5=8;6=1;7=1;8=2;9=4;10=8;11=4;12=8;16=8;17=8;18=8}
$n = 0
while ($ifd -ne 0 -and $n -lt 3) {
  $n++
  $fs.Position = [int64]$ifd
  $cnt = if ($big) { $br.ReadUInt64() } else { $br.ReadUInt16() }
  "---- IFD $n ($cnt tags)"
  $entries = @()
  for ($i = 0; $i -lt $cnt; $i++) {
    $tag = $br.ReadUInt16(); $type = $br.ReadUInt16()
    $count = if ($big) { $br.ReadUInt64() } else { $br.ReadUInt32() }
    $valPos = $fs.Position
    $raw = if ($big) { $br.ReadUInt64() } else { $br.ReadUInt32() }
    $entries += [pscustomobject]@{tag=$tag;type=$type;count=$count;valPos=$valPos;raw=$raw}
  }
  $next = if ($big) { $br.ReadUInt64() } else { $br.ReadUInt32() }
  foreach ($e in $entries) {
    $sz = $sizes[[int]$e.type]; if (-not $sz) { $sz = 1 }
    $total = $sz * $e.count
    $inline = if ($big) { 8 } else { 4 }
    $off = if ($total -le $inline) { $e.valPos } else { [int64]$e.raw }
    $name = if ($names[[int]$e.tag]) { $names[[int]$e.tag] } else { "tag$($e.tag)" }
    $show = [math]::Min([int64]$e.count, 40)
    if ($e.tag -in 273,279,324,325) { "{0}: count {1}" -f $name, $e.count; continue }
    $fs.Position = $off
    $vals = switch ([int]$e.type) {
      2 { $s = [Text.Encoding]::UTF8.GetString($br.ReadBytes([int][math]::Min($e.count, 4000))); ,($s.TrimEnd([char]0)) }
      7 { $s = [Text.Encoding]::UTF8.GetString($br.ReadBytes([int][math]::Min($e.count, 4000))); ,($s) }
      1 { 1..$show | % { $br.ReadByte() } }
      3 { 1..$show | % { $br.ReadUInt16() } }
      4 { 1..$show | % { $br.ReadUInt32() } }
      8 { 1..$show | % { $br.ReadInt16() } }
      9 { 1..$show | % { $br.ReadInt32() } }
      5 { 1..$show | % { "{0}/{1}" -f $br.ReadUInt32(), $br.ReadUInt32() } }
      11 { 1..$show | % { $br.ReadSingle() } }
      12 { 1..$show | % { $br.ReadDouble().ToString([cultureinfo]::InvariantCulture) } }
      16 { 1..$show | % { $br.ReadUInt64() } }
      default { "type $($e.type)" }
    }
    "{0} (n={1}): {2}" -f $name, $e.count, (($vals | % { "$_" }) -join ', ')
  }
  $ifd = $next
}
$fs.Close()
