# Cambios ABAP del portal de proveedores (grupo `ZGF_CON_PORTAL`)

Copias de trabajo de las FM del portal: lo que corre en SAP (`original/` o `actual/`) y la
corrección propuesta (`propuesto/`). Nada de esta carpeta se aplica solo: cada cambio se pega
a mano en DS4, se verifica, se activa y se transporta.

| Carpeta | FM | Cambio | Estado |
|---|---|---|---|
| `ZBVMM_OC_GUARDAR_ENTREGAV2/original` → `propuesto` | Creación de entrega (Solicitar Cita) | @003 multilote, embalaje por bulto | Aplicado en DS4 y QAS |
| `ZBVMM_OC_MOD_ENTR_02/original` → `propuesto` | Modificación de entrega (Modificar Cita) | @004 multilote en modificación | Aplicado en DS4 y QAS (luego @005 en SAP) |
| `ZBVMM_OC_GUARDAR_ENTREGAV2/006-lote-unico-bultos` | Creación | **@006** un lote en varios bultos = un lote SAP | **Propuesto, sin aplicar** |
| `ZBVMM_OC_MOD_ENTR_02/006-lote-unico-bultos` | Modificación (rutina `lotes_modif`) | **@006** lo mismo para lotes nuevos | **Propuesto, sin aplicar** |

Para aplicar @006 desde otra PC con Claude Code, usar [PROMPT-006-otra-pc.md](PROMPT-006-otra-pc.md).

---

## @006 · Un lote repartido en varios bultos

### El problema

Al registrar una cita, el portal manda los lotes como **lote dentro de cada bulto**: un lote de
120 unidades con 50 en el bulto 1 y 70 en el bulto 2 llega como dos filas con la misma fecha de
vencimiento. La FM de creación hacía un lote SAP por fila, así que la entrega quedaba con **dos
lotes con el mismo vencimiento** y la posición partida en dos subposiciones 9000xx.

La relación correcta es de muchos a muchos entre **lotes y HU** (bulto = HU): una HU puede llevar
varios lotes y un lote puede ir en varias HU. Con @006 la FM crea un lote por vencimiento y guarda
aparte cuánto de ese lote va en cada bulto.

### Qué se cambia

| Objeto en SAP | Transacción | Qué se pega | Archivo |
|---|---|---|---|
| FM `ZBVMM_OC_GUARDAR_ENTREGAV2` (include `LZGF_CON_PORTALU32`) | SE37 | El código fuente **completo** | `ZBVMM_OC_GUARDAR_ENTREGAV2/006-lote-unico-bultos/propuesto/LZGF_CON_PORTALU32.abap` |
| Rutina `lotes_modif` del include `LZGF_CON_PORTALF01` | SE80 | **Solo** la rutina, desde su comentario de cabecera hasta su `ENDFORM.` | `ZBVMM_OC_MOD_ENTR_02/006-lote-unico-bultos/propuesto/FORM_lotes_modif.abap` |

No cambian la interfaz de las FM, los servicios OData, el código de `ZBVMM_OC_MOD_ENTR_02`
(`LZGF_CON_PORTALU28`) ni el portal. El detalle de cada cambio está en el `LEEME.md` de cada
carpeta `006-lote-unico-bultos`.

### Requisitos

- Acceso a **DS4, mandante 100**, con autorización de desarrollo (SE37, SE80) y una orden de
  transporte modificable. Las anteriores fueron `DS4K928176` (creación) y `DS4K929212`
  (modificación); se puede usar una nueva para los dos objetos.
- Esta carpeta en la PC donde se trabaje (clonar o actualizar el repositorio `poc-rfc-jco`).

### Paso 1 · Comparar con lo que corre en SAP

El cambio se escribió sobre las copias de `actual/`. Si SAP tiene algo distinto, no se pega
directamente: primero se lleva @006 a la versión activa.

1. **SE37** → `ZBVMM_OC_GUARDAR_ENTREGAV2` → *Visualizar*. Copiar todo el código
   (Ctrl+A, Ctrl+C) y compararlo con `…/006-lote-unico-bultos/actual/LZGF_CON_PORTALU32.abap`.
   Debe ser la versión **@003** del 15.10.2026, sin marcas posteriores.
2. **SE80** → grupo de funciones `ZGF_CON_PORTAL` → *Includes* → `LZGF_CON_PORTALF01` →
   buscar (Ctrl+F) `FORM lotes_modif`. Copiar la rutina completa y compararla con
   `…/ZBVMM_OC_MOD_ENTR_02/006-lote-unico-bultos/actual/FORM_lotes_modif.abap`.
   La copia del repo es de la @004; la @005 del 17.10 no debería haber tocado esta rutina.
3. Si los dos coinciden, seguir. Si no, **parar** y llevar el cambio @006 sobre el código activo.

Alternativa en SAP: *Utilidades → Versiones → Gestión de versiones* muestra si hubo cambios
después de las órdenes anteriores.

### Paso 2 · Aplicar la FM de creación

1. **SE37** → `ZBVMM_OC_GUARDAR_ENTREGAV2` → *Modificar*.
2. Seleccionar todo el código y reemplazarlo por `propuesto/LZGF_CON_PORTALU32.abap`.
   La interfaz (TABLES `T_ENTR_CAB`, `T_ENTR_DET`, `T_ENTR_DET_LOT`, `T_PEDIDOTEXT`,
   `T_RESULT`) no cambia.
3. **Verificar** (Ctrl+F2). Solo se aceptan advertencias que ya existían en otros includes del
   grupo. Si hay errores, anotar línea y mensaje y no activar.
4. **Activar** (Ctrl+F3) y asignar la orden de transporte.

### Paso 3 · Aplicar la rutina de modificación

1. **SE80** → `ZGF_CON_PORTAL` → `LZGF_CON_PORTALF01` → *Modificar*.
2. Buscar `FORM lotes_modif`. Seleccionar desde el bloque de comentarios que la precede
   (`*&---…` con el texto «Crea, actualiza y elimina las subposiciones de lote…») hasta su
   `ENDFORM.` inclusive, y reemplazarlo por `propuesto/FORM_lotes_modif.abap`.
3. **Verificar** el include y luego **activar**. Al ser un include compartido, SAP puede pedir
   activar junto con otros objetos del grupo: activar solo lo que pertenezca a esta orden.

### Paso 4 · Probar

DS4 no tiene entregas con materiales de lote, por eso las versiones anteriores se probaron en QAS
mediante **transporte de copias** a QS4.100. Casos mínimos en el portal de proveedores:

| Caso | Resultado esperado en la entrega |
|---|---|
| Solicitar Cita: 1 lote en 2 bultos | 1 lote SAP, la posición **sin** subposiciones 9000xx, 2 HU con su cantidad |
| Solicitar Cita: lotes X e Y, ambos en los 2 bultos | 2 lotes SAP, 2 subposiciones, cada HU con su parte de X y de Y |
| Solicitar Cita: X en el bulto 1 e Y en el bulto 2 | Igual que antes de @006 |
| Solicitar Cita: material con lote pero sin fechas, en 2 bultos | 1 lote por el total, repartido en las 2 HU |
| Solicitar Cita: material sin gestión de lote | Igual que antes |
| Modificar Cita: agregar un lote **nuevo** en 2 bultos | 1 lote SAP nuevo, 2 HU con su cantidad |
| Modificar Cita: lote existente en 2 bultos | Igual que antes |

Dónde mirar: **VL33N** (posiciones y lotes de la entrega) y la pestaña *Conten.total* de la
visualización de unidades de manipulación (lote y cantidad dentro de cada HU).

### Paso 5 · Si hay que volver atrás

Pegar de nuevo el contenido de `actual/` en el mismo objeto (o recuperar la versión anterior en
*Gestión de versiones*), verificar y activar.

### Limitación conocida

En Modificar Cita, un lote **nuevo** con la misma fecha que un lote **existente** que está en otro
bulto sigue creando un lote nuevo. El portal solo los junta dentro del mismo bulto. Resolverlo
requiere además cambiar una validación del código de `ZBVMM_OC_MOD_ENTR_02`.
