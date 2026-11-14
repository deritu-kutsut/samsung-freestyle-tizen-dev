# 04 · Certificado Samsung (Author + Distributor)

## Por qué hace falta

Toda app Tizen debe estar firmada para instalarse. La extensión `tizentv` solo sabe crear un perfil **genérico de Tizen** («Create Profile (Tizen)»). Los dispositivos Samsung de venta lo rechazan:

```
install failed[118, -12], reason: Check certificate error : :Invalid certificate chain with certificate in signature.:<-3>
```

Se necesita un **certificado de distribuidor emitido por Samsung** que incluya el **DUID** del dispositivo. Se crea con el **Certificate Manager** de Tizen Studio más la **Samsung Certificate Extension**.

## Instalar las herramientas

1. Descarga el instalador **CLI** de Tizen Studio desde `https://download.tizen.org/sdk/Installer/` (carpeta de la versión estable, p. ej. `tizen-studio_6.1`) y verifica la firma:

   ```powershell
   Get-AuthenticodeSignature .\web-cli_Tizen_Studio_6.1_windows-64.exe   # Status: Valid · Samsung Electronics Co., Ltd.
   .\web-cli_Tizen_Studio_6.1_windows-64.exe --accept-license C:\TizenSDK
   ```

2. Abre el **Package Manager** (`C:\TizenSDK\package-manager\package-manager.exe`) → pestaña **Extension SDK** → instala **Samsung Certificate Extension**. En esta pestaña, un botón rojo *delete* indica que el paquete ya está instalado (la columna *License* solo muestra el acuerdo al instalar).
3. El Certificate Manager queda en `…\tools\certificate-manager\certificate-manager.exe`. Si pide `sdb.exe`, cópialo a `…\tools\sdb.exe` para que lea el DUID del dispositivo.

> Los problemas habituales de esta fase (Java, carpeta borrada, instalador gráfico) están en [06-solucion-de-problemas](06-solucion-de-problemas.md).

## Crear el perfil, pantalla por pantalla

Abre el **Certificate Manager**. Si ves «Migration for Certificate Profile», pulsa **Cancel**. Con la lista de perfiles vacía («There is no generated certificate profile»), pulsa **+**.

### Paso 1 · Device Type
- Elige **Samsung**.
- Tipo de dispositivo: **TV**.

### Paso 2 · Certificate Profile
- Escribe un nombre para el perfil (por ejemplo `freestyle-samsung`).

### Paso 3 · Author Certificate (3-3)
- Crea un **certificado Author nuevo** (nombre de autor y contraseña).
- Al terminar verás «The author certificate is complete» y la ruta donde quedó guardado (`%USERPROFILE%\SamsungCertificate\<perfil>\`).
- El campo **Backup path** es opcional (se recomienda copiar el certificado a un lugar seguro).
- Pulsa **Next**.

### Paso 4 · Distributor Certificate
- Elige **Create a new distributor certificate** (la alternativa, *Select an existing distributor certificate*, es para quien ya tiene uno).
- Pulsa **Next**.

### Paso 4-1 · Privilegio, contraseña y DUID
- **Privilege: Public**.
- **Password** y **Password Confirm** del certificado de distribuidor.
- DUID: marca **Add individual DUIDs**. Si el proyector está conectado por SDB, el primer DUID aparece ya marcado; si no, escríbelo (ver [03](03-conexion-sdb.md)). La otra opción, *Import a DUID list file*, sirve para listas de varios dispositivos.
- Pulsa **Next**.
- Se abre el **inicio de sesión con tu cuenta Samsung**: inicia sesión y autoriza.

### Paso 4-2 · Finalización
- «The distributor certificate is complete»: el certificado queda en `…\SamsungCertificate\<perfil>\`.
- Pulsa **Finish**. Confirma el mensaje «Your new certificate profile has been successfully created. This certificate profile has been set as active.»

### Resultado
La pantalla principal muestra el perfil con:
- **Author Certificate** → «Verified by: Samsung VD Author CA».
- **Distributor Certificate** → «Verified by: VD DEVELOPER Public CA».
- Fecha de caducidad (1 año desde la creación en esta prueba).

## Hacer que `tizentv` use el perfil

El perfil se guarda en el `profiles.xml` del Certificate Manager. `tizentv` tiene su propio `profiles.xml`:

```
%USERPROFILE%\tizen-studio-data\vscode-tizentv\resource\profiles.xml
```

1. Haz **copia de seguridad** de ese archivo.
2. Añade el nodo `<profile name="freestyle-samsung">…</profile>` del Certificate Manager y pon `active="freestyle-samsung"` en `<profiles>`.
3. Las contraseñas **no son compatibles** entre ambos: el Certificate Manager las cifra de una forma que `tizentv` no puede leer y el empaquetado falla con
   `PKCS#12 MAC could not be verified. Invalid password?`.
   Soluciónalo con [`scripts/reguardar-password.ps1`](../scripts/reguardar-password.ps1), que pide las contraseñas por teclado, comprueba que abren los `.p12`, las cifra en el formato de `tizentv` y actualiza el perfil.

> **Seguridad:** no copies `.p12`, `.pwd` ni `profiles.xml` a repositorios, capturas ni mensajes.
