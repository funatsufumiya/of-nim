# Edit these two constants to point to your release assets (direct download URLs)
$LibUrl = 'https://github.com/funatsufumiya/of-nim/releases/download/v0.1.0/vs_x64_libs.zip'
$DllUrl = 'https://github.com/funatsufumiya/of-nim/releases/download/v0.1.0/vs_x64_dlls.zip'

# Optional: change extraction destinations relative to repo root
$LibDest = 'lib\\vs\\x64'
$DllDest = '.'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir "..")
$tmp = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmp | Out-Null

function Fetch-And-Extract($url, $destRel) {
  $out = Join-Path $tmp ([IO.Path]::GetFileName($url))
  if ($destRel -eq '.' -or [string]::IsNullOrEmpty($destRel)) {
    $dest = $root
  } else {
    $dest = Join-Path $root $destRel
  }
  if (($destRel -ne '.') -and (Test-Path $dest)) {
    Write-Host "$destRel already exists. Remove it to reinstall."
    exit
    return
  }
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
  New-Item -ItemType Directory -Path $dest -Force | Out-Null
  Write-Host "Extracting to $dest"
  Expand-Archive -LiteralPath $out -DestinationPath $dest -Force
}

try {
  Fetch-And-Extract -url $LibUrl -destRel $LibDest
  Fetch-And-Extract -url $DllUrl -destRel $DllDest
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

Write-Host "Done."
