# PowerShell: tools/generate_windows_icon.ps1
# Generates a multi-size .ico from the app PNG and places it into windows/runner/resources
# Usage: open PowerShell in the flutter_app folder and run:
#   .\tools\generate_windows_icon.ps1

param(
  [string]$src = "assets/images/rail_aid_logo.png",
  [string]$outDir = "windows/runner/resources",
  [string]$tmp = ".flutter_icon_tmp"
)

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
  Write-Error "ImageMagick 'magick' not found. Install it (choco install imagemagick) or add to PATH."
  exit 1
}

if (-not (Test-Path $src)) {
  Write-Error "Source PNG not found at $src. Add your logo PNG there first."
  exit 1
}

# Prepare tmp dir
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null

$sizes = @(16,24,32,48,64,128,256,512)
foreach ($s in $sizes) {
  $out = Join-Path $tmp ("icon_${s}.png")
  magick convert $src -resize ${s}x${s} $out
}

# Create .ico (Windows supports multiple sizes inside)
if (-not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

$outIco = Join-Path $outDir "app_icon.ico"
magick convert `
  $tmp\icon_16.png `
  $tmp\icon_24.png `
  $tmp\icon_32.png `
  $tmp\icon_48.png `
  $tmp\icon_64.png `
  $tmp\icon_128.png `
  $tmp\icon_256.png `
  $tmp\icon_512.png `
  $outIco

if (Test-Path $outIco) {
  Write-Host "Created $outIco"
} else {
  Write-Error "Failed to create .ico"
}

# Clean tmp
Remove-Item $tmp -Recurse -Force
Write-Host "Done. Rebuild app: flutter clean; flutter run -d windows"
