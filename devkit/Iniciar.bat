@echo off
rem Abre Tizen TV Dev Kit (interfaz gráfica) sin ventana de consola.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0TizenTVDevKit.ps1"
