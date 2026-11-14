# 03 · SDB: instalación, conexión y DUID

SDB (*Smart Development Bridge*) es el equivalente de ADB para Tizen.

## Obtener SDB de forma segura

`tizentv` lo descarga solo la primera vez, a `C:\tizentv-tools\sdb\`. Para hacerlo a mano:

1. Consulta el listado oficial `http://download.tizen.org/sdk/tizenstudio/official/pkg_list_windows-64` y localiza el paquete `sdb` (en esta prueba: **4.2.36**, ruta `/binary/sdb_4.2.36_windows-64.zip`).
2. Descarga el ZIP en una carpeta aislada y **verifica el SHA-256** que publica el listado.
3. Copia el contenido de `data\tools\` a `C:\tizentv-tools\sdb\`.

```powershell
C:\tizentv-tools\sdb\sdb.exe version      # Smart Development Bridge version 4.2.36
```

## Conectar

```powershell
sdb connect <IP_PROYECTOR>                # connected to <IP>:26101
sdb devices                               # <IP>:26101   device   <MODELO>
```

Si no conecta: modo desarrollador desactivado, Host PC IP incorrecta, proyector sin reiniciar o distinta red.

## Verificar que es el dispositivo correcto

```powershell
sdb -s <IP>:26101 capability
```

Valores observados en The Freestyle 2.ª gen: `profile_name:tv`, `vendor_name:Samsung`, `platform_version:9.0`, `cpu_arch:armv7`, `sdbd_rootperm:disabled`, `filesync_support:pushpull`.

## Leer el DUID

El **DUID** identifica el dispositivo y debe incluirse en el certificado de distribuidor:

```powershell
sdb -s <IP>:26101 shell 0 getduid
```

(O usa [`scripts/verificar-conexion.ps1`](../scripts/verificar-conexion.ps1) con `-MostrarDuid`.) El Certificate Manager también lo detecta solo si el proyector está conectado por SDB.

## Configurar `tizentv`

En los ajustes de VS Code (`settings.json`):

```json
{
  "tizentv.hostPCAddress": "<IP_DEL_PC>",
  "tizentv.targetDeviceAddress": "<IP_DEL_PROYECTOR>",
  "tizentv.chromeExecutable": "<ruta a un navegador Chromium>"
}
```

Para depurar sirve cualquier navegador Chromium (Chrome, Brave, Edge…).
