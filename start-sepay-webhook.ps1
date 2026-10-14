$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$paymentRoot = $PSScriptRoot
$paymentTools = Join-Path $paymentRoot 'backend\.tools'
$paymentData = Join-Path $paymentRoot 'backend\.data'
$paymentTunnelExe = Join-Path $paymentTools 'cloudflared.exe'

# Keep the executable and temporary tunnel files in the ignored backend folders.
New-Item -ItemType Directory -Path $paymentTools -Force | Out-Null
New-Item -ItemType Directory -Path $paymentData -Force | Out-Null
if (-not (Test-Path -LiteralPath $paymentTunnelExe)) {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest' `
        -Headers @{ 'User-Agent' = 'MangaManagement-payment-setup' } -TimeoutSec 30
    $asset = $release.assets | Where-Object { $_.name -eq 'cloudflared-windows-amd64.exe' } | Select-Object -First 1
    if ($null -eq $asset -or $asset.digest -notmatch '^sha256:([a-f0-9]{64})$') {
        throw 'Official Cloudflare release does not provide the expected SHA-256 checksum.'
    }
    $expectedHash = $Matches[1]
    $downloadUri = [Uri]$asset.browser_download_url
    if ($downloadUri.Scheme -ne 'https' -or $downloadUri.Host -ne 'github.com') {
        throw 'Unexpected Cloudflare release download location.'
    }
    $downloadPath = $paymentTunnelExe + '.download'
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUri.AbsoluteUri -OutFile $downloadPath -TimeoutSec 120
    $actualHash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash
    if ($actualHash -ine $expectedHash) { throw 'Cloudflare executable checksum mismatch.' }
    Move-Item -LiteralPath $downloadPath -Destination $paymentTunnelExe -Force
}

& (Join-Path $paymentRoot 'start-payment-backend.ps1')
$health = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/health' -TimeoutSec 5
if ($health.provider -ne 'sepay') { throw 'Expected payment backend is not running on port 8787.' }

$tunnelPidPath = Join-Path $paymentData 'tunnel.pid'
$urlPath = Join-Path $paymentData 'webhook-url.txt'
$tunnel = $null
if (Test-Path -LiteralPath $tunnelPidPath) {
    $savedPid = [int]([IO.File]::ReadAllText($tunnelPidPath).Trim())
    $savedProcess = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
    if ($null -ne $savedProcess -and $savedProcess.ProcessName -eq 'cloudflared') {
        if (Test-Path -LiteralPath $urlPath) {
            Write-Output ('SePay webhook URL: ' + [IO.File]::ReadAllText($urlPath).Trim())
            exit 0
        }
        $tunnel = $savedProcess
    }
}

$stdout = Join-Path $paymentData 'tunnel.log'
$stderr = Join-Path $paymentData 'tunnel-error.log'
if ($null -eq $tunnel) {
    $tunnel = Start-Process -FilePath $paymentTunnelExe `
        -ArgumentList 'tunnel', '--url', 'http://127.0.0.1:8787', '--no-autoupdate' `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    [IO.File]::WriteAllText($tunnelPidPath, [string]$tunnel.Id)
}
for ($attempt = 0; $attempt -lt 45; $attempt++) {
    $logs = ''
    if (Test-Path -LiteralPath $stderr) { $logs += (Get-Content -LiteralPath $stderr -Raw) }
    if (Test-Path -LiteralPath $stdout) { $logs += (Get-Content -LiteralPath $stdout -Raw) }
    $match = [regex]::Match($logs, 'https://[a-z0-9-]+\.trycloudflare\.com')
    if ($match.Success) {
        $webhookUrl = $match.Value + '/webhooks/sepay'
        [IO.File]::WriteAllText($urlPath, $webhookUrl)
        Write-Output ('SePay webhook URL: ' + $webhookUrl)
        Write-Output 'Use API Key authentication with SEPAY_WEBHOOK_KEY from backend/.env.'
        Write-Output 'This temporary URL works while the computer and Cloudflare process are running.'
        exit 0
    }
    if ($tunnel.HasExited) { throw 'Cloudflare tunnel stopped. See backend/.data/tunnel-error.log.' }
    Start-Sleep -Seconds 1
}
throw 'Tunnel URL is not available yet. See backend/.data/tunnel-error.log and rerun this script.'
