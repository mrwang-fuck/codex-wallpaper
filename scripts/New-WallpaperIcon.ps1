$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot=Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) 'app\assets'
[void][IO.Directory]::CreateDirectory($assetRoot)
function New-RoundedRectangle([single]$X,[single]$Y,[single]$Width,[single]$Height,[single]$Radius) {
    $shape=New-Object Drawing.Drawing2D.GraphicsPath
    $diameter=2*$Radius
    $shape.AddArc($X,$Y,$diameter,$diameter,180,90)
    $shape.AddArc($X+$Width-$diameter,$Y,$diameter,$diameter,270,90)
    $shape.AddArc($X+$Width-$diameter,$Y+$Height-$diameter,$diameter,$diameter,0,90)
    $shape.AddArc($X,$Y+$Height-$diameter,$diameter,$diameter,90,90)
    $shape.CloseFigure()
    return ,$shape
}
$canvas=New-Object Drawing.Bitmap 256,256
$graphics=[Drawing.Graphics]::FromImage($canvas)
$graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([Drawing.Color]::Transparent)
$tile=New-RoundedRectangle 6 6 244 244 52
$gradient=[Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Rectangle]::new(0,0,256,256),[Drawing.Color]::FromArgb(30,49,112),[Drawing.Color]::FromArgb(112,73,218),45)
$graphics.FillPath($gradient,$tile)
$frame=New-RoundedRectangle 37 43 181 143 19
$frameBrush=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(30,255,255,255))
$framePen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(235,239,248,255),8)
$graphics.FillPath($frameBrush,$frame)
$graphics.SetClip($frame)
$moon=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(159,235,255))
$graphics.FillEllipse($moon,163,68,25,25)
$backMountain=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(75,169,223))
$frontMountain=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(178,238,245))
$graphics.FillPolygon($backMountain,[Drawing.Point[]]@([Drawing.Point]::new(31,181),[Drawing.Point]::new(101,95),[Drawing.Point]::new(173,181)))
$graphics.FillPolygon($frontMountain,[Drawing.Point[]]@([Drawing.Point]::new(95,188),[Drawing.Point]::new(165,118),[Drawing.Point]::new(231,188)))
$graphics.ResetClip()
$graphics.DrawPath($framePen,$frame)
$shadow=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(55,13,24,57))
$graphics.FillEllipse($shadow,146,151,92,92)
$graphics.FillEllipse([Drawing.Brushes]::White,146,146,90,90)
$sliderPen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(92,77,190),6)
$sliderPen.StartCap=[Drawing.Drawing2D.LineCap]::Round;$sliderPen.EndCap=[Drawing.Drawing2D.LineCap]::Round
foreach($row in @(170,191,212)) {$graphics.DrawLine($sliderPen,164,$row,218,$row)}
$knob=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(92,77,190))
foreach($point in @(@(179,170),@(204,191),@(188,212))) {$graphics.FillEllipse($knob,$point[0]-7,$point[1]-7,14,14)}
$canvas.Save((Join-Path $assetRoot 'wallpaper-settings.png'),[Drawing.Imaging.ImageFormat]::Png)
$images=New-Object 'Collections.Generic.List[byte[]]'
$sizes=@(16,24,32,48,64,128,256)
foreach($size in $sizes) {
    $small=New-Object Drawing.Bitmap $size,$size
    $drawing=[Drawing.Graphics]::FromImage($small)
    $drawing.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $drawing.DrawImage($canvas,0,0,$size,$size)
    $stream=New-Object IO.MemoryStream
    $small.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
    $images.Add($stream.ToArray())
    $stream.Dispose();$drawing.Dispose();$small.Dispose()
}
$file=[IO.File]::Create((Join-Path $assetRoot 'wallpaper-settings.ico'))
$writer=New-Object IO.BinaryWriter $file
try {
    $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$sizes.Count)
    $offset=6+16*$sizes.Count
    for($index=0;$index -lt $sizes.Count;$index++) {
        $dimension=if($sizes[$index] -eq 256) {0} else {$sizes[$index]}
        $writer.Write([byte]$dimension);$writer.Write([byte]$dimension);$writer.Write([byte]0);$writer.Write([byte]0)
        $writer.Write([uint16]1);$writer.Write([uint16]32);$writer.Write([uint32]$images[$index].Length);$writer.Write([uint32]$offset)
        $offset+=$images[$index].Length
    }
    foreach($bytes in $images) {$writer.Write([byte[]]$bytes)}
} finally {
    $writer.Dispose();$graphics.Dispose();$canvas.Dispose()
    foreach($resource in @($tile,$gradient,$frame,$frameBrush,$framePen,$moon,$backMountain,$frontMountain,$shadow,$sliderPen,$knob)) {$resource.Dispose()}
}
