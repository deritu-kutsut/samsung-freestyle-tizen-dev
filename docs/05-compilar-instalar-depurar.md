# 05 · Compilar, instalar y depurar

## 1. Crear el proyecto

En VS Code: `F1` → **Tizen TV: Create Web Project** → plantilla (p. ej. *Basic › Empty*) → nombre → carpeta.

**Importante:** crea el proyecto en una carpeta **distinta** de la de datos de `tizentv` (`…\tizen-studio-data\vscode-tizentv`). El empaquetado incluye todo el contenido de la raíz del proyecto y se colarían tus claves privadas en el WGT. Comprueba siempre que no haya `*.p12` ni `*.pwd` dentro:

```powershell
Get-ChildItem <carpeta_proyecto> -Recurse -Include *.p12,*.pwd
```

Abre la carpeta del proyecto como workspace (`File › Open Folder`).

## 2. Compilar y firmar

`F1` → **Tizen TV: Build Signed Package**. Debe aparecer *Build the package Successfully!* y generarse `<Nombre>.wgt` en la raíz del proyecto.

Si no aparece ningún mensaje, la firma está fallando en silencio (ver [06](06-solucion-de-problemas.md)). Para ver el error real:

```powershell
node scripts\build-wgt.js <carpeta_proyecto> <ruta_profiles.xml>
```

## 3. Instalar y ejecutar

`F1` → **Tizen TV: Launch Application** → **Run On TV**. La extensión puede decir «Application launched» aunque el proyector haya rechazado el paquete. Para verificar el resultado real:

```powershell
.\scripts\instalar.ps1 -Ip <IP_PROYECTOR> -Wgt <ruta\App.wgt> -AppId <paquete.Nombre>
```

Internamente ejecuta lo mismo que `tizentv`:

```
sdb -s <IP>:26101 push App.wgt /home/owner/share/tmp/sdk_tools/
sdb -s <IP>:26101 shell 0 vd_appuninstall <paquete.Nombre>
sdb -s <IP>:26101 shell 0 vd_appinstall   <paquete.Nombre> /home/owner/share/tmp/sdk_tools/App.wgt
sdb -s <IP>:26101 shell 0 execute         <paquete.Nombre>
```

Instalación correcta ⇒ `install completed` y, al ejecutar, `successfully launched pid = …`. El `AppId` está en `config.xml` (`<tizen:application id="…">`).

## 4. Depurar

`F1` → **Tizen TV: Debug Application**, o:

```powershell
.\scripts\depurar.ps1 -Ip <IP_PROYECTOR> -AppId <paquete.Nombre> -Navegador "<ruta navegador Chromium>"
```

El comando `shell 0 debug` devuelve un **puerto** distinto en cada ejecución (`… with debug 1 port: NNNNN`). El inspector se obtiene de `http://<IP>:NNNNN/json` (campo `devtoolsFrontendUrl`) y se abre en el navegador, con las pestañas habituales de Elements, Console y Network.

Un inspector muy reciente de Chromium puede ser incompatible con el motor del dispositivo; si sale en blanco, prueba con otra versión.

## 5. Ciclo de trabajo diario

```
editar código → Build Signed Package → Launch Application → (Debug Application)
```
