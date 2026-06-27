' Lanzador de "Mis Tareas" en modo widget (ventana siempre encima).
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
appDir  = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = appDir
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & appDir & "\servidor.ps1"" -OnTop", 0, False
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & appDir & "\monitor-ventana.ps1""", 0, False
