<#
.SYNOPSIS
  Sube, instala y ejecuta un WGT en un dispositivo Tizen, comprobando el resultado REAL.
  A diferencia de la extensión tizentv, falla si el dispositivo rechaza la instalación.
.EXAMPLE
  .\instalar.ps1 -Ip 192.168.1.50 -Wgt .\MiApp\MiApp.wgt -AppId AbCdEfGhIj.MiApp
#>
param(
    [Parameter(Mandatory)][string]$Ip,
    [Parameter(Mandatory)][string]$Wgt,
    [Parameter(Mandatory)][string]$AppId,   # <paquete>.<Nombre>, de config.xml
    [string]$Sdb = 'C:\tizentv-tools\sdb\sdb.exe'
)
$ErrorActionPreference = 'Stop'
$destino = "${Ip}:26101"
$remoto  = '/home/owner/share/tmp/sdk_tools/'
if (-not (Test-Path $Wgt)) { throw "No existe $Wgt" }
$archivo = Split-Path $Wgt -Leaf

& $Sdb connect $Ip | Out-Null

Write-Host '== Subiendo paquete' -ForegroundColor Cyan
& $Sdb -s $destino push $Wgt $remoto | Select-Object -Last 2

Write-Host '== Desinstalando versión previa (si existe)' -ForegroundColor Cyan
& $Sdb -s $destino shell 0 vd_appuninstall $AppId 2>&1 | Select-Object -Last 2

Write-Host '== Instalando' -ForegroundColor Cyan
$salida = & $Sdb -s $destino shell 0 vd_appinstall $AppId "$remoto$archivo" 2>&1 | Out-String
$salida.Trim().Split("`n") | Select-Object -Last 4
if ($salida -notmatch 'install completed') {
    throw "El dispositivo rechazó la instalación. Revisa el certificado/DUID.`n$salida"
}

Write-Host '== Ejecutando' -ForegroundColor Cyan
$ej = & $Sdb -s $destino shell 0 execute $AppId 2>&1 | Out-String
$ej.Trim()
if ($ej -notmatch 'successfully launched') { throw "No se pudo ejecutar la app.`n$ej" }
Write-Host 'OK: la app está instalada y en ejecución.' -ForegroundColor Green
