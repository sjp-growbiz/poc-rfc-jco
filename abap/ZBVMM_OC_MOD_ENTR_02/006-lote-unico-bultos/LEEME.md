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
