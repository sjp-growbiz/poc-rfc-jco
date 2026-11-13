# Prompt para verificar API_HANDLINGUNIT desde la PC con SAP

Abrir Claude Code en `poc-rfc-jco` (rama `abap/fase2-multilote` actualizada) y pegar:

```text
Necesito saber si la API estándar API_HANDLINGUNIT (OData V4) sirve para que el portal de proveedores
lea el contenido de cada HU de una entrega entrante, en vez de modificar ABAP. Lee
abap/010-api-handlingunit/LEEME.md y, para el procedimiento con SAP, PASES-ABAP.md.

No cambies nada en SAP sin mi confirmación expresa. Pasos, uno por mensaje:

1) Disponibilidad, en QAS (QS4/100) y en DS4:
   - ¿Está publicado el grupo de servicios API_HANDLINGUNIT en /IWFND/V4_ADMIN? ¿Con qué alias?
   - Si puedes comprobarlo por RFC o HTTP con lo que ya tiene poc-rfc-jco, hazlo; si no, guíame en
     SAP GUI (/IWFND/V4_ADMIN o /IWFND/GW_CLIENT) y espera a que te pase el resultado.
   - Si no está publicado, dime exactamente cómo publicarlo y qué impacto tiene; no lo publiques tú.

2) Metadata: obtén
   /sap/opu/odata4/sap/api_handlingunit/srvd_a2x/sap/handlingunit/0001/$metadata
   y guárdala en abap/010-api-handlingunit/metadata.xml. Lista las propiedades de HandlingUnit y de
   HandlingUnitItem (y sus navegaciones).

3) Prueba con datos reales de QAS, guardando cada respuesta en abap/010-api-handlingunit/respuestas/:
   HandlingUnit?$filter=HandlingUnitReferenceDocument eq '1800133298'&$expand=_HandlingUnitItem
   y lo mismo para las entregas 1800133297 y 1800133273. Si el nombre de la navegación o del filtro
   es otro, usa el que diga la metadata. Compara con lo que hay en VEKP/VEPO de esas entregas
   (SE16 o lectura por RFC): ¿salen todas las HU, con sus posiciones, lotes y cantidades?

4) Completa la columna "Campo en la API" de la tabla del LEEME con el nombre real de cada campo, o
   "no disponible". Pon especial atención a: nº de bulto (VEKP-VHILM_KU), tipo (VEGR2), contenido
   (INHALT), medidas, posición de entrega (VEPO-POSNR) y lote.

5) Autorización: averigua qué usuario técnico usa la destination S4HANA_PROVEEDOR2 del subaccount
   QAS Externo (pregúntame si no lo sabes) y si puede llamar a este servicio (prueba o revisión de
   S_SERVICE / roles). No cambies roles.

6) Escribe en la sección "Resultado" del LEEME: disponibilidad por sistema, campos encontrados y
   faltantes, si cubre las entregas de prueba, y tu recomendación (usar la API, o qué falta).

Reglas: no hagas commit ni push sin preguntarme; no guardes contraseñas ni tokens en el repo ni en
los archivos de respuesta; no cambies nada en SAP sin mi confirmación.
```
