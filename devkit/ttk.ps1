<#
.SYNOPSIS
  Tizen TV Dev Kit · línea de comandos.
.EXAMPLE
  .\ttk.ps1 doctor
  .\ttk.ps1 conectar 192.168.1.50
  .\ttk.ps1 nuevo MiApp
  .\ttk.ps1 todo            # compila, instala y abre el proyecto actual
#>
param(
    [Parameter(Position = 0)][string]$Comando = 'ayuda',
    [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Resto
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\Nucleo.psm1') -Force -DisableNameChecking

function Get-ProyectoActual {
    if ($Resto -and $Resto[0] -and (Test-Path $Resto[0])) { $r = (Resolve-Path $Resto[0]).Path; Set-TtkConfig @{ Proyecto = $r }; return $r }
    if (Test-Path (Join-Path (Get-Location) 'config.xml')) { return (Get-Location).Path }
    $p = (Get-TtkConfig).Proyecto
    if (-not $p) { throw 'No hay proyecto. Usa: ttk nuevo <Nombre>, o pasa la ruta del proyecto.' }
    $p
}

function Show-Ayuda {
    @"
Tizen TV Dev Kit $(Get-TtkVersion) · herramienta no oficial

PREPARAR EL PC
  doctor                    Comprueba todos los requisitos
  instalar-tizentv          Instala la extensión tizentv en VS Code
  instalar-sdb              Descarga SDB oficial y verifica su SHA-256
  instalar-certmanager      Descarga el instalador oficial (firma verificada) y lo abre

PROYECTOR
  conectar <ip>             Conecta por SDB y guarda la IP
  info                      Plataforma, CPU y versión de Tizen
  duid                      Muestra el DUID (para el certificado)

CERTIFICADO
  perfiles                  Lista los perfiles del Certificate Manager
  importar-perfil <nombre>  Lo activa en tizentv (pide las contraseñas)

APPS
  nuevo <Nombre> [carpeta]  Crea un proyecto desde la plantilla
  compilar [proyecto]       Empaqueta y firma el .wgt
  instalar [proyecto]       Instala comprobando la respuesta real
  abrir [proyecto]          Abre la app en el proyector
  todo [proyecto]           Compilar + instalar + abrir
  depurar [proyecto]        Instala, abre en modo depuración y lanza el inspector
  desinstalar [proyecto]    Quita la app del proyector
  config                    Muestra la configuración
"@ | Write-Host
}

try {
    switch ($Comando.ToLower()) {
        'ayuda' { Show-Ayuda }
        'doctor' {
            foreach ($c in Test-TtkEntorno) {
                $m = if ($c.Ok) { 'ok' } else { 'aviso' }
                Write-TtkLog ("{0,-32} {1}" -f $c.Requisito, $c.Detalle) $m
                if (-not $c.Ok) { Write-TtkLog "   -> $($c.Solucion)" info }
            }
        }
        'instalar-tizentv' { Install-TtkTizentv }
        'instalar-sdb' { Install-TtkSdb }
        'instalar-certmanager' { Install-TtkCertificateManager }
        'conectar' { Connect-TtkProyector -Ip ($Resto | Select-Object -First 1) | Format-List }
        'info' { Get-TtkInfoProyector | Format-List }
        'duid' { Write-Host (Get-TtkDuid) }
        'perfiles' { Get-TtkPerfilesCertificateManager | Select-Object Nombre, Origen | Format-Table -AutoSize }
        'importar-perfil' {
            $n = $Resto | Select-Object -First 1
            if (-not $n) { throw 'Indica el nombre del perfil (ver: ttk perfiles).' }
            $a = Read-Host 'Contraseña del certificado AUTHOR' -AsSecureString
            $d = Read-Host 'Contraseña del certificado DISTRIBUTOR' -AsSecureString
            Import-TtkPerfilSamsung -Nombre $n -ClaveAuthor $a -ClaveDistributor $d
        }
        'nuevo' {
            $n = $Resto | Select-Object -First 1
            $c = $Resto | Select-Object -Skip 1 -First 1
            New-TtkProyecto -Nombre $n -Carpeta $c | Format-List
        }
        'compilar' { $null = Build-TtkWgt (Get-ProyectoActual) }
        'instalar' { $null = Install-TtkApp (Get-ProyectoActual) }
        'abrir' { Start-TtkApp (Get-ProyectoActual) }
        'todo' { Invoke-TtkTodo (Get-ProyectoActual) }
        'depurar' { $null = Start-TtkDepuracion (Get-ProyectoActual) }
        'desinstalar' { Remove-TtkApp (Get-ProyectoActual) }
        'config' { Get-TtkConfig | Format-List }
        default { Write-TtkLog "Comando desconocido: $Comando" error; Show-Ayuda; exit 64 }
    }
} catch {
    Write-TtkLog $_.Exception.Message error
    exit 1
}
