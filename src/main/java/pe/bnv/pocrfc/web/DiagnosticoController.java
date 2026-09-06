package pe.bnv.pocrfc.web;

import com.sap.conn.jco.*;
import org.springframework.web.bind.annotation.*;
import pe.bnv.pocrfc.config.JCoProperties;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Escalones de diagnóstico, del más barato al más caro. Sirven para saber
 * exactamente dónde se rompe la cadena si algo falla.
 */
@RestController
@RequestMapping("/api")
public class DiagnosticoController {

    private final JCoProperties props;

    public DiagnosticoController(JCoProperties props) {
        this.props = props;
    }

    /** 1 · ¿carga la librería nativa? No toca la red. */
    @GetMapping("/jco")
    public Map<String, String> jco() {
        Map<String, String> r = new LinkedHashMap<>();
        r.put("version", JCo.getVersion());
        r.put("os", System.getProperty("os.name") + " " + System.getProperty("os.arch"));
        r.put("java", System.getProperty("java.version"));
        r.put("libraryPath", System.getProperty("java.library.path"));
        return r;
    }

    /** 2 · ¿llega la red y acepta el logon? */
    @GetMapping("/ping")
    public Map<String, Object> ping() throws JCoException {
        JCoDestination d = JCoDestinationManager.getDestination(props.getDestino());
        long t0 = System.currentTimeMillis();
        d.ping();
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("destino", d.getDestinationName());
        r.put("ping", "OK");
        r.put("ms", System.currentTimeMillis() - t0);
        return r;
    }

    /** 3 · ¿existe el módulo y vuelve su metadata? Aún no ejecuta ABAP. */
    @GetMapping("/metadata")
    public Map<String, Object> metadata(
            @RequestParam(defaultValue = "ZBTP_OBTENER_TIPO_CAMBIO") String rfc) throws JCoException {
        JCoDestination d = JCoDestinationManager.getDestination(props.getDestino());
        JCoFunction f = d.getRepository().getFunction(rfc);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("rfc", rfc);
        if (f == null) {
            r.put("existe", false);
            return r;
        }
        r.put("existe", true);
        r.put("imports", nombres(f.getImportParameterList()));
        r.put("exports", nombres(f.getExportParameterList()));
        r.put("tablas", nombres(f.getTableParameterList()));
        return r;
    }

    private static Object nombres(JCoParameterList lista) {
        if (lista == null) return java.util.List.of();
        var out = new java.util.ArrayList<String>();
        for (int i = 0; i < lista.getFieldCount(); i++) {
            out.add(lista.getMetaData().getName(i));
        }
        return out;
    }
}
