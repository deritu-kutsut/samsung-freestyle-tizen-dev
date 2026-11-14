<#
.SYNOPSIS
  Lanza una app instalada en modo depuración y abre el inspector remoto en un navegador Chromium.
.EXAMPLE
  .\depurar.ps1 -Ip 192.168.1.50 -AppId AbCdEfGhIj.MiApp -Navegador "C:\Program Files\...\navegador.exe"
#>
param(
    [Parameter(Mandatory)][string]$Ip,
    [Parameter(Mandatory)][string]$AppId,
    [Parameter(Mandatory)][string]$Navegador,
    [string]$Sdb = 'C:\tizentv-tools\sdb\sdb.exe'
)
$ErrorActionPreference = 'Stop'
$destino = "${Ip}:26101"
if (-not (Test-Path $Navegador)) { throw "No existe $Navegador" }

& $Sdb connect $Ip | Out-Null

# 'debug' puede quedarse bloqueado si la app ya está abierta: se ejecuta con límite de tiempo.
$o = Join-Path $env:TEMP 'tizen-debug-out.txt'
$e = Join-Path $env:TEMP 'tizen-debug-err.txt'
$p = Start-Process $Sdb -ArgumentList '-s', $destino, 'shell', '0', 'debug', $AppId -PassThru -NoNewWindow `
        -RedirectStandardOutput $o -RedirectStandardError $e
Start-Sleep -Seconds 15
if (-not $p.HasExited) {
    Stop-Process -Id $p.Id -Force
    throw 'sdb debug no respondió. Reinstala la app (vd_appuninstall + vd_appinstall) y reintenta.'
}
$texto = (Get-Content $o, $e -ErrorAction SilentlyContinue) -join "`n"
if ($texto -notmatch 'port:\s*(\d+)') { throw "No se obtuvo el puerto de depuración.`n$texto" }
$puerto = $Matches[1]
Write-Host "Puerto de depuración: $puerto"

$paginas = Invoke-RestMethod "http://${Ip}:$puerto/json" -TimeoutSec 10
$url = "http://${Ip}:$puerto" + $paginas[0].devtoolsFrontendUrl
Write-Host "Inspector: $url"
Start-Process $Navegador -ArgumentList '--new-window', $url
