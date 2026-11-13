# ZBVMM_OC_GUARDAR_ENTREGAV2 · @007 · una posición de entrega por vencimiento

FM de **creación** de la entrega (Solicitar Cita), include `LZGF_CON_PORTALU32`.
Va junto con @007 de `ZBVMM_OC_MOD_ENTR_02` (modificación).

- `actual/` — lo activo en DS4 el 12.11.2026 (igual a QAS; @006 incluida).
- `propuesto/` — con el cambio `@007`.

## Problema

Una posición de pedido con varios vencimientos quedaba como una posición de entrega en 0 con
subposiciones de lote `9000xx` (`UECHA` = la posición). Otras aplicaciones no saben leer esa
estructura.

## Qué cambia

| # | Dónde | Cambio |
|---|---|---|
| 1 | Antes de `ZBBP_INB_DELIVERY_CREATE` | Los lotes de la trama se suman por (posición de pedido, vencimiento). Si hay más de un vencimiento y suman la cantidad de la posición, la fila de la posición se reemplaza por una fila por vencimiento. SAP crea una posición de entrega por fila (probado en QAS: 1800133280). |
| 2 | Tras leer la entrega creada | Cada posición de entrega se asocia a su vencimiento, en orden y con la misma cantidad. Si algo no cuadra, error y la entrega se elimina (como cualquier error de esta FM). |
| 3 | Bucle de lotes | La posición de entrega toma solo los lotes de su vencimiento: su cantidad es la del vencimiento y el lote va en la propia posición, sin `9000xx`. |

Sin cambios: con un solo vencimiento, o si los lotes no suman la cantidad, todo sigue como @006.
El embalaje ya recorre las líneas de LIPS por número de posición y reparte según el bulto de
cada lote, así que no cambia.

## Lo que no cubre

- Almacenes sin HU obligatoria (`ZBVMM_ENTRENOHU`) y pedidos de reparación: siguen asociando
  cada bulto a la **primera** posición de la posición de pedido (hoy, a la posición padre en 0).
- Las entregas ya creadas con `9000xx` no cambian; la modificación las sigue tratando como antes.

## Pruebas en DS4 (pendientes)

| Caso | Esperado |
|---|---|
| Material con 2 vencimientos repartidos en 2 bultos, de muchos a muchos | 2 posiciones de entrega (10, 20) con su lote y vencimiento, sin 9000xx; 2 HU con la cantidad de cada lote |
| Un solo vencimiento en 2 bultos | Igual que @006: 1 posición con su lote |
| Material sin gestión de lotes | Igual que antes |
| Dos posiciones de pedido, una con 2 vencimientos y otra con 1 | 3 posiciones de entrega |

## Aplicación

**12–13.11.2026 · activo en DS4 e importado en QAS, pendiente de probar en QAS.**

- **Grabado inactivo en DS4** con `poc-rfc-jco` (`POST /api/abap/007/aplicar`, usuario `ABAP_03`):
  U32 en `DS4K928176`; U28 y F01 en `DS4K929212` (SAP impuso esas órdenes: los objetos ya estaban en
  ellas). Lo activo era igual a `actual/`. Verificación de la inactiva: sin errores; 2 advertencias
  nuevas del tipo «ZBVMM_ST_RESULT can be enhanced…», por las firmas de las rutinas nuevas.
- **Activado en SE80** por la persona (13.11.2026). Hay que activar los tres objetos juntos: la FM
  `ZBVMM_OC_MOD_ENTR_02` sola da «FORM INI_POS_VENC does not exist», porque sus rutinas nuevas están en
  F01.
- **Transporte de copias** `DS4K929891` (destino QS4.100), armado y liberado a mano en SE01 con los
  objetos de `DS4K928176` y `DS4K929212` y sus tareas, sin las 4 entradas `…_DETVM` (borradas en DS4).
- **Importado en QS4/100** el 13.11.2026 (`E_SJUAREZ`), código `000`, 83 s. Copia previa de QAS fuera
  del repo. Comprobado: los tres fuentes de QAS son idénticos a `propuesto/`, sintaxis sin errores,
  `TPALOG` todo en `0000`.
- **Pendiente:** publicar el cambio del portal (`esLoteEnPadre`) y probar desde el portal.

## Pruebas en QAS (13.11.2026, pedido 3200063858/150, llamando a las FM como el portal)

| Caso | Resultado |
|---|---|
| Crear: un material, 2 vencimientos, 2 bultos de muchos a muchos (1800133294) | Pos. 10 (lote 855270, 30.06.2027, 2) y 20 (855271, 31.12.2027, 3), sin 9000xx, cada una con su EKES. HU1 = 10×1 + 20×1; HU2 = 10×1 + 20×2 |
| Modificar (OData): nuevas cantidades + tercer vencimiento | Pos. 30 nueva (855272, 31.01.2028, 1) con su EKES; 10 y 20 ajustadas; HU rehechas |
| Modificar: quitar el tercer vencimiento | Pos. 30 y su EKES borradas; 20 pasa a 3; HU rehechas |
| Crear con un solo vencimiento (1800133295) y modificar agregando otro, en los 2 bultos | Pos. 20 nueva (855274, 31.03.2028); un solo lote para los 2 bultos; HU con 1 de cada lote |
| Modificar sin lotes y con otra cantidad una posición con 2 vencimientos | Error «tiene varios vencimientos: envíe el detalle de lotes…»; la entrega no cambió |

Limpieza: 1800133294 y 1800133295 borradas con `ZBVMM_OC_ELIM_ENTR_ERROR`; la pos. 150 sin EKES.
Quedan los lotes de prueba 0000855270 a 0000855274 y las HU vacías 143687–143696, como deja el
borrado del portal.
