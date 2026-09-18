<#
  NAS-T photo prep (PowerShell, no Python needed).

  Default use:
    Put full-resolution photos in  photos-original\
    Run:  .\resize-photos.ps1
    Get:  photos\        web-sized 1x  (what the page displays)
          photos\*@2x    web-sized 2x  (retina / phones, via srcset)
          photos-full\   full-res      (what opens when you click a photo)

  Files named logo* are copied through untouched so PNG transparency survives.
  Existing files are overwritten. Re-run any time you add photos.

  If Windows blocks this script, run this once:
    Unblock-File .\resize-photos.ps1
#>

[CmdletBinding()]
param(
  [string] $Source   = "photos-original",
  [string] $WebOut   = "photos",
  [string] $FullOut  = "photos-full",
  # Sizes are longest edge. For the 3:4 portrait photos this shop shoots, a
  # 680 longest edge gives a 510 wide image, which is the width A/B tested as
  # the sweet spot for gun detail without camo moire. Do not lower this
  # without re-testing against a camo background.
  [int]    $WebMax   = 680,    # 1x  -> 510x680 portrait
  [int]    $RetinaMax= 1360,   # 2x  -> 1020x1360, serves hi-dpi screens 1:1
  [int]    $FullMax  = 3000,   # longest edge for the click-to-view version
  [int]    $WebQ     = 88,
  # The 2x pass is displayed at half its pixel size, so compression artifacts
  # are invisible. Dropping quality here roughly halves the file with no
  # visible cost on the screens that actually load it.
  [int]    $RetinaQ  = 76,
  [int]    $FullQ    = 90,
  [switch] $NoRetina,          # skip the @2x pass
  # Anti-moire insurance. Shrinking a high-frequency pattern (camo weave,
  # ripstop grid, fine checkering) in one big jump can alias it into moire.
  # This halves the image repeatedly instead, so each step only ever throws
  # away every other pixel and the averaging acts as a low-pass filter.
  # Costs a touch of sharpness. The normal path is already clean on these
  # photos, so leave this off unless you actually see banding on a new shot.
  [switch] $Progressive
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# ---------- helpers ----------

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
             Where-Object { $_.MimeType -eq 'image/jpeg' }

function Save-Jpeg {
  param([System.Drawing.Image]$Image, [string]$Path, [int]$Quality)
  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
                   [System.Drawing.Imaging.Encoder]::Quality, [int64]$Quality)
  $Image.Save($Path, $jpegCodec, $ep)
  $ep.Dispose()
}

# Phone photos carry rotation in EXIF rather than in the pixels.
# System.Drawing ignores that, so apply it by hand or everything lands sideways.
function Apply-ExifOrientation {
  param([System.Drawing.Image]$Image)
  $ORIENT = 0x0112
  if ($Image.PropertyIdList -notcontains $ORIENT) { return }
  $v = $Image.GetPropertyItem($ORIENT).Value[0]
  $action = switch ($v) {
    2 { [System.Drawing.RotateFlipType]::RotateNoneFlipX }
    3 { [System.Drawing.RotateFlipType]::Rotate180FlipNone }
    4 { [System.Drawing.RotateFlipType]::Rotate180FlipX }
    5 { [System.Drawing.RotateFlipType]::Rotate90FlipX }
    6 { [System.Drawing.RotateFlipType]::Rotate90FlipNone }
    7 { [System.Drawing.RotateFlipType]::Rotate270FlipX }
    8 { [System.Drawing.RotateFlipType]::Rotate270FlipNone }
    default { $null }
  }
  if ($action) {
    $Image.RotateFlip($action)
    $Image.RemovePropertyItem($ORIENT)
  }
}

# High-quality downscale. This is the step the browser does badly on the fly,
# which is what produced the moire on camo patterns.
function Resize-Fit {
  param([System.Drawing.Image]$Image, [int]$Longest)
  $w = $Image.Width; $h = $Image.Height
  if ([math]::Max($w, $h) -le $Longest) {
    $nw = $w; $nh = $h
  } elseif ($w -ge $h) {
    $nw = $Longest; $nh = [int][math]::Round($h * $Longest / $w)
  } else {
    $nh = $Longest; $nw = [int][math]::Round($w * $Longest / $h)
  }

  # Optional progressive path: halve until one more halving would overshoot,
  # then do the final short step. Each halve averages 4 pixels into 1, which
  # low-passes the image and keeps fine repeating patterns from aliasing.
  $workingImage = $Image
  $scratchList  = @()
  if ($Progressive) {
    $cw = $Image.Width; $ch = $Image.Height
    while ([math]::Max($cw, $ch) / 2 -ge $Longest) {
      $cw = [int][math]::Max(1, [math]::Floor($cw / 2))
      $ch = [int][math]::Max(1, [math]::Floor($ch / 2))
      $half = New-Object System.Drawing.Bitmap($cw, $ch)
      $hg = [System.Drawing.Graphics]::FromImage($half)
      $hg.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $hg.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $hg.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $hg.DrawImage($workingImage, (New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)),
                    0, 0, $workingImage.Width, $workingImage.Height,
                    [System.Drawing.GraphicsUnit]::Pixel)
      $hg.Dispose()
      $scratchList += $half
      $workingImage = $half
    }
  }

  $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
  $bmp.SetResolution(72, 72)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  # Draw onto an explicit rect so edge pixels are not sampled from outside.
  $rect = New-Object System.Drawing.Rectangle(0, 0, $nw, $nh)
  $g.DrawImage($workingImage, $rect, 0, 0, $workingImage.Width, $workingImage.Height,
               [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  foreach ($tmp in $scratchList) { $tmp.Dispose() }
  return $bmp
}

# ---------- run ----------

if (-not (Test-Path -LiteralPath $Source)) {
  New-Item -ItemType Directory -Path $Source -Force | Out-Null
  Write-Host "Created '$Source\'. Put your original photos there and run this again."
  return
}

foreach ($d in @($WebOut, $FullOut)) {
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$exts  = @('.jpg', '.jpeg', '.png', '.webp')
$files = Get-ChildItem -LiteralPath $Source -File |
         Where-Object { $exts -contains $_.Extension.ToLower() } |
         Sort-Object Name

$count = 0
foreach ($f in $files) {

  # Logo passes through untouched: transparency must be preserved.
  if ($f.Name -like 'logo*') {
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $WebOut $f.Name) -Force
    Write-Host ("  logo   {0}  (copied as-is)" -f $f.Name)
    $count++
    continue
  }

  $img = [System.Drawing.Image]::FromFile($f.FullName)
  try {
    Apply-ExifOrientation -Image $img
    $ow = $img.Width; $oh = $img.Height
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)

    $web = Resize-Fit -Image $img -Longest $WebMax
    Save-Jpeg -Image $web -Path (Join-Path (Resolve-Path $WebOut) "$base.jpg") -Quality $WebQ
    $ww = $web.Width; $wh = $web.Height
    $web.Dispose()

    if (-not $NoRetina) {
      $r2 = Resize-Fit -Image $img -Longest $RetinaMax
      Save-Jpeg -Image $r2 -Path (Join-Path (Resolve-Path $WebOut) "$base@2x.jpg") -Quality $RetinaQ
      $r2.Dispose()
    }

    $full = Resize-Fit -Image $img -Longest $FullMax
    Save-Jpeg -Image $full -Path (Join-Path (Resolve-Path $FullOut) "$base.jpg") -Quality $FullQ
    $full.Dispose()
  }
  finally {
    $img.Dispose()
  }

  $beforeMB = [math]::Round($f.Length / 1MB, 1)
  $afterKB  = [math]::Round((Get-Item (Join-Path $WebOut "$base.jpg")).Length / 1KB, 0)
  Write-Host ("  {0}: {1}x{2} ({3} MB) -> {4}x{5} ({6} KB)" -f `
              $f.Name, $ow, $oh, $beforeMB, $ww, $wh, $afterKB)
  $count++
}

Write-Host ""
Write-Host "Done. $count file(s) processed."
Write-Host "Upload BOTH '$WebOut\' and '$FullOut\' to your repo."
