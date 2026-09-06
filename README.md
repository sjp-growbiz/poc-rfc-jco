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

Si el contenedor no alcanza al SAP pero el host sí, es la red: el `compose`
trae comentada la alternativa `network_mode: host`, que hace que el contenedor
use directamente las interfaces del servidor, túnel VPN incluido.

Para diagnosticar desde dentro:

```bash
docker compose exec poc-rfc ping -c2 $JCO_ASHOST
docker compose exec poc-rfc curl -sv telnet://$JCO_ASHOST:33$JCO_SYSNR
```

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
