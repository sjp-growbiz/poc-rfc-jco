# 010 · Contenido de HU con la API estándar `API_HANDLINGUNIT` (sin tocar ABAP)

**Estado:** verificado en DS4 y QAS el 13.11.2026; publicado en los dos. Sin cambios de código ABAP.

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
| HU | número de HU | VEKP-EXIDV | `HandlingUnitExternalID` |
| HU | nº de bulto del portal ("Embalaje 1") | VEKP-VHILM_KU | **no disponible** |
| HU | tipo de embalaje | VEKP-VEGR2 | **no disponible** |
| HU | peso bruto | VEKP-BRGEW | `GrossWeight` / `WeightUnit` |
| HU | largo, ancho, alto | VEKP-LAENG / BREIT / HOEHE | `HandlingUnitLength` / `Width` / `Height` / `UnitOfMeasureDimension` |
| HU | contenido | VEKP-INHALT | **no disponible** |
| Posición | posición de entrega | VEPO-POSNR | `HandlingUnitRefDocumentItem` |
| Posición | material | VEPO-MATNR | `Material` |
| Posición | lote | VEPO-CHARG | `Batch` |
| Posición | cantidad y unidad | VEPO-VEMNG / VEMEH | `HandlingUnitQuantity` / `HandlingUnitQuantityUnit` |

4. Que el usuario técnico de la destination del portal en QAS Externo (`S4HANA_PROVEEDOR2`) tenga
   autorización para el servicio.

Ruta del servicio:
`/sap/opu/odata4/sap/api_handlingunit/srvd_a2x/sap/handlingunit/0001/`

Fuentes: SAP KBA 3726817 (filtro `HandlingUnitReferenceDocument`), KBA 3753210 (la API de entregas
entrantes no trae HU), SAP Help "Retrieve Handling Units" (S/4HANA on-premise).

## Resultado

### Paso 1 · Disponibilidad (13.11.2026, leído por ADT, sin cambiar nada)

| Sistema | Service binding `API_HANDLINGUNIT` | Grupo de servicios V4 |
|---|---|---|
| DS4/100 | Existe, estándar SAP, `RELEASED`, versión 0001.3 | **No publicado** (`published="false"`, sin URL) |
| QS4/100 | Igual | **No publicado** |

Mientras no se publique, la URL del servicio no responde y no se pueden hacer los pasos 2 y 3
(metadata y pruebas por HTTP). Publicarlo es decisión de BVN: se hace en `/IWFND/V4_ADMIN`
(grupo `API_HANDLINGUNIT`, alias de sistema `LOCAL`), pide una orden y hay que repetirlo en QAS y
producción.

### Campos, según la definición del servicio (CDS, igual en los dos sistemas)

El servicio expone `A_HandlingUnit_2` (HU), `A_HandlingUnitItem_2` (contenido),
`A_HandlingUnitReferenceDoc` y `A_HandlingUnitItemSerialNumber`. La columna "Campo en la API" de la
tabla de arriba ya tiene los nombres.

- **Sí trae:** HU, material de embalaje, peso, medidas, entrega de referencia y, por ítem, la
  posición de entrega, el material, el **lote** y la cantidad. Con eso se resuelven el lote y el
  vencimiento por fila, y también los embalajes que se pierden.
- **No trae:** el nº de bulto del portal (`VHILM_KU`), el tipo de embalaje (`VEGR2`) ni el contenido
  (`INHALT`). Esos campos sí están en VEKP (en QS4, 1800133298: `VHILM_KU` 1/1/2, `VEGR2` CJM,
  `INHALT` lleno), pero la API no los publica. El portal los tendría que seguir tomando de
  `ZET_MOSTRAR_REGISTROSet` / `ZET_EMB_COMPLSet`, que justamente pierde embalajes.
- La clave incluye `Warehouse`. Estas HU no son de EWM (`LGNUM` vacío): queda por comprobar en la
  prueba real que la API devuelva HU de entregas entrantes de logística.

### Paso 2 · Publicación y metadata en DS4 (13.11.2026)

- Publicado en DS4/100 por la persona en `/IWFND/V4_ADMIN` (grupo `API_HANDLINGUNIT`, alias `LOCAL`),
  orden de customizing **`DS4K929904`**.
- `$metadata` responde 200 (hay que pedirla con `Accept: application/xml`; con JSON da 406). Guardada en
  `metadata.xml`. Entidades `HandlingUnit`, `HandlingUnitItem`, `HandlingUnitReferenceDocument`,
  `HandlingUnitSerialNumber`; propiedades iguales a los CDS (tabla de campos de arriba).
- `HandlingUnit?$count=true` responde 200 con 0 registros: **DS4 no tiene HU** (VEKP vacía para
  entregas entrantes), así que en DEV no se puede comprobar el contenido.

### Paso 3 · Publicación en QAS y pruebas con datos reales (13.11.2026)

- Transporte de copias **`DS4K929907`** (armado en SE01 con *Objetos de orden* de `DS4K929904`: las 3
  entradas `TABU` con clave `100API_HANDLINGUNIT…`), importado en QS4/100: código `000`, `TPALOG`
  todo `0000`. La API responde en QAS (`$metadata` 200).
- Llamada: `HandlingUnit?$filter=HandlingUnitReferenceDocument eq '<entrega>'&$expand=_HandlingUnitItem`
  con el usuario personal `E_SJUAREZ`. Respuestas en `respuestas/`.

| Entrega | Caso | HU en VEKP | HU en la API | Contenido (HU, pos., material, lote, cantidad) contra VEPO |
|---|---|---|---|---|
| 1800133298 | @007, agua con 2 vencimientos en 2 bultos (la hoja hoy pierde el bulto 1) | 3 | 2 | **Idéntico** (4 líneas). La HU que falta, 1000732390, está vacía en VEPO (sobrante de una modificación) |
| 1800133297 | @007, 2 materiales × 2 vencimientos en 3 bultos | 3 | 3 | **Idéntico** (12 líneas) |
| 1800133273 | Lotes en `9000xx` (Recepción hoy pierde los bultos 1 y 2) | 4 | 4 | **Idéntico** (4 líneas, posiciones 900001–900004) |

Conclusiones:
- La API **lee HU de entregas entrantes que no son de EWM** (`Warehouse` vacío) y trae todas las que
  tienen contenido, con la posición de entrega y el lote. No pierde embalajes, ni con @007 ni con `9000xx`.
- El vencimiento sale del cruce `Batch` ↔ lote de `A_InbDeliveryItem` (o por posición de entrega).
- Siguen sin estar en la API: nº de bulto (`VHILM_KU`), tipo (`VEGR2`) y contenido (`INHALT`).

### Paso 5 · Autorización

La destination `S4HANA_PROVEEDOR2` (QAS Externo) usa el mismo usuario con que se hicieron las pruebas
(`E_SJUAREZ`), así que la autorización en QAS está comprobada. Observación: es un usuario personal;
si caduca su clave o se bloquea, el portal deja de funcionar. Para producción conviene un usuario
técnico (tipo sistema) con `S_SERVICE` para `API_HANDLINGUNIT`.

### Paso 6 · Recomendación

**Usar la API.** Resuelve los dos problemas sin tocar ABAP: trae todas las HU con contenido (no pierde
embalajes) y cada línea con su posición de entrega y lote, que con `A_InbDeliveryItem` da el
vencimiento. Para los datos de cabecera que la API no tiene:

| Dato de la hoja | De dónde sacarlo | Comprobado en las 3 entregas |
|---|---|---|
| Nº de bulto ("Embalaje N") | Orden de las HU por `HandlingUnitExternalID` | Sí: el orden coincide con `VHILM_KU` en las 9 HU |
| Tipo de embalaje | `PackagingMaterial` (`CAJA-CARTON` = CAJ, `CAJA-MADERA` = CJM) | Sí, uno a uno |
| Peso y medidas | `GrossWeight`, `HandlingUnitLength/Width/Height` | Sí |
| Contenido (`INHALT`) | `ZET_MOSTRAR_REGISTROSet` por `Exidv`, cuando la HU aparece ahí; si no, vacío | No está en la API |

Riesgos: el orden por número de HU como nº de bulto es una deducción (las HU se crean en el orden de
los bultos); si se quiere exacto, `VHILM_KU` solo se obtiene con ABAP o con una extensión del CDS.

Pase a producción: liberar `DS4K929904` (customizing) por la ruta normal. Las órdenes de copias
`DS4K929907` no van a producción.
