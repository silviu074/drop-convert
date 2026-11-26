# Draws the orange bubble (same look as the app) at several sizes and packs them into app.ico.
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
$pngs = @()
foreach ($size in 256, 64, 48, 32, 16) {
  $dv = New-Object System.Windows.Media.DrawingVisual
  $dc = $dv.RenderOpen()
  $brush = New-Object System.Windows.Media.LinearGradientBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFB347")), ([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFF5E62")), 45
  $r = $size / 2
  $dc.DrawEllipse($brush, $null, (New-Object System.Windows.Point $r, $r), $r * 0.96, $r * 0.96)
  $text = New-Object System.Windows.Media.FormattedText ([string][char]0x21C4), ([Globalization.CultureInfo]::InvariantCulture), ([System.Windows.FlowDirection]::LeftToRight), (New-Object System.Windows.Media.Typeface "Segoe UI Bold"), ($size * 0.55), ([System.Windows.Media.Brushes]::White), 1.0
  $dc.DrawText($text, (New-Object System.Windows.Point ($r - $text.Width / 2), ($r - $text.Height / 2 - $size * 0.03)))
  $dc.Close()
  $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap $size, $size, 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
  $bmp.Render($dv)
  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
  $ms = New-Object System.IO.MemoryStream
  $enc.Save($ms)
  $pngs += , @($size, $ms.ToArray())
}
# ICO file: header, one directory entry per size, then the PNG data
$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $out
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$pngs.Count)
$offset = 6 + 16 * $pngs.Count
foreach ($p in $pngs) {
  $s = if ($p[0] -ge 256) { 0 } else { $p[0] }
  $w.Write([byte]$s); $w.Write([byte]$s); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$p[1].Length); $w.Write([uint32]$offset)
  $offset += $p[1].Length
}
foreach ($p in $pngs) { $w.Write($p[1]) }
[System.IO.File]::WriteAllBytes("$PSScriptRoot\app.ico", $out.ToArray())
