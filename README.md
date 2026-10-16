# poc-rfc-jco

Sonda de conectividad RFC hacia SAP **desde un servidor fuera de SAP BTP**.

Replica una sola llamada real del portafolio —`ZBTP_OBTENER_TIPO_CAMBIO`, la más
liviana de las que están vivas— para medir esfuerzo y factibilidad antes de
tocar los backends existentes.

Origen: `backend_zinvoice` · `ParametroServiceImpl.listaTipoCambio()`

## Qué prueba, y en qué orden

| Escalón | Endpoint | Qué demuestra |
|---|---|---|
| 1 | `GET /api/jco` | La librería nativa carga en este SO y esta arquitectura. No toca la red. |
| 2 | `GET /api/ping` | La red llega al gateway y el logon RFC es aceptado. |
| 3 | `GET /api/metadata` | El módulo de función existe y su metadata viaja de vuelta. |
| 4 | `GET /api/tipo-cambio` | La llamada completa, con datos. |

Si el escalón 4 devuelve un error **ABAP**, la POC es un éxito: significa que el
transporte funciona y el problema es de lógica de negocio. Si devuelve un error
**JCo**, hay algo que resolver en red, credenciales o imagen. El manejador de
excepciones distingue los dos casos explícitamente.

## Cómo leer un error

La respuesta trae el mensaje tal como lo emitió SAP, no una traducción propia:

```json
{
  "tipo": "ABAP",
  "veredicto": "El transporte funciona. El error viene de la lógica ABAP del servidor.",
  "grupo": 104,
  "key": "JCO_ERROR_SYSTEM_FAILURE",
  "mensaje": "Indique una fecha válida",
  "mensajeSap": { "clase": "SG", "numero": "102", "tipo": "E" }
}
```

`tipo` es el veredicto en una palabra y el código HTTP lo repite:

- **`ABAP`, HTTP 422** — la llamada llegó al servidor y el ABAP la rechazó. La
  cadena de transporte está viva; el problema es de negocio o de parámetros.
- **`JCO`, HTTP 502** — no hubo conversación con el servidor. Red, puertos,
  credenciales o librería nativa.

La clasificación va por el *grupo* de la excepción, no por su clase de Java: JCo
sólo lanza `AbapException` para las excepciones declaradas en la firma del
módulo, mientras que un `MESSAGE ... RAISING` llega como `JCoException` de grupo
`SYSTEM_FAILURE`. Los dos son igual de "ABAP" para lo que aquí se quiere medir.

`mensajeSap` aparece cuando el error nace de una sentencia `MESSAGE`, y es lo
que hay que llevarle al equipo funcional: con clase y número se ubica el texto
en SE91. En los fallos de red, `mensaje` trae el diagnóstico crudo de la capa NI
—el puerto que intentó, el `ERRNO` y su texto—, que es lo que necesita Basis.

## Antes de construir

1. **La librería nativa y el jar.** Los repone `setup.sh` desde el paquete de SAP:

   ```bash
   ./setup.sh ../sapjco31P_14-70004517.zip
   ```

   Deja `libs/sapjco3.jar` y `native/libsapjco3.so`, y alinea la versión en el
   `pom.xml`. Ninguno de los dos se versiona: son software licenciado.

   El paquete verificado es **3.1.14, linuxx86_64**. Si el servidor no es
   x86_64, hay que descargar el paquete de esa arquitectura —el script avisa—.
   No mezclar jar y nativa de versiones distintas: JCo lo comprueba al arrancar
   y se niega.

2. **Las credenciales.** `cp .env.example .env` y completar con lo que entregue
   Basis: host, número de sistema, mandante, usuario RFC y clave.

3. **La red.** La VPN tiene que alcanzar los puertos del gateway y el
   dispatcher, `33<nn>` y `32<nn>` donde `<nn>` es el número de sistema. No
   basta con el 8000 del OData.

4. **El proxy TLS, si la red corporativa intercepta HTTPS.** Maven descarga las
   dependencias dentro del contenedor, y ahí el truststore del JDK no conoce la
   CA de la empresa: el build muere con `PKIX path building failed`. Extraer la
   raíz y dejarla en `certs/`:

   ```bash
   mkdir -p certs
   openssl s_client -connect repo.maven.apache.org:443 -showcerts </dev/null 2>/dev/null \
     | openssl x509 > certs/proxy-root.pem
   ```

   Si el certificado que ofrece el proxy no es la raíz sino una intermedia,
   sirve igual: basta con que algún eslabón de la cadena sea de confianza. En
   Windows también se puede exportar desde el almacén de certificados. El
   `Dockerfile` los importa solo si existen; `certs/*.pem` no se versiona.

## Construir y correr

```bash
docker compose up --build
```

Comprobar, de menor a mayor:

```bash
curl -s localhost:8080/api/jco      | jq
curl -s localhost:8080/api/ping     | jq
curl -s localhost:8080/api/metadata | jq
curl -s "localhost:8080/api/tipo-cambio?moneda=USD" | jq
```

`I_FECHA` va en formato **`dd.MM.yyyy`**, no en el `yyyyMMdd` habitual de ABAP:
con cualquier otro formato el módulo responde `Indique una fecha válida`. Sin el
parámetro `fecha` se usa hoy, ya con ese formato. Ojo con la longitud, más abajo.

La respuesta trae la fecha ya decodificada, y el `GDATU` crudo al lado para
poder cotejar contra SE16:

```json
[
  {
    "fecha": "2020-09-04",
    "gdatu": "79799095",
    "monedaOrigen": "USD",
    "monedaDestino": "PEN",
    "tipoCambio": 3.54200
  }
]
```

SAP guarda esa fecha invertida —`99999999` menos `aaaammdd`— para que el orden
natural del índice deje primero lo más reciente.

Si el contenedor no alcanza al SAP pero el host sí, es la red: el `compose`
trae comentada la alternativa `network_mode: host`, que hace que el contenedor
use directamente las interfaces del servidor, túnel VPN incluido.

Para diagnosticar desde dentro:

```bash
docker compose exec poc-rfc ping -c2 $JCO_ASHOST
docker compose exec poc-rfc curl -sv telnet://$JCO_ASHOST:33$JCO_SYSNR
```

## Ver qué viaja en cada llamada

Hay dos trazas, y responden preguntas distintas.

**Los parámetros de la llamada**, en el log de la aplicación. Va encendido: en
una sonda, ver qué viajó es el objetivo y no un extra —fue este volcado el que
delató que `I_FECHA` se truncaba—. Se apaga con `JCO_TRACE_RFC=false`.

```
--> ZBTP_OBTENER_TIPO_CAMBIO petición
    I_CURR = PEN
    I_FECHA = 07.09.20
<-- ZBTP_OBTENER_TIPO_CAMBIO respuesta en 834 ms
    T_TCURR: 4 filas
      MANDT=100  KURST=M  FCURR=EUR  TCURR=PEN  GDATU=79799092  UKURS=4.33500
      ... 2 filas más
```

Es lo que sirve para comparar contra lo que hace el backend en BTP: mismos
parámetros de entrada, misma tabla de salida. `JCO_TRACE_MAX_FILAS` limita la
muestra por tabla —diez por defecto— porque una tabla de tipos de cambio de un
año son miles de líneas.

Al replicar esto en los backends de producción conviene revisarlo: el volcado
incluye los datos de negocio que viajaron.

**El protocolo RFC**, con el trace nativo de JCo:

```bash
JCO_TRACE_LEVEL=4 docker compose up
```

Es el nivel al que se diagnostica un problema de transporte —handshake,
codepage, tiempos por segmento— y el que pide el soporte de SAP. Con 4 alcanza
para casi todo; los niveles altos crecen muy rápido.

Por defecto escribe archivos `JCO*.trc` en `JCO_TRACE_PATH`, que es justo donde
no se ven: hay que entrar con `docker exec` a sacarlos. Para que salgan por la
consola, junto al resto del log:

```bash
JCO_TRACE_LEVEL=4 JCO_TRACE_DESTINO=consola docker compose up
```

```
DEBUG ... com.sap.conn.jco.trace : [JCoAPI] JCoDestinationManager.getDestination(S4HANA_DEST_RFC)
          got from provider EnvDestinationDataProvider the following properties:
          { jco.client.lang=ES, jco.client.passwd=<secret>, jco.client.client=100, ... }
```

Con un listener registrado JCo deja de escribir los `.trc`: la salida se desvía
entera, no se duplica. Como es un logger propio —`com.sap.conn.jco.trace`—, se
puede subir o bajar sin tocar el resto de JCo, con `JCO_TRACE_LOG_LEVEL`.

JCo enmascara la clave en su propio trace (`jco.client.passwd=<secret>`), pero
el usuario, el host y el mandante sí aparecen. El `.gitignore` excluye los
`.trc`; para la consola, vale lo de siempre con los logs.

## Cuidado con las longitudes

`I_FECHA` es `CHAR(8)`. Un `dd.MM.yyyy` son diez caracteres, así que JCo
**trunca en silencio**: `07.09.2026` viaja como `07.09.20` y el módulo responde
con tipos de cambio de 2020. Sin error, sin aviso, con datos verosímiles.

Por eso `/api/metadata` devuelve tipo y longitud de cada campo, y por eso el
servicio avisa en el log cuando un valor no cabe:

```
WARN  I_FECHA es CHAR(8) y se le mandaron 10 caracteres:
      "07.09.2026" viajará como "07.09.20"
```

Al replicar esto en los backends conviene revisar los veinte módulos con el
mismo criterio: un parámetro más corto de lo que uno cree no rompe nada, y ese
es justamente el problema.

## Separar Java 21 de la salida de BTP

Este proyecto corre sobre Java 21, así que prueba dos cosas a la vez: que JCo
funciona fuera de BTP y que funciona sobre Java 21. Son las brechas de dos POC
distintas y conviene poder aislarlas.

Para eso está `tools/JCoProbe.java`: la misma secuencia, sin Spring, compilable
en Java 8 y en Java 21.

```bash
javac -cp libs/sapjco3.jar -d /tmp/probe tools/JCoProbe.java
java  -cp libs/sapjco3.jar:/tmp/probe -Djava.library.path=native JCoProbe
```

Correrlo con un JRE 8 y con uno 21 responde por separado:

- falla en ambos → el problema es de red o credenciales
- funciona en 8 y falla en 21 → el problema es la versión de Java
- funciona en ambos → las dos brechas quedan cerradas

Dentro del contenedor es lo mismo: `JDK=17 docker compose up --build`.

## Cómo se replica en los backends existentes

Los sitios de llamada **no cambian**. `JCoDestinationManager.getDestination(nombre)`
sigue escrito igual; lo único que cambia es quién responde a ese nombre.

En BTP responde el servicio de conectividad a través del Cloud Connector. Fuera
de BTP responde `EnvDestinationDataProvider`, que se registra al arrancar. Copiar
`config/` a cada backend y añadir las variables de entorno es todo el trabajo:
las veinte invocaciones RFC del portafolio quedan intactas.

## Lo que este proyecto no hace

- No usa XSUAA: no hay autenticación. Es una sonda, no un servicio.
  No exponerla fuera de la red de pruebas.
- No usa el servicio de destinos de BTP ni el Cloud Connector.
- No cubre SNC. Si el sistema lo exige, hay que añadir las propiedades `snc.*`
  y la librería criptográfica.
