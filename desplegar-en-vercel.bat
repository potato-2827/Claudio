@echo off
setlocal
rem === Despliega la version web de "Mis Tareas" a Vercel ===
rem Usa el Node portable de la carpeta del proyecto (no necesitas instalar Node).
set "NODEDIR=%~dp0..\node"
set "PATH=%NODEDIR%;%PATH%"
cd /d "%~dp0"

echo ============================================
echo   Subir "Mis Tareas" (version web) a Vercel
echo ============================================
echo.
echo - Necesitas una cuenta gratis en https://vercel.com
echo - La PRIMERA vez te va a pedir iniciar sesion: se abre el navegador
echo   y autenticas vos (Claude no entra a tu cuenta).
echo - Cuando pregunte por configuracion, podes aceptar las opciones por defecto.
echo.
pause

call "%NODEDIR%\npx.cmd" vercel

echo.
echo --------------------------------------------
echo Si arriba aparece una URL, ya esta desplegado (preview).
echo Para publicar la version DEFINITIVA (produccion), corre de nuevo con:
echo    "%NODEDIR%\npx.cmd" vercel --prod
echo --------------------------------------------
echo.
pause
endlocal
