param([int]$Port = 8082)

if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "Proxy already on port $Port; skipping."
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path "$repoRoot\.cursor-claude" | Out-Null

Set-Location $repoRoot
Write-Host "Starting proxy on 127.0.0.1:$Port ..."
uv run uvicorn server:app --host 127.0.0.1 --port $Port
