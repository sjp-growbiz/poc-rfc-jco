# Solicitud a Basis · POC de conectividad RFC fuera de BTP

**Qué queremos probar.** Llamar a un módulo de función existente
(`ZBTP_OBTENER_TIPO_CAMBIO`, sólo lectura) desde un servidor Linux propio
conectado por VPN, sin pasar por SAP BTP ni por el Cloud Connector.

**Ambiente:** QAS. **Duración:** una sesión de pruebas.
**Sistema de origen:** servidor Linux ya conectado a la red por VPN.

---

## 1 · Datos de conexión

| Dato | Variable | Valor | Observación |
|---|---|---|---|
| Host del servidor de aplicación | `JCO_ASHOST` | `vhcpvqs4ci.buenaventura.pe` | Inferido del ICM. **Confirmar** que el host RFC sea el mismo. |
| Número de sistema | `JCO_SYSNR` | `00` | Inferido del puerto 44300. **Confirmar.** |
| Mandante | `JCO_CLIENT` | — | **Requerido.** |
| Usuario | `JCO_USER` | — | **Requerido.** Tipo COMMUNICATION o SYSTEM. |
| Clave | `JCO_PASSWD` | — | **Requerido.** |
| ¿SNC obligatorio? | `JCO_SNC_MODE` | — | **Confirmar.** Si sí, hace falta la librería criptográfica y el nombre SNC del servidor. |

El usuario **no debe ser de diálogo**: se bloquea con el uso concurrente y la
clave caduca. Uno de comunicación evita ambas cosas.

---

## 2 · Autorizaciones del usuario

Objeto **`S_RFC`**, con `RFC_TYPE = FUGR` y `ACTVT = 16`, sobre estos grupos:

| `RFC_NAME` | Para qué |
|---|---|
| Grupo de funciones de `ZBTP_OBTENER_TIPO_CAMBIO` | La llamada en sí |
| `SDIFRUNTIME` | Leer la metadata del módulo |
| `RFC1` | Consultar el repositorio de funciones |
| `SYST` | Handshake inicial de la conexión |

Los tres últimos son el detalle que más veces se olvida: sin ellos la conexión
se establece pero la llamada falla al pedir la metadata, con un error que
parece de red y no lo es.

---

## 3 · Reglas de firewall

Origen: el servidor Linux de la POC. Destino: el host de la tabla anterior.

| Puerto | Fórmula | Con `sysnr = 00` | Para qué |
|---|---|---|---|
| Gateway | `33<nn>` | **3300** | La conexión RFC. Imprescindible. |
| Dispatcher | `32<nn>` | **3200** | Handshake y balanceo. Imprescindible. |
| Message server | `36<nn>` | 3600 | Sólo si se conecta por grupo de logon en vez de a un servidor fijo. |

**No basta con el 8000 ni el 44300**, que son los puertos HTTP/HTTPS que usan
las integraciones OData actuales. RFC va por puertos propios.

---

## 4 · Comprobación

Desde el servidor de la POC, antes de levantar nada:

```bash
nc -zv vhcpvqs4ci.buenaventura.pe 3300
nc -zv vhcpvqs4ci.buenaventura.pe 3200
```

Si ambos responden, el resto es nuestro.

---

## 5 · Lo que esta prueba no toca

- Es **sólo lectura**: el módulo devuelve tipos de cambio de `T_TCURR`.
- No escribe, no crea documentos, no modifica maestros.
- No requiere cambios en BTP: el Cloud Connector y los destinos actuales
  siguen exactamente como están.
- El servidor de la POC no queda expuesto a internet.
