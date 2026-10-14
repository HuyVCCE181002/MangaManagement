# PowerShell Static HTTP Server
$port = 8888
$root = "C:\Users\ngovi\OneDrive\Desktop\prm\MangaManagement\build\web"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()
Write-Host "Serving $root on http://127.0.0.1:$port"
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response
    $path = $req.Url.LocalPath
    if ($path -eq '/') { $path = '/index.html' }
    $fullPath = Join-Path $root ($path.TrimStart('/').Replace('/','\'))
    if (Test-Path $fullPath) {
        $bytes = [System.IO.File]::ReadAllBytes($fullPath)
        $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
        $mime = switch -Regex ($ext) {
            '\.html' { 'text/html; charset=utf-8' }
            '\.js'   { 'application/javascript' }
            '\.css'  { 'text/css' }
            '\.json' { 'application/json' }
            '\.png'  { 'image/png' }
            '\.svg'  { 'image/svg+xml' }
            '\.ico'  { 'image/x-icon' }
            default  { 'application/octet-stream' }
        }
        $res.ContentType = $mime
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $res.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes("Not found: $path")
        $res.OutputStream.Write($msg, 0, $msg.Length)
    }
    $res.Close()
}
