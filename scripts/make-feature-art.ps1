<#
scripts/make-feature-art.ps1 (Josh 2026-09-27): the pictures of the six
features, for the first login's cards and each feature's own page.

    powershell -ExecutionPolicy Bypass -File scripts\make-feature-art.ps1 -Source <folder of screenshots>

Each is a 16:9 piece of one screenshot (taken with /bt demo on: the made-up
realm, notes, journal and party), shrunk to 455x256 and written as a 24-bit
TGA on a 512x256 canvas - a power of two each way, which every build of the
client draws - into Art/Features/<feature>.tga. The picture fills the left
455 of the 512; UI/Window.lua's W.Picture crops to it (FEATURE_ART_U).

To take new ones, change the file names and crops below: a crop is x, y,
width and height in the screenshot's own pixels, and wants to be 16:9.
#>
param(
	[Parameter(Mandatory = $true)][string]$Source
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "Art\Features"
New-Item -ItemType Directory -Force $Out | Out-Null

$PicW, $PicH, $CanvasW = 455, 256, 512
$Crops = @(
	@{ key = "dock";      file = "64.png"; x = 860;  y = 0;   w = 675; h = 380 },
	@{ key = "frames";    file = "64.png"; x = 0;    y = 0;   w = 900; h = 506 },
	@{ key = "interface"; file = "66.png"; x = 520;  y = 520; w = 780; h = 438 },
	@{ key = "census";    file = "67.png"; x = 490;  y = 250; w = 680; h = 382 },
	@{ key = "ledger";    file = "69.png"; x = 1055; y = 612; w = 480; h = 270 },
	@{ key = "menagerie"; file = "74.png"; x = 430;  y = 145; w = 760; h = 427 }
)

# an uncompressed 24-bit TGA, bottom row first, blue-green-red
function Write-Tga([System.Drawing.Bitmap]$bmp, [string]$path) {
	$bw, $bh = $bmp.Width, $bmp.Height
	$header = New-Object byte[] 18
	$header[2] = 2
	$header[12] = $bw -band 255; $header[13] = ($bw -shr 8) -band 255
	$header[14] = $bh -band 255; $header[15] = ($bh -shr 8) -band 255
	$header[16] = 24
	$rect = New-Object System.Drawing.Rectangle 0, 0, $bw, $bh
	$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
	$stride = $data.Stride
	$raw = New-Object byte[] ($stride * $bh)
	[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $raw, 0, $raw.Length)
	$bmp.UnlockBits($data)
	$pixels = New-Object byte[] ($bw * 3 * $bh)
	for ($row = 0; $row -lt $bh; $row++) {
		# the bitmap's top row is the TGA's last
		[Array]::Copy($raw, ($bh - 1 - $row) * $stride, $pixels, $row * $bw * 3, $bw * 3)
	}
	$fs = [IO.File]::Create($path)
	$fs.Write($header, 0, 18)
	$fs.Write($pixels, 0, $pixels.Length)
	$fs.Close()
}

foreach ($c in $Crops) {
	$src = [System.Drawing.Image]::FromFile((Join-Path $Source $c.file))
	$canvas = New-Object System.Drawing.Bitmap $CanvasW, $PicH, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
	$g = [System.Drawing.Graphics]::FromImage($canvas)
	$g.Clear([System.Drawing.Color]::Black)
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $PicW, $PicH),
		(New-Object System.Drawing.Rectangle $c.x, $c.y, $c.w, $c.h), [System.Drawing.GraphicsUnit]::Pixel)
	$g.Dispose(); $src.Dispose()
	$path = Join-Path $Out ($c.key + ".tga")
	Write-Tga $canvas $path
	$canvas.Dispose()
	Write-Host ("{0}: {1} KB" -f $path, [int]((Get-Item $path).Length / 1KB))
}
