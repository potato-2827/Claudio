# ============================================================
#  Servidor de respaldo local de "Mis Tareas"
#  - Guarda automaticamente el estado en tareas.json (archivo real)
#  - Mantiene copias periodicas en \backups
#  - Expone una mini API en http://localhost:8777 con CORS
#  - Abre la app (Edge en modo aplicacion). Parametros:
#       -OnTop      la ventana queda siempre encima (modo widget)
#       -NoBrowser  no abre Edge (uso interno / pruebas)
# ============================================================
param([switch]$OnTop, [switch]$NoBrowser)

$ErrorActionPreference = "Stop"
$appDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$port      = 8777
$base      = "http://localhost:$port/"
$dataFile  = Join-Path $appDir "tareas.json"
$backupDir = Join-Path $appDir "backups"
$htmlUrl   = "file:///" + ((Join-Path $appDir "index.html") -replace '\\','/' -replace ' ','%20')

$edge = @(
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

function Open-App {
  if($NoBrowser -or -not $edge){ return }
  Start-Process $edge -ArgumentList "--app=$htmlUrl","--window-size=470,790"
}
function Apply-Window {
  # Tamanio del contenido en pixeles CSS (luego se escala segun el DPI)
  $cssW = 460
  $cssH = 820
  try {
    Add-Type -ErrorAction Stop @'
using System;
using System.Runtime.InteropServices;
namespace WinApp {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static class U {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int cx,int cy,uint f);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int ht,bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  }
}
'@
  } catch {}
  for($i=0; $i -lt 40; $i++){
    Start-Sleep -Milliseconds 250
    $h = (Get-Process msedge -ErrorAction SilentlyContinue |
          Where-Object { $_.MainWindowTitle -eq "Mis Tareas" } |
          Select-Object -First 1).MainWindowHandle
    if($h -and $h -ne 0){
      try {
        $dpi = [WinApp.U]::GetDpiForWindow($h); if($dpi -le 0){ $dpi = 96 }
        $scale = $dpi / 96.0
        $w  = [int]($cssW * $scale)
        $ht = [int]($cssH * $scale)
        $rect = New-Object WinApp.RECT
        [WinApp.U]::GetWindowRect($h, [ref]$rect) | Out-Null
        $x = $rect.Left; $y = $rect.Top
        if($x -lt 0 -or $x -gt 6000){ $x = 90 }
        if($y -lt 0 -or $y -gt 4000){ $y = 50 }
        [WinApp.U]::MoveWindow($h, $x, $y, $w, $ht, $true) | Out-Null
        if($OnTop){ [WinApp.U]::SetWindowPos($h, [IntPtr](-1), 0,0,0,0, 0x0003) | Out-Null }
      } catch {}
      break
    }
  }
}

# Si ya hay un servidor corriendo, solo abrimos la ventana y salimos.
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($base)
try { $listener.Start() }
catch { Open-App; Apply-Window; return }

Open-App
Apply-Window
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Send($res, [string]$body, [string]$ctype, [int]$code = 200){
  $res.StatusCode = $code
  $res.Headers["Access-Control-Allow-Origin"]  = "*"
  $res.Headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
  $res.Headers["Access-Control-Allow-Headers"] = "Content-Type"
  $res.Headers["Cache-Control"] = "no-store"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  $res.ContentType = "$ctype; charset=utf-8"
  $res.ContentLength64 = $bytes.Length
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
  $res.OutputStream.Close()
}

while($listener.IsListening){
  try { $ctx = $listener.GetContext() } catch { break }
  $req = $ctx.Request; $res = $ctx.Response
  $p = $req.Url.AbsolutePath; $m = $req.HttpMethod
  try {
    if($m -eq "OPTIONS"){
      Send $res "" "text/plain" 204
    }
    elseif($p -eq "/api/ping"){
      Send $res "ok" "text/plain"
    }
    elseif($p -eq "/api/bye"){
      Send $res "bye" "text/plain"; $listener.Stop(); break
    }
    elseif($p -eq "/api/data" -and $m -eq "GET"){
      $json = if(Test-Path $dataFile){ [System.IO.File]::ReadAllText($dataFile, $utf8) } else { "{}" }
      Send $res $json "application/json"
    }
    elseif($p -eq "/api/data" -and $m -eq "POST"){
      $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
      $body = $reader.ReadToEnd(); $reader.Close()
      # escritura "atomica": archivo temporal y reemplazo
      $tmp = "$dataFile.tmp"
      [System.IO.File]::WriteAllText($tmp, $body, $utf8)
      Move-Item -Force $tmp $dataFile
      # copia de seguridad como mucho cada 5 minutos
      $latest = Get-ChildItem $backupDir -Filter "tareas-*.json" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if(-not $latest -or ((Get-Date) - $latest.LastWriteTime).TotalMinutes -ge 5){
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        [System.IO.File]::WriteAllText((Join-Path $backupDir "tareas-$stamp.json"), $body, $utf8)
        Get-ChildItem $backupDir -Filter "tareas-*.json" |
          Sort-Object LastWriteTime -Descending | Select-Object -Skip 40 |
          Remove-Item -Force -ErrorAction SilentlyContinue
      }
      Send $res '{"ok":true}' "application/json"
    }
    else {
      Send $res "not found" "text/plain" 404
    }
  } catch {
    try { Send $res ("error: " + $_.Exception.Message) "text/plain" 500 } catch {}
  }
}
try { $listener.Close() } catch {}
