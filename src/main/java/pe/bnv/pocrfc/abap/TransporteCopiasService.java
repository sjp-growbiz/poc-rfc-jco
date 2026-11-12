package pe.bnv.pocrfc.abap;

import com.sap.conn.jco.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import pe.bnv.pocrfc.config.JCoProperties;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Transporte de copias (orden tipo T) para llevar a QAS lo que está en órdenes
 * de workbench todavía abiertas, sin liberarlas.
 *
 * Es lo que ya se hacía a mano en SE01 para probar en QS4: una orden de copias
 * con la lista de objetos de las originales. Las originales no se tocan, siguen
 * modificables y nada entra en la ruta hacia producción.
 *
 * Solo se libera lo que es tipo T: una orden de workbench (K) nunca.
 */
@Service
public class TransporteCopiasService {

    private static final Logger log = LoggerFactory.getLogger(TransporteCopiasService.class);
    private static final Pattern ORDEN = Pattern.compile("^[A-Z0-9]{3}K\\d{6}$");

    private final JCoProperties props;
    private final AbapProperties abap;
    private final FuenteAbapRfc rfc;
    private final AdtRfc adt;

    public TransporteCopiasService(JCoProperties props, AbapProperties abap, FuenteAbapRfc rfc, AdtRfc adt) {
        this.adt = adt;
        this.props = props;
        this.abap = abap;
        this.rfc = rfc;
    }

    private void exigirEscritura() {
        if (!abap.isEscritura()) {
            throw new Cambio006Service.Rechazo(HttpStatus.FORBIDDEN,
                    "Escritura apagada. Arrancar con ABAP_ESCRITURA=true solo para esta operación.", Map.of());
        }
    }

    private static String orden(String o) {
        String t = o == null ? "" : o.trim().toUpperCase(Locale.ROOT);
        if (!ORDEN.matcher(t).matches()) {
            throw new Cambio006Service.Rechazo(HttpStatus.BAD_REQUEST, "Orden con formato inválido: " + o, Map.of());
        }
        return t;
    }

    private JCoFunction funcion(JCoDestination d, String nombre) throws JCoException {
        JCoFunction f = d.getRepository().getFunction(nombre);
        if (f == null) {
            throw new IllegalStateException("El sistema no ofrece " + nombre + " por RFC");
        }
        return f;
    }

    private Map<String, String> cabecera(String orden) throws JCoException {
        List<Map<String, String>> f = rfc.leerTabla("E070",
                List.of("TRKORR", "TRFUNCTION", "TRSTATUS", "TARSYSTEM", "AS4USER"), "TRKORR", orden);
        if (f.isEmpty()) {
            throw new Cambio006Service.Rechazo(HttpStatus.BAD_REQUEST, "La orden " + orden + " no existe", Map.of());
        }
        return f.get(0);
    }

    /** Crea la orden de copias y le copia la lista de objetos de cada orden de origen. No libera. */
    public Map<String, Object> crear(List<String> origenes, String destino, String texto, List<String> excluir)
            throws JCoException {
        exigirEscritura();
        if (origenes == null || origenes.isEmpty()) {
            throw new Cambio006Service.Rechazo(HttpStatus.BAD_REQUEST, "Falta al menos una orden de origen", Map.of());
        }
        List<String> desde = origenes.stream().map(TransporteCopiasService::orden).toList();
        for (String o : desde) {
            cabecera(o); // que exista
        }

        JCoDestination d = JCoDestinationManager.getDestination(props.getDestino());
        Map<String, Object> r = new LinkedHashMap<>();

        JCoFunction c = funcion(d, "TR_EXT_CREATE_REQUEST");
        JCoParameterList in = c.getImportParameterList();
        in.setValue("IV_REQUEST_TYPE", "T");
        in.setValue("IV_TARGET", destino);
        in.setValue("IV_TEXT", texto);
        in.setValue("IV_AUTHOR", d.getAttributes().getUser());
        c.execute(d);
        String nueva = c.getExportParameterList().getString("ES_REQ_ID").trim();
        String error = c.getExportParameterList().getString("EV_EXCEPTION").trim();
        r.put("mensajeCreacion", c.getExportParameterList().getString("ES_MSG").trim());
        if (nueva.isEmpty() || !error.isEmpty()) {
            r.put("excepcion", error);
            throw new Cambio006Service.Rechazo(HttpStatus.BAD_GATEWAY, "SAP no creó la orden de copias", r);
        }
        r.put("ordenDeCopias", nueva);
        log.warn("Orden de copias {} creada hacia {}", nueva, destino);

        r.put("objetos", agregar(nueva, desde, excluir));
        r.put("cabecera", cabecera(nueva));
        return r;
    }

    /** Objetos (PGMID, OBJECT, OBJ_NAME) de una orden y de sus tareas, sin repetir. */
    private java.util.Set<List<String>> objetosDe(String orden) throws JCoException {
        java.util.Set<List<String>> objs = new java.util.LinkedHashSet<>();
        List<String> ordenes = new java.util.ArrayList<>(List.of(orden));
        for (Map<String, String> t : rfc.leerTabla("E070", List.of("TRKORR"), "STRKORR", orden)) {
            ordenes.add(t.get("TRKORR"));
        }
        for (String o : ordenes) {
            for (Map<String, String> f : rfc.leerTabla("E071", List.of("PGMID", "OBJECT", "OBJ_NAME"), "TRKORR", o)) {
                objs.add(List.of(f.get("PGMID"), f.get("OBJECT"), f.get("OBJ_NAME")));
            }
        }
        return objs;
    }

    /**
     * Inserta en una orden de copias ya creada los objetos de las órdenes de
     * origen (TR_COPY_COMM no es remoto; TR_EXT_INSERT_IN_REQUEST sí).
     */
    public Map<String, Object> agregar(String ordenCopias, List<String> origenes, List<String> excluir)
            throws JCoException {
        exigirEscritura();
        String o = orden(ordenCopias);
        Map<String, String> cab = cabecera(o);
        if (!"T".equals(cab.get("TRFUNCTION")) || !"D".equals(cab.get("TRSTATUS"))) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT,
                    "La orden " + o + " no es un transporte de copias modificable", Map.of("orden", cab));
        }
        java.util.Set<List<String>> objs = new java.util.LinkedHashSet<>();
        for (String origen : origenes) {
            objs.addAll(objetosDe(orden(origen)));
        }
        // Objetos borrados en DEV: SAP no deja liberar una copia que los lleve sin
        // marca de borrado, y TR_EXT_INSERT_IN_REQUEST no sabe ponerla.
        List<String> fuera = new java.util.ArrayList<>();
        if (excluir != null) {
            objs.removeIf(x -> {
                boolean quitar = excluir.stream().anyMatch(n -> x.get(2).trim().equalsIgnoreCase(n.trim()));
                if (quitar) {
                    fuera.add(String.join(" ", x));
                }
                return quitar;
            });
        }
        if (objs.isEmpty()) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT, "Las órdenes de origen no tienen objetos", Map.of());
        }

        JCoDestination d = JCoDestinationManager.getDestination(props.getDestino());
        JCoFunction f = funcion(d, "TR_EXT_INSERT_IN_REQUEST");
        f.getImportParameterList().setValue("IV_REQ_ID", o);
        JCoTable t = f.getTableParameterList().getTable("IT_OBJECTS");
        JCoMetaData md = t.getMetaData();
        List<String> campos = new java.util.ArrayList<>();
        for (int i = 0; i < md.getFieldCount(); i++) {
            campos.add(md.getName(i));
        }
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("excluidos", fuera);
        if (!campos.containsAll(List.of("PGMID", "OBJECT", "OBJ_NAME"))) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT,
                    "IT_OBJECTS no tiene PGMID/OBJECT/OBJ_NAME (tiene " + campos + "); no se inserta nada", r);
        }
        for (List<String> x : objs) {
            t.appendRow();
            t.setValue("PGMID", x.get(0));
            t.setValue("OBJECT", x.get(1));
            t.setValue("OBJ_NAME", x.get(2));
        }
        f.execute(d);
        r.put("enviados", objs.size());
        r.put("mensaje", f.getExportParameterList().getString("ES_MSG").trim());
        r.put("excepcion", f.getExportParameterList().getString("EV_EXCEPTION").trim());

        java.util.Set<List<String>> enCopia = objetosDe(o);
        r.put("objetosEnLaCopia", enCopia.size());
        java.util.Set<List<String>> faltan = new java.util.LinkedHashSet<>(objs);
        faltan.removeAll(enCopia);
        r.put("faltan", faltan);
        r.put("objetos", enCopia.stream().map(x -> String.join(" ", x)).toList());
        return r;
    }

    /** Borra una orden de copias sin liberar (una que se creó de más). Solo tipo T modificable. */
    public Map<String, Object> borrar(String ordenCopias, boolean confirmar) throws JCoException {
        exigirEscritura();
        String o = orden(ordenCopias);
        Map<String, String> cab = cabecera(o);
        if (!"T".equals(cab.get("TRFUNCTION")) || !"D".equals(cab.get("TRSTATUS")) || !confirmar) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT,
                    "Solo se borra una orden de copias modificable, con confirmar=true", Map.of("orden", cab));
        }
        AdtRfc.Respuesta x = adt.pedir("DELETE", "/sap/bc/adt/cts/transportrequests/" + o,
                Map.of("Accept", "application/vnd.sap.adt.transportorganizer.v1+xml"), null);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("retorno", x.status() + " " + x.motivo());
        if (!x.ok()) {
            r.put("cuerpo", x.cuerpo());
        }
        r.put("sigueExistiendo", !rfc.leerTabla("E070", List.of("TRKORR"), "TRKORR", o).isEmpty());
        return r;
    }

    /**
     * Importa una orden ya liberada en el sistema al que se está conectado
     * (CTS_API_IMPORT_CHANGE_REQUEST, la API remota estándar de TMS).
     *
     * Solo en los sistemas de abap.importar-en (por defecto QS4): nunca en
     * producción, y nunca "a distancia" desde otro sistema del dominio.
     */
    public Map<String, Object> importar(String sistema, String mandante, String ordenLiberada, boolean confirmar)
            throws JCoException {
        exigirEscritura();
        String o = orden(ordenLiberada);
        JCoDestination d = JCoDestinationManager.getDestination(props.getDestino());
        String sid = d.getAttributes().getSystemID();
        String cli = d.getAttributes().getClient();
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("conectadoA", sid + "/" + cli);
        if (!abap.getImportarEn().contains(sid) || !sid.equalsIgnoreCase(sistema) || !cli.equals(mandante)) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT, "Solo se importa en el sistema al que se está "
                    + "conectado y si figura en abap.importar-en (" + abap.getImportarEn() + ")", r);
        }
        if (!o.startsWith(sid) && !confirmar) {
            throw new Cambio006Service.Rechazo(HttpStatus.BAD_REQUEST, "Falta confirmar=true", r);
        }
        if (o.startsWith(sid)) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT, "La orden " + o + " es de este mismo sistema", r);
        }
        JCoFunction f = funcion(d, "CTS_API_IMPORT_CHANGE_REQUEST");
        f.getImportParameterList().setValue("SYSTEM", sid);
        f.getImportParameterList().setValue("CLIENT", cli);
        JCoTable t = f.getTableParameterList().getTable("REQUESTS");
        t.appendRow();
        t.setValue(0, o);
        long t0 = System.currentTimeMillis();
        f.execute(d);
        r.put("codigoRetorno", f.getExportParameterList().getString("RETCODE").trim());
        r.put("mensaje", f.getExportParameterList().getString("MESSAGE").trim());
        r.put("segundos", (System.currentTimeMillis() - t0) / 1000);
        r.put("ordenEnDestino", rfc.leerTabla("E070", List.of("TRKORR", "TRFUNCTION", "TRSTATUS"), "TRKORR", o));
        log.warn("Importación de {} en {}/{}: {} {}", o, sid, cli, r.get("codigoRetorno"), r.get("mensaje"));
        return r;
    }

    /** Libera una orden de copias. Se niega con cualquier otro tipo de orden. */
    public Map<String, Object> liberar(String ordenCopias, boolean confirmar) throws JCoException {
        exigirEscritura();
        String o = orden(ordenCopias);
        Map<String, String> cab = cabecera(o);
        if (!"T".equals(cab.get("TRFUNCTION"))) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT, "La orden " + o + " no es un transporte de copias "
                    + "(tipo " + cab.get("TRFUNCTION") + "). Aquí solo se liberan órdenes tipo T.", Map.of("orden", cab));
        }
        if (!"D".equals(cab.get("TRSTATUS"))) {
            throw new Cambio006Service.Rechazo(HttpStatus.CONFLICT, "La orden " + o + " no está modificable (estado "
                    + cab.get("TRSTATUS") + ")", Map.of("orden", cab));
        }
        if (!confirmar) {
            throw new Cambio006Service.Rechazo(HttpStatus.BAD_REQUEST, "Falta confirmar=true", Map.of("orden", cab));
        }
        // BAPI_CTREQUEST_RELEASE rechaza las órdenes tipo T ("no es una orden").
        // El organizador de transportes de ADT libera cualquier tipo.
        // relwithignlock y no newreleasejobs: en una orden de copias los objetos están
        // bloqueados en las órdenes originales, que es justo lo que se quiere conservar.
        AdtRfc.Respuesta x = adt.pedir("POST", "/sap/bc/adt/cts/transportrequests/" + o + "/relwithignlock",
                Map.of("Accept", "application/vnd.sap.adt.transportorganizer.v1+xml",
                        "Content-Type", "application/vnd.sap.adt.transportorganizer.v1+xml"),
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?><tm:root xmlns:tm=\"http://www.sap.com/cts/adt/tm\" "
                        + "tm:number=\"" + o + "\" tm:useraction=\"relwithignlock\"/>");
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("retorno", x.status() + " " + x.motivo());
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("chkrun:(type|shortText)=\"([^\"]*)\"").matcher(x.cuerpo());
        List<String> mensajes = new java.util.ArrayList<>();
        while (m.find()) {
            mensajes.add(m.group(2));
        }
        r.put("mensajes", mensajes);
        if (!x.ok() || mensajes.isEmpty()) {
            r.put("cuerpo", x.cuerpo().length() > 3000 ? x.cuerpo().substring(0, 3000) : x.cuerpo());
        }
        r.put("cabecera", cabecera(o));
        log.warn("Liberación de la orden de copias {}: {}", o, r.get("retorno"));
        return r;
    }
}
