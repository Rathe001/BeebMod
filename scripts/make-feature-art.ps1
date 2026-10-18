<#
scripts/make-feature-art.ps1 (Josh 2026-09-27): the pictures of the
features, for the first login's slides (UI/Welcome.lua, W.ABOUT).

    powershell -ExecutionPolicy Bypass -File scripts\make-feature-art.ps1 -Source <folder of screenshots>

A SLIDESHOW EACH, AND THE SAME PICTURES FOR CURSEFORGE (Josh 2026-10-18: "I'd
like to create some updated images as part of this, maybe several images so
we can have a small slideshow per module. We'll probably reuse these to
update the addon's CurseForge description"). Each slide is a 16:9 piece of
one screenshot (taken with the Testing page's made-up data on where a
feature needs it). It is written twice:

  * Art/Features/<key>.blp, shrunk to 455x256 on a 512x256 canvas, a power
    of two each way. The picture fills the left 455 of the 512;
    UI/Welcome.lua crops to it (ART_U). A BLP, DXT1-compressed, is 64 KB
    where a TGA is 384 KB; dock2 showed the client draws one (Josh
    2026-10-18: "Dock slide 2 seems ok"), so every slide is one. A key in
    -Tga is written as a TGA instead. Whichever is written, the other goes.
  * docs/screens/<key>.jpg, the piece at the screenshot's own size, for the
    CurseForge page, as a JPEG at quality 95: the screenshots are JPEGs
    already, and a PNG of one was five times the size for nothing. docs/ is
    left out of the download (.pkgmeta).

To take new ones, change the file names and crops below: a crop is x, y,
width and height in the screenshot's own pixels (these are 1920x1200), and
wants to be 16:9. Then list the slide in UI/Welcome.lua's W.ABOUT and
restart the game: a /reload does not find new files.
#>
param(
	[Parameter(Mandatory = $true)][string]$Source,
	# keys written as a TGA rather than a DXT1 BLP
	[string[]]$Tga = @(),
	# only these keys; every one when empty
	[string[]]$Only = @()
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "Art\Features"
$Screens = Join-Path $Root "docs\screens"
New-Item -ItemType Directory -Force $Out | Out-Null
New-Item -ItemType Directory -Force $Screens | Out-Null

$PicW, $PicH, $CanvasW = 455, 256, 512
$S = "WoWScrnShot_101826_"
$Crops = @(
	# the dock: beside the game, the Experience tooltip, the quests, a readout's tooltip
	@{ key = "dock1"; file = "${S}134558.jpg"; x = 864; y = 0; w = 1056; h = 594 },
	@{ key = "dock2"; file = "${S}134621.jpg"; x = 1152; y = 240; w = 768; h = 432 },
	@{ key = "dock3"; file = "${S}134656.jpg"; x = 1280; y = 540; w = 640; h = 360 },
	@{ key = "dock4"; file = "${S}134850.jpg"; x = 1152; y = 380; w = 768; h = 432 },
	# unit frames: the party and nameplates, your damage over time, the raid, the buffs
	@{ key = "unitframes1"; file = "${S}135339.jpg"; x = 0; y = 0; w = 1600; h = 900 },
	@{ key = "unitframes2"; file = "${S}135729.jpg"; x = 360; y = 0; w = 960; h = 540 },
	@{ key = "unitframes3"; file = "${S}135615.jpg"; x = 0; y = 330; w = 960; h = 540 },
	@{ key = "unitframes4"; file = "${S}135820.jpg"; x = 555; y = 0; w = 1365; h = 768 },
	# game frames: the bag window, item tooltips, a spell tooltip, the character sheet
	# (the item tooltips again with their tags, 180245: Josh, "Can we use this
	# for the item tooltip slide?")
	@{ key = "interface1"; file = "${S}135845.jpg"; x = 770; y = 560; w = 864; h = 486 },
	@{ key = "interface2"; file = "${S}180245.jpg"; x = 312; y = 515; w = 760; h = 428 },
	@{ key = "interface3"; file = "${S}140006.jpg"; x = 1150; y = 876; w = 576; h = 324 },
	@{ key = "interface4"; file = "${S}140121.jpg"; x = 180; y = 343; w = 800; h = 450 },
	# the Ledger: charts, Find people, a note on a tooltip, commendations, a
	# new rank's toast
	@{ key = "ledger1"; file = "${S}140257.jpg"; x = 270; y = 70; w = 1264; h = 711 },
	@{ key = "ledger2"; file = "${S}140349.jpg"; x = 270; y = 70; w = 1264; h = 711 },
	@{ key = "ledger3"; file = "${S}140432.jpg"; x = 1130; y = 876; w = 576; h = 324 },
	@{ key = "ledger4"; file = "${S}140402.jpg"; x = 270; y = 70; w = 1264; h = 711 },
	@{ key = "ledger5"; file = "${S}180525.jpg"; x = 694; y = 82; w = 530; h = 298 },
	# the Expedition: an enemy's page, its abilities, the cards (in the
	# metals of 2026-10-18), commendations, a new rank's toast (without
	# Hemet's quote: the first, 140807, went with it on 2026-10-18)
	@{ key = "expedition1"; file = "${S}142253.jpg"; x = 276; y = 245; w = 1358; h = 764 },
	@{ key = "expedition2"; file = "${S}142347.jpg"; x = 276; y = 245; w = 1358; h = 764 },
	@{ key = "expedition3"; file = "${S}180434.jpg"; x = 330; y = 176; w = 1290; h = 726 },
	@{ key = "expedition4"; file = "${S}140708.jpg"; x = 310; y = 80; w = 1264; h = 711 },
	@{ key = "expedition5"; file = "${S}180516.jpg"; x = 694; y = 82; w = 530; h = 298 }
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

# A BLP2 holding one DXT1 level, no alpha. Each 4x4 block keeps the two ends
# of its colours along their widest channel and two between them, which is
# what DXT1 can say.
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class BeebBlp {
	static ushort To565(int r, int g, int b) {
		return (ushort)(((r * 31 + 127) / 255) << 11 | ((g * 63 + 127) / 255) << 5 | ((b * 31 + 127) / 255));
	}
	static void From565(ushort c, out int r, out int g, out int b) {
		r = ((c >> 11) & 31) * 255 / 31; g = ((c >> 5) & 63) * 255 / 63; b = (c & 31) * 255 / 31;
	}
	public static void Write(Bitmap bmp, string path) {
		int w = bmp.Width, h = bmp.Height;
		var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
		var raw = new byte[data.Stride * h];
		Marshal.Copy(data.Scan0, raw, 0, raw.Length);
		int stride = data.Stride;
		bmp.UnlockBits(data);
		var blocks = new byte[(w / 4) * (h / 4) * 8];
		int o = 0;
		var pr = new int[16]; var pg = new int[16]; var pb = new int[16];
		for (int by = 0; by < h; by += 4) {
			for (int bx = 0; bx < w; bx += 4) {
				int minR = 255, minG = 255, minB = 255, maxR = 0, maxG = 0, maxB = 0;
				for (int i = 0; i < 16; i++) {
					int p = (by + i / 4) * stride + (bx + i % 4) * 3;
					pb[i] = raw[p]; pg[i] = raw[p + 1]; pr[i] = raw[p + 2];
					minR = Math.Min(minR, pr[i]); maxR = Math.Max(maxR, pr[i]);
					minG = Math.Min(minG, pg[i]); maxG = Math.Max(maxG, pg[i]);
					minB = Math.Min(minB, pb[i]); maxB = Math.Max(maxB, pb[i]);
				}
				// the ends: the darkest and lightest along the widest channel
				int ch = (maxG - minG >= maxR - minR && maxG - minG >= maxB - minB) ? 1 : (maxR - minR >= maxB - minB ? 0 : 2);
				int lo = 0, hi = 0;
				for (int i = 1; i < 16; i++) {
					int v = ch == 0 ? pr[i] : ch == 1 ? pg[i] : pb[i];
					int vlo = ch == 0 ? pr[lo] : ch == 1 ? pg[lo] : pb[lo];
					int vhi = ch == 0 ? pr[hi] : ch == 1 ? pg[hi] : pb[hi];
					if (v < vlo) lo = i;
					if (v > vhi) hi = i;
				}
				ushort c0 = To565(pr[hi], pg[hi], pb[hi]), c1 = To565(pr[lo], pg[lo], pb[lo]);
				uint idx = 0;
				if (c0 < c1) { ushort t = c0; c0 = c1; c1 = t; }
				if (c0 != c1) {
					int r0, g0, b0, r1, g1, b1;
					From565(c0, out r0, out g0, out b0); From565(c1, out r1, out g1, out b1);
					int[,] pal = { { r0, g0, b0 }, { r1, g1, b1 },
						{ (2 * r0 + r1) / 3, (2 * g0 + g1) / 3, (2 * b0 + b1) / 3 },
						{ (r0 + 2 * r1) / 3, (g0 + 2 * g1) / 3, (b0 + 2 * b1) / 3 } };
					for (int i = 0; i < 16; i++) {
						int best = 0, bestD = int.MaxValue;
						for (int k = 0; k < 4; k++) {
							int dr = pr[i] - pal[k, 0], dg = pg[i] - pal[k, 1], db = pb[i] - pal[k, 2];
							int d = dr * dr * 3 + dg * dg * 4 + db * db * 2;
							if (d < bestD) { bestD = d; best = k; }
						}
						idx |= (uint)best << (i * 2);
					}
				}
				blocks[o++] = (byte)(c0 & 255); blocks[o++] = (byte)(c0 >> 8);
				blocks[o++] = (byte)(c1 & 255); blocks[o++] = (byte)(c1 >> 8);
				blocks[o++] = (byte)(idx & 255); blocks[o++] = (byte)((idx >> 8) & 255);
				blocks[o++] = (byte)((idx >> 16) & 255); blocks[o++] = (byte)(idx >> 24);
			}
		}
		using (var f = new BinaryWriter(File.Create(path))) {
			f.Write(new byte[] { (byte)'B', (byte)'L', (byte)'P', (byte)'2' });
			f.Write((uint)1);          // version
			f.Write((byte)2);          // DXT
			f.Write((byte)0);          // no alpha
			f.Write((byte)0);          // DXT1
			f.Write((byte)0);          // no mipmaps
			f.Write((uint)w); f.Write((uint)h);
			const int header = 4 + 4 + 4 + 8 + 16 * 4 * 2 + 256 * 4;
			for (int i = 0; i < 16; i++) f.Write((uint)(i == 0 ? header : 0));
			for (int i = 0; i < 16; i++) f.Write((uint)(i == 0 ? blocks.Length : 0));
			f.Write(new byte[256 * 4]); // the palette, unused by DXT
			f.Write(blocks);
		}
	}
}
"@

foreach ($c in $Crops) {
	if ($Only.Count -gt 0 -and -not ($Only -contains $c.key)) { continue }
	$src = [System.Drawing.Image]::FromFile((Join-Path $Source $c.file))
	$from = New-Object System.Drawing.Rectangle $c.x, $c.y, $c.w, $c.h
	# the full-size piece, for the CurseForge page
	$full = New-Object System.Drawing.Bitmap $c.w, $c.h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
	$g = [System.Drawing.Graphics]::FromImage($full)
	$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $c.w, $c.h), $from, [System.Drawing.GraphicsUnit]::Pixel)
	$g.Dispose()
	$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
	$q = New-Object System.Drawing.Imaging.EncoderParameters 1
	$q.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 95L
	$full.Save((Join-Path $Screens ($c.key + ".jpg")), $jpeg, $q)
	$full.Dispose()
	# and the slide
	$canvas = New-Object System.Drawing.Bitmap $CanvasW, $PicH, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
	$g = [System.Drawing.Graphics]::FromImage($canvas)
	$g.Clear([System.Drawing.Color]::Black)
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $PicW, $PicH), $from, [System.Drawing.GraphicsUnit]::Pixel)
	$g.Dispose(); $src.Dispose()
	if ($Tga -contains $c.key) {
		$path = Join-Path $Out ($c.key + ".tga")
		Write-Tga $canvas $path
		$other = Join-Path $Out ($c.key + ".blp")
	} else {
		$path = Join-Path $Out ($c.key + ".blp")
		[BeebBlp]::Write($canvas, $path)
		$other = Join-Path $Out ($c.key + ".tga")
	}
	if (Test-Path $other) { Remove-Item $other }
	$canvas.Dispose()
	Write-Host ("{0}: {1} KB" -f $path, [int]((Get-Item $path).Length / 1KB))
}
