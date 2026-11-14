# 06 · Solución de problemas

Errores reales encontrados durante la puesta en marcha, con causa y solución.

## Firma e instalación

| Síntoma | Causa | Solución |
|---|---|---|
| `install failed[118, -12] … Invalid certificate chain` | Perfil de certificado **genérico de Tizen** | Crear el perfil Samsung ([04](04-certificado-samsung.md)) y activarlo |
| `PKCS#12 MAC could not be verified. Invalid password?` | El Certificate Manager y `tizentv` cifran las contraseñas de forma distinta | Ejecutar `scripts/reguardar-password.ps1` |
| *Build Signed Package* no muestra ningún mensaje | `tizentv` 1.3.3 captura el error de firma sin reportarlo (`buildWidget` solo lo escribe en la consola) | Reproducir con `node scripts/build-wgt.js …` para ver el error real |
| «Application launched» pero la app no aparece | `Launch Application` solo comprueba que `sdb` terminó, no el resultado del dispositivo | Usar `scripts/instalar.ps1`, que lee `install completed` |
| `1010 : App install fail` | Casi siempre certificado/DUID | Verificar que el DUID del perfil coincide con `getduid` |
| `The app with ID … is not available for the user 5001` | La app no está instalada | Revisar el resultado de `vd_appinstall` |
| `was get app info failed` al desinstalar | La app aún no existía | Es normal en la primera instalación |

## Conexión

| Síntoma | Solución |
|---|---|
| `sdb connect` no conecta | Modo desarrollador activo, *Host PC IP* correcta, proyector reiniciado, misma subred |
| `sdb shell 0 debug` se queda colgado sin salida | La app ya estaba abierta: reinstalar (`vd_appuninstall` + `vd_appinstall`) y volver a depurar |
| El Certificate Manager avisa «There is no …\tools\sdb.exe» | Copiar `sdb.exe` a `…\tools\sdb.exe` |

## Instalación de Tizen Studio / Package Manager

| Síntoma | Causa | Solución |
|---|---|---|
| `NoClassDefFoundError: javax/xml/bind/JAXBException` | El Package Manager usa tu Java (≥ 11), que ya no incluye JAXB | Ejecutarlo con el **JDK 8 incluido** en la instalación de Tizen (`JAVA_HOME=<SDK>\jdk`) |
| `Cannot find installed SDK` | El `.jar` del Package Manager busca el SDK relativo a su carpeta | Ejecutarlo **desde su propia carpeta** (`cd <SDK>\package-manager`) |
| `Cannot install updates` y desaparece la carpeta `jdk` | El actualizador reemplaza el JDK que está usando | Conservar una copia del `jdk`; restaurarla y reintentar |
| Instalar `cert-add-on` falla en la instalación solo CLI | Es un plugin del IDE (depende de `common-eplugin`) | Instalar con el instalador del IDE (`web-ide_…`) y usar el Package Manager gráfico |
| El instalador `web-ide_…` no termina | Es gráfico, no admite `--accept-license` silencioso | Completarlo en su ventana (carpeta nueva, p. ej. `C:\TizenStudioIDE`) |
| `Error: Invalid the destination directory` | El instalador exige una carpeta vacía | Instalar en una carpeta nueva |
| El IDE aparece incompleto (falta `TizenStudio.exe`) | La instalación del IDE quedó a medias | No hace falta el IDE: el Certificate Manager es independiente |

## Rutas protegidas

Algunas herramientas de automatización bloquean borrar `C:\tizen-studio`. Si una instalación queda rota, bórrala manualmente desde el Explorador y reinstala en una carpeta nueva.

## Comprobaciones rápidas

```powershell
sdb devices                                      # ¿aparece el proyector?
Get-AuthenticodeSignature <instalador>           # ¿firma válida de Samsung?
Get-ChildItem <proyecto> -Recurse -Include *.p12,*.pwd   # ¿claves dentro del proyecto?
```
