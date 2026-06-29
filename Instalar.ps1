# ============================================================
#  Instalador de "Mis Tareas" (version Electron)
#  - Crea accesos directos en Escritorio y Menu Inicio que
#    abren la app nativa de Electron (ventana propia).
#  - Opcional: -InicioConWindows  -> tambien arranca con Windows.
#  - Opcional: -Desinstalar       -> borra los accesos creados.
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File Instalar.ps1
#    powershell -ExecutionPolicy Bypass -File Instalar.ps1 -InicioConWindows
#    powershell -ExecutionPolicy Bypass -File Instalar.ps1 -Desinstalar
# ============================================================

param(
    [switch]$InicioConWindows,
    [switch]$Desinstalar
)

$ErrorActionPreference = "Stop"
$appDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$electron = Join-Path $appDir "node_modules\electron\dist\electron.exe"
$icoPath  = Join-Path $appDir "icono.ico"

$desktop   = [Environment]::GetFolderPath("Desktop")
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$startup   = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"

$lnkDesktop   = Join-Path $desktop   "Mis Tareas.lnk"
$lnkStartMenu = Join-Path $startMenu "Mis Tareas.lnk"
$lnkStartup   = Join-Path $startup   "Mis Tareas.lnk"

Write-Host ""

# ---------- Desinstalar ----------
if ($Desinstalar) {
    Write-Host "  Quitando 'Mis Tareas'..." -ForegroundColor Cyan
    foreach ($l in @($lnkDesktop, $lnkStartMenu, $lnkStartup)) {
        if (Test-Path $l) { Remove-Item $l -Force; Write-Host "  [ok] Borrado: $l" -ForegroundColor Green }
    }
    Write-Host "  Listo. (Tus tareas en tareas.json NO se tocaron.)" -ForegroundColor Cyan
    Write-Host ""
    return
}

# ---------- Verificaciones ----------
Write-Host "  Instalando 'Mis Tareas'..." -ForegroundColor Cyan
if (-not (Test-Path $electron)) {
    Write-Host "  [ERROR] No se encuentra Electron en:" -ForegroundColor Red
    Write-Host "          $electron" -ForegroundColor Red
    Write-Host "          Asegurate de tener la carpeta node_modules completa." -ForegroundColor Red
    return
}
if (-not (Test-Path $icoPath)) {
    Write-Host "  [aviso] Falta icono.ico; los accesos usaran el icono de Electron." -ForegroundColor Yellow
}

# ---------- Crear accesos directos ----------
$shell = New-Object -ComObject WScript.Shell
function New-Shortcut($lnkPath, $desc) {
    $s = $shell.CreateShortcut($lnkPath)
    $s.TargetPath       = $electron
    $s.Arguments        = '"' + $appDir + '"'
    $s.WorkingDirectory = $appDir
    if (Test-Path $icoPath) { $s.IconLocation = "$icoPath,0" }
    $s.Description       = $desc
    $s.Save()
}

New-Shortcut $lnkDesktop   "Mis Tareas - lista de pendientes"
New-Shortcut $lnkStartMenu "Mis Tareas - lista de pendientes"
Write-Host "  [ok] Acceso directo en el Escritorio." -ForegroundColor Green
Write-Host "  [ok] Acceso directo en el Menu Inicio." -ForegroundColor Green

if ($InicioConWindows) {
    New-Shortcut $lnkStartup "Mis Tareas - inicio con Windows"
    Write-Host "  [ok] Arrancara con Windows (Carpeta de Inicio)." -ForegroundColor Green
} else {
    Write-Host "  [i]  Para arrancar con Windows: volve a correr con  -InicioConWindows" -ForegroundColor DarkCyan
}

Write-Host ""
Write-Host "  Listo. Busca 'Mis Tareas' en el Menu Inicio o el Escritorio." -ForegroundColor Cyan
Write-Host "  - Datos / respaldo automatico: $appDir\tareas.json" -ForegroundColor DarkCyan
Write-Host "  - Copias periodicas:           $appDir\backups" -ForegroundColor DarkCyan
Write-Host "  - Modo widget (siempre encima): se activa desde dentro de la app (menu)." -ForegroundColor DarkCyan
Write-Host ""
