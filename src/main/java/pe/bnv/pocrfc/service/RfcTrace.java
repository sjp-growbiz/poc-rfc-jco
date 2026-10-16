package pe.bnv.pocrfc.service;

import com.sap.conn.jco.JCoDestination;
import com.sap.conn.jco.JCoException;
import com.sap.conn.jco.JCoFunction;
import com.sap.conn.jco.JCoMetaData;
import com.sap.conn.jco.JCoParameterList;
import com.sap.conn.jco.JCoTable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import pe.bnv.pocrfc.config.JCoProperties;

/**
 * Vuelca al log lo que se le manda al módulo de función y lo que responde.
 *
 * Es el nivel de detalle que sirve para comparar contra lo que hace el backend
 * en BTP: mismos parámetros de entrada, misma tabla de salida. Para el detalle
 * del protocolo RFC —handshake, codepage, tiempos por segmento— está el trace
 * nativo de JCo, que se enciende aparte con JCO_TRACE_LEVEL.
 *
 * Apagado por defecto: en una tabla de tipos de cambio de un año esto son miles
 * de líneas, y el volcado incluye los datos de negocio que viajaron.
 */
@Component
public class RfcTrace {

    private static final Logger log = LoggerFactory.getLogger(RfcTrace.class);

    private final JCoProperties props;

    public RfcTrace(JCoProperties props) {
        this.props = props;
    }

    /**
     * Ejecuta la función dejando constancia de la ida y la vuelta. Con el trace
     * apagado es exactamente {@code f.execute(destino)} y no cuesta nada.
     */
    public void ejecutar(JCoFunction f, JCoDestination destino) throws JCoException {
        if (!props.isTraceRfc()) {
            f.execute(destino);
            return;
        }

        log.info("--> {} petición\n{}", f.getName(), parametros(f.getImportParameterList()));

        long t0 = System.currentTimeMillis();
        try {
            f.execute(destino);
        } catch (JCoException e) {
            // El fallo se relanza tal cual; aquí sólo se deja la marca de que la
            // vuelta no trajo datos, para que el log cuente la historia completa.
            log.info("<-- {} sin respuesta tras {} ms · {}",
                    f.getName(), System.currentTimeMillis() - t0, e.getKey());
            throw e;
        }

        log.info("<-- {} respuesta en {} ms\n{}{}",
                f.getName(), System.currentTimeMillis() - t0,
                parametros(f.getExportParameterList()),
                tablas(f.getTableParameterList()));
    }

    /** Parámetros escalares, uno por línea. */
    private static String parametros(JCoParameterList lista) {
        if (lista == null || lista.getFieldCount() == 0) {
            return "    (sin parámetros)\n";
        }
        JCoMetaData md = lista.getMetaData();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lista.getFieldCount(); i++) {
            String nombre = md.getName(i);
            sb.append("    ").append(nombre).append(" = ").append(lista.getString(nombre)).append('\n');
        }
        return sb.toString();
    }

    /** Tablas, con el total de filas y las primeras {@code traceMaxFilas}. */
    private String tablas(JCoParameterList lista) {
        if (lista == null || lista.getFieldCount() == 0) {
            return "";
        }
        JCoMetaData md = lista.getMetaData();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lista.getFieldCount(); i++) {
            JCoTable t = lista.getTable(i);
            int total = t.getNumRows();
            int muestra = Math.min(props.getTraceMaxFilas(), total);
            sb.append("    ").append(md.getName(i)).append(": ").append(total).append(" filas\n");
            for (int fila = 0; fila < muestra; fila++) {
                t.setRow(fila);
                sb.append("      ").append(fila(t)).append('\n');
            }
            if (total > muestra) {
                sb.append("      ... ").append(total - muestra).append(" filas más\n");
            }
            // El cursor queda donde lo dejó el recorrido; devolverlo al inicio
            // evita sorpresas en quien lea la tabla después de este volcado.
            t.firstRow();
        }
        return sb.toString();
    }

    private static String fila(JCoTable t) {
        JCoMetaData md = t.getMetaData();
        StringBuilder sb = new StringBuilder();
        for (int c = 0; c < md.getFieldCount(); c++) {
            if (c > 0) {
                sb.append("  ");
            }
            sb.append(md.getName(c)).append('=').append(t.getString(c));
        }
        return sb.toString();
    }
}
