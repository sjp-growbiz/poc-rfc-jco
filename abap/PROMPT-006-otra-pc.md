# Prompt para aplicar @006 desde otra PC

Uso: en la otra PC, abrir Claude Code en la carpeta del repositorio `poc-rfc-jco` ya
actualizado (debe existir `abap/README.md` y las carpetas `abap/*/006-lote-unico-bultos`) y
pegar el texto del bloque siguiente. El asistente guía paso a paso; los cambios en SAP los hace
la persona en SAP GUI.

```text
Necesito aplicar en SAP DS4 (mandante 100) el cambio ABAP @006 del portal de proveedores de
Buenaventura. Todo está en este repositorio, carpeta abap/. Lee primero, en este orden:
  1. abap/README.md (sección "@006 · Un lote repartido en varios bultos")
  2. abap/ZBVMM_OC_GUARDAR_ENTREGAV2/006-lote-unico-bultos/LEEME.md
  3. abap/ZBVMM_OC_MOD_ENTR_02/006-lote-unico-bultos/LEEME.md
  4. Los archivos de actual/ y propuesto/ de esas dos carpetas.

Contexto en dos líneas: al registrar una cita, un mismo lote repartido en varios bultos se
creaba como varios lotes SAP con el mismo vencimiento. @006 agrupa por vencimiento en la FM
ZBVMM_OC_GUARDAR_ENTREGAV2 y en la rutina lotes_modif de LZGF_CON_PORTALF01 (FM de
modificación ZBVMM_OC_MOD_ENTR_02), y reparte la cantidad del lote entre los bultos.

Yo no programo en ABAP: guíame paso a paso, un paso por mensaje, y espera a que confirme.

Tareas, en este orden:

A) Revisión estática, antes de tocar SAP.
   - Compara actual/ contra propuesto/ en las dos carpetas y resume los cambios en una tabla.
   - Si puedes, valida la sintaxis con abaplint (npx @abaplint/cli, versión fija, sintaxis
     v757, solo la regla parser_error) en una carpeta temporal fuera del repo, sobre los dos
     archivos de propuesto/. Si no puedes instalarlo, dilo y sigue.
   - Revisa a mano: bloques IF/LOOP/DO balanceados, field-symbols declarados antes de usarse,
     tipos de las tablas nuevas (lt_lot_grp, lt_lips_bulto con clave posnr vhilm_ku y campo
     cant, lt_nuevo, lt_fechas) y que no queden referencias a la clave vieja de lt_lips_bulto.

B) Comparar con lo que corre en SAP.
   - Pídeme que copie desde SE37 el código activo de ZBVMM_OC_GUARDAR_ENTREGAV2 y desde SE80 la
     rutina FORM lotes_modif de LZGF_CON_PORTALF01, y que los pegue aquí o los guarde en
     abap/ZBVMM_OC_GUARDAR_ENTREGAV2/006-lote-unico-bultos/activo/ y
     abap/ZBVMM_OC_MOD_ENTR_02/006-lote-unico-bultos/activo/.
   - Compáralos con actual/. Si son iguales (ignorando espacios), seguimos con propuesto/.
     Si hay diferencias, muéstramelas y prepara una versión nueva que aplique @006 sobre el
     código activo, guardada en una carpeta propuesto-activo/ al lado. No sobrescribas
     actual/ ni propuesto/.

C) Aplicar en DS4, guiándome.
   - Primero la FM de creación en SE37 (reemplazo completo), luego la rutina lotes_modif en
     SE80 (solo la rutina, desde su comentario de cabecera hasta su ENDFORM.).
   - En cada uno: Verificar (Ctrl+F2) antes de activar. Si SAP da errores, pídeme el texto
     exacto y la línea, corrige el archivo y vuelve a darme el bloque a pegar.
   - Pregúntame qué orden de transporte usar; no supongas una.

D) Pruebas.
   - Dame la lista de casos del README (Paso 4) como checklist y dime qué revisar en VL33N y en
     Conten.total de las HU para cada uno.

Reglas:
   - No hagas commit, push ni cambios de rama en git salvo que yo lo pida.
   - No transportes nada ni me propongas liberar órdenes: eso lo decido yo.
   - No pidas ni guardes contraseñas de SAP.
   - Al terminar, agrega al final de los dos LEEME.md una sección "Aplicación" con fecha, orden
     de transporte, resultado de Verificar/Activar, diferencias encontradas con lo activo y
     pruebas hechas.
```
