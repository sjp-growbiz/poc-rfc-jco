# 010 · Contenido de HU con la API estándar `API_HANDLINGUNIT` (sin tocar ABAP)

**Estado:** por verificar en SAP. No hay cambios de código ABAP.

## Para qué

La hoja de embalaje del portal (planificacionentregav2, Solicitar Cita → Ver/Descargar) se arma con
`ZET_MOSTRAR_REGISTROSet`, que:
1. no trae lote ni fecha de vencimiento por fila, y
2. pierde embalajes cuando un ítem de pedido tiene varias posiciones de entrega (ver @009; entrega
   1800133298 sin el embalaje 1, 1800133273 sin los embalajes 1 y 2 en Recepción).

El programa ABAP de ese servicio **no se puede modificar** (lo usan varias apps). La alternativa es que el
portal lea el contenido real de cada HU con la API estándar y cruce el lote con su vencimiento:

| Fuente | Aporta |
|---|---|
| `API_HANDLINGUNIT` (OData V4, estándar) | HU de la entrega y su contenido: material, **lote**, cantidad, posición de entrega |
| `API_INBOUND_DELIVERY_SRV/A_InbDeliveryItem` (ya usado por el portal) | lote y **fecha de vencimiento** de cada posición de entrega |

Con @007 cada vencimiento es una posición con su propio lote, así que el cruce por lote es exacto.

## Lo que hay que confirmar

1. Que `API_HANDLINGUNIT` esté publicado en QAS (y DS4): grupo de servicios en `/IWFND/V4_ADMIN`.
2. Que lea las HU de **entregas entrantes de logística** (no EWM) filtrando por la entrega.
3. Qué campos devuelve. La hoja necesita:

| Nivel | Dato | Campo SAP de referencia | Campo en la API |
|---|---|---|---|
| HU | número de HU | VEKP-EXIDV | |
| HU | nº de bulto del portal ("Embalaje 1") | VEKP-VHILM_KU | |
| HU | tipo de embalaje | VEKP-VEGR2 | |
| HU | peso bruto | VEKP-BRGEW | |
| HU | largo, ancho, alto | VEKP-LAENG / BREIT / HOEHE | |
| HU | contenido | VEKP-INHALT | |
| Posición | posición de entrega | VEPO-POSNR | |
| Posición | material | VEPO-MATNR | |
| Posición | lote | VEPO-CHARG | |
| Posición | cantidad y unidad | VEPO-VEMNG / VEMEH | |

4. Que el usuario técnico de la destination del portal en QAS Externo (`S4HANA_PROVEEDOR2`) tenga
   autorización para el servicio.

Ruta del servicio:
`/sap/opu/odata4/sap/api_handlingunit/srvd_a2x/sap/handlingunit/0001/`

Fuentes: SAP KBA 3726817 (filtro `HandlingUnitReferenceDocument`), KBA 3753210 (la API de entregas
entrantes no trae HU), SAP Help "Retrieve Handling Units" (S/4HANA on-premise).

## Resultado

(pendiente: lo completa la ejecución de `PROMPT-otra-pc.md`)
