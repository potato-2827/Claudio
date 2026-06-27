' Lanzador de "Mis Tareas"
' Inicia el servidor de respaldo (oculto) que a su vez abre la app.
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
appDir  = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = appDir
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & appDir & "\servidor.ps1""", 0, False
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & appDir & "\monitor-ventana.ps1""", 0, False
