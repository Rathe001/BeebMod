<#
scripts/make-addon-icon.ps1 (Josh 2026-10-18: "we need an icon for the
addons panel so we dont show as "?""): Art/icon.tga, the picture the
client's AddOn list shows beside BeebMod's name (## IconTexture in
BeebMod.toc).

A dark rounded square with a "B" in BeebMod's blue (the dock header's
"Beeb", 74c0fc), in Google Sans SemiBold, the dock header's own font.
Drawn four times larger and shrunk, so the curves come out smooth. A
64x64 32-bit TGA, top row first.

    powershell -ExecutionPolicy Bypass -File scripts\make-addon-icon.ps1
#>
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$Root = Split-Path -Parent $PSScriptRoot
$Size, $Scale = 64, 4
$Big = $Size * $Scale

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $Root "Art\Fonts\GoogleSans-SemiBold.ttf"))
$family = $fonts.Families[0]

$bmp = New-Object System.Drawing.Bitmap $Big, $Big, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)

# the rounded square, and a rim of the blue round it
function RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$d = $r * 2
	$p.AddArc($x, $y, $d, $d, 180, 90)
	$p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
	$p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
	$p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
	$p.CloseFigure()
	return $p
}
$inset = 2 * $Scale
$square = RoundRect $inset $inset ($Big - 2 * $inset) ($Big - 2 * $inset) (12 * $Scale)
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 13, 20, 18))), $square)
$blue = [System.Drawing.Color]::FromArgb(255, 0x74, 0xC0, 0xFC)
$g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(150, 0x74, 0xC0, 0xFC)), (2 * $Scale)), $square)

# the B, centred on its own ink rather than on the font's line
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
# (winding: the default fill leaves a hole where the letter's outlines overlap)
$path.FillMode = [System.Drawing.Drawing2D.FillMode]::Winding
$path.AddString("B", $family, [int][System.Drawing.FontStyle]::Regular, (46 * $Scale), (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
$ink = $path.GetBounds()
$m = New-Object System.Drawing.Drawing2D.Matrix
$m.Translate(($Big - $ink.Width) / 2 - $ink.X, ($Big - $ink.Height) / 2 - $ink.Y)
$path.Transform($m)
$g.FillPath((New-Object System.Drawing.SolidBrush $blue), $path)
$g.Dispose()

# shrunk to 64, then written bottom-up as BGRA with the top-left origin flag
$small = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g2 = [System.Drawing.Graphics]::FromImage($small)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g2.DrawImage($bmp, 0, 0, $Size, $Size)
$g2.Dispose(); $bmp.Dispose()

$bytes = New-Object byte[] (18 + $Size * $Size * 4)
$bytes[2] = 2
$bytes[12] = $Size; $bytes[14] = $Size
$bytes[16] = 32; $bytes[17] = 0x28
$i = 18
for ($y = 0; $y -lt $Size; $y++) {
	for ($x = 0; $x -lt $Size; $x++) {
		$c = $small.GetPixel($x, $y)
		$bytes[$i] = $c.B; $bytes[$i + 1] = $c.G; $bytes[$i + 2] = $c.R; $bytes[$i + 3] = $c.A
		$i += 4
	}
}
$small.Dispose()
$out = Join-Path $Root "Art\icon.tga"
[System.IO.File]::WriteAllBytes($out, $bytes)
Write-Host "wrote Art/icon.tga"
