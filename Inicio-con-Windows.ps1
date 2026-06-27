# ============================================================
#  Activa o desactiva que "Mis Tareas" inicie junto con Windows.
#    Inicio-con-Windows.ps1            -> activar (normal)
#    Inicio-con-Windows.ps1 -Widget    -> activar en modo widget (encima)
#    Inicio-con-Windows.ps1 -Off       -> desactivar
# ============================================================
param([switch]$Widget, [switch]$Off)

$appDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$startup = [Environment]::GetFolderPath("Startup")
$lnk     = Join-Path $startup "Mis Tareas.lnk"

if($Off){
  if(Test-Path $lnk){ Remove-Item $lnk -Force; Write-Host "Inicio automatico DESACTIVADO." -ForegroundColor Yellow }
  else { Write-Host "El inicio automatico no estaba activado." -ForegroundColor DarkGray }
  return
}

$wscript = Join-Path $env:WINDIR "System32\wscript.exe"
$target  = Join-Path $appDir $(if($Widget){"Iniciar-widget.vbs"}else{"Iniciar.vbs"})
$ico     = Join-Path $appDir "icono.ico"

$sh = New-Object -ComObject WScript.Shell
$s  = $sh.CreateShortcut($lnk)
$s.TargetPath       = $wscript
$s.Arguments        = '"' + $target + '"'
$s.IconLocation     = "$ico,0"
$s.WorkingDirectory = $appDir
$s.Description       = "Mis Tareas (inicio automatico)"
$s.Save()

Write-Host ("Inicio automatico ACTIVADO" + $(if($Widget){" (modo widget, siempre encima)"}else{""}) + ".") -ForegroundColor Green
Write-Host "Para desactivarlo:  powershell -ExecutionPolicy Bypass -File Inicio-con-Windows.ps1 -Off" -ForegroundColor DarkCyan
