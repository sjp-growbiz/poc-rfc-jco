package pe.bnv.pocrfc.abap;

import com.sap.conn.jco.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import pe.bnv.pocrfc.config.JCoProperties;

import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Cliente de ADT (ABAP Development Tools) por RFC.
 *
 * Es el mismo canal que usa Eclipse: las peticiones REST de /sap/bc/adt viajan
 * dentro del módulo remoto SADT_REST_RFC_ENDPOINT. Se usa para grabar porque
 * RPY_PROGRAM_UPDATE no es remoto en DS4, y porque es el camino soportado:
 * bloquea el objeto, graba la versión inactiva en la orden y verifica sintaxis
 * con las mismas autorizaciones que tendría la persona en Eclipse.
 */
@Service
public class AdtRfc {

    private static final Logger log = LoggerFactory.getLogger(AdtRfc.class);
    static final String ENDPOINT = "SADT_REST_RFC_ENDPOINT";

    public record Respuesta(int status, String motivo, Map<String, String> cabeceras, String cuerpo) {
        public boolean ok() {
            return status >= 200 && status < 300;
        }
    }

    private final JCoProperties props;

    public AdtRfc(JCoProperties props) {
        this.props = props;
    }

    private JCoDestination destino() throws JCoException {
        return JCoDestinationManager.getDestination(props.getDestino());
    }

    /** Una petición suelta, sin sesión. */
    public Respuesta pedir(String metodo, String uri, Map<String, String> cabeceras, String cuerpo)
            throws JCoException {
        return pedir(destino(), metodo, uri, cabeceras, cuerpo);
    }

    private Respuesta pedir(JCoDestination d, String metodo, String uri, Map<String, String> cabeceras,
                            String cuerpo) throws JCoException {
        JCoFunction f = d.getRepository().getFunction(ENDPOINT);
        if (f == null) {
            throw new IllegalStateException("El sistema no ofrece " + ENDPOINT + " por RFC");
        }
        JCoStructure req = f.getImportParameterList().getStructure("REQUEST");
        JCoStructure linea = req.getStructure("REQUEST_LINE");
        linea.setValue("METHOD", metodo);
        linea.setValue("URI", uri);
        linea.setValue("VERSION", "HTTP/1.1");
        JCoTable hs = req.getTable("HEADER_FIELDS");
        for (Map.Entry<String, String> h : cabeceras.entrySet()) {
            hs.appendRow();
            hs.setValue("NAME", h.getKey());
            hs.setValue("VALUE", h.getValue());
        }
        if (cuerpo != null) {
            req.setValue("MESSAGE_BODY", cuerpo.getBytes(StandardCharsets.UTF_8));
        }

        long t0 = System.currentTimeMillis();
        f.execute(d);

        JCoStructure res = f.getExportParameterList().getStructure("RESPONSE");
        JCoStructure st = res.getStructure("STATUS_LINE");
        Map<String, String> out = new LinkedHashMap<>();
        JCoTable rh = res.getTable("HEADER_FIELDS");
        for (int i = 0; i < rh.getNumRows(); i++) {
            rh.setRow(i);
            out.put(rh.getString("NAME").toLowerCase(), rh.getString("VALUE"));
        }
        byte[] b = res.getByteArray("MESSAGE_BODY");
        Respuesta r = new Respuesta(Integer.parseInt(st.getString("STATUS_CODE").trim()),
                st.getString("REASON_PHRASE"), out, b == null ? "" : new String(b, StandardCharsets.UTF_8));
        // La URI lleva el lockHandle: no es un secreto, pero tampoco hace falta en el log.
        log.info("ADT {} {} -> {} {} ({} ms)", metodo, uri.replaceAll("lockHandle=[^&]+", "lockHandle=…"),
                r.status(), r.motivo(), System.currentTimeMillis() - t0);
        return r;
    }

    /** Fuente por ADT. version: active | inactive (la inactiva cae en la activa si no hay). */
    public Respuesta leerFuente(String uriObjeto, String version) throws JCoException {
        return pedir("GET", uriObjeto + "/source/main?version=" + version, Map.of("Accept", "text/plain"), null);
    }

    /**
     * Bloquea, graba la fuente como versión inactiva en la orden y desbloquea,
     * todo en una misma sesión RFC (el bloqueo vive en la sesión).
     */
    public Map<String, Object> grabarInactivo(String uriObjeto, List<String> fuente, String orden)
            throws JCoException {
        JCoDestination d = destino();
        Map<String, Object> r = new LinkedHashMap<>();
        Map<String, String> sesion = Map.of("X-sap-adt-sessiontype", "stateful");
        JCoContext.begin(d);
        try {
            Map<String, String> hLock = new LinkedHashMap<>(sesion);
            hLock.put("Accept", "application/vnd.sap.as+xml;charset=UTF-8;dataname=com.sap.adt.lock.result");
            Respuesta lock = pedir(d, "POST", uriObjeto + "?_action=LOCK&accessMode=MODIFY", hLock, null);
            if (!lock.ok()) {
                throw new AdtError("No se pudo bloquear el objeto", lock);
            }
            String handle = etiqueta(lock.cuerpo(), "LOCK_HANDLE");
            if (handle == null || handle.isBlank()) {
                throw new AdtError("El bloqueo no devolvió LOCK_HANDLE", lock);
            }
            r.put("ordenQueYaTeniaElObjeto", etiqueta(lock.cuerpo(), "CORRNR"));
            try {
                Map<String, String> hPut = new LinkedHashMap<>(sesion);
                hPut.put("Content-Type", "text/plain; charset=utf-8");
                // Las FM lo exigen (400 "Accept header missing"); a los includes les da igual.
                hPut.put("Accept", "text/plain");
                Respuesta put = pedir(d, "PUT",
                        uriObjeto + "/source/main?lockHandle=" + codificar(handle) + "&corrNr=" + orden,
                        hPut, String.join("\r\n", fuente) + "\r\n");
                if (!put.ok()) {
                    throw new AdtError("SAP rechazó la grabación", put);
                }
                r.put("grabado", put.status() + " " + put.motivo());
            } finally {
                Respuesta un = pedir(d, "POST", uriObjeto + "?_action=UNLOCK&lockHandle=" + codificar(handle),
                        sesion, null);
                r.put("desbloqueo", un.status() + " " + un.motivo());
            }
        } finally {
            JCoContext.end(d);
        }
        return r;
    }

    /**
     * Verificación de sintaxis (el Ctrl+F2 de SE80). version: inactive | active.
     * Pedir "inactive" de un include que no tiene versión inactiva da falsos
     * errores en cascada ("FORM ... does not exist"): se verifica vacío.
     */
    public Respuesta verificarSintaxis(String uriObjeto, String version) throws JCoException {
        String xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                + "<chkrun:checkObjectList xmlns:chkrun=\"http://www.sap.com/adt/checkrun\" "
                + "xmlns:adtcore=\"http://www.sap.com/adt/core\">"
                + "<chkrun:checkObject adtcore:uri=\"" + uriObjeto + "\" chkrun:version=\"" + version + "\"/>"
                + "</chkrun:checkObjectList>";
        Map<String, String> h = new LinkedHashMap<>();
        h.put("Content-Type", "application/vnd.sap.adt.checkobjects+xml");
        h.put("Accept", "application/vnd.sap.adt.checkmessages+xml");
        return pedir("POST", "/sap/bc/adt/checkruns?reporters=abapCheckRun", h, xml);
    }

    /**
     * Activa exactamente los objetos indicados (el Ctrl+F3 de SE80 sobre ellos).
     * preauditRequested=false: no arrastra otros objetos inactivos del usuario.
     * Cada elemento: {uri ADT, nombre}. Si SAP no activa, el cuerpo trae los mensajes.
     */
    public Respuesta activar(List<String[]> objetos) throws JCoException {
        StringBuilder xml = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                + "<adtcore:objectReferences xmlns:adtcore=\"http://www.sap.com/adt/core\">");
        for (String[] o : objetos) {
            xml.append("<adtcore:objectReference adtcore:uri=\"").append(o[0])
               .append("\" adtcore:name=\"").append(o[1]).append("\"/>");
        }
        xml.append("</adtcore:objectReferences>");
        Map<String, String> h = new LinkedHashMap<>();
        h.put("Content-Type", "application/xml");
        h.put("Accept", "application/xml");
        return pedir("POST", "/sap/bc/adt/activation?method=activate&preauditRequested=false", h, xml.toString());
    }

    public static class AdtError extends RuntimeException {
        public final Respuesta respuesta;

        AdtError(String mensaje, Respuesta r) {
            super(mensaje + ": " + r.status() + " " + r.motivo());
            this.respuesta = r;
        }
    }

    static String etiqueta(String xml, String nombre) {
        Matcher m = Pattern.compile("<" + nombre + ">([^<]*)</" + nombre + ">").matcher(xml);
        return m.find() ? m.group(1) : null;
    }

    private static String codificar(String s) {
        return java.net.URLEncoder.encode(s, StandardCharsets.UTF_8);
    }
}
