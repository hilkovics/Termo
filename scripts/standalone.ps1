param([string]$Html = '.\index.html', [string]$Out = '.\dist\Skladka-Senec.html')
# Jeden súbor na zdieľanie: do hotovej mapy vloží termo snímku (data URI) a knižnicu Leaflet.
# Z internetu sa potom načítavajú už len podkladové mapy (Esri, CARTO) a písma.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent (Resolve-Path -LiteralPath $Html)
$html = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Html))
$leaflet = 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4'
$wc = New-Object Net.WebClient
$wc.Encoding = [Text.Encoding]::UTF8
$css = $wc.DownloadString("$leaflet/leaflet.min.css")
$js = $wc.DownloadString("$leaflet/leaflet.min.js")
if ($js -match '</script') { throw 'leaflet.min.js obsahuje </script>, nedá sa vložiť priamo' }
$png = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $dir 'termo-result.png')))
$parts = @(
  @("<link rel=`"stylesheet`" href=`"$leaflet/leaflet.min.css`">", "<style>`n$css`n</style>"),
  @("<script src=`"$leaflet/leaflet.min.js`"></script>", "<script>`n$js`n</script>"),
  @("L.imageOverlay('termo-result.png'", "L.imageOverlay('data:image/png;base64,$png'")
)
foreach ($p in $parts) {
  if (-not $html.Contains($p[0])) { throw "v $Html chýba: $($p[0].Substring(0, [Math]::Min(60, $p[0].Length)))" }
  $html = $html.Replace($p[0], $p[1])
}
$outFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
New-Item -ItemType Directory -Force (Split-Path -Parent $outFull) | Out-Null
[IO.File]::WriteAllText($outFull, $html, (New-Object Text.UTF8Encoding $false))
"written $Out, $([Math]::Round((Get-Item $Out).Length / 1MB, 1)) MB"
