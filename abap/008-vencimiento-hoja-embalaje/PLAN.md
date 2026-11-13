# 008 · Fecha de vencimiento en la hoja de embalaje

**Estado:** propuesto, sin aplicar. El portal ya está listo (planificacionentregav2 **1.2.9**, en QAS
Externo desde el 13.11.2026).

## Problema

La hoja de embalaje del portal (Solicitar Cita → Ver / Descargar) arma la tabla de materiales de cada
embalaje con `ZET_MOSTRAR_REGISTROSet` (servicio `ZBVMM_WEB_OC_REL_PEDC_XCONF_SRV`). Cada fila es una
**línea de entrega dentro de una HU**, pero el servicio no devuelve ni el lote ni la posición de entrega:
solo pedido (`Zebeln`), posición de pedido (`Zvgpos`), material y cantidad.

Con @007, un material con dos vencimientos son dos posiciones de entrega del mismo ítem de pedido, y
en la hoja salen dos filas iguales salvo la cantidad. Sin la posición o el lote no se puede saber qué
fecha corresponde a cada fila.

## Lo que ya hace el portal (1.2.9)

Columna **F. Venc.** en la tabla de materiales:
1. Si la fila trae `Zvfdat`, la muestra (acepta `yyyyMMdd`, `yyyy-MM-dd` o `/Date(ms)/`; `00000000` = vacío).
2. Si no, la toma de los lotes de la entrega (`API_INBOUND_DELIVERY_SRV/A_InbDeliveryItem`) **solo** si
   la posición del pedido tiene una única fecha.
3. Con varias fechas y sin `Zvfdat`, queda en blanco.

Con este cambio de SAP el punto 1 cubre todos los casos.

## Cambio propuesto en SAP

Agregar a cada fila de `ZET_MOSTRAR_REGISTROSet` el lote y el vencimiento de su línea de entrega.

| # | Objeto | Cambio |
|---|---|---|
| 1 | `LZGF_CON_PORTALTOP`, tipo `gty_likps` | Campos `charg TYPE lips-charg` y `vfdat TYPE lips-vfdat`. |
| 2 | `LZGF_CON_PORTALF01`, FORM `get_data_tablas` | Agregar `b~charg b~vfdat` al `SELECT … FROM likp AS a INNER JOIN lips AS b … INTO CORRESPONDING FIELDS OF TABLE gt_likps`. |
| 3 | `LZGF_CON_PORTALF01`, FORM `prepare_data` | En el `LOOP AT gt_likps`, antes del `LOOP AT gt_vepo`, mover `<fs_likps>-charg` y `<fs_likps>-vfdat` a `<fs_final>-zcharg` / `<fs_final>-zvfdat`. Las filas de `gt_final_vepo` se copian de `<fs_final>` en las dos ramas (primera HU y siguientes), así que heredan los dos campos. Revisar también `carga_nohu` (almacenes sin HU). |
| 4 | DDIC | `gt_final` y `gt_final_vepo` son `TABLE OF zbvmm_entrega_re` (tabla Z). Se necesitan los campos `ZCHARG` (`CHARG_D`) y `ZVFDAT` (`VFDAT`): append a `ZBVMM_ENTREGA_RE` o, si la entidad OData usa otra estructura, en esa. **Confirmar primero** qué estructura usa la entidad. |
| 5 | SEGW `ZBVMM_WEB_OC_REL_PEDC_XCONF` | Entidad `ZET_MOSTRAR_REGISTRO`: propiedades `Zcharg` (Edm.String, 10) y `Zvfdat`. Recomendado **Edm.String de 8** (`yyyyMMdd`) en vez de Edm.DateTime, para evitar errores con fechas vacías; el portal acepta ambos. Regenerar objetos de runtime. |
| 6 | DPC_EXT del servicio | Si `GET_ENTITYSET` de `ZET_MOSTRAR_REGISTROSet` hace `MOVE-CORRESPONDING` desde `gt_final`/`gt_final_vepo`, no cambia. Si arma la salida campo a campo, agregar los dos. |

`LIPS-VFDAT` es el vencimiento que @007 (y @003/@006) graban en cada línea de lote con
`BAPI_INB_DELIVERY_CHANGE` (`EXPIRYDATE`). Para posiciones sin lote queda vacío.

## Impacto en otros consumidores

`ZET_MOSTRAR_REGISTROSet` lo usan también `recepcionentregav2` (Recepción, Escáner) y otras apps.
Agregar propiedades no rompe a quien lee JSON por nombre. No se cambia ningún campo existente.

## Pruebas

| Caso | Esperado en la hoja |
|---|---|
| Material con 2 vencimientos en 3 bultos (como la entrega 1800133297) | Cada fila con su fecha |
| Material con un lote | Su fecha (igual que hoy con 1.2.9) |
| Material sin gestión de lote | Columna vacía |
| Entrega sin OC | Sin cambios (esa tabla no tiene la columna) |
