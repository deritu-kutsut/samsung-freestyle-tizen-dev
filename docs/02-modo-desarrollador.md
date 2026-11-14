# 02 · Activar el modo desarrollador en el proyector

Este paso es **físico** (con el mando del proyector). Sigue la guía oficial de Samsung
[«Enabling Developer Mode»](https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/tv-device.html) y **detente antes de los pasos que usan Tizen Studio**.

Resumen del procedimiento:

1. En el proyector abre **Apps**.
2. Con el mando introduce **1 2 3 4 5**.
3. Activa **Developer Mode: ON**.
4. En **Host PC IP** escribe la IP de tu ordenador (la del PC que usará SDB).
5. **Reinicia** el proyector.

## Datos que necesitas anotar

| Dato | Dónde |
|---|---|
| IP del PC | `ipconfig` en Windows |
| IP del proyector | Ajustes → Red → Estado de la red |

Comprueba que ambos equipos están en la misma subred (por ejemplo `192.168.1.x`).

> Samsung indica que no se admite instalar apps por USB y que el puerto `26101` es interno del dispositivo: no se abre ni se configura manualmente.

