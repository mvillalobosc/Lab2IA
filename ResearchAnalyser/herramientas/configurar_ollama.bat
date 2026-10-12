@echo off
setlocal enabledelayedexpansion
title Configurar Ollama para el Procesador bibliometrico
color 0F

echo ==========================================================
echo   CONFIGURAR OLLAMA PARA EL PROCESADOR BIBLIOMETRICO
echo ==========================================================
echo.
echo Esto hace tres cosas:
echo   1. Autoriza a la pagina del procesador a hablarle a Ollama
echo   2. Reinicia Ollama para que tome el cambio
echo   3. Comprueba que quedo funcionando
echo.
echo No necesitas permisos de administrador.
echo.
pause
echo.

REM ==========================================================
REM  1. Guardar la variable
REM ==========================================================
echo [1/3] Guardando la autorizacion...
setx OLLAMA_ORIGINS "*" >nul 2>&1
if errorlevel 1 (
  echo       ERROR: no pude guardar la variable.
  echo       Prueba abriendo este archivo con clic derecho, "Ejecutar como administrador".
  echo.
  pause
  exit /b 1
)
set "OLLAMA_ORIGINS=*"
echo       Listo. OLLAMA_ORIGINS quedo en *
echo.

REM ==========================================================
REM  2. Cerrar Ollama y volver a abrirlo
REM ==========================================================
echo [2/3] Reiniciando Ollama...

set "ESTABA=no"
tasklist /FI "IMAGENAME eq ollama app.exe" 2>nul | find /I "ollama app.exe" >nul && set "ESTABA=si"
tasklist /FI "IMAGENAME eq ollama.exe"     2>nul | find /I "ollama.exe"     >nul && set "ESTABA=si"

taskkill /F /IM "ollama app.exe" >nul 2>&1
taskkill /F /IM "ollama.exe"     >nul 2>&1
taskkill /F /IM "Ollama.exe"     >nul 2>&1
taskkill /F /IM "ollama-app.exe" >nul 2>&1

if "!ESTABA!"=="si" (
  echo       Ollama estaba corriendo, lo cerre.
) else (
  echo       Ollama no estaba corriendo.
)

REM esperar a que suelte el puerto
timeout /t 3 /nobreak >nul

REM buscar donde esta instalado
set "EXE="
for %%P in (
  "%LOCALAPPDATA%\Programs\Ollama\ollama app.exe"
  "%LOCALAPPDATA%\Programs\Ollama\Ollama.exe"
  "%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
  "%PROGRAMFILES%\Ollama\ollama app.exe"
  "%PROGRAMFILES%\Ollama\Ollama.exe"
  "%PROGRAMFILES(X86)%\Ollama\Ollama.exe"
) do (
  if exist %%P if not defined EXE set "EXE=%%~P"
)

if not defined EXE (
  for /f "delims=" %%A in ('where ollama 2^>nul') do if not defined EXE set "EXE=%%A"
)

if not defined EXE (
  echo       No encontre el programa de Ollama en las rutas normales.
  echo       Abrelo tu desde el menu Inicio y despues vuelve a correr este archivo.
  echo.
  pause
  exit /b 1
)

echo       Abriendo: !EXE!
start "" "!EXE!"

REM esperar a que levante, hasta 30 segundos
echo       Esperando que arranque...
set "ARRIBA=no"
for /l %%I in (1,1,15) do (
  if "!ARRIBA!"=="no" (
    timeout /t 2 /nobreak >nul
    curl -s -m 3 -o nul http://localhost:11434/api/tags >nul 2>&1
    if not errorlevel 1 set "ARRIBA=si"
  )
)

if "!ARRIBA!"=="no" (
  echo       Ollama no respondio en 30 segundos.
  echo       Abrelo a mano desde el menu Inicio y vuelve a correr este archivo.
  echo.
  pause
  exit /b 1
)
echo       Ollama esta arriba.
echo.

REM ==========================================================
REM  3. Comprobar que la autorizacion funciona
REM ==========================================================
echo [3/3] Comprobando la autorizacion...

set "CAB=%TEMP%\ollama_cabeceras.txt"
del "%CAB%" >nul 2>&1
curl -s -m 6 -H "Origin: null" -D "%CAB%" -o "%TEMP%\ollama_modelos.json" http://localhost:11434/api/tags >nul 2>&1

set "PERMISO=no"
if exist "%CAB%" (
  findstr /I "access-control-allow-origin" "%CAB%" >nul 2>&1 && set "PERMISO=si"
)

echo.
echo ==========================================================
if "!PERMISO!"=="si" (
  echo   TODO LISTO
  echo ==========================================================
  echo.
  echo   Ollama responde y acepta a la pagina del procesador.
  echo.
  echo   Modelos que tienes instalados:
  powershell -NoProfile -Command "try{ (Get-Content -Raw '%TEMP%\ollama_modelos.json' | ConvertFrom-Json).models | ForEach-Object { '     - ' + $_.name } } catch { '     (no pude leer la lista)' }" 2>nul
  echo.
  echo   Ahora vuelve al procesador y aprieta "Probar conexion".
  echo   Escribe en el campo Modelo uno de los de arriba.
) else (
  echo   OLLAMA RESPONDE, PERO SIGUE SIN AUTORIZAR LA PAGINA
  echo ==========================================================
  echo.
  echo   La variable quedo guardada, pero el Ollama que esta corriendo
  echo   todavia no la tomo. Casi siempre es porque quedo un proceso viejo.
  echo.
  echo   Prueba esto:
  echo     1. Reinicia el computador
  echo     2. Vuelve a correr este archivo
  echo.
  echo   Si igual no funciona, avisame y lo vemos.
)
echo ==========================================================
echo.
echo   Recordatorio: OLLAMA_ORIGINS quedo en *, o sea cualquier pagina
echo   web que visites podria hablarle a tu Ollama local. Si te molesta,
echo   corre en PowerShell:  setx OLLAMA_ORIGINS "null"
echo   y vuelve a correr este archivo.
echo.
pause
endlocal
