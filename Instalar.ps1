# ============================================================
#  Instalador de "Mis Tareas"
#  - Genera el icono
#  - Crea accesos directos en Escritorio y Menu Inicio
#    que abren la app en modo aplicacion de Edge (ventana propia)
# ============================================================

$ErrorActionPreference = "Stop"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$html   = Join-Path $appDir "index.html"
$icoPath = Join-Path $appDir "icono.ico"

Write-Host ""
Write-Host "  Instalando 'Mis Tareas'..." -ForegroundColor Cyan
Write-Host ""

# ---------- 1. Generar el icono (PNG 256x256 dentro de un .ico) ----------
Add-Type -AssemblyName System.Drawing
$size = 256
$bmp  = New-Object System.Drawing.Bitmap $size, $size
$g    = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "AntiAlias"
$g.Clear([System.Drawing.Color]::Transparent)

# fondo redondeado con degradado morado/indigo
$rect = New-Object System.Drawing.Rectangle 0,0,$size,$size
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 56
$path.AddArc(0,0,$r,$r,180,90)
$path.AddArc($size-$r,0,$r,$r,270,90)
$path.AddArc($size-$r,$size-$r,$r,$r,0,90)
$path.AddArc(0,$size-$r,$r,$r,90,90)
$path.CloseFigure()
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255,99,102,241),
    [System.Drawing.Color]::FromArgb(255,167,139,250),
    45)
$g.FillPath($brush, $path)

# checkmark blanco
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 26
$pen.StartCap = "Round"; $pen.EndCap = "Round"; $pen.LineJoin = "Round"
$pts = @(
    (New-Object System.Drawing.PointF 70,134),
    (New-Object System.Drawing.PointF 112,176),
    (New-Object System.Drawing.PointF 188,86)
)
$g.DrawLines($pen, $pts)
$g.Dispose()

# guardar PNG a memoria
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$png = $ms.ToArray()
$ms.Dispose(); $bmp.Dispose()

# envolver el PNG en un contenedor .ico
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter $fs
$bw.Write([uint16]0)      # reservado
$bw.Write([uint16]1)      # tipo = icono
$bw.Write([uint16]1)      # cantidad de imagenes
$bw.Write([byte]0)        # ancho (0 = 256)
$bw.Write([byte]0)        # alto  (0 = 256)
$bw.Write([byte]0)        # colores
$bw.Write([byte]0)        # reservado
$bw.Write([uint16]1)      # planos
$bw.Write([uint16]32)     # bits por pixel
$bw.Write([uint32]$png.Length)  # tamano de la imagen
$bw.Write([uint32]22)     # offset
$bw.Write($png)
$bw.Flush(); $bw.Close(); $fs.Close()
Write-Host "  [ok] Icono generado." -ForegroundColor Green

# ---------- 2. Crear accesos directos (usan el lanzador con respaldo) ----------
$wscript        = Join-Path $env:WINDIR "System32\wscript.exe"
$launcher       = Join-Path $appDir "Iniciar.vbs"
$launcherWidget = Join-Path $appDir "Iniciar-widget.vbs"

$shell = New-Object -ComObject WScript.Shell
function New-Shortcut($lnkPath, $target, $desc){
    $s = $shell.CreateShortcut($lnkPath)
    $s.TargetPath = $wscript
    $s.Arguments  = '"' + $target + '"'
    $s.IconLocation = "$icoPath,0"
    $s.WorkingDirectory = $appDir
    $s.Description = $desc
    $s.Save()
}

$desktop   = [Environment]::GetFolderPath("Desktop")
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"

New-Shortcut (Join-Path $desktop   "Mis Tareas.lnk")          $launcher       "Mis Tareas - lista de pendientes"
New-Shortcut (Join-Path $startMenu "Mis Tareas.lnk")          $launcher       "Mis Tareas - lista de pendientes"
New-Shortcut (Join-Path $desktop   "Mis Tareas (widget).lnk") $launcherWidget "Mis Tareas - modo widget (siempre encima)"
Write-Host "  [ok] Accesos directos creados (Escritorio + Menu Inicio)." -ForegroundColor Green
Write-Host "  [ok] Acceso 'Mis Tareas (widget)' (siempre encima) en el Escritorio." -ForegroundColor Green

Write-Host ""
Write-Host "  Listo. Busca 'Mis Tareas' en el Menu Inicio o en el Escritorio." -ForegroundColor Cyan
Write-Host "  - Respaldo automatico en:   $appDir\tareas.json" -ForegroundColor DarkCyan
Write-Host "  - Copias periodicas en:     $appDir\backups" -ForegroundColor DarkCyan
Write-Host "  - Anclar a barra de tareas: abre la app, clic derecho en su icono > Anclar." -ForegroundColor DarkCyan
Write-Host "  - Iniciar con Windows:      ejecuta  Inicio-con-Windows.ps1" -ForegroundColor DarkCyan
Write-Host ""
