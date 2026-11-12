package pe.bnv.pocrfc.abap;

import com.sap.conn.jco.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import pe.bnv.pocrfc.config.JCoProperties;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Lectura y escritura de fuente ABAP por RFC, con los módulos estándar del
 * repositorio (RPY_*) y RFC_READ_TABLE para las comprobaciones.
 *
 * Ninguno de estos módulos se llama con el trace de RfcTrace: el volcado de un
 * include de cinco mil líneas no le sirve a nadie en el log.
 *
 * Los parámetros se asignan solo si existen en la metadata del sistema: la
 * firma de los RPY_* varía entre releases y es preferible un error claro
 * ("el sistema no ofrece X") a un JCoException por un campo inexistente.
 */
@Service
public class FuenteAbapRfc {

    private static final Logger log = LoggerFactory.getLogger(FuenteAbapRfc.class);

    static final String LEER = "RPY_PROGRAM_READ";
    static final String GRABAR = "RPY_PROGRAM_UPDATE";
    static final String TABLA = "RFC_READ_TABLE";

    /** Módulos que se consultan en /capacidades, para decidir con datos y no a ciegas. */
    static final List<String> CANDIDATOS = List.of(
            LEER, GRABAR, TABLA, "RFC_READ_REPORT", "RPY_FUNCTIONMODULE_READ_NEW");

    private final JCoProperties props;
    private final AbapProperties abap;

    public FuenteAbapRfc(JCoProperties props, AbapProperties abap) {
        this.props = props;
        this.abap = abap;
    }

    private JCoDestination destino() throws JCoException {
        return JCoDestinationManager.getDestination(props.getDestino());
    }

    private JCoFunction funcion(JCoDestination d, String nombre) throws JCoException {
        JCoFunction f = d.getRepository().getFunction(nombre);
        if (f == null) {
            throw new IllegalStateException("El sistema no ofrece el módulo " + nombre
                    + " por RFC (no existe, no es remoto o el usuario no puede leer su metadata)");
        }
        return f;
    }

    /** Qué módulos hay y con qué parámetros: para saber qué camino de escritura existe. */
    public Map<String, Object> capacidades() throws JCoException {
        JCoDestination d = destino();
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("sistema", d.getAttributes().getSystemID());
        r.put("mandante", d.getAttributes().getClient());
        r.put("usuario", d.getAttributes().getUser());
        Map<String, Object> modulos = new LinkedHashMap<>();
        for (String m : CANDIDATOS) {
            JCoFunction f = d.getRepository().getFunction(m);
            if (f == null) {
                modulos.put(m, "no disponible");
                continue;
            }
            Map<String, Object> firma = new LinkedHashMap<>();
            firma.put("imports", nombres(f.getImportParameterList()));
            firma.put("exports", nombres(f.getExportParameterList()));
            firma.put("tablas", nombres(f.getTableParameterList()));
            modulos.put(m, firma);
        }
        r.put("modulos", modulos);
        return r;
    }

    private static List<String> nombres(JCoParameterList l) {
        List<String> r = new ArrayList<>();
        if (l == null) return r;
        JCoMetaData md = l.getMetaData();
        for (int i = 0; i < l.getFieldCount(); i++) {
            r.add(md.getName(i) + " " + md.getTypeAsString(i) + "(" + md.getLength(i) + ")");
        }
        return r;
    }

    private static boolean tiene(JCoParameterList l, String campo) {
        return l != null && l.getMetaData().hasField(campo);
    }

    private static void siExiste(JCoParameterList l, String campo, String valor) {
        if (tiene(l, campo)) {
            l.setValue(campo, valor);
        }
    }

    /**
     * Fuente de un programa o include.
     *
     * @param ultimaVersion true lee la versión inactiva si existe (lo recién
     *                      grabado y aún sin activar); false, la activa.
     */
    public List<String> leer(String include, boolean ultimaVersion) throws JCoException {
        JCoDestination d = destino();
        JCoFunction f = funcion(d, LEER);
        JCoParameterList in = f.getImportParameterList();
        in.setValue("PROGRAM_NAME", include);
        siExiste(in, "LANGUAGE", props.getLang());
        siExiste(in, "WITH_INCLUDELIST", " ");
        siExiste(in, "ONLY_SOURCE", "X");
        siExiste(in, "WITH_LOWERCASE", "X");
        if (ultimaVersion) {
            if (!tiene(in, "READ_LATEST_VERSION")) {
                throw new IllegalStateException(LEER + " no tiene READ_LATEST_VERSION: no se puede leer la versión inactiva");
            }
            in.setValue("READ_LATEST_VERSION", "X");
        }

        long t0 = System.currentTimeMillis();
        f.execute(d);

        // SOURCE_EXTENDED trae 255 caracteres por línea; SOURCE corta en 72 y
        // el U32 tiene líneas de 164. Sin la extendida no se compara nada.
        JCoParameterList tablas = f.getTableParameterList();
        if (!tiene(tablas, "SOURCE_EXTENDED")) {
            throw new IllegalStateException(LEER + " no devuelve SOURCE_EXTENDED; SOURCE corta en 72 columnas");
        }
        JCoTable t = tablas.getTable("SOURCE_EXTENDED");
        List<String> lineas = new ArrayList<>(t.getNumRows());
        for (int i = 0; i < t.getNumRows(); i++) {
            t.setRow(i);
            lineas.add(t.getString(0));
        }
        log.info("{} {} ({}): {} líneas en {} ms", LEER, include, ultimaVersion ? "última versión" : "activa",
                lineas.size(), System.currentTimeMillis() - t0);
        return lineas;
    }

    /**
     * Graba la fuente como versión INACTIVA, asignada a la orden. No activa:
     * eso queda para SE80 (Verificar, Activar), con la persona mirando.
     */
    public void grabarInactivo(String include, List<String> fuente, String orden) throws JCoException {
        JCoDestination d = destino();
        JCoFunction f = funcion(d, GRABAR);
        JCoParameterList in = f.getImportParameterList();
        for (String campo : List.of("PROGRAM_NAME", "TRANSPORT_NUMBER", "SAVE_INACTIVE")) {
            if (!tiene(in, campo)) {
                throw new IllegalStateException(GRABAR + " no tiene el parámetro " + campo
                        + "; no se graba por este camino");
            }
        }
        if (!tiene(f.getTableParameterList(), "SOURCE_EXTENDED")) {
            throw new IllegalStateException(GRABAR + " no tiene SOURCE_EXTENDED; con SOURCE se cortarían las líneas a 72");
        }
        for (int i = 0; i < fuente.size(); i++) {
            if (fuente.get(i).length() > 255) {
                throw new IllegalArgumentException(include + " línea " + (i + 1) + " pasa de 255 caracteres");
            }
        }
        in.setValue("PROGRAM_NAME", include);
        in.setValue("TRANSPORT_NUMBER", orden);
        in.setValue("SAVE_INACTIVE", abap.getMarcaInactivo());

        JCoTable t = f.getTableParameterList().getTable("SOURCE_EXTENDED");
        for (String l : fuente) {
            t.appendRow();
            t.setValue(0, l);
        }
        long t0 = System.currentTimeMillis();
        f.execute(d);
        log.warn("{} {} grabado como inactivo en la orden {} ({} líneas, {} ms)",
                GRABAR, include, orden, fuente.size(), System.currentTimeMillis() - t0);
    }

    /** RFC_READ_TABLE con una sola condición de igualdad. Devuelve filas campo→valor. */
    public List<Map<String, String>> leerTabla(String tabla, List<String> campos, String campoFiltro, String valor)
            throws JCoException {
        JCoDestination d = destino();
        JCoFunction f = funcion(d, TABLA);
        f.getImportParameterList().setValue("QUERY_TABLE", tabla);
        f.getImportParameterList().setValue("DELIMITER", "|");
        f.getImportParameterList().setValue("ROWCOUNT", 500);
        JCoTable opt = f.getTableParameterList().getTable("OPTIONS");
        opt.appendRow();
        opt.setValue("TEXT", campoFiltro + " = '" + valor.replace("'", "''") + "'");
        JCoTable fl = f.getTableParameterList().getTable("FIELDS");
        for (String c : campos) {
            fl.appendRow();
            fl.setValue("FIELDNAME", c);
        }
        f.execute(d);
        JCoTable data = f.getTableParameterList().getTable("DATA");
        List<Map<String, String>> filas = new ArrayList<>();
        for (int i = 0; i < data.getNumRows(); i++) {
            data.setRow(i);
            String[] v = data.getString("WA").split("\\|", -1);
            Map<String, String> fila = new LinkedHashMap<>();
            for (int c = 0; c < campos.size(); c++) {
                fila.put(campos.get(c), c < v.length ? v[c].trim() : "");
            }
            filas.add(fila);
        }
        return filas;
    }

    public boolean disponible(String modulo) throws JCoException {
        return destino().getRepository().getFunction(modulo) != null;
    }
}
