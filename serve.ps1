# Minimal static file server (no dependencies, uses .NET HttpListener).
# Usage: powershell -ExecutionPolicy Bypass -File serve.ps1 [-Port 8000]
param(
    [int]$Port = 8000,
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'text/javascript; charset=utf-8'
    '.mjs'  = 'text/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.ico'  = 'image/x-icon'
    '.webp' = 'image/webp'
    '.woff' = 'font/woff'
    '.woff2'= 'font/woff2'
    '.txt'  = 'text/plain; charset=utf-8'
    '.map'  = 'application/json; charset=utf-8'
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Error "Failed to start on port $Port. It may be in use. $_"
    exit 1
}

Write-Host "Serving $Root"
Write-Host "  $prefix"
Write-Host "Press Ctrl+C to stop."

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response

        try {
            $relPath = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/')
            if ([string]::IsNullOrEmpty($relPath)) { $relPath = 'index.html' }

            $fullPath = Join-Path $Root $relPath
            $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
            $resolvedFull = [System.IO.Path]::GetFullPath($fullPath)

            if ((Test-Path $resolvedFull -PathType Container)) {
                $resolvedFull = Join-Path $resolvedFull 'index.html'
            }

            if (-not $resolvedFull.StartsWith($resolvedRoot) -or -not (Test-Path $resolvedFull -PathType Leaf)) {
                $res.StatusCode = 404
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
                $res.ContentType = 'text/plain; charset=utf-8'
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $ext = [System.IO.Path]::GetExtension($resolvedFull).ToLower()
                $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
                $bytes = [System.IO.File]::ReadAllBytes($resolvedFull)
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        } catch {
            $res.StatusCode = 500
            $msg = [System.Text.Encoding]::UTF8.GetBytes("500 Internal Server Error`n$_")
            $res.OutputStream.Write($msg, 0, $msg.Length)
        } finally {
            $res.OutputStream.Close()
        }

        Write-Host ("{0} {1} {2}" -f $req.HttpMethod, $req.Url.AbsolutePath, $res.StatusCode)
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
