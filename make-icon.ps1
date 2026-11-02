# Converts icon-source.jpg into a multi-resolution app.ico with transparent
# rounded corners. Run: powershell -ExecutionPolicy Bypass -File make-icon.ps1
Add-Type -AssemblyName System.Drawing
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = [System.Drawing.Image]::FromFile((Join-Path $dir 'icon-source.jpg'))

# Region of the rounded square inside the source artwork (slightly inset to avoid white fringe)
$crop = New-Object System.Drawing.Rectangle 190, 190, 646, 646
$radiusFrac = 0.18
$sizes = 256, 64, 48, 32, 24, 20, 16

$pngs = @()
foreach ($s in $sizes) {
    # 1. scale the cropped square
    $scaled = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($scaled)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $s, $s), $crop, 'Pixel')
    $g.Dispose()

    # 2. paint it through an anti-aliased rounded-rect mask
    $out = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $d = [Math]::Max(2, $s * $radiusFrac * 2)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc(0, 0, $d, $d, 180, 90)
    $p.AddArc($s - $d, 0, $d, $d, 270, 90)
    $p.AddArc($s - $d, $s - $d, $d, $d, 0, 90)
    $p.AddArc(0, $s - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    $brush = New-Object System.Drawing.TextureBrush $scaled
    $g.FillPath($brush, $p)
    $g.Dispose(); $brush.Dispose(); $scaled.Dispose()

    if ($s -ge 256) {
        $ms = New-Object System.IO.MemoryStream
        $out.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $data = $ms.ToArray()
    } else {
        # classic 32-bit DIB entry: header + bottom-up BGRA pixels + empty AND mask
        $ms = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter $ms
        $bw.Write([UInt32]40); $bw.Write([Int32]$s); $bw.Write([Int32]($s * 2))
        $bw.Write([UInt16]1); $bw.Write([UInt16]32); $bw.Write([UInt32]0)
        $bw.Write([UInt32]0); $bw.Write([Int32]0); $bw.Write([Int32]0)
        $bw.Write([UInt32]0); $bw.Write([UInt32]0)
        for ($y = $s - 1; $y -ge 0; $y--) {
            for ($x = 0; $x -lt $s; $x++) {
                $c = $out.GetPixel($x, $y)
                $bw.Write([byte]$c.B); $bw.Write([byte]$c.G); $bw.Write([byte]$c.R); $bw.Write([byte]$c.A)
            }
        }
        $maskRow = [Math]::Ceiling($s / 32) * 4
        $bw.Write((New-Object byte[] ($maskRow * $s)))
        $bw.Flush()
        $data = $ms.ToArray()
    }
    $out.Dispose()
    $pngs += , @($s, $data)
}
$src.Dispose()

# 3. write ICO container (PNG-compressed entries)
$fs = [System.IO.File]::Create((Join-Path $dir 'app.ico'))
$w = New-Object System.IO.BinaryWriter $fs
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$pngs.Count)
$offset = 6 + 16 * $pngs.Count
foreach ($e in $pngs) {
    $s = $e[0]; $data = $e[1]
    $b = if ($s -ge 256) { 0 } else { $s }
    $w.Write([byte]$b); $w.Write([byte]$b); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([UInt16]1); $w.Write([UInt16]32)
    $w.Write([UInt32]$data.Length); $w.Write([UInt32]$offset)
    $offset += $data.Length
}
foreach ($e in $pngs) { $w.Write($e[1]) }
$w.Close()
Write-Host "app.ico written ($($pngs.Count) sizes)"
