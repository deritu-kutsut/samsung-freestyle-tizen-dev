<#
.SYNOPSIS
  Conecta por SDB a un dispositivo Samsung/Tizen y muestra su estado.
.EXAMPLE
  .\verificar-conexion.ps1 -Ip 192.168.1.50
  .\verificar-conexion.ps1 -Ip 192.168.1.50 -MostrarDuid
#>
param(
    [Parameter(Mandatory)][string]$Ip,
    [string]$Sdb = 'C:\tizentv-tools\sdb\sdb.exe',
    [switch]$MostrarDuid
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Sdb)) { throw "No se encuentra SDB en $Sdb" }
$destino = "${Ip}:26101"

Write-Host "== Red: $Ip" -ForegroundColor Cyan
if (-not (Test-Connection $Ip -Count 2 -Quiet)) { Write-Warning 'El dispositivo no responde al ping.' }
$tcp = Test-NetConnection $Ip -Port 26101 -WarningAction SilentlyContinue
Write-Host "Puerto 26101 accesible: $($tcp.TcpTestSucceeded)"

Write-Host "== SDB" -ForegroundColor Cyan
& $Sdb version
& $Sdb connect $Ip
& $Sdb devices

Write-Host "== Capacidades relevantes" -ForegroundColor Cyan
& $Sdb -s $destino capability | Select-String 'profile_name|vendor_name|platform_version|cpu_arch|filesync_support|sdbd_rootperm'

if ($MostrarDuid) {
    Write-Host "== DUID" -ForegroundColor Cyan
    & $Sdb -s $destino shell 0 getduid
} else {
    Write-Host 'Añade -MostrarDuid para mostrar el DUID (identificador del dispositivo; no lo publiques).'
}
