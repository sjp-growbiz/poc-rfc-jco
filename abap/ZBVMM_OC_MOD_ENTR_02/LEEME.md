# ZBVMM_WEB_OC_PORTAL_FASE2_SRV · multilote en modificación (@004)

Servicio OData de **modificación de entregas entrantes** del portal de
proveedores. Objetos:

| Objeto | Archivo |
|---|---|
| Clase `ZCL_ZBVMM_WEB_OC_PORTA_DPC_EXT` (`CREATE_DEEP_ENTITY`) | `ZCL_ZBVMM_WEB_OC_PORTA_DPC_EXT.abap` |
| FM `ZBVMM_OC_MOD_ENTR_02` | `LZGF_CON_PORTALU28.abap` |
| FORMs `lotes_modif`, `modif_entrega`, `proce_hu`, nuevo `refresca_lips02` | `LZGF_CON_PORTALF01.abap` |
| Tipos y globales (`gty_lips_02-uecha`, `gt_lote_bulto`, …) | `LZGF_CON_PORTALTOP.abap` |

- `original/` — fuente activa en DS4 al 16.10.2026 (orden DS4K929212 / tarea DS4K929213).
- `propuesto/` — con los cambios, marcados `@004`.

**Aplicado en DS4 (DEV, mandante 100) el 16.10.2026 01:43** por ADT, orden
**DS4K929212** / tarea **DS4K929213** (ABAP_03): TOP, F01, FM y clase escritos,
verificación de sintaxis de SAP sin errores (solo advertencias preexistentes) y
activados juntos. Comprobado por RFC: sin versiones inactivas y fuente activo
idéntico a `propuesto/`. **No** transportado a QAS.

El modelo OData (MPC) no cambia: ya tenía la entidad de lotes
`ZET_DETALLE_LOT_MOD` y la navegación `MODIF_DET_LOT`.

## Qué faltaba

| # | Problema en DS4 | Efecto |
|---|---|---|
| 1 | El FM recibe `T_ENTR_LOT` pero **nunca lo copia** a `gt_entr_lot`, que es lo que leen los FORMs. | La lógica de lotes estaba muerta: los lotes se ignoraban. |
| 2 | `proce_hu` embala cada bulto en la **primera línea de LIPS** de la posición. | Con lotes es la posición padre (sin lote): las subposiciones 9000xx no se embalan. |
| 3 | `gt_lips02` no se relee tras crear subposiciones. | El embalaje no las ve. |
| 4 | `proce_hu` solo trabaja si la entrega **ya tenía HU**; un error al borrarlos se ignoraba. | Sin HU previos la modificación no hacía nada, en silencio. |
| 5 | `lotes_modif` se ejecutaba dos veces por llamada. | Doble procesamiento de lotes. |
| 6 | La partición se deducía por "menor POSNR" / "línea sin lote". | Falla con dos líneas sin lote del mismo ítem (confirmaciones). |
| 7 | `modif_entrega` saltaba toda línea con lote. | Cambios de cantidad ignorados sin aviso; posiciones partidas que salen de la trama no se eliminaban. |
| 8 | Unidad base (`MEINS`) con cantidad en unidad de pedido; `VRKME` nunca se leía. | Cantidad errónea si difieren. |
| 9 | Un único lote solo iba a la padre si igualaba la cantidad **anterior**. | Partición innecesaria al cambiar cantidad. |
| 10 | Error en `BAPI_BATCH_CREATE`: sin rollback, seguía con otras posiciones. | Lotes huérfanos y estado a medias. |
| 11 | `DELETE ADJACENT DUPLICATES` de bultos sin `SORT`; `SORT` de la tabla equivocada; globales sin limpiar. | HU duplicados y datos arrastrados entre llamadas. |
| 12 | `posnr` y `charg` de los lotes nuevos no volvían al portal. | En la siguiente modificación el portal no puede referirse a esos lotes. |

## Qué cambia

**FM `ZBVMM_OC_MOD_ENTR_02`**
- Limpia globales. Pasa los lotes a `gt_entr_lot`: un lote nuevo por fila; un
  lote existente (con `POSNR`) en una sola fila sumando sus bultos, con el
  reparto por bulto en `gt_lote_bulto`.
- **Validaciones antes de tocar nada** (así `proce_hu` no borra HU para fallar
  después):
  - por posición, suma de lotes = suma de bultos;
  - por bulto, lo que declara = sus lotes;
  - lotes de posiciones que no están en la entrega;
  - posición partida que llega sin lotes y con otra cantidad;
  - posición con un único lote en la propia posición que pasa a varios u otro
    lote (requiere partir la posición: **no soportado**, error claro).
- Lee `VRKME` y `UECHA`; corrige el `SORT` de complementarios.
- Devuelve `posnr`/`charg` reales de los lotes nuevos en el orden de la trama
  (solo si no hubo error).
- Si la llamada falla, marca para borrado (`DEL_FLAG`) los lotes que creó y que
  no quedaron en la entrega; si no puede, avisa (`W`).

**`lotes_modif`** — una vez por llamada; padre y subposiciones por `UECHA`;
unidad `VRKME`; un único lote ⇒ posición padre aunque cambie la cantidad;
`LTMENGE = 0` en un lote existente ⇒ se elimina su línea; actualiza
vencimiento; rollback y corte ante error; registra lotes creados y su bulto.

**`modif_entrega`** — subposiciones y padres por `UECHA`; una línea con un solo
lote sin lotes en la trama se modifica normalmente (conserva el lote); posición
partida que sale de la trama ⇒ se elimina la padre; relee LIPS tras el primer
cambio exitoso (`refresca_lips02`).

**`proce_hu`**
- El `IF` de "había HU" envuelve solo el borrado; modificar y embalar corre
  siempre. Error al borrar un HU ⇒ error y corte.
- `SORT` de bultos.
- Embalaje repartido:
  - **pasada 1**: de cada línea, lo asignado por el portal a ese bulto
    (`gt_lote_bulto`, admite un lote en varios bultos);
  - **pasada 2**: líneas sin bulto asignado, por cantidad;
  - la padre de una partición no se embala.
- Errores si un bulto declara más de lo que hay o si queda cantidad sin bulto;
  corta tras error.
- Peso del bulto y mensaje: una vez por línea de detalle.
- Ignora las líneas de embalaje complementario.

**DPC** — lote sin `VHILMLT` ⇒ toma el bulto donde viene anidado; devuelve
`posnr` y `charg` de cada lote en la respuesta.

El contrato con el portal se mantiene (HTTP 201, mensajes en
`ZET_RESULT_MOD_ENTSet`). Los errores nuevos llegan como filas `Type = 'E'`.
**Novedad para el front**: la respuesta trae `Posnr` y `Charg` en cada lote; el
portal debe guardarlos y reenviarlos en la siguiente modificación de esa
entrega (sin ellos, el lote se trata como nuevo).

## Verificación hecha (sin escribir en SAP)

- `abaplint` (parser): 0 errores.
- **Verificación de sintaxis de SAP en DS4**, enviando el código sin guardar
  (check run de ADT con contenido): FM, F01, TOP y clase con **0 errores**; solo
  las advertencias preexistentes de otros FORMs (la clase, ninguna). SAP acepta
  un solo fuente sin guardar por verificación, así que FM y F01 se verificaron
  con las globales/tipo nuevos declarados en la propia prueba.
- Revisión de lógica independiente; sus hallazgos están incorporados salvo los
  marcados abajo como "a probar en DEV".

## Cómo aplicarlo

En DS4, orden **DS4K929212** (tarea DS4K929213), que ya contiene estos objetos.
Subir TOP, F01, FM y clase y **activarlos juntos** (el FM y el F01 usan los
tipos nuevos del TOP).

## Pruebas en DEV

| Caso | Esperado |
|---|---|
| Modificar cantidad, posición sin lotes (con y sin HU) | Igual que hoy. |
| Entrega en almacén con HU que aún no tiene HU | Ahora se modifica y embala (antes no hacía nada). |
| Posición sin lote → 2 lotes nuevos en 1 bulto | Subposiciones 9000xx con lote, embaladas; la respuesta trae `Posnr`/`Charg`. |
| 1 posición en 2 bultos, un lote en cada uno | Cada lote en su HU. |
| Mismo lote existente repartido en 2 bultos | Una subposición con la suma; cada bulto embala su parte. |
| Posición con 1 lote (en la padre), cambia cantidad sin lotes | Cambia la cantidad, conserva el lote. |
| Posición con 1 lote en la padre → 2 lotes | Error claro; no se toca nada. |
| Posición partida, cambia cantidad sin enviar lotes | Error claro; no se toca nada (HU incluidos). |
| Lotes que no suman lo de los bultos (por posición o por bulto) | Error claro; no se toca nada. |
| Lote existente con cantidad 0 / quitado de la trama | Se elimina su subposición. |
| Quitar la posición partida completa | Se elimina la padre (**verificar** que arrastra las subposiciones). |
| Cambiar el total de una posición partida enviando lotes | **Verificar** que SAP recalcula la cantidad de la padre. |
| Error al crear un lote | Error; lotes creados en la llamada marcados para borrado. |

## Límites conocidos

- `proce_hu` elimina los HU **antes** de modificar (diseño previo). Las
  validaciones nuevas cubren los errores de datos, pero un error de SAP en
  `BAPI_BATCH_CREATE` o `BAPI_INB_DELIVERY_CHANGE` aún deja la entrega sin HU.
- Un lote **nuevo** repartido en dos bultos llega como dos filas sin clave
  común y se crea como dos lotes SAP. Unirlas exige una clave del portal (p. ej.
  lote del proveedor, `LICHA`), que la trama no tiene.
- Se asume que la cantidad del portal, `LTMENGE` y `LFIMG` están en la misma
  unidad (la del pedido = `VRKME`); no hay conversión.
- El cambio de vencimiento de un lote existente se envía en la entrega; falta
  confirmar en DEV si actualiza el maestro de lote.
