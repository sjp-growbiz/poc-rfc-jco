# ZBVMM_OC_MOD_ENTR_02 · @007 · una posición de entrega por vencimiento

FM de **modificación** de la entrega (Modificar Cita). Cambian `LZGF_CON_PORTALU28` (la FM) y
`LZGF_CON_PORTALF01` (rutinas; se graba el include completo). Va junto con @007 de
`ZBVMM_OC_GUARDAR_ENTREGAV2`.

- `actual/` — lo activo en DS4 el 12.11.2026 (igual a QAS; @006 incluida).
- `propuesto/` — con el cambio `@007`.

## Qué cambia

Una posición de pedido **sin subposiciones 9000xx** se trata como "una posición de entrega por
vencimiento". Las entregas que ya tienen `9000xx` siguen con la lógica anterior.

| # | Dónde | Cambio |
|---|---|---|
| 1 | `lotes_modif` | Lote nuevo (vencimiento nuevo): va en una posición libre de la misma posición de pedido (sin lote y que ningún lote de la trama nombra) o, si no hay, en una **posición nueva** agregada con `BAPI_DELIVERYPROCESSING_EXEC` (`DELIVERY_EXTEND`). Nunca `9000xx`. |
| 2 | `lotes_modif` | Posición de la posición de pedido que ningún lote de la trama nombra: se elimina. |
| 3 | `agrega_pos_entrega` (nueva) | Agrega la posición que refiere al pedido, con la cantidad del vencimiento y COMMIT propio. `BAPI_INB_DELIVERY_CHANGE` no puede (VL 216). |
| 4 | `quita_pos_mod_creadas` (nueva) y U28 | Si la modificación falla antes de grabarse, se borran las posiciones agregadas en la llamada; después se marcan para borrado sus lotes, como antes. |
| 5 | U28 | Se quita la validación @004 «tiene el lote X: no se puede cambiar a varios lotes u otro lote». |
| 6 | U28 y `modif_entrega` | Posición de pedido repartida en varias posiciones que llega **sin lotes** y con otra cantidad: error (no se sabe a qué vencimiento va). Con la misma cantidad no se toca. |
| 7 | `verifica_lotes_mod` | La comprobación «quedó en la posición padre y no en una subposición» solo se aplica a posiciones con `9000xx`. |
| 8 | `verifica_lotes_mod` | Un lote nuevo en varios bultos son varias filas con el mismo lote: se compara la **suma** con LIPS. Antes cada fila contra la línea entera, lo que daba error (afectaba también a @006). |
| 9 | `ini_pos_venc` (nueva) y U28 | Limpia las globales nuevas al inicio de cada llamada. |

Las globales nuevas (`gt_pos_indep`, `gt_pos_mod_creadas`) están declaradas en F01, antes de
`lotes_modif`, para no tocar el TOP. U28 no las usa directamente: llama a FORMs de F01.

El embalaje (`proce_hu`) ya trabaja por número de posición con `gt_lote_bulto`: no cambia.

## Probado antes de escribir (QAS, 12.11.2026, pedido 3200063858/150)

| Prueba | Resultado |
|---|---|
| Agregar posición independiente con `BAPI_INB_DELIVERY_CHANGE` | VL 216 «Posición 000020 inexistente» |
| Agregar con `BAPI_DELIVERYPROCESSING_EXEC` y `DELIVERY_EXTEND` | Posición 20 igual a la 10 (ZEL1, 1004/0230, mov. 101), `UECHA` 0, con su EKES |
| Lote y vencimiento en esa posición con `BAPI_INB_DELIVERY_CHANGE` | OK |
| Borrar esa posición con `DEL_ITEM` | OK; su EKES se borró sola |

## Portal

`planificacionentregav2/webapp/controller/Page1.controller.js`, `esLoteEnPadre` devuelve
siempre `false`: el portal ya no bloquea agregar lotes a una posición con un único lote.
**Publicar solo junto con @007 en SAP.**

## Pruebas en DS4 (pendientes)

| Caso | Esperado |
|---|---|
| Entrega creada con @007 (10 y 20, un vencimiento cada una): cambiar cantidades por bulto | Mismas posiciones, nuevas cantidades, HU rehechas |
| Agregar un tercer vencimiento | Posición nueva (30) con su lote; sin 9000xx |
| Quitar un vencimiento | Su posición se elimina |
| Posición con un solo lote (sin 9000xx): agregar un segundo vencimiento | Posición nueva para el segundo lote |
| Lote nuevo en 2 bultos | 1 lote, 1 posición, 2 HU |
| Posición repartida que llega sin lotes y con otra cantidad | Error, la entrega no cambia |
| Error provocado tras agregar la posición | La posición agregada se borra, el lote queda marcado para borrado |
| Entrega antigua con 9000xx | Igual que @006 |

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
