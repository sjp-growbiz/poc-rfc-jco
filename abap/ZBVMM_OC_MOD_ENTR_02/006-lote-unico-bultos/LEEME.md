# ZBVMM_OC_MOD_ENTR_02 · @006 · un lote nuevo repartido en varios bultos

FM de **modificación** de la entrega (Modificar Cita), grupo `ZGF_CON_PORTAL`.
El cambio está solo en la rutina `lotes_modif` del include `LZGF_CON_PORTALF01`.
El código de la FM (`LZGF_CON_PORTALU28`, hoy @005) **no cambia**.

- `actual/` — `LZGF_CON_PORTALF01.abap` del repo (@004, 16.10.2026) y la rutina aislada
  `FORM_lotes_modif.abap`.
- `propuesto/` — los mismos con el cambio `@006`. Para aplicarlo basta reemplazar la rutina
  `lotes_modif` por `propuesto/FORM_lotes_modif.abap`.

> **Antes de pegar:** la @005 del 17.10 se aplicó en DS4 después de la copia del repo. Sus
> cambios están en el código de la FM, no en `lotes_modif`, pero hay que comparar la rutina
> activa en SE80 con `actual/FORM_lotes_modif.abap`. Si difiere, avisar antes de reemplazar.

## Problema

Los lotes que ya existen en SAP se suman por `POSNR` y su reparto por bulto queda en
`gt_lote_bulto` (desde @004). Los lotes **nuevos** no: `lotes_modif` creaba un lote SAP por
cada fila de la trama, así que un lote nuevo en dos bultos salía como dos lotes.

## Qué cambia en `lotes_modif`

| # | Cambio |
|---|---|
| 1 | Conteo de lotes por posición: los nuevos con el mismo vencimiento cuentan **una** vez. Decide si el lote va en la posición padre o en una 9000xx. |
| 2 | Lote nuevo con el mismo vencimiento que otro ya preparado para la posición: no se crea lote ni subposición; se suma su cantidad a la línea ya preparada, recibe el mismo `POSNR`/`CHARG` y su parte se agrega a `gt_lote_bulto`. |

El embalaje (`proce_hu`) ya reparte una línea en varios bultos según `gt_lote_bulto`; no cambia.
La devolución de `POSNR`/`CHARG` al portal (en la FM) tampoco: todas las filas del vencimiento
reciben los mismos valores.

## Verificación hecha

- Bloques balanceados en el include completo (script local).
- **No** compilado en SAP. Primer paso: *Verificar* el include en SE80.

## Pruebas mínimas antes de QAS

| Caso | Esperado |
|---|---|
| Lote nuevo en 2 bultos, sin otros lotes, posición sin partir | 1 lote SAP en la posición, 2 HU con su cantidad. |
| 2 lotes nuevos, ambos en los 2 bultos | 2 lotes SAP, 2 subposiciones. |
| Lote existente en 2 bultos | Igual que hoy. |
| Lote nuevo en un bulto con la misma fecha que un lote existente de **otro** bulto | Igual que hoy: se crea un lote nuevo. El portal junta nuevo y existente solo dentro del mismo bulto; juntarlos en la FM es un cambio aparte (también toca la validación de lote en la posición padre de la FM). |

## Aplicación

**11.11.2026 · DS4 mandante 100 · activo en DS4 e importado en QAS, pendiente de probar.**

- **Cómo:** por RFC con `poc-rfc-jco` (canal ADT, `SADT_REST_RFC_ENDPOINT`), usuario `ABAP_03`.
- **Orden de transporte:** `DS4K929212` (el include ya estaba en esa orden).
- **Diferencias con lo activo:** la rutina activa no era la de `actual/`. Tenía la @005
  (`lv_nueva_sub` y la fila de la posición padre al crear una subposición) y tres líneas
  marcadas `+@006` de otro cambio (factores de conversión al eliminar subposiciones).
  Por eso no se grabó `propuesto/` sino `propuesto-activo/FORM_lotes_modif.abap`: @006
  llevado sobre la rutina activa (`FORM_lotes_modif.base.abap`) con una fusión de tres vías.
  Solo agrega líneas (53); el único conflicto fue el `CLEAR` al inicio del bucle de
  posiciones, donde se conservaron los dos. `FORM_lotes_modif.diff` tiene el detalle.
- **Grabación:** include `LZGF_CON_PORTALF01` de 5786 líneas, solo cambia `lotes_modif`.
  Releído después: la versión inactiva es la grabada y la activa no cambió.
- **Verificar:** sin errores. 37 advertencias, todas en código anterior del grupo
  (ninguna en las líneas agregadas).
- **Activar:** activado el 11.11.2026 (ABAP_03, desde la lista de objetos inactivos).
- **Transporte a QAS:** orden de copias `DS4K929851` (tipo T, destino QS4.100), liberada el
  11.11.2026 con los 40 objetos de `DS4K928176` y `DS4K929212`. Quedaron fuera la estructura y
  el tipo tabla `…_DETVM`, borrados en DS4. Las dos órdenes originales siguen modificables.
  Importada en QS4/100 el 11.11.2026 con `poc-rfc-jco` (usuario `E_SJUAREZ`), código `000`.
  Comprobado después: el fuente de QAS es idéntico al de DS4 y la sintaxis no da errores.
- **Pruebas:** ninguna todavía. Procedimiento del pase: `PASES-ABAP.md` en la raíz del proyecto.
