<#
.SYNOPSIS
  Guarda las contraseñas de un perfil Samsung (creado con el Certificate Manager de Tizen Studio)
  en el formato que entiende la extensión tizentv.

.DESCRIPTION
  Pide las contraseñas por teclado (no se muestran ni se guardan en claro), comprueba que abren
  los .p12, las cifra con la herramienta oficial de tizentv y actualiza su profiles.xml.
  Si una contraseña no abre su certificado, no se modifica nada.

  Nota: la contraseña se pasa un instante como argumento a wincrypt.exe, por lo que podría verse
  en la lista de procesos de tu propio equipo durante esa fracción de segundo.

.EXAMPLE
  .\reguardar-password.ps1 -Perfil freestyle-samsung `
      -AuthorP12 "$env:USERPROFILE\SamsungCertificate\freestyle-samsung\author.p12" `
      -DistributorP12 "$env:USERPROFILE\SamsungCertificate\freestyle-samsung\distributor.p12"
#>
param(
    [Parameter(Mandatory)][string]$Perfil,
    [Parameter(Mandatory)][string]$AuthorP12,
    [Parameter(Mandatory)][string]$DistributorP12,
    [string]$Perfiles = "$env:USERPROFILE\tizen-studio-data\vscode-tizentv\resource\profiles.xml",
    [string]$Wincrypt = 'C:\tizentv-tools\certificate-encryptor\wincrypt.exe'
)
$ErrorActionPreference = 'Stop'

$dirClaves = Join-Path (Split-Path $Perfiles -Parent) 'Author'
$pwdAuthor = Join-Path $dirClaves "$Perfil-author.pwd"
$pwdDist   = Join-Path $dirClaves "$Perfil-distributor.pwd"

foreach ($f in $Wincrypt, $AuthorP12, $DistributorP12, $Perfiles) {
    if (-not (Test-Path $f)) { throw "No existe: $f" }
}

function Read-Plain($mensaje) {
    $s = Read-Host $mensaje -AsSecureString
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Test-P12($archivo, $clave) {
    try { $null = New-Object Security.Cryptography.X509Certificates.X509Certificate2($archivo, $clave); $true }
    catch { $false }
}

function Save-Pwd($clave, $archivo) {
    if ($clave.Contains('"')) { throw 'La contraseña no puede contener comillas dobles.' }
    & $Wincrypt --encrypt "$clave" $archivo | Out-Null
    if (-not (Test-Path $archivo)) { throw "No se creó $archivo" }
}

$a = Read-Plain 'Contraseña del certificado AUTHOR'
if (-not (Test-P12 $AuthorP12 $a)) { throw 'Esa contraseña NO abre el certificado Author. No se cambió nada.' }
$d = Read-Plain 'Contraseña del certificado DISTRIBUTOR'
if (-not (Test-P12 $DistributorP12 $d)) { throw 'Esa contraseña NO abre el certificado Distributor. No se cambió nada.' }

Copy-Item $Perfiles "$Perfiles.bak-pwd" -Force
Save-Pwd $a $pwdAuthor
Save-Pwd $d $pwdDist
$a = $null; $d = $null

[xml]$x = Get-Content $Perfiles
$p = $x.SelectSingleNode("//profile[@name='$Perfil']")
if (-not $p) { throw "El perfil '$Perfil' no existe en $Perfiles. Cópialo primero desde el profiles.xml del Certificate Manager." }
$items = $p.SelectNodes('profileitem')
$items[0].SetAttribute('password', $pwdAuthor)
$items[1].SetAttribute('password', $pwdDist)
$x.profiles.SetAttribute('active', $Perfil)
$x.Save($Perfiles)

Write-Host "Listo: contraseñas re-guardadas y perfil '$Perfil' activo en tizentv." -ForegroundColor Green
