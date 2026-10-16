# ZBVMM_OC_ELIM_ENTR_ERROR · corrección @001

FM `ZBVMM_OC_ELIM_ENTR_ERROR` (grupo `ZGF_CON_PORTAL`, include `U27`,
habilitado para RFC). Borra los HU y la entrega entrante cuando falla la
creación desde el portal, y revierte las confirmaciones de EKES.

- `original/` — fuente activo leído de DS4 por RFC el 16.10.2026
  (última versión: E_KCHIRINOS, 31.12.2023).
- `propuesto/` — el mismo fuente con el cambio, marcado `@001`.

**No aplicado en SAP.** Hace falta tu confirmación y una orden de transporte
que indiques tú.

## El bug

Al final, el loop que pasa `IT_RESULT` (local) a `T_RESULT` (parámetro) añade
una fila vacía a `T_RESULT` y luego copia la fila local **sobre sí misma**:

```abap
APPEND INITIAL LINE TO t_result ASSIGNING FIELD-SYMBOL(<fs_resultados>).
MOVE-CORRESPONDING <fs_result> TO <fs_result>.        " ← no hace nada
```

`T_RESULT` sale con tantas filas como mensajes, pero todas vacías
(`CODIGO = 000`, `TYPE = ' '`, `MSG = ' '`).

## Cambio propuesto (una línea)

```abap
MOVE-CORRESPONDING <fs_result> TO <fs_resultados>.    "+@001
```

`IT_RESULT` es `ZBVMM_ST_RESULT` y `T_RESULT` es
`ZBVMM_TT_CONFIRMAR_RESULTADO`, que tiene la misma estructura como tipo de
línea (`CODIGO`, `MSG`, `TYPE`; comprobado en DD40L/DD03L). La copia es campo
a campo y no se pierde nada. La interfaz no cambia.

## Lo que devuelve el FM una vez corregido

| Situación | Filas en `T_RESULT` (hoy: las mismas, vacías) |
|---|---|
| Entrega borrada (`BAPI_INB_DELIVERY_CHANGE` sin mensajes) | `999 · S · "La entrega ha sido eliminada."` (TEXT-013) |
| Error al quitar un HU (`BAPI_HU_DELETE_FROM_DEL`) | una fila por mensaje E: `000 · E · <texto del mensaje>` |
| Error al borrar la entrega | una fila por mensaje E: `000 · E · <texto>` |

`CODIGO` sale `000` en los errores: `carga_errores` (F01) hace
`MOVE-CORRESPONDING bapiret2 → zbvmm_st_result`, y en BAPIRET2 solo coincide
el campo `TYPE`; el número del mensaje (`NUMBER`) no pasa a `CODIGO`. No se
toca aquí.

## Llamadores

Índice de dónde-se-usa (`CROSS`, `TYPE = 'F'`). `WBCROSSGT` no aplica a
módulos de función y no tiene entradas:

| Include | FM | Servicio OData (DPC_EXT) | Llamadas |
|---|---|---|---|
| `LZGF_CON_PORTALU02` | `ZBVMM_OC_GUARDAR_ENTREGA` (V1) | `ZBVMM_WEB_OC_GUARD_ENTREGA_SRV` (`ZCL_ZBVMM_WEB_OC_GU_01_DPC_EXT`) | 2: error general (`g_error`) y error del mov. 103 `ZBIM` |
| `LZGF_CON_PORTALU32` | `ZBVMM_OC_GUARDAR_ENTREGAV2` (V2, @003) | `ZBVMM_WEB_OC_GUARD_ENTREGAV2_SRV` (`ZCL_ZBVMM_WEB_OC_GUARD_DPC_EXT`) | 1 activa (las dos de antes de @003 están comentadas) |

No hay otros llamadores en ABAP. Los dos DPC copian `CODIGO`, `MSG` y `TYPE`
tal cual a `ZETRESULTADOSet`.

**Pendiente: llamadas RFC externas.** El FM está habilitado para RFC
(`TFDIR-FMODE = R`), así que un backend del portal podría llamarlo por RFC sin
pasar por estos servicios. Desde SAP no se puede ver en el índice; hay que
mirar ST03N (perfil de servidor RFC) en QAS/PRD, o preguntarlo al equipo del
portal. En el código local (`Documents\GitHub`) no aparece.

## Impacto por llamador

Los dos llamadores hacen lo mismo con lo que devuelve el FM:

```abap
LOOP AT lt_result ASSIGNING <fs_res_elim>.
  APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
  MOVE-CORRESPONDING <fs_res_elim> TO <fs_result>.
  <fs_result>-msg = TEXT-046.              " "No se creo la entrega."
ENDLOOP.
```

Como `MSG` se sobrescribe, **con solo el fix del FM el portal sigue viendo
el texto TEXT-046**. Cambian `CODIGO` y `TYPE`. El número de filas es el
mismo de hoy.

| Llamador / caso | Hoy en `ZETRESULTADOSet` | Con @001 |
|---|---|---|
| V1 y V2, entrega borrada | `000 · ' ' · No se creo la entrega.` | `999 · S · No se creo la entrega.` |
| V1 y V2, no se pudo borrar (HU o entrega) | `000 · ' ' · No se creo la entrega.` (una por mensaje) | `000 · E · No se creo la entrega.` (una por mensaje) |
| V1, error antes de crear la entrega (`lw_delivery` vacío; V1 llama al FM igual) | la BAPI falla por entrega inexistente → `000 · ' ' · No se creo…` | `000 · E · No se creo la entrega.` |

### Qué hace el portal con eso

Front `LOGISTICA/planificacionentregav2`, `Registro.controller.js`:
- rama `PRD` (l.2026–2068): V1, `ZBVMM_WEB_OC_GUARD_ENTREGA_SRV`.
- rama `feature/barcode-enlace-material` (l.2486–2513): V2,
  `..._ENTREGAV2_SRV`. Misma lógica.

```js
data.ZETRESULTADOSet.results.forEach(function (value) {
    if (value.Type === "E") {
        MsgError = value.Msg + "\n";      // "=" y no "+=": se queda con la ÚLTIMA E
        CodigoMsg = true;
    }
});
if (CodigoMsg) MessageBox.error(MsgError) else MessageBox.success(results[0].Msg)
```

`Codigo` no se usa nunca y `Type = 'S'` se ignora. Lo único que importa es si
hay alguna `E` y cuál es **la última**. Las filas del FM de eliminación se
añaden al final, así que, si alguna es `E`, es la que ve el usuario.

| Caso | Popup hoy | Popup con solo @001 |
|---|---|---|
| V1/V2, error y entrega borrada | Error con el mensaje real | **Igual** (la fila `999 · S` se ignora) |
| V1/V2, creación OK | Éxito, "Se creó la entrega: …" | **Igual** |
| **V1, falla la creación** (`lw_delivery` vacío; V1 llama al FM igual y la BAPI falla por entrega inexistente) | Error con el mensaje real (p. ej. el de la clave de confirmación) | **Error "No se creo la entrega."**: se pierde el motivo. ⚠ Es el error más frecuente. |
| V1/V2, error y la entrega **no** se puede borrar | Error con el mensaje real; la entrega queda viva sin avisar | Error "No se creo la entrega.": se pierde el motivo y tampoco dice que la entrega sigue viva |

**Conclusión: aplicar solo @001 empeora lo que ve el usuario en V1 y no
le aporta nada visible.** El fix del FM tiene que ir junto con un ajuste en
los llamadores.

V2 decide si marca los lotes leyendo `LIKP`, no `T_RESULT`, y ya filtra
`lw_delivery IS NOT INITIAL`; en sus datos @001 no cambia nada más.

## Propuesta completa (recomendada)

1. **U27 (este FM)**: @001, la línea 132.
2. **U02 (V1), primera llamada** (l.1146): no llamar al FM sin entrega, igual
   que V2:
   ```abap
   IF g_error EQ abap_true AND lw_delivery IS NOT INITIAL.
   ```
   Así, cuando falla la creación, el popup sigue mostrando el motivo real.
   Hoy la llamada con entrega vacía tampoco hace nada útil. La segunda
   llamada (mov. 103 `ZBIM`) ya tiene entrega.
3. **U02 y U32, loop tras la llamada**: no pisar el texto de las filas E y
   decir que la entrega sigue viva:
   ```abap
   LOOP AT lt_result ASSIGNING <fs_res_elim>.
     APPEND INITIAL LINE TO t_result ASSIGNING <fs_result>.
     MOVE-CORRESPONDING <fs_res_elim> TO <fs_result>.
     IF <fs_result>-type EQ 'E'.
       <fs_result>-msg = |No se pudo eliminar la entrega { lw_delivery ALPHA = OUT }: { <fs_res_elim>-msg }|.
     ELSE.
       <fs_result>-msg = TEXT-046.            "mismo texto que hoy
     ENDIF.
   ENDLOOP.
   ```
   Con el front actual, el popup de ese caso (raro) muestra por qué no se
   pudo borrar y no el error original. Es lo más urgente para el usuario: hay
   una entrega huérfana. U32 se vuelve a tocar (acaba de ir en DS4K928176).
4. **Front (independiente, recomendado)**: en las dos ramas,
   `MsgError += value.Msg + "\n";`. Así el popup muestra todos los errores,
   el original y el de eliminación. No cambia el contrato.

Con 1+2 solos (sin 3) el popup queda como hoy en todos los casos menos uno:
cuando la entrega no se puede borrar sale "No se creo la entrega." en lugar
del motivo. Con 1+2+3 no se pierde nada respecto a hoy y se gana el aviso de
la entrega huérfana.

## Otros defectos vistos en el FM (no corregidos, por si se abre otro cambio)

- `E_MESSAGE` nunca se rellena.
- `IF sy-subrc EQ 0` después de `BAPI_INB_DELIVERY_CHANGE` y de
  `ME_CONFIRMATION_UPDATE`: sin `EXCEPTIONS`, siempre es 0.
- Se da por borrada la entrega solo si `RETURN` vuelve **vacío**. Si la BAPI
  devuelve un mensaje S/W/I, no se hace commit, no se borran
  `ZBVMM_ENTRENOHU` / `ZBVMM_ENTREGA_RE` y no sale la fila 999. Habría que
  comprobar que no hay E/A en vez de que no haya mensajes.
- Las confirmaciones EKES se revierten aunque la entrega no se haya podido
  borrar (el bloque no depende del resultado).
- V1 llama al FM con `I_VBELN` vacío cuando la entrega no llegó a crearse
  (V2 ya lo evita). El `SELECT` de VEKP por `VPOBJKEY = ' '` devolvería HU
  sin objeto. En DS4 hoy no hay ninguna (comprobado), pero en PRD no se ha
  mirado.

## Cómo aplicarlo (DS4)

1. SE37 / ADT → `ZBVMM_OC_ELIM_ENTR_ERROR` → código fuente: reemplazar la
   línea 132 (o el include completo con `propuesto/LZGF_CON_PORTALU27.abap`).
2. Verificar y activar. Orden de transporte: la que indiques.
3. Pruebas:

| Caso | Esperado en `ZETRESULTADOSet` |
|---|---|
| V2: error en lotes/embalaje, entrega borrada | Las E del error + `999 · S · No se creo la entrega.` |
| V2: error y la entrega no se puede borrar (p. ej. HU bloqueado) | Las E del error + `000 · E · No se creo la entrega.` |
| V1: los mismos dos casos | Lo mismo |
| V1: falla la creación (p. ej. clave de confirmación) | Popup con el motivo real, como hoy (requiere el punto 2) |
| V1 y V2: creación correcta | Sin cambios (`000 · ' ' · Se creó la entrega: …`) |
| SE37 directo con una entrega inexistente | `T_RESULT` con fila(s) `000 · E · <texto>`. Hoy salen vacías. Antes de cambiar nada es la prueba más rápida de que el bug existe: no borra nada. |
