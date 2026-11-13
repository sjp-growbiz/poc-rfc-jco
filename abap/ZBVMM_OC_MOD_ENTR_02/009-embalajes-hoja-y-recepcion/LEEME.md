# @009 · Embalajes que desaparecen en la hoja de embalaje y en Recepción

Include `LZGF_CON_PORTALF01` (grupo `ZGF_CON_PORTAL`), rutinas `prepare_data` y `agregar_mat`.
Las usa el GET de `ZET_MOSTRAR_REGISTROSet` (`ZBVMM_WEB_OC_REL_PEDC_XCONF_SRV`), que alimenta la hoja
de embalaje del portal (Solicitar Cita → Ver/Descargar) y la app **Recepción de entregas**.

- `actual/` — el F01 de @007, activo en DS4 y QAS desde el 13.11.2026 (copia de
  `007-posicion-por-vencimiento/propuesto/`). **Comparar con lo activo antes de grabar.**
- `propuesto/` — con `@009` (12 líneas marcadas).
- `sim_agregar_mat.py` — réplica del algoritmo que reproduce el caso.

## Síntoma

| Entrega | Qué se ve |
|---|---|
| 1800133298 (portal, 13.11.2026) | 2 embalajes; la hoja solo muestra el **embalaje 2**, con dos filas iguales de agua de mesa. |
| 1800133273 (Recepción, 06.11.2026) | 4 embalajes; Recepción solo muestra los **embalajes 3 y 4**. |

## Causa

`prepare_data` recorre las líneas de entrega. Por cada una agrega su fila a `gt_final` y, por cada HU
que la contiene, una copia en `gt_final_vepo`. Luego `agregar_mat` pasa esas copias a `gt_final` y
**borra la fila original**. Para encontrarla hacía un `READ TABLE gt_final WITH KEY` entrega + posición
de pedido + pedido + material.

Esa clave no es única cuando una posición de pedido tiene varias líneas de entrega: lotes en `9000xx`
(@003/@006) o una posición por vencimiento (@007). En la segunda línea el `READ` encuentra la fila de
la **primera**, ya resuelta, y la borra. Resultado: desaparece el embalaje de esa fila y la fila de la
línea en curso queda duplicada.

```text
Caso 1800133298: agua con 2 vencimientos = pos. 10 (bulto 1) y pos. 20 (bulto 2)
Hoy:        [(20, bulto 2), (20, bulto 2)]  -> bultos: [2]
Corregido:  [(10, bulto 1), (20, bulto 2)]  -> bultos: [1, 2]
```

## Corrección

| Dónde | Cambio |
|---|---|
| `prepare_data` | Guarda el índice de la fila de la línea en curso (`lv_idx_final = lines( gt_final )` tras el `APPEND`); se limpia en cada vuelta. |
| `prepare_data` | Llama `agregar_mat USING lv_idx_final`, y solo si esa línea creó su fila (protege los pedidos de reparación, donde `gt_final_vepo` puede venir de la línea anterior). |
| `agregar_mat` | Recibe el índice y lee/borra **esa** fila (`READ TABLE gt_final … INDEX i_idx_final`), en vez de buscar por clave. |

No cambia el formato ni los campos del servicio. Las posiciones con una sola línea de entrega dan el
mismo resultado que hoy.

## Relación con 008

008 (vencimiento en la hoja) también toca `prepare_data`. Aplicar **primero 009** y construir 008 sobre
este F01.

## Pruebas

| Caso | Esperado |
|---|---|
| 1800133298 en la hoja de embalaje | Embalajes 1 y 2, cada uno con su fila de agua |
| 1800133273 en Recepción | Embalajes 1 a 4 |
| Entrega sin lotes, un material en 2 bultos | Igual que hoy |
| Pedido de reparación | Igual que hoy |
| Almacén sin HU | Igual que hoy (otra rama, `carga_nohu`) |

Consulta directa para comprobar: `ZET_MOSTRAR_REGISTROSet?$filter=Zvbeln eq '1800133298'&$format=json`
→ una fila por línea de entrega y HU, con `ZvhilmKu` 1 y 2.

## Prompt para aplicarlo desde la PC con SAP

```text
Aplica en SAP el cambio @009 de abap/ZBVMM_OC_MOD_ENTR_02/009-embalajes-hoja-y-recepcion (lee su
LEEME.md y PASES-ABAP.md). Pasos, uno por mensaje, esperando mi confirmación:
1) Lee el include LZGF_CON_PORTALF01 activo en DS4 y compáralo con actual/. Si difiere, lleva @009
   sobre lo activo en una carpeta propuesto-activo/ y muéstrame las diferencias.
2) Graba el include en DS4 (inactivo), verifica la sintaxis y dime el resultado. Pregúntame la orden.
3) Yo activo en SE80. Luego llama ZET_MOSTRAR_REGISTROSet con Zvbeln '1800133298' en DS4 o, tras el
   transporte, en QAS, y confirma que salen los embalajes 1 y 2.
4) Transporte de copias a QS4.100 solo con mi confirmación.
Reglas: sin commit/push salvo que lo pida; sin contraseñas. Al terminar, agrega "Aplicación" al LEEME.
```
