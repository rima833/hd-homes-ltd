# Publish Flutter web build to the Vercel-connected static repo (hd-homes-web).
param(
  [string]$DeployRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) "..\hd-homes-web"),
  [string]$WebRepo = "https://github.com/rima833/hd-homes-web.git"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $projectRoot "build\web"

Push-Location $projectRoot
try {
  flutter build web --release
} finally {
  Pop-Location
}

if (-not (Test-Path (Join-Path $DeployRoot ".git"))) {
  git clone $WebRepo $DeployRoot
}

Push-Location $DeployRoot
try {
  git fetch origin
  git checkout main
  git pull origin main
  Get-ChildItem -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
  Copy-Item -Path (Join-Path $buildDir "*") -Destination $DeployRoot -Recurse -Force
  Copy-Item -Path (Join-Path $projectRoot "vercel.json") -Destination $DeployRoot -Force
  git add -A
  if (-not (git diff --cached --quiet)) {
    git commit -m "Publish latest HD Homes web build from hd-homes-ltd main."
    git push origin main
  } else {
    Write-Host "No changes to publish."
  }
} finally {
  Pop-Location
}
