# ZBVMM_OC_GUARDAR_ENTREGAV2 · correcciones @003

Servicio OData `ZBVMM_WEB_OC_GUARD_ENTREGAV2_SRV` y su FM
`ZBVMM_OC_GUARDAR_ENTREGAV2` (grupo `ZGF_CON_PORTAL`, include `U32`).

- `original/` — fuente leída de DS4 por RFC el 15.10.2026 (versión activa).
- `propuesto/` — misma fuente con los cambios, marcados `@003`.

**Aplicado en DS4 (DEV, mandante 100) el 16.10.2026 00:13** por ADT, orden
**DS4K928176** / tarea **DS4K928177** (usuario ABAP_03). Verificación de
sintaxis de SAP sin errores (solo advertencias preexistentes de otros
includes del grupo) y activado. Comprobado por RFC: sin versiones inactivas y
fuente activo idéntico a `propuesto/`. **No** transportado a QAS.

El contrato con el portal no cambia:
HTTP 201, mensajes en `ZETRESULTADOSet`, y el éxito sigue siendo
`000 · "Se creó la entrega: <vbeln>"` con `TYPE` vacío.

## Qué cambia

| # | Dónde | Cambio |
|---|---|---|
| 1 | FM, inicio | Limpia las globales del grupo (`gt_pedpos`, `gt_ekpo`, `gt_entrenohu`, `gt_embcomp`…) y ordena `T_ENTR_DET_LOT`. Antes una llamada podía arrastrar filas de otra a `MODIFY zbvmm_entrenohu / zbvmm_emb_comp`, y la búsqueda binaria dependía de que el llamador ordenara. |
| 2 | FM, cabecera | `LFDAT` y `LFUHR` del proveedor si son plausibles y la fecha no está en el pasado; si no, hoy (como antes). |
| 3 | FM, lotes | Posición sin `ZDETALLELOT` ⇒ un lote por la cantidad completa (como antes de @002), **solo si el material gestiona lotes** en el centro (`MARC-XCHPF`). Si no, la posición no se toca. |
| 4 | FM, lotes | Error en `BAPI_BATCH_CREATE` ⇒ rollback, se corta, no se modifica la entrega. Antes se confirmaba y se seguía con lote vacío. |
| 5 | FM, lotes | `T_ENTR_DET_LOT-POSNR` guarda la posición real del lote (la posición o su 9000xx); antes siempre la posición padre. |
| 6 | FM, embalaje | Cada bulto embala solo su cantidad. Pasada 1: lotes con `VHILMLT` = bulto. Pasada 2: lotes sin bulto, por orden. Antes cada bulto embalaba la posición completa y, con una posición en dos bultos, la entrega se borraba. |
| 7 | FM, embalaje | Error claro si un bulto declara más de lo que hay, o si queda cantidad de lote sin bulto. Tras un error no se crean ni embalan más HU. |
| 7b | FM, embalaje | Se embalan también los materiales sin lote (@002 los dejaba fuera con `charg NE space`); solo se excluye la posición principal de una partición de lote (`LIPS-UECHA`). |
| 7c | FM, embalaje | El estado 04 se graba una vez, después de los controles (antes, una vez por bulto). |
| 8 | FM, embalaje | Cantidad del HU en unidad base (`LFIMG × UMVKZ / UMVKN`). Si la unidad de venta es la base, el factor es 1 y no cambia nada. |
| 9 | FM, cierre | La eliminación por error se hace una sola vez, solo si la entrega existe, y marca para borrado los lotes creados (`BAPI_BATCH_CHANGE`, `DEL_FLAG`), solo si la entrega efectivamente desapareció de LIKP. |
| 10 | FM, cierre | Un único mensaje de éxito, solo si no hubo errores, con un commit final (sustituye al `COMMIT WORK` que se quitó del DPC). Antes salía hasta una vez por línea de LIPS, y también cuando la entrega se había borrado. |
| 10b | FM, creación | Si `ZBBP_INB_DELIVERY_CREATE` falla con `MESSAGE`, el error llega al portal (antes: respuesta vacía). |
| 10c | FM, mov. 103 | Fecha de contabilización = hoy si `LFDAT` es futura (ahora `LFDAT` puede venir del proveedor). |
| 11 | FM | `ZUL_AUFL` se lee de la misma fila que `VEGR2`/`INHALT` (antes, de la última fila de otro LOOP). |
| 12 | DPC_EXT | `CREATE_DEEP_ENTITY` y la firma de `CUSTOME_CREATE_DEEP_ENTITY` usan `ZCL_ZBVMM_WEB_OC_GUARD_MPC_EXT` (antes, el MPC del servicio V1). Sin `COMMIT WORK`. |

Se mantiene a propósito la espera de @001 tras crear cada lote: solo actúa si
el lote aún no es visible en MCHA.

## Verificación hecha

- Sintaxis: `abaplint` 2.120 (parser, release 7.57+) sin errores, en Docker.
- Bloques `IF/LOOP/DO` balanceados.
- Firmas y campos confirmados en DS4 por RFC: `BAPI_BATCH_CHANGE`,
  `BAPIBATCHATT(X)-DEL_FLAG`, `BBP_INBD_L-DELIV_TIME`, `LIPS-UMVKZ/UMVKN/UECHA`,
  `MARC-XCHPF`, `DATE/TIME_CHECK_PLAUSIBILITY`.
- Revisión de lógica independiente; sus hallazgos están incorporados.
- **No** se compiló en SAP (no se escribe en el sistema desde aquí): la
  verificación de sintaxis de SE37/SE24 con el DDIC real es el primer paso.

## Cómo aplicarlo (DS4)

1. **SE24 → `ZCL_ZBVMM_WEB_OC_GUARD_DPC_EXT`**
   - Método `CUSTOME_CREATE_DEEP_ENTITY` → Parámetros → `ER_DEEP_ENTITY`:
     tipo `ZCL_ZBVMM_WEB_OC_GUARD_MPC_EXT=>TS_DEEP_ENTITY`.
   - `CREATE_DEEP_ENTITY`: reemplazar con `propuesto/…CM001.abap`.
   - `CUSTOME_CREATE_DEEP_ENTITY`: reemplazar con `propuesto/…CM002.abap`.
   - Verificar y activar.
2. **SE37 → `ZBVMM_OC_GUARDAR_ENTREGAV2`** → código fuente: reemplazar con
   `propuesto/LZGF_CON_PORTALU32.abap` (la interfaz no cambia). Verificar y activar.
3. Una sola orden de transporte para los dos objetos.

## Pruebas mínimas antes de QAS

| Caso | Esperado |
|---|---|
| 1 posición, 1 bulto, 1 lote = cantidad | Igual que hoy. |
| 1 posición en 2 bultos, 2 lotes con `VHILMLT` | Cada lote en su HU. Hoy: la entrega se borra. |
| Igual, sin `VHILMLT` | Reparto por orden, entrega creada. |
| Posición sin lotes | Un lote por el total, embalada. |
| Bulto declara más que sus lotes | Un error claro, entrega eliminada, lotes con marca de borrado. |
| Material sin gestión de lote, sin lotes | No se crea lote; se embala igual. |
| Material sin gestión de lote, con lotes enviados | Error de `BAPI_BATCH_CREATE`, entrega eliminada (datos inconsistentes). |
| Pedido de reparación (`ZREP`) | Igual que hoy. |
| Almacén sin HU (no `0230`) | Igual que hoy. |
| Importación `ZBIM` con error en el mov. 103 | Entrega eliminada una vez, lotes marcados. |
| `LFDAT` vacía / pasada / futura | Hoy / hoy / la enviada. |

## Fuera de alcance (anotado)

- `ZBVMM_OC_ELIM_ENTR_ERROR` hace `MOVE-CORRESPONDING <fs_result> TO <fs_result>`
  y devuelve filas vacías; por eso los mensajes de eliminación solo muestran
  `TEXT-046`. Lo usan otros procesos: corregirlo aparte.
- Devolver errores como HTTP 4xx rompería el contrato; requiere coordinar con
  todas las apps que consumen el servicio.
