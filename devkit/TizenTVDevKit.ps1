# Tizen TV Dev Kit · interfaz gráfica (Windows Forms). Herramienta no oficial.
param([ValidateSet(1, 2)][int]$Pestana = 1)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace Ttk -Name Win -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][Ttk.Win]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()
# Escalado manual según los DPI del monitor: las fuentes en puntos ya escalan solas; las posiciones, no.
$g0 = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $script:EscalaDpi = $g0.DpiX / 96; $g0.Dispose()
function S([double]$v) { [int][math]::Round($v * $script:EscalaDpi) }

$Modulo = Join-Path $PSScriptRoot 'lib\Nucleo.psm1'
Import-Module $Modulo -Force -DisableNameChecking
$script:Cola = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
$script:Tarea = $null
$script:Botones = New-Object System.Collections.Generic.List[object]

# ---------------------------------------------------------------- estilo
$cFondo = [Drawing.Color]::FromArgb(248, 250, 252)
$cAcento = [Drawing.Color]::FromArgb(30, 64, 175)
$fTitulo = New-Object Drawing.Font('Segoe UI', 10.5, [Drawing.FontStyle]::Bold)
$fDesc = New-Object Drawing.Font('Segoe UI', 8.5)
$fNormal = New-Object Drawing.Font('Segoe UI', 9.5)

function New-Ctl([string]$Tipo, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Texto = '') {
    $c = New-Object "System.Windows.Forms.$Tipo"
    $c.Location = New-Object Drawing.Point((S $X), (S $Y))
    $c.Size = New-Object Drawing.Size((S $W), (S $H))
    if ($Texto) { $c.Text = $Texto }
    $c.Font = $fNormal
    $c
}

function New-Boton([string]$Texto, [int]$X, [int]$Y, [int]$W, [int]$H = 30, [switch]$Principal) {
    $b = New-Ctl 'Button' $X $Y $W $H $Texto
    $b.FlatStyle = 'Flat'
    $b.Cursor = 'Hand'
    if ($Principal) {
        $b.BackColor = $cAcento; $b.ForeColor = [Drawing.Color]::White
        $b.FlatAppearance.BorderSize = 0
        $b.Font = New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)
    } else {
        $b.BackColor = [Drawing.Color]::White
        $b.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(203, 213, 225)
    }
    $script:Botones.Add($b)
    $b
}

# ---------------------------------------------------------------- registro y tareas en segundo plano
function Add-Log([string]$Entrada) {
    $partes = $Entrada.Split('|', 2)
    $tipo = if ($partes.Count -eq 2) { $partes[0] } else { 'info' }
    $texto = $partes[-1]
    $color = switch ($tipo) {
        'ok' { [Drawing.Color]::FromArgb(134, 239, 172) }
        'aviso' { [Drawing.Color]::FromArgb(253, 224, 71) }
        'error' { [Drawing.Color]::FromArgb(252, 165, 165) }
        'paso' { [Drawing.Color]::FromArgb(125, 211, 252) }
        default { [Drawing.Color]::FromArgb(226, 232, 240) }
    }
    $log.SelectionStart = $log.TextLength
    $log.SelectionColor = $color
    $log.AppendText("$(Get-Date -Format HH:mm:ss)  $texto`r`n")
    $log.ScrollToCaret()
}

function Set-Ocupado([bool]$Ocupado) {
    foreach ($b in $script:Botones) { $b.Enabled = -not $Ocupado }
    $form.UseWaitCursor = $Ocupado
    $barra.Visible = $Ocupado
}

function Start-Tarea {
    param([string]$Titulo, [string]$Codigo, [hashtable]$Variables = @{}, [scriptblock]$AlTerminar)
    if ($script:Tarea) { return }
    Set-Ocupado $true
    Add-Log "paso|── $Titulo"
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('TtkCola', $script:Cola)
    foreach ($k in $Variables.Keys) { $rs.SessionStateProxy.SetVariable($k, $Variables[$k]) }
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript("`$ErrorActionPreference = 'Stop'; Import-Module '$Modulo' -DisableNameChecking; $Codigo")
    $script:Tarea = @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke(); AlTerminar = $AlTerminar }
}

function Complete-Tarea {
    $t = $script:Tarea; $script:Tarea = $null
    $resultado = $null; $fallo = $null
    try { $resultado = $t.Ps.EndInvoke($t.Handle) }
    catch { $fallo = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message } }
    if (-not $fallo -and $t.Ps.Streams.Error.Count) { $fallo = $t.Ps.Streams.Error[0].Exception.Message }
    $linea = $null
    while ($script:Cola.TryDequeue([ref]$linea)) { Add-Log $linea }
    if ($fallo) { Add-Log "error|[XX] $fallo" }
    $t.Ps.Dispose(); $t.Rs.Close()
    Set-Ocupado $false
    if ($t.AlTerminar) { & $t.AlTerminar $resultado (-not $fallo) }
}

# ---------------------------------------------------------------- diálogos
function Read-Texto([string]$Titulo, [string]$Pregunta) {
    $d = New-Object Windows.Forms.Form
    $d.Text = $Titulo; $d.ClientSize = New-Object Drawing.Size(380, 130); $d.FormBorderStyle = 'FixedDialog'
    $d.StartPosition = 'CenterParent'; $d.MaximizeBox = $false; $d.MinimizeBox = $false
    $l = New-Ctl 'Label' 12 12 356 22 $Pregunta
    $t = New-Ctl 'TextBox' 12 40 356 26
    $ok = New-Ctl 'Button' 192 84 85 30 'Aceptar'; $ok.DialogResult = 'OK'
    $no = New-Ctl 'Button' 283 84 85 30 'Cancelar'; $no.DialogResult = 'Cancel'
    $d.Controls.AddRange(@($l, $t, $ok, $no)); $d.AcceptButton = $ok; $d.CancelButton = $no
    if ($d.ShowDialog($form) -eq 'OK') { $t.Text.Trim() } else { $null }
}

function Read-Claves([string]$Perfil) {
    $d = New-Object Windows.Forms.Form
    $d.Text = "Contraseñas del perfil '$Perfil'"; $d.ClientSize = New-Object Drawing.Size(400, 200)
    $d.FormBorderStyle = 'FixedDialog'; $d.StartPosition = 'CenterParent'; $d.MaximizeBox = $false; $d.MinimizeBox = $false
    $i = New-Ctl 'Label' 12 10 376 36 'Las que pusiste al crear los certificados en el Certificate Manager. No se guardan en claro.'
    $i.Font = $fDesc
    $l1 = New-Ctl 'Label' 12 52 150 22 'Certificado Author:'
    $t1 = New-Ctl 'TextBox' 165 50 223 26; $t1.UseSystemPasswordChar = $true
    $l2 = New-Ctl 'Label' 12 92 150 22 'Certificado Distributor:'
    $t2 = New-Ctl 'TextBox' 165 90 223 26; $t2.UseSystemPasswordChar = $true
    $ok = New-Ctl 'Button' 212 150 85 32 'Importar'; $ok.DialogResult = 'OK'
    $no = New-Ctl 'Button' 303 150 85 32 'Cancelar'; $no.DialogResult = 'Cancel'
    $d.Controls.AddRange(@($i, $l1, $t1, $l2, $t2, $ok, $no)); $d.AcceptButton = $ok; $d.CancelButton = $no
    $r = $null
    if ($d.ShowDialog($form) -eq 'OK' -and $t1.Text -and $t2.Text) {
        $r = @{ A = (ConvertTo-SecureString $t1.Text -AsPlainText -Force); D = (ConvertTo-SecureString $t2.Text -AsPlainText -Force) }
    }
    $t1.Clear(); $t2.Clear(); $d.Dispose()
    $r
}

# ---------------------------------------------------------------- ventana
$form = New-Object Windows.Forms.Form
$form.Text = "Tizen TV Dev Kit $(Get-TtkVersion)"
$form.AutoScaleMode = 'None'
$form.ClientSize = New-Object Drawing.Size((S 1000), (S 770))
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $cFondo
$icono = Join-Path $PSScriptRoot 'recursos\icono.ico'
if (Test-Path $icono) { $form.Icon = New-Object Drawing.Icon($icono) }

$cab = New-Ctl 'Panel' 0 0 1000 66
$cab.BackColor = [Drawing.Color]::FromArgb(15, 23, 42)
$tt = New-Ctl 'Label' 18 8 700 30 'Tizen TV Dev Kit'
$tt.Font = New-Object Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold); $tt.ForeColor = [Drawing.Color]::White
$st = New-Ctl 'Label' 20 40 900 20 'Crea, firma, instala y depura apps web en tu Smart TV o proyector Samsung con Tizen  ·  herramienta no oficial'
$st.Font = $fDesc; $st.ForeColor = [Drawing.Color]::FromArgb(148, 163, 184)
$cab.Controls.AddRange(@($tt, $st))

$tabs = New-Ctl 'TabControl' 12 76 976 438
$tabs.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
$tab1 = New-Object Windows.Forms.TabPage '1 · Preparar (una sola vez)'
$tab2 = New-Object Windows.Forms.TabPage '2 · Mis apps'
foreach ($tp in $tab1, $tab2) { $tp.BackColor = [Drawing.Color]::White; [void]$tabs.TabPages.Add($tp) }

# ---- pestaña 1: asistente
$script:Estados = @{}
function Add-Paso([int]$N, [string]$Titulo, [string]$Desc) {
    $y = 10 + ($N - 1) * 54
    $num = New-Ctl 'Label' 10 ($y + 2) 32 32 "$N"
    $num.Font = New-Object Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold); $num.ForeColor = $cAcento
    $t = New-Ctl 'Label' 46 $y 448 22 $Titulo; $t.Font = $fTitulo
    $d = New-Ctl 'Label' 46 ($y + 22) 448 32 $Desc; $d.Font = $fDesc; $d.ForeColor = [Drawing.Color]::FromArgb(100, 116, 139)
    $e = New-Ctl 'Label' 642 ($y + 6) 104 24 '…'
    $e.Font = New-Object Drawing.Font('Segoe UI', 9.5, [Drawing.FontStyle]::Bold); $e.ForeColor = [Drawing.Color]::Gray
    $tab1.Controls.AddRange(@($num, $t, $d, $e))
    $script:Estados[$N] = $e
    $d
}
function Set-Estado([int]$N, $Ok) {
    $e = $script:Estados[$N]
    if ($null -eq $Ok) { $e.Text = '…'; $e.ForeColor = [Drawing.Color]::Gray }
    elseif ($Ok) { $e.Text = '✔ Listo'; $e.ForeColor = [Drawing.Color]::FromArgb(22, 163, 74) }
    else { $e.Text = '✖ Pendiente'; $e.ForeColor = [Drawing.Color]::FromArgb(220, 38, 38) }
}

$cfg = Get-TtkConfig
[void](Add-Paso 1 'Requisitos básicos' 'Node.js, Visual Studio Code y un navegador Chromium (Chrome, Edge o Brave).')
[void](Add-Paso 2 'Extensión tizentv de VS Code' 'Herramienta de Samsung que empaqueta y firma las apps para TV.')
[void](Add-Paso 3 'SDB (Smart Development Bridge)' 'Descarga oficial de download.tizen.org con verificación SHA-256.')
$desc4 = Add-Paso 4 'Proyector en modo desarrollador' "Apps → pulsa 1 2 3 4 5 → Developer Mode ON → Host PC IP: $($cfg.IpPc) → reinicia. Luego escribe su IP:"
[void](Add-Paso 5 'Certificate Manager (Tizen Studio)' 'Instalador oficial (~630 MB, firma verificada). Luego, en Package Manager → Extension SDK → Samsung Certificate Extension.')
[void](Add-Paso 6 'Crear el certificado Samsung' '+ → Samsung → TV → Author nuevo → Distributor nuevo → Public → DUID marcado → login Samsung → Finish.')
[void](Add-Paso 7 'Activar el perfil en tizentv' 'Copia el perfil y guarda sus contraseñas en el formato que entiende tizentv.')

$bDoctor = New-Boton 'Comprobar todo' 752 12 196
$bExt = New-Boton 'Instalar extensión' 752 66 196
$bSdb = New-Boton 'Instalar SDB' 752 120 196
$txtIp = New-Ctl 'TextBox' 504 180 130 26 $cfg.Ip
$bConectar = New-Boton 'Conectar' 752 174 196
$bCm = New-Boton 'Instalar Cert. Manager' 752 228 196
$bDuid = New-Boton 'Leer DUID' 504 282 130
$bAbrirCm = New-Boton 'Abrir Cert. Manager' 752 282 196
$cmbPerfil = New-Ctl 'ComboBox' 504 342 130 26; $cmbPerfil.DropDownStyle = 'DropDownList'
$bImportar = New-Boton 'Importar perfil…' 752 336 196
$tab1.Controls.AddRange(@($bDoctor, $bExt, $bSdb, $txtIp, $bConectar, $bCm, $bDuid, $bAbrirCm, $cmbPerfil, $bImportar))

# ---- pestaña 2: mis apps
$lp = New-Ctl 'Label' 16 22 80 24 'Proyecto:'; $lp.Font = $fTitulo
$txtProy = New-Ctl 'TextBox' 100 20 560 26 $cfg.Proyecto
$bExaminar = New-Boton 'Examinar…' 670 18 130
$bNueva = New-Boton 'Nueva app…' 810 18 140
$lInfo = New-Ctl 'Label' 100 52 850 22 ''; $lInfo.Font = $fDesc; $lInfo.ForeColor = [Drawing.Color]::FromArgb(100, 116, 139)
$bTodo = New-Boton '▶  Compilar, instalar y abrir' 16 92 330 64 -Principal
$bCompilar = New-Boton 'Solo compilar' 362 92 140 30
$bInstalar = New-Boton 'Solo instalar' 512 92 140 30
$bAbrir = New-Boton 'Abrir en el proyector' 662 92 170 30
$bDepurar = New-Boton 'Depurar en el navegador' 362 126 290 30
$bDesinst = New-Boton 'Desinstalar' 662 126 170 30
$bCarpeta = New-Boton 'Abrir carpeta' 16 176 160 30
$bVsCode = New-Boton 'Abrir en VS Code' 186 176 160 30
$tip = New-Ctl 'Label' 16 230 930 140 ("Cómo trabajar:`r`n" +
    "1. 'Nueva app…' crea un proyecto con navegación por mando a distancia (flechas, OK y Atrás).`r`n" +
    "2. Edita index.html, css/style.css y js/main.js (por ejemplo, en VS Code).`r`n" +
    "3. Pulsa ▶. El kit firma con tu certificado Samsung, instala y comprueba la respuesta real del proyector.`r`n" +
    "4. 'Depurar en el navegador' abre el inspector (consola, DOM, red) conectado a la app del proyector.")
$tip.Font = $fNormal; $tip.ForeColor = [Drawing.Color]::FromArgb(51, 65, 85)
$tab2.Controls.AddRange(@($lp, $txtProy, $bExaminar, $bNueva, $lInfo, $bTodo, $bCompilar, $bInstalar, $bAbrir, $bDepurar, $bDesinst, $bCarpeta, $bVsCode, $tip))

# ---- registro
$lLog = New-Ctl 'Label' 14 520 300 20 'Actividad'; $lLog.Font = $fTitulo
$barra = New-Ctl 'ProgressBar' 838 524 150 14; $barra.Style = 'Marquee'; $barra.Visible = $false
$log = New-Ctl 'RichTextBox' 12 544 976 214
$log.ReadOnly = $true; $log.BackColor = [Drawing.Color]::FromArgb(15, 23, 42); $log.BorderStyle = 'None'
$log.Font = New-Object Drawing.Font('Consolas', 9.5)
$form.Controls.AddRange(@($cab, $tabs, $lLog, $barra, $log))

# ---------------------------------------------------------------- lógica
function Update-Proyecto {
    try {
        $p = Get-TtkProyecto $txtProy.Text
        $lInfo.Text = "App: $($p.Nombre)   ·   Id: $($p.AppId)   ·   Paquete: $($p.Wgt)"
        Set-TtkConfig @{ Proyecto = $p.Ruta }
        $true
    } catch { $lInfo.Text = 'Elige o crea un proyecto (carpeta con config.xml).'; $false }
}

function Update-Perfiles {
    $cmbPerfil.Items.Clear()
    foreach ($p in Get-TtkPerfilesCertificateManager) { [void]$cmbPerfil.Items.Add($p.Nombre) }
    if ($cmbPerfil.Items.Count) { $cmbPerfil.SelectedIndex = 0 }
}

$alDiagnostico = {
    param($r, $ok)
    if (-not $ok -or -not $r) { return }
    $m = @{}; foreach ($c in $r) { $m[$c.Requisito] = $c }
    Set-Estado 1 ($m['Node.js'].Ok -and $m['Visual Studio Code'].Ok -and $m['Navegador Chromium'].Ok)
    Set-Estado 2 $m['Extensión tizentv'].Ok
    Set-Estado 3 $m['SDB'].Ok
    Set-Estado 4 $m['Proyector (modo desarrollador)'].Ok
    Set-Estado 5 $m['Certificate Manager'].Ok
    Set-Estado 6 ([bool](Get-TtkPerfilesCertificateManager))
    Set-Estado 7 $m['Perfil de certificado Samsung'].Ok
    Update-Perfiles
    $pend = @($r | Where-Object { -not $_.Ok })
    if ($pend.Count) { foreach ($c in $pend) { Add-Log "aviso|[!!] $($c.Requisito): $($c.Solucion)" } }
    else { Add-Log 'ok|[OK] Todo listo. Ve a la pestaña «2 · Mis apps».' }
}
function Invoke-Diagnostico { Start-Tarea 'Comprobando el entorno' 'Test-TtkEntorno' -AlTerminar $alDiagnostico }

function Test-ProyectoSeleccionado {
    if (Update-Proyecto) { return $true }
    [void][Windows.Forms.MessageBox]::Show('Primero elige o crea un proyecto.', 'Tizen TV Dev Kit'); $false
}

$bDoctor.Add_Click({ Invoke-Diagnostico })
$bExt.Add_Click({ Start-Tarea 'Instalando la extensión tizentv' 'Install-TtkTizentv' -AlTerminar { Invoke-Diagnostico } })
$bSdb.Add_Click({ Start-Tarea 'Instalando SDB' 'Install-TtkSdb' -AlTerminar { Invoke-Diagnostico } })
$bConectar.Add_Click({
    $ip = $txtIp.Text.Trim()
    if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { [void][Windows.Forms.MessageBox]::Show('Escribe una IP válida, por ejemplo 192.168.1.50.'); return }
    Start-Tarea "Conectando con $ip" 'Connect-TtkProyector -Ip $Ip | Out-Null; $i = Get-TtkInfoProyector; Write-TtkLog ("{0} · {1} · Tizen {2} · {3}" -f $i.Fabricante, $i.Perfil, $i.Tizen, $i.Cpu) ok' `
        -Variables @{ Ip = $ip } -AlTerminar { param($r, $ok) Set-Estado 4 $ok }
})
$bCm.Add_Click({ Start-Tarea 'Instalando Certificate Manager' 'Install-TtkCertificateManager' })
$bAbrirCm.Add_Click({ Start-Tarea 'Abriendo Certificate Manager' 'Start-TtkCertificateManager' })
$bDuid.Add_Click({
    Start-Tarea 'Leyendo el DUID del proyector' 'Get-TtkDuid' -AlTerminar {
        param($r, $ok)
        if ($ok -and $r) { $duid = "$($r[0])"; [Windows.Forms.Clipboard]::SetText($duid); Add-Log "ok|[OK] DUID: $duid (copiado al portapapeles)" }
    }
})
$bImportar.Add_Click({
    Update-Perfiles
    if (-not $cmbPerfil.SelectedItem) { [void][Windows.Forms.MessageBox]::Show('No hay perfiles en el Certificate Manager. Créalo primero (paso 6).'); return }
    $perfil = [string]$cmbPerfil.SelectedItem
    $c = Read-Claves $perfil
    if (-not $c) { return }
    Start-Tarea "Importando el perfil '$perfil'" 'Import-TtkPerfilSamsung -Nombre $Perfil -ClaveAuthor $A -ClaveDistributor $D' `
        -Variables @{ Perfil = $perfil; A = $c.A; D = $c.D } -AlTerminar { Invoke-Diagnostico }
})

$bExaminar.Add_Click({
    $f = New-Object Windows.Forms.FolderBrowserDialog
    $f.Description = 'Carpeta del proyecto (la que contiene config.xml)'
    if ($txtProy.Text -and (Test-Path $txtProy.Text)) { $f.SelectedPath = $txtProy.Text }
    if ($f.ShowDialog($form) -eq 'OK') { $txtProy.Text = $f.SelectedPath; [void](Update-Proyecto) }
})
$bNueva.Add_Click({
    $n = Read-Texto 'Nueva app' 'Nombre (solo letras y números, sin espacios):'
    if (-not $n) { return }
    Start-Tarea "Creando la app '$n'" 'New-TtkProyecto -Nombre $Nombre' -Variables @{ Nombre = $n } -AlTerminar {
        param($r, $ok) if ($ok -and $r) { $txtProy.Text = $r[0].Ruta; [void](Update-Proyecto) }
    }
})
$txtProy.Add_Leave({ [void](Update-Proyecto) })
$bTodo.Add_Click({ if (Test-ProyectoSeleccionado) { Start-Tarea 'Compilar, instalar y abrir' 'Invoke-TtkTodo $Ruta' -Variables @{ Ruta = $txtProy.Text } } })
$bCompilar.Add_Click({ if (Test-ProyectoSeleccionado) { Start-Tarea 'Compilando' 'Build-TtkWgt $Ruta | Out-Null' -Variables @{ Ruta = $txtProy.Text } } })
$bInstalar.Add_Click({ if (Test-ProyectoSeleccionado) { Start-Tarea 'Instalando' 'Install-TtkApp $Ruta | Out-Null' -Variables @{ Ruta = $txtProy.Text } } })
$bAbrir.Add_Click({ if (Test-ProyectoSeleccionado) { Start-Tarea 'Abriendo la app' 'Start-TtkApp $Ruta' -Variables @{ Ruta = $txtProy.Text } } })
$bDepurar.Add_Click({ if (Test-ProyectoSeleccionado) { Start-Tarea 'Depurando' 'Start-TtkDepuracion $Ruta | Out-Null' -Variables @{ Ruta = $txtProy.Text } } })
$bDesinst.Add_Click({ if (Test-ProyectoSeleccionado) { Start-Tarea 'Desinstalando' 'Remove-TtkApp $Ruta' -Variables @{ Ruta = $txtProy.Text } } })
$bCarpeta.Add_Click({ if (Test-ProyectoSeleccionado) { Start-Process explorer.exe $txtProy.Text } })
$bVsCode.Add_Click({
    if (-not (Test-ProyectoSeleccionado)) { return }
    $code = Get-Command code -ErrorAction SilentlyContinue
    if ($code) { Start-Process $code.Source -ArgumentList "`"$($txtProy.Text)`"" -WindowStyle Hidden } else { Add-Log 'aviso|[!!] VS Code no está en el PATH.' }
})

$reloj = New-Object Windows.Forms.Timer
$reloj.Interval = 150
$reloj.Add_Tick({
    $linea = $null
    while ($script:Cola.TryDequeue([ref]$linea)) { Add-Log $linea }
    if ($script:Tarea -and $script:Tarea.Handle.IsCompleted) { Complete-Tarea }
})
$form.Add_Load({ $form.WindowState = 'Normal' })
$form.Add_Shown({
    $form.WindowState = 'Normal'; $form.Activate()
    $reloj.Start()
    $tabs.SelectedIndex = $Pestana - 1
    Add-Log "info|Tizen TV Dev Kit $(Get-TtkVersion) · configuración en $env:APPDATA\TizenTVDevKit"
    [void](Update-Proyecto)
    if (-not $txtProy.Text) { $lInfo.Text = 'Pulsa «Nueva app…» para empezar.' }
    Invoke-Diagnostico
})
$form.Add_FormClosing({ $reloj.Stop() })
[void]$form.ShowDialog()
