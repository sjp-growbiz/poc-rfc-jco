# Pases ABAP por RFC con `poc-rfc-jco`

Procedimiento para llevar un cambio ABAP de la carpeta `abap/` a **DEV (DS4)** y de ahí a
**QAS (QS4)** sin SAP GUI, salvo la activación. Está escrito a partir del pase del cambio
@006 (11.11.2026) e incluye lo que se aprendió en él.

Producción no entra en este procedimiento: la aplicación se niega a importar en cualquier
sistema que no figure en `abap.importar-en` (por defecto solo `QS4`).

## Resumen del flujo

| # | Paso | Sistema | Quién | Modifica SAP |
|---|---|---|---|---|
| 1 | Preparar JCo, certificados y `.env` | PC | Una vez | No |
| 2 | Comparar lo activo con `actual/` | DS4 | Aplicación | No |
| 3 | Si difiere, fusionar en `propuesto-activo/` | PC | Persona + asistente | No |
| 4 | Grabar como **inactivo** en la orden | DS4 | Aplicación | Sí |
| 5 | Verificar sintaxis | DS4 | Aplicación | No |
| 6 | **Activar** | DS4 | Persona, en SE80 | Sí |
| 7 | Crear y liberar el transporte de copias | DS4 | Aplicación | Sí |
| 8 | Importar el transporte de copias | QS4 | Aplicación | Sí |
| 9 | Verificar que QAS quedó igual que DEV | QS4 | Aplicación | No |
| 10 | Probar en el portal y registrar en los `LEEME.md` | QS4 | Persona | — |

Las órdenes de workbench **no se liberan** en este flujo. Eso se decide aparte, cuando el
cambio está probado.

## 1 · Preparación (una vez por PC)

1. **JCo.** Descargar `sapjco31P_XX-XXXXXXXX.zip` (Linux x86_64) del SAP Support Portal con
   usuario S y ejecutar `./setup.sh <zip>`. Deja `libs/sapjco3.jar` y `native/libsapjco3.so`.
   Tiene que ser el paquete de Linux aunque la PC sea Windows: la aplicación corre en Docker.
2. **Proxy TLS.** Si el build muere con `PKIX path building failed`, exportar la CA del proxy
   corporativo a `certs/*.pem`. Tomarla del almacén de certificados de Windows, que es donde
   el equipo ya confía en ella, y no de lo que ofrece la red.
3. **Conexiones.** Un archivo por sistema, ninguno versionado:

   | Archivo | Sistema | Uso |
   |---|---|---|
   | `.env.dev` | DS4 / 100 | Grabar, verificar, crear y liberar el transporte de copias |
   | `.env.qas` | QS4 / 100 | Importar y verificar |

4. **Red.** Desde la PC tienen que responder los puertos 3300 y 3200 de cada host.

El sistema se elige al levantar, y la escritura se enciende solo para el paso que la necesita:

```bash
ENV_FILE=.env.dev docker compose up --build -d                    # DEV, solo lectura
ENV_FILE=.env.dev ABAP_ESCRITURA=true docker compose up -d        # DEV, con escritura
ENV_FILE=.env.qas docker compose up -d                            # QAS, solo lectura
```

Hay un solo contenedor: al levantar con otro `ENV_FILE` cambia de sistema. Antes de cada
paso que escribe, confirmar a qué sistema apunta con `GET /api/abap/capacidades`.

## 2 · Comparar lo activo con `actual/` (DS4)

```bash
curl -s localhost:8080/api/abap/006/comparar | jq
```

Guarda lo activo en `abap/*/activo/` y da un estado por objeto:

| Estado | Qué significa | Qué hacer |
|---|---|---|
| `LISTO` | Lo activo es igual a la base | Seguir al paso 4 |
| `DIFIERE_DE_LA_BASE` | Alguien cambió el objeto después de la copia del repo | Paso 3 |
| `HAY_VERSION_INACTIVA` | Hay una versión inactiva que no es la nuestra | Parar y averiguar de quién es |
| `GRABADO_PENDIENTE_DE_ACTIVAR` | Ya está grabado; falta activar | Paso 6 |
| `YA_APLICADO` | Lo activo ya es lo propuesto | Nada |

**No correr `comparar` apuntando a QAS**: sobrescribe las copias `activo/` de DEV. En QAS
se usa `GET /api/abap/fuente?include=…`.

## 3 · Si lo activo difiere: fusionar

No se pega `propuesto/` encima: se perdería lo que otra persona activó. Se hace una fusión de
tres vías con base `actual/`, "lo nuestro" `activo/` y "lo de ellos" `propuesto/`:

```bash
git merge-file -p activo/RUTINA.abap actual/RUTINA.abap propuesto/RUTINA.abap > fusion.abap
```

Antes hay que quitar los espacios finales y unificar los saltos de línea de los tres archivos.
El resultado, con los conflictos resueltos a mano, va en `propuesto-activo/`:

- `RUTINA.abap`: lo que se grabará.
- `RUTINA.base.abap`: la versión activa de la que parte. La aplicación exige que SAP siga
  igual a esta base en el momento de grabar.
- `RUTINA.diff`: para revisar.

`actual/` y `propuesto/` no se tocan. Si `propuesto-activo/` existe, manda sobre `propuesto/`.
La persona revisa el diff antes de seguir.

## 4 · Grabar como inactivo (DS4)

```bash
ENV_FILE=.env.dev ABAP_ESCRITURA=true docker compose up -d
curl -s -X POST "localhost:8080/api/abap/006/aplicar?orden=DS4KNNNNNN&objeto=U32&confirmar=true" | jq
```

Un objeto por llamada. La aplicación comprueba la orden en `E070`, vuelve a leer lo activo,
bloquea el objeto por ADT, graba la versión inactiva y relee. Para dar `ok`, la última
versión tiene que ser la enviada y la activa no tiene que haber cambiado.

**La orden la impone SAP, no se elige.** Si el objeto ya está en una orden abierta, solo se
puede grabar en esa. El error lo dice (`corrNr`), y también la respuesta del bloqueo
(`ordenQueYaTeniaElObjeto`).

## 5 · Verificar sintaxis (DS4)

```bash
curl -s "localhost:8080/api/abap/006/verificar?version=inactive" | jq
```

Es el Ctrl+F2 de SE80. Se aceptan las advertencias que ya existían en el grupo; con cualquier
error, no se activa. `version=inactive` solo sirve mientras exista la versión inactiva; una
vez activado, usar `version=active` (el valor por defecto).

## 6 · Activar (DS4, a mano)

En SE80, en la lista de objetos inactivos, marcar **solo** los objetos del cambio y activar.
Los demás objetos inactivos del usuario son de otros trabajos. Después, `comparar` tiene que
dar `YA_APLICADO`.

La aplicación no activa a propósito: es el punto en que una persona mira antes de que el
código quede en uso.

## 7 · Transporte de copias (DS4)

```bash
curl -s -X POST -G localhost:8080/api/abap/transporte/copias \
  --data-urlencode "origen=DS4KAAAAAA" --data-urlencode "origen=DS4KBBBBBB" \
  --data-urlencode "destino=QS4.100" --data-urlencode "texto=TdC: ..." \
  --data-urlencode "excluir=NOMBRE_DE_OBJETO_BORRADO" | jq
curl -s -X POST "localhost:8080/api/abap/transporte/liberar?orden=DS4KNNNNNN&confirmar=true" | jq
```

- `copias` crea una orden tipo T y le inserta los objetos de las órdenes de origen y de sus
  tareas. Revisar en la respuesta que `faltan` esté vacío.
- Llevar **todos** los objetos de las órdenes, no solo los que se tocaron: así QAS no queda con
  una mezcla de versiones.
- `excluir` saca los objetos **borrados en DEV** (`TADIR-DELFLAG = X`). Con ellos dentro, SAP
  no libera: «Orden contiene tabla no existente … sin indicador de borrado».
- `liberar` solo acepta órdenes tipo T. Al terminar, `TRSTATUS` pasa por `O` y queda en `R`.
- Si una copia quedó mal armada, `POST /api/abap/transporte/borrar?orden=…&confirmar=true`
  la elimina mientras no se haya liberado.

## 8 · Importar (QS4)

```bash
ENV_FILE=.env.qas ABAP_ESCRITURA=true docker compose up -d
curl -s -m 570 -X POST "localhost:8080/api/abap/transporte/importar?sistema=QS4&mandante=100&orden=DS4KNNNNNN&confirmar=true" | jq
ENV_FILE=.env.qas docker compose up -d      # apagar la escritura
```

Tarda uno o dos minutos. El resultado correcto es `codigoRetorno` `000`.

## 9 · Verificar QAS

```bash
curl -s "localhost:8080/api/abap/fuente?include=LZGF_CON_PORTALU32" > qas.abap   # y comparar con DEV
curl -s "localhost:8080/api/abap/006/verificar?version=active" | jq
curl -s -G localhost:8080/api/abap/tabla --data-urlencode "tabla=TPALOG" \
  --data-urlencode "campos=TRSTEP" --data-urlencode "campos=RETCODE" \
  --data-urlencode "filtro=TRKORR" --data-urlencode "valor=DS4KNNNNNN" | jq
```

Tres comprobaciones: el fuente de QAS es idéntico al de DEV, la sintaxis no da errores y
todos los pasos de `TPALOG` tienen código `0000` (`0004` son advertencias; `0008` o más, error).

## 10 · Probar y registrar

Las pruebas funcionales se hacen en el portal contra QAS. Al terminar, agregar la sección
«Aplicación» en el `LEEME.md` de cada cambio: fecha, órdenes, diferencias encontradas con lo
activo, resultado de verificar y activar, transporte a QAS y pruebas.

---

## Qué hacer

- **Leer antes de escribir.** Todo pase empieza por `capacidades` y `comparar`, que no
  modifican nada. En @006 fue lo que descubrió que la @005 sí había tocado `lotes_modif`,
  al contrario de lo que decía el LEEME.
- **Confirmar el sistema antes de cada escritura.** Un solo contenedor sirve a DEV y a QAS.
- **Encender la escritura para un paso y apagarla después.** `ABAP_ESCRITURA=true` va en la
  línea de comandos, nunca en el `.env`.
- **Grabar inactivo y dejar la activación a una persona.**
- **Releer después de grabar.** No dar por bueno un `200 OK`: comparar la última versión con lo
  enviado y la activa con la anterior.
- **Guardar una copia de QAS antes de importar**, con `/api/abap/fuente`, fuera de `activo/`.
- **Consultar `TFDIR-FMODE` antes de contar con un módulo.** `R` es remoto. Que
  `/api/metadata` devuelva la firma no significa que se pueda llamar por RFC.
- **Usar el canal de ADT (`SADT_REST_RFC_ENDPOINT`) para lo que los módulos clásicos no dejan.**
  Es el que usa Eclipse y respeta las mismas autorizaciones.
- **Anotar la marca del cambio que ya existe en SAP.** En DS4 había líneas `+@006` de otro
  cambio dentro de la misma rutina. Antes de numerar, buscar la marca en el código activo.

## Qué no hacer

- **No pegar `propuesto/` si lo activo difiere de `actual/`.** Se pierde trabajo ajeno.
- **No liberar las órdenes de workbench para probar en QAS.** Liberar no se deshace y deja el
  transporte en la cola hacia producción. Para probar, transporte de copias.
- **No llevar a QAS solo los objetos tocados** si las órdenes traen más: pueden depender de
  versiones que QAS no tiene.
- **No verificar con `version=inactive` un include que no tiene versión inactiva.** Devuelve
  decenas de errores falsos del tipo «FORM … does not exist». Pasó en QAS tras la importación:
  con `version=active` no había ninguno.
- **No fiarse de `DWINACTIV` para saber si una FM está inactiva.** Figura con el nombre de la
  función, no con el del include. Lo fiable es comparar la última versión con la activa.
- **No llamar `/sap/...` desde Git Bash sin `MSYS_NO_PATHCONV=1`.** Convierte la ruta en
  `C:/Program Files/Git/sap/...`.
- **No reintentar a ciegas una llamada de escritura que falló.** Primero comprobar con
  `comparar` que no se grabó nada.
- **No exponer el puerto 8080 fuera de la PC.** La aplicación no tiene autenticación.
- **No descargar JCo de sitios que no sean SAP**, ni guardar claves de SAP en el repositorio.

## Qué funciona por RFC en DS4 y QS4, y qué no

| Necesidad | Lo que no sirve | Lo que sí |
|---|---|---|
| Leer fuente | `RFC_READ_REPORT` (no existe); `SOURCE` corta en 72 columnas | `RPY_PROGRAM_READ` con `SOURCE_EXTENDED` |
| Grabar fuente | `RPY_PROGRAM_UPDATE` (existe, no es remoto) | ADT: `LOCK`, `PUT …/source/main`, `UNLOCK` en sesión con estado |
| Verificar sintaxis | — | ADT `/sap/bc/adt/checkruns` |
| Crear orden de copias | `BAPI_CTREQUEST_CREATE` (solo workbench y customizing) | `TR_EXT_CREATE_REQUEST` con tipo `T` |
| Poner objetos en la orden | `TR_COPY_COMM`, `TR_APPEND_TO_COMM_OBJS_KEYS` (no remotos) | `TR_EXT_INSERT_IN_REQUEST` |
| Liberar la copia | `BAPI_CTREQUEST_RELEASE` («no es una orden»); ADT `newreleasejobs` (falla por los bloqueos) | ADT `relwithignlock`, con `tm:number` en el cuerpo |
| Borrar una orden | — | ADT `DELETE /sap/bc/adt/cts/transportrequests/{orden}` |
| Importar | `TMS_MGR_IMPORT_TR_REQUEST` (no remoto) | `CTS_API_IMPORT_CHANGE_REQUEST`, conectado al sistema destino |
| Leer tablas (`E070`, `E071`, `TFDIR`, `TPALOG`) | — | `RFC_READ_TABLE` |

Detalles de ADT que costaron un intento cada uno:

- La fuente de una **FM** se graba en `…/fmodules/<fm>/source/main`. Ahí la interfaz es una
  sentencia (`FUNCTION x TABLES … .`) y no el bloque de comentarios `*"` del include: se
  conserva la cabecera que devuelve ADT y se reemplaza solo el cuerpo.
- El `PUT` de una FM exige la cabecera `Accept`; el de un include no.
- El bloqueo vive en la sesión: `LOCK`, `PUT` y `UNLOCK` van dentro de `JCoContext.begin/end`
  con `X-sap-adt-sessiontype: stateful`.

## Autorizaciones que usa

No se revisaron los roles: la lista se deduce de las operaciones que funcionaron. Sirve de guía
si otro usuario recibe un error de autorización.

| Usuario | Sistema | Lo que probablemente hace falta |
|---|---|---|
| `ABAP_03` | DS4 | `S_RFC` (grupos de `RPY_*`, `RFC_READ_TABLE`, `SADT_REST_RFC_ENDPOINT`, `TR_EXT_*`), `S_ADT_RES`, `S_DEVELOP` con modificación, `S_TRANSPRT` para crear y liberar órdenes, `S_TABU_DIS` de lectura |
| `E_SJUAREZ` | QS4 | `S_RFC` (los de lectura y `CTS_API_*`), `S_CTS_ADMI` para importar, `S_ADT_RES`, `S_TABU_DIS` de lectura |

## Registro del pase @006 (11.11.2026)

| Qué | Dato |
|---|---|
| Objetos | FM `ZBVMM_OC_GUARDAR_ENTREGAV2` (`LZGF_CON_PORTALU32`) y rutina `lotes_modif` de `LZGF_CON_PORTALF01` |
| Órdenes de workbench | `DS4K928176` (creación) y `DS4K929212` (modificación). Siguen modificables |
| Fusión | `lotes_modif` activa traía la @005; @006 se llevó encima en `propuesto-activo/` (53 líneas agregadas) |
| Activación en DS4 | Hecha a mano por `ABAP_03` |
| Transporte de copias | `DS4K929851`, 40 objetos, liberado e importado en QS4/100 con código `000` |
| Excluidos de la copia | `ZBVMM_ST_GUARDAR_ENTREGA_DETVM` y `ZBVMM_TT_GUARDAR_ENTREGA_DETVM`, borrados en DS4 |
| Verificación en QAS | Fuente idéntico al de DS4; sintaxis sin errores; `TPALOG` todo en `0000` |
| Pendiente | Pruebas funcionales en el portal contra QAS; decidir si la marca pasa a `@007` |

## Registro del pase @007 (12–13.11.2026)

| Qué | Dato |
|---|---|
| Objetos | `LZGF_CON_PORTALU32`, `LZGF_CON_PORTALU28` y `LZGF_CON_PORTALF01` (include completo) |
| Herramienta | Los endpoints pasan a `/api/abap/{cambio}/…` (006, 007). Nuevo `POST /api/abap/{cambio}/activar?confirmar=true` (ADT `/sap/bc/adt/activation`), sin usar todavía |
| Órdenes | Las mismas de @006: `DS4K928176` y `DS4K929212` |
| Activación en DS4 | A mano en SE80. Los tres objetos juntos: U28 sola no compila sin el F01 nuevo |
| Transporte de copias | `DS4K929891`, armado y liberado a mano en SE01 sin las 4 entradas `…_DETVM`; importado en QS4/100 con `000` |
| Verificación en QAS | Fuente idéntico al grabado; sintaxis sin errores; `TPALOG` todo en `0000` |

Lecciones:

- **Una clave con `$` en un `.env` llega cortada al contenedor.** Docker Compose toma `$…` como una
  variable. Hay que poner el valor entre comillas simples (`JCO_PASSWD='…'`) o escribir `$$`. Para
  comprobarlo sin mostrar la clave, comparar su largo en el archivo y en `docker inspect`.
- **Después de cambiar un `.env`, recrear el contenedor** (`--force-recreate`). Con `up -d` a veces
  solo se reinicia y sigue usando las variables viejas.
- **Si el login falla, detener el contenedor enseguida.** Los reintentos pueden bloquear el usuario.

Intentos fallidos que dejaron rastro: un dump `CALL_FUNCTION_NOT_REMOTE` en ST22 de DS4
(`ABAP_03`, por `RPY_PROGRAM_UPDATE` y otro por `TR_COPY_COMM`) y la orden de copias
`DS4K929850`, que se creó con los objetos borrados, no se pudo liberar y se eliminó.
