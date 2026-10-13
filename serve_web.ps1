Add-Type -AssemblyName System.Net.Http
$root = "C:\Users\ngovi\OneDrive\Desktop\prm\MangaManagement\build\web"
$port = 49724
$prefix = "http://localhost:$port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $root on $prefix"

$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".mjs"  = "application/javascript; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
    ".ttf"  = "font/ttf"
    ".otf"  = "font/otf"
    ".wasm" = "application/wasm"
    ".map"  = "application/json"
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $rel = $context.Request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrEmpty($rel)) { $rel = "index.html" }
        $path = Join-Path $root $rel
        if (-not (Test-Path $path)) {
            $path = Join-Path $root "index.html"  # SPA fallback for Flutter routing
        }
        $ext = [System.IO.Path]::GetExtension($path).ToLower()
        $type = $mime[$ext]
        if (-not $type) { $type = "application/octet-stream" }
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $context.Response.ContentType = $type
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.Headers.Add("Cache-Control", "no-cache")
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.Close()
    } catch {
        Write-Host "ERR: $_"
        break
    }
}
$listener.Stop()
