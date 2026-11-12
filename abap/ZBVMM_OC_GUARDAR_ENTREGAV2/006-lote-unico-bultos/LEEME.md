# ZBVMM_OC_GUARDAR_ENTREGAV2 · @006 · un lote repartido en varios bultos

FM de **creación** de la entrega entrante (Solicitar Cita), grupo `ZGF_CON_PORTAL`,
include `LZGF_CON_PORTALU32`.

- `actual/` — la versión @003 que corre hoy (igual a la que pegó el usuario el 11.11.2026).
- `propuesto/` — con el cambio, marcado `@006`. Se reemplaza el include completo.

## Problema

El portal manda una fila de lote por **bulto y vencimiento**. Un lote de 120 con 50 en el
bulto 1 y 70 en el bulto 2 llega como dos filas con la misma fecha. La FM creaba un lote SAP
por fila: dos lotes con el mismo vencimiento y la posición partida en dos subposiciones 9000xx.
El embalaje además asumía una línea de entrega por bulto (`lt_lips_bulto` con clave única `posnr`).

## Qué cambia

| # | Dónde | Cambio |
|---|---|---|
| 1 | Creación de lotes | Por posición, las filas se agrupan por vencimiento (`lt_lot_grp`): **un** `BAPI_BATCH_CREATE` y **una** línea de entrega por fecha, con la cantidad sumada. Si un solo vencimiento cubre la posición, el lote va en la propia posición, sin partirla. |
| 2 | Creación de lotes | `POSNR`/`CHARG` del lote se devuelven a **todas** las filas de su vencimiento. |
| 3 | Embalaje | `lt_lips_bulto` pasa a tabla ordenada con clave `posnr + vhilm_ku` y campo `cant`: el reparto lote ↔ bulto es de muchos a muchos. |
| 4 | Embalaje, pasada 1 | Cada bulto toma de cada línea solo la cantidad que el portal le asignó, y la descuenta. |
| 5 | Embalaje, pasada 2 | Sin cambio de criterio: solo líneas sin ningún bulto asignado (posición sin lotes). |

No cambian la interfaz de la FM, el servicio OData ni el portal.

## Casos simulados

Réplica del algoritmo en Python (scratchpad de la sesión, `sim_006.py`):

| Caso | Lotes SAP | Contenido de las HU |
|---|---|---|
| Lote X: 50 en bulto 1 y 70 en bulto 2 | 1 (X 120, en la posición) | B1: X 50 · B2: X 70 |
| Bultos 1 y 2 con X 10 + Y 10 cada uno | 2 (X 20, Y 20) | B1: X 10 + Y 10 · B2: X 10 + Y 10 |
| X solo en bulto 1, Y solo en bulto 2 | 2 | B1: X 50 · B2: Y 70 |
| Sin lotes, en dos bultos | 1 por el total | B1: 50 · B2: 70 |
| B1: X 30 + Y 20 · B2: X 70 | 2 (X 100, Y 20) | B1: X 30 + Y 20 · B2: X 70 |

## Verificación hecha

- Bloques `IF/LOOP/DO/CASE` balanceados (script local).
- **No** compilado en SAP ni pasado por abaplint (no se permitió descargarlo en esta sesión).
  El primer paso en SE37 es *Verificar*.

## Cómo aplicarlo (DS4)

1. SE37 → `ZBVMM_OC_GUARDAR_ENTREGAV2` → Código fuente: reemplazar con `propuesto/LZGF_CON_PORTALU32.abap`.
2. Verificar y activar. Misma orden que la FM de modificación (ver su LEEME).

## Pruebas mínimas antes de QAS

| Caso | Esperado |
|---|---|
| 1 posición, 1 lote en 2 bultos | 1 lote SAP, posición sin partir, 2 HU con su cantidad. |
| 2 lotes, ambos en los 2 bultos | 2 lotes SAP, 2 subposiciones, cada HU con su parte de cada lote. |
| 2 lotes, cada uno en su bulto | Igual que hoy. |
| Posición sin lotes en 2 bultos | Igual que hoy: 1 lote por el total, reparto por orden. |
| Material sin gestión de lote | Igual que hoy. |
| Almacén sin HU / pedido ZREP / importación ZBIM | Igual que hoy. |

## Aplicación

**11.11.2026 · DS4 mandante 100 · activo en DS4 e importado en QAS, pendiente de probar.**

- **Cómo:** por RFC con `poc-rfc-jco` (canal ADT, `SADT_REST_RFC_ENDPOINT`), usuario `ABAP_03`.
- **Orden de transporte:** `DS4K928176`. Se intentó primero en `DS4K929212` y SAP lo
  rechazó: la FM ya estaba bloqueada en `DS4K928176` (la orden de la @003), que sigue abierta.
  La parte de modificación de @006 va en `DS4K929212`: las dos órdenes viajan juntas.
- **Diferencias con lo activo:** ninguna. Lo activo era igual a `actual/` (@003, 1731 líneas).
- **Grabación:** `propuesto/LZGF_CON_PORTALU32.abap` completo, 1811 líneas. La interfaz no
  cambia. Releído después: la versión inactiva es la grabada y la activa no cambió.
- **Verificar:** sin errores. 37 advertencias, todas en otros includes del grupo.
- **Activar:** activado el 11.11.2026 (ABAP_03, desde la lista de objetos inactivos).
- **Transporte a QAS:** orden de copias `DS4K929851` (tipo T, destino QS4.100), liberada el
  11.11.2026 con los 40 objetos de `DS4K928176` y `DS4K929212`. Quedaron fuera la estructura y
  el tipo tabla `…_DETVM`, borrados en DS4. Las dos órdenes originales siguen modificables.
  Importada en QS4/100 el 11.11.2026 con `poc-rfc-jco` (usuario `E_SJUAREZ`), código `000`.
  Comprobado después: el fuente de QAS es idéntico al de DS4 y la sintaxis no da errores.
- **Pruebas:** ninguna todavía. Procedimiento del pase: `PASES-ABAP.md` en la raíz del proyecto.
