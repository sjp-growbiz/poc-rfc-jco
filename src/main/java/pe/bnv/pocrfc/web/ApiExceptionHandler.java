package pe.bnv.pocrfc.web;

import com.sap.conn.jco.JCoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/**
 * Distinguir el tipo de fallo es el objetivo de la POC.
 *
 *   tipo ABAP -> la llamada llegó al servidor y fue el ABAP quien la rechazó.
 *                El transporte funciona. Para efectos de factibilidad, ÉXITO.
 *   tipo JCO  -> no se completó la conexión, el logon o la carga de la nativa.
 *                Aquí sí hay algo que resolver en red, credenciales o imagen.
 *
 * La clasificación se hace por el grupo de la excepción, no por su clase de
 * Java: JCo sólo lanza AbapException para las excepciones declaradas en el
 * módulo de función. Un MESSAGE ... RAISING o un dump llegan como JCoException
 * de grupo SYSTEM_FAILURE, que es igual de "ABAP" aunque no sea AbapException.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    /** Grupos en los que el servidor SAP respondió: la cadena de transporte está viva. */
    private static final Set<Integer> DEL_SERVIDOR = Set.of(
            JCoException.JCO_ERROR_APPLICATION_EXCEPTION,
            JCoException.JCO_ERROR_ABAP_EXCEPTION,
            JCoException.JCO_ERROR_ABAP_CLASS_EXCEPTION,
            JCoException.JCO_ERROR_SYSTEM_FAILURE);

    @ExceptionHandler(JCoException.class)
    public ResponseEntity<Map<String, Object>> jco(JCoException e) {
        boolean delServidor = DEL_SERVIDOR.contains(e.getGroup());

        Map<String, Object> r = new LinkedHashMap<>();
        r.put("tipo", delServidor ? "ABAP" : "JCO");
        r.put("error", veredicto(e.getGroup(), delServidor));
        r.put("grupo", e.getGroup());
        r.put("key", e.getKey());
        r.put("mensaje", mensaje(e));

        // El triplete de la sentencia MESSAGE, cuando el error nace de una.
        // Es lo que hay que darle al equipo funcional para ubicar el texto en SE91.
        Map<String, Object> sap = new LinkedHashMap<>();
        poner(sap, "clase", e.getMessageClass());
        poner(sap, "numero", e.getMessageNumber());
        if (e.getMessageType() > ' ') {
            sap.put("tipo", String.valueOf(e.getMessageType()));
        }
        // JCo rellena el arreglo hasta cuatro posiciones aunque el mensaje no use
        // ninguna, así que un arreglo de puros nulos no aporta nada al cliente.
        String[] params = e.getMessageParameters();
        if (params != null) {
            var usados = Arrays.stream(params).filter(p -> p != null && !p.isBlank()).toList();
            if (!usados.isEmpty()) {
                sap.put("parametros", usados);
            }
        }
        if (!sap.isEmpty()) {
            r.put("mensajeSap", sap);
        }

        // La causa sólo se incluye si aporta algo: JCo suele envolver la excepción
        // original prefijando su propio texto, y repetirla entera no ayuda a nadie.
        Throwable causa = e.getCause();
        if (causa != null) {
            String texto = causa.getMessage();
            if (texto != null && !texto.isBlank() && !String.valueOf(r.get("mensaje")).contains(texto)) {
                r.put("causa", causa.getClass().getName() + ": " + texto);
            }
        }

        if (delServidor) {
            log.warn("SAP rechazó la llamada · {} · {}", e.getKey(), r.get("mensaje"));
        } else {
            log.error("Fallo de transporte · grupo {} · {}", e.getGroup(), e.getKey(), e);
        }

        // 422: la petición viajó y el servidor la rechazó por su contenido.
        // 502: no hubo conversación con el servidor.
        return ResponseEntity
                .status(delServidor ? HttpStatus.UNPROCESSABLE_ENTITY : HttpStatus.BAD_GATEWAY)
                .body(r);
    }

    /** Rechazos del despliegue ABAP: el motivo y el detalle que lo justifica. */
    @ExceptionHandler(pe.bnv.pocrfc.abap.Cambio006Service.Rechazo.class)
    public ResponseEntity<Map<String, Object>> rechazo(pe.bnv.pocrfc.abap.Cambio006Service.Rechazo e) {
        log.warn("Despliegue ABAP rechazado · {}", e.getMessage());
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("tipo", "RECHAZO");
        r.put("mensaje", e.getMessage());
        if (e.detalle != null && !e.detalle.isEmpty()) {
            r.put("detalle", e.detalle);
        }
        return ResponseEntity.status(e.status).body(r);
    }

    /** Una precondición del sistema que no se cumple (módulo o parámetro ausente). */
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> estado(IllegalStateException e) {
        log.warn("Precondición no cumplida · {}", e.getMessage());
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("tipo", "PRECONDICION");
        r.put("mensaje", e.getMessage());
        return ResponseEntity.status(HttpStatus.CONFLICT).body(r);
    }

    @ExceptionHandler(Throwable.class)
    public ResponseEntity<Map<String, Object>> otro(Throwable e) {
        log.error("Error no esperado", e);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("tipo", e.getClass().getName());
        r.put("mensaje", String.valueOf(e.getMessage()));
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(r);
    }

    /**
     * getMessageText() sólo trae algo cuando el error nace de una sentencia
     * MESSAGE con su texto resuelto; en el resto de los casos vuelve vacío y el
     * texto útil —el de SAP, y el diagnóstico de red de la capa NI— está en
     * getMessage(). Devolver el primero a secas deja al cliente sin nada.
     */
    private static String mensaje(JCoException e) {
        String texto = e.getMessageText();
        if (texto != null && !texto.isBlank()) {
            return texto;
        }
        String m = e.getMessage();
        return (m == null || m.isBlank()) ? "(sin texto; revisar el log del contenedor)" : m;
    }

    private static String veredicto(int grupo, boolean delServidor) {
        if (grupo == JCoException.JCO_ERROR_COMMUNICATION) {
            return "No se alcanzó el servidor: revisar la VPN y los puertos 33<nn>/32<nn> del gateway.";
        }
        if (grupo == JCoException.JCO_ERROR_LOGON_FAILURE
                || grupo == JCoException.JCO_ERROR_PASSWORD_CHANGE_REQUIRED) {
            return "La red llega pero el logon fue rechazado: revisar mandante, usuario y clave.";
        }
        if (grupo == JCoException.JCO_ERROR_FUNCTION_NOT_FOUND) {
            return "El módulo de función no existe o el usuario RFC no puede leer el repositorio.";
        }
        if (delServidor) {
            return "El transporte funciona. El error viene de la lógica ABAP del servidor.";
        }
        return "No se completó la conexión: revisar red, puertos, credenciales o librería nativa.";
    }

    private static void poner(Map<String, Object> destino, String clave, String valor) {
        if (valor != null && !valor.isBlank()) {
            destino.put(clave, valor);
        }
    }
}
