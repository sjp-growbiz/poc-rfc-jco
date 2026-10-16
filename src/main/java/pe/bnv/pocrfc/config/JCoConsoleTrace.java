package pe.bnv.pocrfc.config;

import com.sap.conn.jco.JCoTraceListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Puente entre el trace nativo de JCo y el log de la aplicación.
 *
 * Por defecto JCo escribe su trace en archivos JCO*.trc dentro del contenedor,
 * que es justo donde no se ve: hay que entrar con docker exec y sacarlos. Con
 * este listener el mismo contenido sale por la salida estándar, mezclado en
 * orden con el resto del log, y lo recoge quien ya esté leyendo la consola:
 * docker compose logs, el driver de logging, la consola de la IDE.
 *
 * El nivel que llega en cada mensaje es el de JCo, no el de SLF4J, así que se
 * traduce: lo que JCo considera error o aviso conserva esa severidad y todo lo
 * demás baja a DEBUG, porque en niveles altos son miles de líneas por llamada.
 */
public class JCoConsoleTrace implements JCoTraceListener {

    /**
     * Logger propio, para poder subirlo o bajarlo sin tocar el resto:
     * logging.level.com.sap.conn.jco.trace
     */
    private static final Logger log = LoggerFactory.getLogger("com.sap.conn.jco.trace");

    @Override
    public void trace(int nivel, String mensaje) {
        if (nivel <= ERRORS) {
            log.error("{}", mensaje);
        } else if (nivel <= ERROR_WARNING) {
            log.warn("{}", mensaje);
        } else {
            log.debug("{}", mensaje);
        }
    }
}
