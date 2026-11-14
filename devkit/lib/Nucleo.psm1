# Tizen TV Dev Kit · núcleo compartido por la interfaz gráfica y la línea de comandos.
# Herramienta no oficial; no está afiliada a Samsung.

$script:Raiz          = Split-Path $PSScriptRoot -Parent
$script:DirConfig     = Join-Path $env:APPDATA 'TizenTVDevKit'
$script:ArchivoConfig = Join-Path $script:DirConfig 'config.json'
$script:RemotoTmp     = '/home/owner/share/tmp/sdk_tools/'
$script:UrlPaquetes   = 'http://download.tizen.org/sdk/tizenstudio/official'
$script:UrlInstalador = 'https://download.tizen.org/sdk/Installer/tizen-studio_6.1/web-ide_Tizen_Studio_6.1_windows-64.exe'
$script:Version       = '1.0.0'

# ---------------------------------------------------------------- registro
function Write-TtkLog {
    param([string]$Texto, [ValidateSet('info', 'ok', 'aviso', 'error', 'paso')][string]$Tipo = 'info')
    $marca = @{ info = '  '; ok = 'OK'; aviso = '!!'; error = 'XX'; paso = '>>' }[$Tipo]
    $linea = "[$marca] $Texto"
    if ($global:TtkCola) { $global:TtkCola.Enqueue("$Tipo|$linea") }
    else {
        $color = @{ info = 'Gray'; ok = 'Green'; aviso = 'Yellow'; error = 'Red'; paso = 'Cyan' }[$Tipo]
        Write-Host $linea -ForegroundColor $color
    }
}

function Get-TtkVersion { $script:Version }

# ---------------------------------------------------------------- configuración
function Find-TtkNavegador {
    $candidatos = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )
    $candidatos | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

function Get-TtkConfig {
    $c = [ordered]@{
        Ip        = ''
        IpPc      = ''
        Sdb       = 'C:\tizentv-tools\sdb\sdb.exe'
        Perfiles  = Join-Path $env:USERPROFILE 'tizen-studio-data\vscode-tizentv\resource\profiles.xml'
        Navegador = ''
        Proyecto  = ''
        Proyectos = Join-Path $env:USERPROFILE 'tizen-apps'
    }
    if (Test-Path $script:ArchivoConfig) {
        try {
            $leido = Get-Content $script:ArchivoConfig -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $leido.PSObject.Properties) { if ($null -ne $p.Value) { $c[$p.Name] = $p.Value } }
        } catch { Write-TtkLog "Configuración dañada; se usan valores por defecto." aviso }
    }
    if (-not $c.Navegador) { $c.Navegador = Find-TtkNavegador }
    if (-not $c.IpPc) { $c.IpPc = Get-TtkIpLocal }
    [pscustomobject]$c
}

function Set-TtkConfig {
    param([Parameter(Mandatory)][hashtable]$Valores)
    $actual = Get-TtkConfig
    $tabla = [ordered]@{}
    foreach ($p in $actual.PSObject.Properties) { $tabla[$p.Name] = $p.Value }
    foreach ($k in $Valores.Keys) { $tabla[$k] = $Valores[$k] }
    New-Item -ItemType Directory -Force $script:DirConfig | Out-Null
    [pscustomobject]$tabla | ConvertTo-Json | Set-Content $script:ArchivoConfig -Encoding UTF8
}

function Get-TtkIpLocal {
    try {
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
            Sort-Object InterfaceMetric | Select-Object -First 1 -ExpandProperty IPAddress
    } catch { '' }
}

# ---------------------------------------------------------------- utilidades de procesos
function Invoke-TtkProceso {
    param([Parameter(Mandatory)][string]$Exe, [string[]]$Argumentos = @(), [int]$TimeoutSeg = 120)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.Arguments = ($Argumentos | ForEach-Object {
            if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $o = $p.StandardOutput.ReadToEndAsync()
    $e = $p.StandardError.ReadToEndAsync()
    $termino = $p.WaitForExit($TimeoutSeg * 1000)
    if (-not $termino) { try { $p.Kill() } catch {} }
    [void]$o.Wait(3000); [void]$e.Wait(3000)
    $salida = ''
    if ($o.IsCompleted) { $salida += $o.Result }
    if ($e.IsCompleted) { $salida += $e.Result }
    [pscustomobject]@{ Codigo = $(if ($termino) { $p.ExitCode } else { -1 }); Salida = $salida.Trim(); TiempoAgotado = -not $termino }
}

function Get-TtkSdb {
    $sdb = (Get-TtkConfig).Sdb
    if (-not (Test-Path $sdb)) { throw "No se encuentra SDB en $sdb. Usa 'Instalar SDB' en el asistente." }
    $sdb
}

function Start-TtkServidorSdb {
    # Se arranca sin redirigir salidas: el servidor de SDB hereda los manejadores y bloquearía la lectura.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = Get-TtkSdb
    $psi.Arguments = 'start-server'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    [void]$p.WaitForExit(15000)
}

function Invoke-TtkSdb {
    param([string[]]$Argumentos, [int]$TimeoutSeg = 60)
    Start-TtkServidorSdb
    Invoke-TtkProceso -Exe (Get-TtkSdb) -Argumentos $Argumentos -TimeoutSeg $TimeoutSeg
}

function Get-TtkDestino {
    $ip = (Get-TtkConfig).Ip
    if (-not $ip) { throw 'No hay IP del proyector configurada.' }
    "${ip}:26101"
}

# ---------------------------------------------------------------- herramientas externas
function Find-TtkTizentv {
    $dir = Join-Path $env:USERPROFILE '.vscode\extensions'
    if (-not (Test-Path $dir)) { return $null }
    Get-ChildItem $dir -Directory -Filter 'tizensdk.tizentv-*' | Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
}

function Find-TtkSdkTizen {
    # Devuelve las instalaciones de Tizen Studio (ruta de programa y de datos) leyendo sdk.info.
    $raices = @('C:\TizenStudioIDE', 'C:\TizenSDK', 'C:\tizen-studio', "$env:USERPROFILE\tizen-studio")
    foreach ($r in $raices) {
        $info = Join-Path $r 'sdk.info'
        if (Test-Path $info) {
            $t = Get-Content $info -Raw
            $datos = if ($t -match 'TIZEN_SDK_DATA_PATH=(.+)') { $Matches[1].Trim() } else { "$r-data" }
            [pscustomobject]@{ Ruta = $r; Datos = $datos }
        }
    }
}

function Find-TtkCertificateManager {
    foreach ($s in Find-TtkSdkTizen) {
        $exe = Join-Path $s.Ruta 'tools\certificate-manager\certificate-manager.exe'
        if (Test-Path $exe) { return [pscustomobject]@{ Exe = $exe; Sdk = $s.Ruta; Datos = $s.Datos } }
    }
}

function Find-TtkPackageManager {
    foreach ($s in Find-TtkSdkTizen) {
        $exe = Join-Path $s.Ruta 'package-manager\package-manager.exe'
        if (Test-Path $exe) { return $exe }
    }
}

function Start-TtkCertificateManager {
    $cm = Find-TtkCertificateManager
    if (-not $cm) { throw "No está instalado. Usa 'Instalar Certificate Manager'." }
    # Con sdb.exe en <SDK>\tools, el Certificate Manager detecta solo el DUID del proyector conectado.
    $sdbSdk = Join-Path $cm.Sdk 'tools\sdb.exe'
    $sdb = (Get-TtkConfig).Sdb
    if (-not (Test-Path $sdbSdk) -and (Test-Path $sdb)) {
        Copy-Item (Join-Path (Split-Path $sdb -Parent) '*') (Join-Path $cm.Sdk 'tools') -Include sdb.exe, ansicon.exe, ANSI32.dll -Force
    }
    $dirCm = Split-Path $cm.Exe -Parent
    $javaw = Join-Path $cm.Sdk 'jdk\bin\javaw.exe'
    $lanzador = Get-ChildItem (Join-Path $dirCm 'plugins') -Filter 'org.eclipse.equinox.launcher_*.jar' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ((Test-Path $javaw) -and $lanzador) {
        # El ejecutable nativo a veces no arranca; el lanzador Java con el JDK del SDK es fiable.
        Start-Process $javaw -ArgumentList '-jar', "`"$($lanzador.FullName)`"" -WorkingDirectory $dirCm
    } else {
        if (-not (Test-Path $javaw)) { Write-TtkLog "Falta el JDK del SDK ($javaw): reinstala desde el Package Manager si no abre." aviso }
        Start-Process $cm.Exe -WorkingDirectory $dirCm
    }
    Write-TtkLog 'Certificate Manager abierto. Pulsa "+" -> Samsung -> TV y sigue el asistente.' ok
}

# ---------------------------------------------------------------- diagnóstico
function Test-TtkEntorno {
    $cfg = Get-TtkConfig
    $r = New-Object System.Collections.Generic.List[object]
    function Add-R($n, $ok, $d, $s) { $r.Add([pscustomobject]@{ Requisito = $n; Ok = $ok; Detalle = $d; Solucion = $s }) }

    $node = Get-Command node -ErrorAction SilentlyContinue
    Add-R 'Node.js' ([bool]$node) $(if ($node) { (& node -v) } else { 'no encontrado' }) 'Instala Node.js LTS desde nodejs.org'

    $code = Get-Command code -ErrorAction SilentlyContinue
    Add-R 'Visual Studio Code' ([bool]$code) $(if ($code) { 'instalado' } else { 'no encontrado' }) 'Instala VS Code desde code.visualstudio.com'

    $ext = Find-TtkTizentv
    Add-R 'Extensión tizentv' ([bool]$ext) $(if ($ext) { Split-Path $ext -Leaf } else { 'no instalada' }) "Botón 'Instalar extensión tizentv'"

    $sdbOk = Test-Path $cfg.Sdb
    Add-R 'SDB' $sdbOk $(if ($sdbOk) { $cfg.Sdb } else { 'no instalado' }) "Botón 'Instalar SDB'"

    Add-R 'Navegador Chromium' ([bool]$cfg.Navegador) $(if ($cfg.Navegador) { $cfg.Navegador } else { 'no encontrado' }) 'Instala Chrome, Edge o Brave (para depurar)'

    $cm = Find-TtkCertificateManager
    Add-R 'Certificate Manager' ([bool]$cm) $(if ($cm) { $cm.Exe } else { 'no instalado' }) "Botón 'Instalar Certificate Manager'"

    $perfil = Get-TtkPerfilActivo
    $perfilOk = $perfil -and $perfil.EsSamsung
    $det = if (-not $perfil) { 'sin perfil activo' } elseif ($perfil.EsSamsung) { "$($perfil.Nombre) (Samsung)" } else { "$($perfil.Nombre) (genérico de Tizen: el proyector lo rechazará)" }
    Add-R 'Perfil de certificado Samsung' $perfilOk $det "Crea el perfil en Certificate Manager y usa 'Importar perfil Samsung'"

    $ipOk = $false; $detIp = 'sin configurar'
    if ($cfg.Ip) {
        $tcp = Test-NetConnection $cfg.Ip -Port 26101 -WarningAction SilentlyContinue -InformationLevel Quiet
        $ipOk = [bool]$tcp; $detIp = "$($cfg.Ip):26101 " + $(if ($tcp) { 'accesible' } else { 'no responde' })
    }
    Add-R 'Proyector (modo desarrollador)' $ipOk $detIp 'Activa Developer Mode con la IP de este PC y reinicia el proyector'
    $r
}

# ---------------------------------------------------------------- instalación de requisitos
function Install-TtkTizentv {
    $code = Get-Command code -ErrorAction SilentlyContinue
    if (-not $code) { throw 'VS Code no está instalado o no está en el PATH.' }
    Write-TtkLog 'Instalando la extensión tizentv en VS Code...' paso
    $r = Invoke-TtkProceso -Exe $code.Source -Argumentos @('--install-extension', 'tizensdk.tizentv') -TimeoutSeg 300
    if ($r.Salida -notmatch 'successfully installed|already installed') { throw "No se pudo instalar: $($r.Salida)" }
    Write-TtkLog 'Extensión tizentv instalada.' ok
}

function Get-TtkPaqueteTizen {
    param([Parameter(Mandatory)][string]$Nombre)
    $bytes = (Invoke-WebRequest -UseBasicParsing "$script:UrlPaquetes/pkg_list_windows-64" -TimeoutSec 60).Content
    $texto = if ($bytes -is [byte[]]) { [Text.Encoding]::UTF8.GetString($bytes) } else { [string]$bytes }
    foreach ($bloque in ($texto -split "\r?\n(?=Package : )")) {
        if ($bloque -match "^Package : $([regex]::Escape($Nombre))\s*\r?\n") {
            $campos = @{}
            foreach ($l in $bloque -split "\r?\n") { if ($l -match '^(\w[\w-]*) : (.*)$') { $campos[$Matches[1]] = $Matches[2].Trim() } }
            return [pscustomobject]@{ Version = $campos.Version; Ruta = $campos.Path; Sha256 = $campos.SHA256; Bytes = [int64]$campos.Size }
        }
    }
    throw "No se encontró el paquete $Nombre en el repositorio oficial."
}

function Install-TtkSdb {
    $cfg = Get-TtkConfig
    Write-TtkLog 'Consultando el repositorio oficial de Tizen...' paso
    $pkg = Get-TtkPaqueteTizen -Nombre 'sdb'
    Write-TtkLog "SDB $($pkg.Version) · $([math]::Round($pkg.Bytes / 1MB, 1)) MB"
    $tmp = Join-Path $env:TEMP ("ttk-sdb-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        $zip = Join-Path $tmp 'sdb.zip'
        Invoke-WebRequest -UseBasicParsing "$script:UrlPaquetes$($pkg.Ruta)" -OutFile $zip -TimeoutSec 600
        $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
        if ($hash -ne $pkg.Sha256.ToUpper()) { throw "El SHA-256 no coincide (descarga dañada o alterada)." }
        Write-TtkLog 'SHA-256 verificado contra el listado oficial.' ok
        Expand-Archive $zip (Join-Path $tmp 'x') -Force
        $destino = Split-Path $cfg.Sdb -Parent
        New-Item -ItemType Directory -Force $destino | Out-Null
        Copy-Item (Join-Path $tmp 'x\data\tools\*') $destino -Recurse -Force
        $v = Invoke-TtkProceso -Exe $cfg.Sdb -Argumentos @('version')
        Write-TtkLog "Instalado: $($v.Salida)" ok
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

function Install-TtkCertificateManager {
    # Descarga el instalador oficial del IDE de Tizen Studio, verifica la firma de Samsung y lo abre.
    $dir = Join-Path $script:DirConfig 'descargas'
    New-Item -ItemType Directory -Force $dir | Out-Null
    $exe = Join-Path $dir (Split-Path $script:UrlInstalador -Leaf)
    if (-not (Test-Path $exe)) {
        Write-TtkLog 'Descargando el instalador oficial de Tizen Studio (~630 MB). Puede tardar varios minutos...' paso
        Invoke-WebRequest -UseBasicParsing $script:UrlInstalador -OutFile "$exe.part" -TimeoutSec 7200
        Move-Item "$exe.part" $exe -Force
    }
    $firma = Get-AuthenticodeSignature $exe
    if ($firma.Status -ne 'Valid' -or $firma.SignerCertificate.Subject -notmatch 'Samsung Electronics') {
        Remove-Item $exe -Force
        throw "Firma digital no válida ($($firma.Status)). Se eliminó el instalador."
    }
    Write-TtkLog 'Firma digital de Samsung Electronics verificada.' ok
    Write-TtkLog 'Se abre el instalador: acepta la licencia, instala en una carpeta NUEVA (p. ej. C:\TizenStudioIDE) y al final deja marcado "Launch the Package Manager".' aviso
    Write-TtkLog 'En el Package Manager: pestaña Extension SDK -> instalar "Samsung Certificate Extension".' aviso
    Start-Process $exe
}

# ---------------------------------------------------------------- proyector
function Connect-TtkProyector {
    param([string]$Ip)
    if ($Ip) { Set-TtkConfig @{ Ip = $Ip } }
    $ip = (Get-TtkConfig).Ip
    if (-not $ip) { throw 'Indica la IP del proyector.' }
    Write-TtkLog "Conectando con $ip ..." paso
    $r = Invoke-TtkSdb @('connect', $ip) -TimeoutSeg 30
    if ($r.Salida -notmatch 'connected to|already connected') {
        throw "No conecta: $($r.Salida). Revisa Developer Mode (Host PC IP = $((Get-TtkConfig).IpPc)), la red y reinicia el proyector."
    }
    $lista = (Invoke-TtkSdb @('devices')).Salida
    $linea = ($lista -split "\r?\n") | Where-Object { $_ -match [regex]::Escape($ip) } | Select-Object -First 1
    $modelo = if ($linea) { ($linea -split '\s+')[-1] } else { '?' }
    Write-TtkLog "Conectado a $modelo ($ip)" ok
    [pscustomobject]@{ Ip = $ip; Modelo = $modelo }
}

function Get-TtkInfoProyector {
    $r = Invoke-TtkSdb @('-s', (Get-TtkDestino), 'capability')
    $info = [ordered]@{}
    foreach ($l in $r.Salida -split "\r?\n") { if ($l -match '^([\w_]+):(.*)$') { $info[$Matches[1]] = $Matches[2].Trim() } }
    if (-not $info.Count) { throw "Sin respuesta del proyector: $($r.Salida)" }
    [pscustomobject]@{
        Fabricante = $info.vendor_name; Perfil = $info.profile_name; Tizen = $info.platform_version
        Cpu = $info.cpu_arch; Root = $info.sdbd_rootperm; Sdbd = $info.sdbd_version
    }
}

function Get-TtkDuid {
    $r = Invoke-TtkSdb @('-s', (Get-TtkDestino), 'shell', '0', 'getduid')
    $duid = ($r.Salida -split "\r?\n" | Where-Object { $_ -match '^[A-Z0-9]{8,}$' } | Select-Object -First 1)
    if (-not $duid) { throw "No se pudo leer el DUID: $($r.Salida)" }
    $duid
}

# ---------------------------------------------------------------- certificados
function Get-TtkPerfilActivo {
    $ruta = (Get-TtkConfig).Perfiles
    if (-not (Test-Path $ruta)) { return $null }
    [xml]$x = Get-Content $ruta
    $activo = $x.profiles.active
    if (-not $activo) { return $null }
    $nodo = $x.SelectSingleNode("//profile[@name='$activo']")
    if (-not $nodo) { return $null }
    $dist = $nodo.SelectNodes('profileitem') | Where-Object { $_.distributor -eq '1' } | Select-Object -First 1
    $generico = $dist -and ($dist.key -match 'tizen-distributor-signer|sdk-public|sdk-partner')
    [pscustomobject]@{ Nombre = $activo; EsSamsung = -not $generico }
}

function Get-TtkPerfilesCertificateManager {
    foreach ($s in Find-TtkSdkTizen) {
        $ruta = Join-Path $s.Datos 'profile\profiles.xml'
        if (Test-Path $ruta) {
            [xml]$x = Get-Content $ruta
            foreach ($p in $x.SelectNodes('//profile')) {
                $items = $p.SelectNodes('profileitem')
                [pscustomobject]@{
                    Nombre = $p.name; Origen = $ruta
                    Author = $items[0].key; Distributor = $items[1].key
                }
            }
        }
    }
}

function Find-TtkWincrypt {
    $c = 'C:\tizentv-tools\certificate-encryptor\wincrypt.exe'
    if (Test-Path $c) { return $c }
    # tizentv lo descarga en el primer uso; se fuerza la descarga con su propio módulo.
    $ext = Find-TtkTizentv
    if (-not $ext) { throw 'Falta la extensión tizentv.' }
    $tools = (Join-Path $ext 'node_modules\@tizentv\tools') -replace '\\', '/'
    $r = Invoke-TtkProceso -Exe 'node' -Argumentos @('-e', "require('$tools').getEncryptorPath().then(p=>console.log(p))") -TimeoutSeg 300
    $ruta = ($r.Salida -split "\r?\n" | Where-Object { $_ -match 'wincrypt\.exe$' } | Select-Object -Last 1)
    if (-not $ruta -or -not (Test-Path $ruta)) { throw "No se pudo obtener wincrypt.exe: $($r.Salida)" }
    $ruta
}

function ConvertFrom-TtkSecure([Security.SecureString]$s) {
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Test-TtkP12([string]$Archivo, [Security.SecureString]$Clave) {
    try { $null = New-Object Security.Cryptography.X509Certificates.X509Certificate2($Archivo, $Clave); $true } catch { $false }
}

function Import-TtkPerfilSamsung {
    <#
      Copia un perfil del Certificate Manager al profiles.xml de tizentv, guarda las contraseñas en el
      formato de tizentv (el cifrado del Certificate Manager no es compatible) y lo deja activo.
    #>
    param(
        [Parameter(Mandatory)][string]$Nombre,
        [Parameter(Mandatory)][Security.SecureString]$ClaveAuthor,
        [Parameter(Mandatory)][Security.SecureString]$ClaveDistributor
    )
    $origen = Get-TtkPerfilesCertificateManager | Where-Object Nombre -eq $Nombre | Select-Object -First 1
    if (-not $origen) { throw "No existe el perfil '$Nombre' en el Certificate Manager." }
    if (-not (Test-TtkP12 $origen.Author $ClaveAuthor)) { throw 'La contraseña Author no abre author.p12. No se cambió nada.' }
    if (-not (Test-TtkP12 $origen.Distributor $ClaveDistributor)) { throw 'La contraseña Distributor no abre distributor.p12. No se cambió nada.' }
    Write-TtkLog 'Contraseñas verificadas contra los certificados.' ok

    $perfiles = (Get-TtkConfig).Perfiles
    $dirRes = Split-Path $perfiles -Parent
    $dirClaves = Join-Path $dirRes 'Author'
    New-Item -ItemType Directory -Force $dirClaves | Out-Null
    if (-not (Test-Path $perfiles)) {
        Set-Content $perfiles '<?xml version="1.0" encoding="UTF-8" standalone="no"?><profiles active="" version="3.1"></profiles>' -Encoding UTF8
    } else {
        Copy-Item $perfiles "$perfiles.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
    }

    $wincrypt = Find-TtkWincrypt
    $pwdA = Join-Path $dirClaves "$Nombre-author.pwd"
    $pwdD = Join-Path $dirClaves "$Nombre-distributor.pwd"
    foreach ($par in @(@($ClaveAuthor, $pwdA), @($ClaveDistributor, $pwdD))) {
        $plano = ConvertFrom-TtkSecure $par[0]
        if ($plano.Contains('"')) { throw 'La contraseña no puede contener comillas dobles.' }
        $null = Invoke-TtkProceso -Exe $wincrypt -Argumentos @('--encrypt', $plano, $par[1])
        $plano = $null
        if (-not (Test-Path $par[1])) { throw "No se pudo cifrar la contraseña en $($par[1])." }
    }

    [xml]$x = Get-Content $perfiles
    $viejo = $x.SelectSingleNode("//profile[@name='$Nombre']")
    if ($viejo) { [void]$x.profiles.RemoveChild($viejo) }
    $p = $x.CreateElement('profile'); $p.SetAttribute('name', $Nombre)
    foreach ($d in @(@('0', $origen.Author, $pwdA), @('1', $origen.Distributor, $pwdD), @('2', '', ''))) {
        $i = $x.CreateElement('profileitem')
        $i.SetAttribute('ca', ''); $i.SetAttribute('distributor', $d[0]); $i.SetAttribute('key', $d[1])
        $i.SetAttribute('password', $d[2]); $i.SetAttribute('rootca', '')
        [void]$p.AppendChild($i)
    }
    [void]$x.profiles.AppendChild($p)
    $x.profiles.SetAttribute('active', $Nombre)
    $x.Save($perfiles)
    Write-TtkLog "Perfil '$Nombre' importado y activo para tizentv." ok
}

# ---------------------------------------------------------------- proyectos
function Get-TtkProyecto {
    param([Parameter(Mandatory)][string]$Ruta)
    $cfgXml = Join-Path $Ruta 'config.xml'
    if (-not (Test-Path $cfgXml)) { throw "No es un proyecto Tizen (falta config.xml): $Ruta" }
    [xml]$x = Get-Content $cfgXml -Encoding UTF8
    $ns = New-Object Xml.XmlNamespaceManager $x.NameTable
    $ns.AddNamespace('w', 'http://www.w3.org/ns/widgets'); $ns.AddNamespace('tizen', 'http://tizen.org/ns/widgets')
    $app = $x.SelectSingleNode('//tizen:application', $ns)
    $nombre = $x.SelectSingleNode('//w:name', $ns).InnerText.Trim()
    [pscustomobject]@{ Ruta = (Resolve-Path $Ruta).Path; Nombre = $nombre; AppId = $app.id; Wgt = Join-Path $Ruta "$nombre.wgt" }
}

function New-TtkProyecto {
    param([Parameter(Mandatory)][string]$Nombre, [string]$Carpeta)
    if ($Nombre -notmatch '^[A-Za-z][A-Za-z0-9]{0,49}$') { throw 'El nombre debe empezar por letra y tener solo letras y números (sin espacios).' }
    if (-not $Carpeta) { $Carpeta = (Get-TtkConfig).Proyectos }
    $destino = Join-Path $Carpeta $Nombre
    if ((Test-Path $destino) -and (Get-ChildItem $destino -Force | Select-Object -First 1)) { throw "La carpeta ya existe y no está vacía: $destino" }
    $datosTizentv = Split-Path (Split-Path (Get-TtkConfig).Perfiles -Parent) -Parent
    if ($destino.StartsWith($datosTizentv, [StringComparison]::OrdinalIgnoreCase)) { throw 'No crees proyectos dentro de la carpeta de datos de tizentv: el paquete incluiría tus claves.' }

    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $rng = New-Object Random
    $paquete = -join (1..10 | ForEach-Object { $chars[$rng.Next($chars.Length)] })

    New-Item -ItemType Directory -Force $destino | Out-Null
    Copy-Item (Join-Path $script:Raiz 'plantilla\*') $destino -Recurse -Force
    foreach ($f in Get-ChildItem $destino -Recurse -File -Include *.xml, *.html, *.js, *.css) {
        $t = [IO.File]::ReadAllText($f.FullName)
        $t = $t.Replace('{{NOMBRE}}', $Nombre).Replace('{{PAQUETE}}', $paquete)
        [IO.File]::WriteAllText($f.FullName, $t, (New-Object Text.UTF8Encoding($false)))
    }
    Set-TtkConfig @{ Proyecto = $destino }
    Write-TtkLog "Proyecto creado: $destino (id $paquete.$Nombre)" ok
    Get-TtkProyecto $destino
}

function Build-TtkWgt {
    param([Parameter(Mandatory)][string]$Ruta)
    $p = Get-TtkProyecto $Ruta
    $claves = Get-ChildItem $p.Ruta -Recurse -File -Include *.p12, *.pwd -ErrorAction SilentlyContinue
    if ($claves) { throw "Hay claves privadas dentro del proyecto ($($claves[0].Name)). Sácalas antes de empaquetar." }
    $perfil = Get-TtkPerfilActivo
    if (-not $perfil) { throw 'No hay perfil de certificado activo.' }
    if (-not $perfil.EsSamsung) { Write-TtkLog "El perfil '$($perfil.Nombre)' es genérico de Tizen: el proyector rechazará la instalación." aviso }
    $ext = Find-TtkTizentv
    if (-not $ext) { throw 'Falta la extensión tizentv de VS Code.' }
    Write-TtkLog "Compilando y firmando '$($p.Nombre)' con el perfil '$($perfil.Nombre)'..." paso
    $r = Invoke-TtkProceso -Exe 'node' -Argumentos @((Join-Path $script:Raiz 'lib\build-wgt.js'), $p.Ruta, (Get-TtkConfig).Perfiles, $ext) -TimeoutSeg 300
    if ($r.Salida -match 'MAC could not be verified|Invalid password') { throw "Contraseña del certificado no válida para tizentv. Usa 'Importar perfil Samsung' de nuevo." }
    if ($r.Salida -notmatch 'BUILD_OK' -or -not (Test-Path $p.Wgt)) { throw "Falló el empaquetado:`n$($r.Salida)" }
    $kb = [math]::Round((Get-Item $p.Wgt).Length / 1KB)
    Write-TtkLog "Paquete firmado: $($p.Wgt) ($kb KB)" ok
    $p
}

function Install-TtkApp {
    param([Parameter(Mandatory)][string]$Ruta)
    $p = Get-TtkProyecto $Ruta
    if (-not (Test-Path $p.Wgt)) { throw 'No hay paquete .wgt: compila primero.' }
    $dest = Get-TtkDestino
    $null = Connect-TtkProyector
    Write-TtkLog 'Subiendo el paquete al proyector...' paso
    $push = Invoke-TtkSdb @('-s', $dest, 'push', $p.Wgt, $script:RemotoTmp) -TimeoutSeg 300
    if ($push.Salida -notmatch '1 file\(s\) pushed') { throw "No se pudo subir: $($push.Salida)" }
    $null = Invoke-TtkSdb @('-s', $dest, 'shell', '0', 'vd_appuninstall', $p.AppId) -TimeoutSeg 120
    Write-TtkLog 'Instalando...' paso
    $ins = Invoke-TtkSdb @('-s', $dest, 'shell', '0', 'vd_appinstall', $p.AppId, "$($script:RemotoTmp)$($p.Nombre).wgt") -TimeoutSeg 300
    if ($ins.Salida -notmatch 'install completed') {
        $motivo = ($ins.Salida -split "\r?\n" | Where-Object { $_ -match 'failed|reason' } | Select-Object -First 1)
        if ($ins.Salida -match 'certificate') { $motivo += ' -> El certificado no es válido para este proyector (¿perfil genérico o DUID distinto?).' }
        throw "El proyector rechazó la instalación: $motivo"
    }
    Write-TtkLog 'Instalación completada en el proyector.' ok
    $p
}

function Start-TtkApp {
    param([Parameter(Mandatory)][string]$Ruta)
    $p = Get-TtkProyecto $Ruta
    $r = Invoke-TtkSdb @('-s', (Get-TtkDestino), 'shell', '0', 'execute', $p.AppId) -TimeoutSeg 60
    if ($r.Salida -notmatch 'successfully launched') { throw "No se pudo abrir la app: $($r.Salida)" }
    Write-TtkLog "App '$($p.Nombre)' abierta en el proyector." ok
}

function Invoke-TtkTodo {
    param([Parameter(Mandatory)][string]$Ruta)
    $null = Build-TtkWgt $Ruta
    $null = Install-TtkApp $Ruta
    Start-TtkApp $Ruta
}

function Start-TtkDepuracion {
    param([Parameter(Mandatory)][string]$Ruta)
    $cfg = Get-TtkConfig
    if (-not $cfg.Navegador) { throw 'No hay navegador Chromium para el inspector.' }
    # Reinstalar evita que 'debug' se bloquee si la app ya estaba abierta.
    $p = Install-TtkApp $Ruta
    Write-TtkLog 'Abriendo en modo depuración...' paso
    $r = Invoke-TtkSdb @('-s', (Get-TtkDestino), 'shell', '0', 'debug', $p.AppId) -TimeoutSeg 30
    if ($r.Salida -notmatch 'port:\s*(\d+)') { throw "No se obtuvo el puerto de depuración: $($r.Salida)" }
    $puerto = $Matches[1]
    $paginas = Invoke-RestMethod "http://$($cfg.Ip):$puerto/json" -TimeoutSec 15
    $url = "http://$($cfg.Ip):$puerto" + @($paginas)[0].devtoolsFrontendUrl
    Start-Process $cfg.Navegador -ArgumentList '--new-window', $url
    Write-TtkLog "Inspector abierto (puerto $puerto)." ok
    $url
}

function Remove-TtkApp {
    param([Parameter(Mandatory)][string]$Ruta)
    $p = Get-TtkProyecto $Ruta
    $r = Invoke-TtkSdb @('-s', (Get-TtkDestino), 'shell', '0', 'vd_appuninstall', $p.AppId) -TimeoutSeg 120
    if ($r.Salida -match 'uninstall completed') { Write-TtkLog "App '$($p.Nombre)' desinstalada." ok }
    else { Write-TtkLog "Respuesta: $($r.Salida)" aviso }
}

Export-ModuleMember -Function *-Ttk*
