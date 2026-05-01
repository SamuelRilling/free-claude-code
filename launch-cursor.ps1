$proxyDir      = "D:\Coding Projects\free-claude-code"
$proxyPort     = 8082
$cursorExe     = "D:\Coding Projects\cursor\Cursor.exe"
$cursorCfgDir  = "D:\Coding Projects\free-claude-code\.cursor-claude"

function Stop-PortProcess($port) {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object { taskkill /PID $_.OwningProcess /F /T 2>&1 | Out-Null }
}

Write-Host "=== Free Claude Code Launcher ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $cursorCfgDir | Out-Null

# Reuse existing proxy if already running (e.g. from this repo's VSCode/Cursor task)
$proxyProc = $null
if (Get-NetTCPConnection -LocalPort $proxyPort -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "Proxy already on port $proxyPort; reusing." -ForegroundColor Yellow
} else {
    Stop-PortProcess $proxyPort
    Write-Host "Starting proxy..." -ForegroundColor Yellow
    $proxyProc = Start-Process uv `
        -ArgumentList "run", "uvicorn", "server:app", "--host", "127.0.0.1", "--port", "$proxyPort" `
        -WorkingDirectory $proxyDir `
        -NoNewWindow `
        -PassThru
}

# Wait up to 20 seconds for the proxy to bind to the port
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep 1
    if (Get-NetTCPConnection -LocalPort $proxyPort -State Listen -ErrorAction SilentlyContinue) {
        $ready = $true; break
    }
}
if (-not $ready) {
    Write-Host "ERROR: Proxy did not bind to port $proxyPort." -ForegroundColor Red
    if ($proxyProc) { taskkill /PID $proxyProc.Id /F /T 2>&1 | Out-Null }
    Start-Sleep 3; exit 1
}

Write-Host "Proxy ready. Launching Cursor..." -ForegroundColor Green

$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:$proxyPort"
$env:CLAUDE_CONFIG_DIR  = $cursorCfgDir
$cursorProc = Start-Process $cursorExe -PassThru
$env:ANTHROPIC_BASE_URL = $null
$env:CLAUDE_CONFIG_DIR  = $null

Write-Host "Cursor launched (PID $($cursorProc.Id)). Close this window to stop the proxy." -ForegroundColor Cyan

try {
    $cursorProc.WaitForExit()
    Write-Host "Cursor exited. Stopping proxy..." -ForegroundColor Yellow
} finally {
    if ($proxyProc) { taskkill /PID $proxyProc.Id /F /T 2>&1 | Out-Null }
    Stop-PortProcess $proxyPort
    Write-Host "Proxy stopped." -ForegroundColor Green
    Start-Sleep 2
}
