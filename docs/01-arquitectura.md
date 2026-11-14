# 01 · Arquitectura y prerrequisitos

## Piezas y por qué cada una

**Tizen Studio completo no es necesario para apps web de TV.** La extensión de VS Code `tizentv` (de Samsung) descarga bajo demanda las herramientas que necesita a `C:\tizentv-tools\` (SDB, cifrado de contraseñas, generador de certificados). Tizen Studio solo se usa aquí por una razón: su **Certificate Manager**, que es el único que crea el perfil de certificado *Samsung*.

> La extensión de VS Code «Tizen» (.NET, `tizen.vscode-tizen-csharp`) es **otra cosa**: sirve para .NET/Flutter. Su comando *Install Tizen CLI* no es necesario para apps web de TV y puede tardar mucho.

## Prerrequisitos

| Requisito | Detalle |
|---|---|
| Sistema | Windows 10/11, PowerShell 5.1 |
| Editor | Visual Studio Code |
| Extensión | `tizensdk.tizentv` (Tizen TV) |
| Node.js | Para `scripts/build-wgt.js` (probado con v24) |
| Red | PC y proyector en la **misma red local**; la IP del proyector debe ser estable |
| Cuenta | Cuenta de Samsung (para el certificado de distribuidor) |
| Dispositivo | Modo desarrollador activo |
| Espacio | ~1 GB si instalas Package Manager/Certificate Manager |

## Carpetas que se crean

| Ruta | Contenido |
|---|---|
| `%USERPROFILE%\tizen-studio-data\vscode-tizentv\resource\` | `profiles.xml` y claves de `tizentv` (**sensible**) |
| `C:\tizentv-tools\` | SDB y utilidades descargadas por `tizentv` |
| `%USERPROFILE%\SamsungCertificate\<perfil>\` | `author.p12` y `distributor.p12` del Certificate Manager (**sensible**) |
| carpeta del proyecto | Tu app web (`config.xml`, `index.html`…) — **sin claves dentro** |

## Flujo completo

```
Modo desarrollador ─▶ SDB connect ─▶ leer DUID ─▶ Certificate Manager (perfil Samsung)
        ─▶ re-guardar contraseñas en formato tizentv ─▶ build firmado (WGT)
        ─▶ sdb push + vd_appinstall ─▶ execute / debug ─▶ inspector remoto
```
