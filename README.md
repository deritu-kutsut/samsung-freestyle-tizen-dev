# Desarrollo de apps web para Samsung The Freestyle (2.ª gen) con Tizen

Guía técnica, reproducible y probada para **crear, firmar, instalar y depurar una aplicación web (WGT) en un proyector Samsung The Freestyle 2.ª generación (Tizen 9.0)** desde Windows 11, usando Visual Studio Code, las herramientas oficiales de Samsung y Tizen, y Claude Code como asistente.

> Verificado el 14/11/2026 con: Windows 11, VS Code 1.146, extensión `tizentv` 1.3.3, SDB 4.2.36, Tizen Studio 6.1 (Package Manager + Certificate Manager) y Samsung Certificate Extension 2.0.x.
> Proyecto independiente, **no afiliado a Samsung**. «Samsung», «Tizen» y «The Freestyle» son marcas de sus respectivos titulares.

## Qué resuelve

Instalar una app propia en un Smart TV/proyector Samsung exige: modo desarrollador, conexión por SDB, un **certificado de distribuidor de Samsung ligado al DUID del dispositivo**, empaquetado firmado y despliegue. La documentación oficial está dispersa y varios pasos fallan en silencio. Este repositorio documenta el camino completo, con los errores reales que aparecen y sus soluciones.

## Resultado

Una app de prueba firmada con certificado Samsung se **instaló, se ejecutó y se depuró** en el proyector (JavaScript funcionando, inspector remoto abierto en un navegador Chromium).

## Arquitectura

```
┌─────────────── PC con Windows 11 ───────────────┐          ┌──── Proyector (red local) ────┐
│ VS Code + extensión tizentv                     │          │ Tizen 9.0 · modo desarrollador │
│   ├─ empaqueta y firma el WGT                   │   SDB    │ sdbd escuchando en :26101      │
│ SDB (Smart Development Bridge)  ───────────────────────────▶ instala / ejecuta / depura    │
│ Certificate Manager (Tizen Studio)              │  TCP     │ valida firma + DUID            │
│   └─ perfil Samsung (Author + Distributor)      │          └────────────────────────────────┘
│ Navegador Chromium ◀── inspector remoto ◀───────────────────────  puerto de depuración
└─────────────────────────────────────────────────┘
```

Decisiones clave:

| Pieza | Elección | Motivo |
|---|---|---|
| Entorno de desarrollo | VS Code + `tizentv` | Es la vía ligera oficial de Samsung para TV; no requiere el IDE completo |
| Conexión | SDB 4.2.x (descarga oficial) | Es lo que usa `tizentv` internamente; puerto del dispositivo 26101 |
| Certificado | **Samsung** (no el genérico de Tizen) | Los dispositivos de venta rechazan el certificado genérico |
| Gestor de certificados | Certificate Manager de Tizen Studio | Único que ofrece el perfil Samsung (TV + DUID) |
| Depuración | Inspector web remoto en Chromium | Incluido en Tizen para apps web |

## Guía rápida

1. [Activar el modo desarrollador](docs/02-modo-desarrollador.md) en el proyector.
2. [Instalar SDB y conectar](docs/03-conexion-sdb.md); leer el **DUID**.
3. [Crear el perfil de certificado Samsung](docs/04-certificado-samsung.md) (pantalla por pantalla).
4. [Compilar, instalar y depurar](docs/05-compilar-instalar-depurar.md).
5. Si algo falla: [solución de problemas](docs/06-solucion-de-problemas.md).

Visión general y prerrequisitos en [docs/01-arquitectura.md](docs/01-arquitectura.md).

## Scripts incluidos

| Script | Función |
|---|---|
| [`scripts/verificar-conexion.ps1`](scripts/verificar-conexion.ps1) | Conecta por SDB y muestra el estado, plataforma y (opcional) el DUID |
| [`scripts/reguardar-password.ps1`](scripts/reguardar-password.ps1) | Guarda las contraseñas del perfil Samsung en el formato que entiende `tizentv` |
| [`scripts/build-wgt.js`](scripts/build-wgt.js) | Empaqueta y firma el WGT desde la línea de comandos (muestra errores reales) |
| [`scripts/instalar.ps1`](scripts/instalar.ps1) | Sube, instala y ejecuta el WGT, **comprobando el resultado real** del proyector |
| [`scripts/depurar.ps1`](scripts/depurar.ps1) | Lanza la app en modo depuración y abre el inspector |

## Seguridad

- **Nunca** publiques ni subas a Git: `*.p12`, `*.pwd`, `profiles.xml`, `author.p12`, `distributor.p12`, contraseñas ni tokens (el `.gitignore` los excluye).
- Trata el **DUID** del dispositivo como un identificador personal: no lo compartas en público.
- Mantén tus claves **fuera** de la carpeta del proyecto: el empaquetado incluye todo el contenido de la raíz del proyecto.
- Descarga los instaladores solo de `download.tizen.org` y verifica la firma digital de Samsung (`Get-AuthenticodeSignature`) y los SHA-256 publicados.

## Límites conocidos

- Tizen ejecuta **apps web (WGT)** o .NET; no hay plataforma Unity/Tizen. Un juego de Unity solo podría intentarse como build WebGL, con fuertes limitaciones de memoria, CPU y red.
- El certificado de desarrollo Samsung caduca (1 año en esta prueba) y está ligado a los DUID que declares.
- La extensión `tizentv` 1.3.3 **oculta errores** de firma e informa «launched» aunque el dispositivo rechace la instalación; los scripts de este repositorio verifican el resultado real.

## Licencia

[MIT](LICENSE).
