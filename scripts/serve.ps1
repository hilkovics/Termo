param([string]$Root, [int]$Port = 8765)
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
"Serving $Root on http://localhost:$Port/"
while ($l.IsListening) {
  $c = $l.GetContext()
  $name = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
  if (-not $name) { $name = 'index.html' }
  $p = Join-Path $Root $name
  if (Test-Path -LiteralPath $p -PathType Leaf) {
    $bytes = [IO.File]::ReadAllBytes($p)
    $c.Response.ContentType = $(if ($p -like '*.png') { 'image/png' } else { 'text/html; charset=utf-8' })
    $c.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else { $c.Response.StatusCode = 404 }
  $c.Response.Close()
}
