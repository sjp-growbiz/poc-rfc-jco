# Prompt para aplicar 008 desde la otra PC

Abrir Claude Code en `poc-rfc-jco` (rama `abap/fase2-multilote` actualizada) y pegar:

```text
Necesito que la hoja de embalaje del portal muestre la fecha de vencimiento por fila. El portal ya
está listo (planificacionentregav2 1.2.9 lee el campo Zvfdat de cada fila); falta que SAP lo envíe.
Lee abap/008-vencimiento-hoja-embalaje/PLAN.md y PASES-ABAP.md (procedimiento de pase).

Pasos, uno por mensaje, esperando mi confirmación:

1) Investigar en DS4, sin cambiar nada:
   - Servicio ZBVMM_WEB_OC_REL_PEDC_XCONF_SRV, entidad ZET_MOSTRAR_REGISTRO: estructura ABAP de la
     entidad, y cómo GET_ENTITYSET (DPC_EXT) llena la salida (MOVE-CORRESPONDING o campo a campo).
   - FORM get_data_tablas y prepare_data en LZGF_CON_PORTALF01, tipo gty_likps en LZGF_CON_PORTALTOP,
     y si ZBVMM_ENTREGA_RE es la estructura de la entidad.
   - Compara lo activo con las copias del repo (abap/ZBVMM_OC_MOD_ENTR_02/007-posicion-por-vencimiento).
   Dame un resumen y la propuesta concreta antes de escribir.
2) Preparar en abap/008-vencimiento-hoja-embalaje/actual y propuesto/ los fuentes (TOP, F01, DPC_EXT
   si aplica) con la marca @008. Validar sintaxis (abaplint si se puede) y bloques balanceados.
3) Guiarme con lo que no se puede hacer por RFC: append de campos en DDIC y propiedades en SEGW
   (Zcharg Edm.String 10, Zvfdat Edm.String 8 yyyyMMdd), regenerar runtime.
4) Grabar los fuentes, verificar y activar en DS4. Preguntarme la orden de transporte.
5) Probar en DS4 o QAS llamando ZET_MOSTRAR_REGISTROSet?$filter=Zvbeln eq '1800133297' y comprobar
   que cada fila trae Zcharg y Zvfdat correctos.

Reglas: no hacer commit/push salvo que lo pida; no transportar sin mi confirmación; no pedir ni guardar
contraseñas. Al terminar, agrega una sección "Aplicación" en PLAN.md con fecha, orden, objetos y pruebas.
```
