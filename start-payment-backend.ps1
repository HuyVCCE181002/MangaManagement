$ErrorActionPreference = 'Stop'
$paymentRoot = $PSScriptRoot
$paymentDir = Join-Path $paymentRoot 'backend'
$paymentData = Join-Path $paymentDir '.data'
& node (Join-Path $paymentDir 'setup.js')
if ($LASTEXITCODE -ne 0) { throw 'Payment backend setup failed.' }
New-Item -ItemType Directory -Path $paymentData -Force | Out-Null
try {
    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/health' -TimeoutSec 2
    if ($health.provider -eq 'sepay') {
        Write-Output 'Payment backend is already running at http://127.0.0.1:8787.'
        exit 0
    }
} catch { }
$paymentProcess = Start-Process -FilePath 'node' -ArgumentList '--env-file=.env', 'server.js' `
    -WorkingDirectory $paymentDir -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $paymentData 'server.log') `
    -RedirectStandardError (Join-Path $paymentData 'server-error.log')
Write-Output "Payment backend started (PID $($paymentProcess.Id))."
Write-Output 'Configure SePay bank linking and the HTTPS webhook before expecting real payment confirmation.'
