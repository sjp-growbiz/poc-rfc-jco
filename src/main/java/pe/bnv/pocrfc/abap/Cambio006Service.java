package pe.bnv.pocrfc.abap;

import com.sap.conn.jco.JCoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Cambio @006 (un lote repartido en varios bultos), tal como lo describe
 * abap/README.md:
 *
 *   U32 · include LZGF_CON_PORTALU32 (FM ZBVMM_OC_GUARDAR_ENTREGAV2): reemplazo completo.
 *   F01 · rutina lotes_modif del include LZGF_CON_PORTALF01: solo esa rutina,
 *         desde su comentario de cabecera hasta su ENDFORM.
 *
 * Reglas, en el orden en que se comprueban antes de grabar:
 *   1. Lo activo en SAP tiene que ser igual a actual/ (ignorando espacios
 *      finales). Si no, se para: @006 se escribió sobre actual/.
 *   2. No puede haber ya una versión inactiva del include (alguien a medias).
 *   3. La orden existe y está modificable (E070, TRSTATUS = D).
 *   4. Se graba INACTIVO. Verificar y Activar se hacen en SE80.
 *   5. Después se relee: la última versión es el objetivo y la activa no cambió.
 */
@Service
public class Cambio006Service {

    private static final Logger log = LoggerFactory.getLogger(Cambio006Service.class);
    private static final Pattern ORDEN = Pattern.compile("^[A-Z0-9]{3}K\\d{6}$");

    /** Un objeto del cambio. form == null: reemplazo del include completo. */
    record Objeto(String clave, String include, String carpeta, String archivo, String form, String uriAdt,
                  boolean esFuncion) {}

    private static final String GRUPO = "/sap/bc/adt/functions/groups/zgf_con_portal";

    static final List<Objeto> OBJETOS = List.of(
            new Objeto("U32", "LZGF_CON_PORTALU32",
                    "ZBVMM_OC_GUARDAR_ENTREGAV2/006-lote-unico-bultos", "LZGF_CON_PORTALU32.abap", null,
                    GRUPO + "/fmodules/zbvmm_oc_guardar_entregav2", true),
            new Objeto("F01", "LZGF_CON_PORTALF01",
                    "ZBVMM_OC_MOD_ENTR_02/006-lote-unico-bultos", "FORM_lotes_modif.abap", "lotes_modif",
                    GRUPO + "/includes/lzgf_con_portalf01", false));

    private final FuenteAbapRfc rfc;
    private final AbapProperties props;
    private final AdtRfc adt;

    public Cambio006Service(FuenteAbapRfc rfc, AbapProperties props, AdtRfc adt) {
        this.rfc = rfc;
        this.props = props;
        this.adt = adt;
    }

    /**
     * Lo que se manda a ADT. Para un include es el objetivo tal cual. Para una
     * FM, ADT presenta la interfaz como sentencia (FUNCTION x TABLES ... .) y
     * no como el bloque de comentarios *" del include: se conserva la cabecera
     * que ADT devuelve hoy —la interfaz no cambia— y se reemplaza el cuerpo.
     */
    private List<String> fuenteParaAdt(Estado e) throws JCoException {
        Objeto o = e.o();
        if (!o.esFuncion()) {
            return e.objetivo();
        }
        int k = finBloqueInterfaz(e.activo());
        if (k != finBloqueInterfaz(e.objetivo())
                || !Texto.iguales(e.activo().subList(0, k), e.objetivo().subList(0, k))) {
            throw new Rechazo(HttpStatus.CONFLICT, o.clave() + ": el bloque de interfaz cambia entre lo activo "
                    + "y el objetivo; por ADT solo se reemplaza el cuerpo.", Map.of());
        }
        AdtRfc.Respuesta r = adt.leerFuente(o.uriAdt(), "active");
        if (!r.ok()) {
            throw new AdtRfc.AdtError("No se pudo leer la FM por ADT", r);
        }
        List<String> porAdt = List.of(r.cuerpo().split("\\r?\\n", -1));
        // Mismo cuerpo por los dos caminos: garantiza que la línea k corta en el mismo sitio.
        if (!Texto.iguales(porAdt.subList(Math.min(k, porAdt.size()), porAdt.size()),
                e.activo().subList(k, e.activo().size()))) {
            throw new Rechazo(HttpStatus.CONFLICT, o.clave() + ": el cuerpo que devuelve ADT no coincide con el "
                    + "include a partir de la línea " + (k + 1) + "; no se graba.", Map.of());
        }
        List<String> out = new ArrayList<>(porAdt.subList(0, k));
        out.addAll(e.objetivo().subList(k, e.objetivo().size()));
        return out;
    }

    /** Índice de la primera línea después del bloque *" de interfaz del include de una FM. */
    private static int finBloqueInterfaz(List<String> include) {
        int ultimo = -1;
        for (int i = 1; i < include.size() && include.get(i).startsWith("*\""); i++) {
            ultimo = i;
        }
        if (ultimo < 0) {
            throw new IllegalStateException("El include de la FM no empieza con el bloque de interfaz *\"");
        }
        return ultimo + 1;
    }

    private static Map<String, Object> resumen(AdtRfc.Respuesta r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("status", r.status() + " " + r.motivo());
        m.put("cuerpo", r.cuerpo());
        return m;
    }

    /** Rechazo con código HTTP y detalle; lo traduce ApiExceptionHandler. */
    public static class Rechazo extends RuntimeException {
        public final HttpStatus status;
        public final Map<String, Object> detalle;

        Rechazo(HttpStatus status, String mensaje, Map<String, Object> detalle) {
            super(mensaje);
            this.status = status;
            this.detalle = detalle;
        }
    }

    /** Estado de un objeto: lo activo, lo esperado y lo que se grabaría. */
    private record Estado(Objeto o, List<String> activo, List<String> objetivo, String estado,
                          Map<String, Object> informe) {}

    private Path archivo(Objeto o, String sub, String nombre) {
        return Path.of(props.getDir(), o.carpeta(), sub, nombre);
    }

    private Estado evaluar(Objeto o, boolean guardarActivo) throws JCoException, IOException {
        List<String> activo = rfc.leer(o.include(), false);
        Map<String, Object> inf = new LinkedHashMap<>();
        inf.put("include", o.include());

        // propuesto-activo/ manda si existe: es @006 llevado sobre lo que SAP
        // tenía activo cuando difería de actual/. Su .base.abap es esa versión
        // activa, y es contra ella que se exige igualdad antes de grabar.
        List<String> actual;
        List<String> propuesto;
        Path sobreActivo = archivo(o, "propuesto-activo", o.archivo());
        if (Files.exists(sobreActivo)) {
            propuesto = Texto.leerArchivo(sobreActivo);
            actual = Texto.leerArchivo(archivo(o, "propuesto-activo", o.archivo().replace(".abap", ".base.abap")));
            inf.put("origen", "propuesto-activo/ (base: " + o.archivo().replace(".abap", ".base.abap") + ")");
        } else {
            propuesto = Texto.leerArchivo(archivo(o, "propuesto", o.archivo()));
            actual = Texto.leerArchivo(archivo(o, "actual", o.archivo()));
            inf.put("origen", "propuesto/ (base: actual/)");
        }
        inf.put("lineasActivo", activo.size());

        List<String> comparable;
        List<String> objetivo;
        if (o.form() == null) {
            comparable = activo;
            objetivo = propuesto;
        } else {
            // Lo que se reemplaza: tantas líneas de comentario sobre el FORM
            // como tiene la copia de actual/, hasta el ENDFORM.
            int cab = Texto.lineasCabecera(actual);
            int[] r = Texto.ubicarForm(activo, o.form(), cab);
            inf.put("rutina", o.form());
            inf.put("rutinaEnActivo", "líneas " + (r[0] + 1) + " a " + (r[1] + 1));
            comparable = Texto.extraerForm(activo, o.form(), cab);
            objetivo = Texto.reemplazarForm(activo, o.form(), cab, propuesto);
            // Informativo: el include entero contra la copia @004 del repo. Que
            // difiera fuera de la rutina no bloquea: esas partes no se tocan.
            List<String> includeActual = Texto.leerArchivo(archivo(o, "actual", o.include() + ".abap"));
            inf.put("includeCompletoIgualAlRepo", Texto.iguales(includeActual, activo));
        }

        if (guardarActivo) {
            Texto.escribirArchivo(archivo(o, "activo", o.include() + ".abap"), activo);
            if (o.form() != null) {
                Texto.escribirArchivo(archivo(o, "activo", o.archivo()), comparable);
            }
            inf.put("copiaActivo", o.carpeta() + "/activo/");
        }

        String estado;
        if (Texto.iguales(comparable, propuesto)) {
            estado = "YA_APLICADO";
        } else {
            Map<String, Object> d = Texto.diferencia(actual, comparable, 40);
            if (Boolean.TRUE.equals(d.get("iguales"))) {
                estado = "LISTO";
            } else {
                estado = "DIFIERE_DE_LA_BASE";
                inf.put("diferenciaConLaBase", d);
            }
        }

        List<Map<String, String>> inactivos = inactivos(o.include());
        if (inactivos == null) {
            inf.put("versionInactiva", "no se pudo consultar (RFC_READ_TABLE no disponible)");
        } else if (!inactivos.isEmpty()) {
            inf.put("versionInactiva", inactivos);
            if (!"YA_APLICADO".equals(estado)) {
                estado = "HAY_VERSION_INACTIVA";
            }
        }
        // DWINACTIV no alcanza: una FM inactiva figura ahí con el nombre de la
        // función, no con el del include. Lo que no falla es comparar la última
        // versión con la activa.
        List<String> ultima = rfc.leer(o.include(), true);
        if (!Texto.iguales(ultima, activo)) {
            estado = Texto.iguales(ultima, objetivo) ? "GRABADO_PENDIENTE_DE_ACTIVAR" : "HAY_VERSION_INACTIVA";
        }
        inf.put("lineasObjetivo", objetivo.size());
        inf.put("estado", estado);
        return new Estado(o, activo, objetivo, estado, inf);
    }

    /** Entradas de DWINACTIV del include; null si no se puede consultar. */
    private List<Map<String, String>> inactivos(String include) {
        try {
            if (!rfc.disponible(FuenteAbapRfc.TABLA)) {
                return null;
            }
            return rfc.leerTabla("DWINACTIV", List.of("OBJECT", "OBJ_NAME", "UNAME"), "OBJ_NAME", include);
        } catch (JCoException e) {
            log.warn("No se pudo leer DWINACTIV para {}: {}", include, e.getMessage());
            return null;
        }
    }

    private List<Objeto> seleccion(String objeto) {
        if (objeto == null || objeto.isBlank() || objeto.equalsIgnoreCase("todos")) {
            return OBJETOS;
        }
        String k = objeto.toUpperCase(Locale.ROOT);
        return OBJETOS.stream().filter(o -> o.clave().equals(k)).findFirst()
                .map(List::of)
                .orElseThrow(() -> new Rechazo(HttpStatus.BAD_REQUEST,
                        "objeto debe ser U32, F01 o todos", Map.of("objeto", objeto)));
    }

    /** Paso B del README: lee lo activo, lo guarda en activo/ y lo compara con actual/. Solo lee en SAP. */
    public Map<String, Object> comparar(String objeto) throws JCoException, IOException {
        Map<String, Object> r = new LinkedHashMap<>();
        for (Objeto o : seleccion(objeto)) {
            r.put(o.clave(), evaluar(o, true).informe());
        }
        return r;
    }

    /** El Ctrl+F2 de SE80 sobre la versión inactiva (o la activa si no hay). No modifica nada. */
    public Map<String, Object> verificar(String objeto, String version) throws JCoException {
        Map<String, Object> r = new LinkedHashMap<>();
        java.util.regex.Pattern msg = java.util.regex.Pattern.compile(
                "<chkrun:checkMessage chkrun:uri=\"([^\"]*)\" chkrun:type=\"(.)\" chkrun:shortText=\"([^\"]*)\"");
        for (Objeto o : seleccion(objeto)) {
            AdtRfc.Respuesta x = adt.verificarSintaxis(o.uriAdt(), version);
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("status", x.status() + " " + x.motivo());
            List<String> errores = new ArrayList<>();
            List<String> avisos = new ArrayList<>();
            java.util.regex.Matcher k = msg.matcher(x.cuerpo());
            while (k.find()) {
                String donde = k.group(1).replaceAll(".*/includes/|.*/fmodules/", "").replace("/source/main#start=", " línea ");
                String linea = k.group(2) + " · " + donde + " · " + k.group(3);
                ("E".equals(k.group(2)) || "A".equals(k.group(2)) || "X".equals(k.group(2)) ? errores : avisos).add(linea);
            }
            m.put("errores", errores);
            m.put("avisos", avisos);
            if (!x.ok() || (errores.isEmpty() && avisos.isEmpty())) {
                m.put("cuerpo", x.cuerpo());
            }
            r.put(o.clave(), m);
        }
        return r;
    }

    /** Graba @006 como inactivo en la orden indicada. */
    public Map<String, Object> aplicar(String orden, String objeto, boolean confirmar, boolean omitirChequeoOrden)
            throws JCoException, IOException {
        if (!props.isEscritura()) {
            throw new Rechazo(HttpStatus.FORBIDDEN,
                    "Escritura ABAP apagada. Arrancar con ABAP_ESCRITURA=true solo para el despliegue.", Map.of());
        }
        if (!confirmar) {
            throw new Rechazo(HttpStatus.BAD_REQUEST,
                    "Falta confirmar=true. Antes, revisar /api/abap/006/comparar.", Map.of());
        }
        String tr = orden == null ? "" : orden.trim().toUpperCase(Locale.ROOT);
        if (!ORDEN.matcher(tr).matches()) {
            throw new Rechazo(HttpStatus.BAD_REQUEST, "Orden de transporte con formato inválido (p. ej. DS4K912345)",
                    Map.of("orden", String.valueOf(orden)));
        }

        Map<String, Object> r = new LinkedHashMap<>();
        r.put("orden", verificarOrden(tr, omitirChequeoOrden));

        List<Estado> estados = new ArrayList<>();
        Map<String, Object> previo = new LinkedHashMap<>();
        for (Objeto o : seleccion(objeto)) {
            Estado e = evaluar(o, true);
            estados.add(e);
            previo.put(o.clave(), e.informe());
        }
        for (Estado e : estados) {
            if (!e.estado().equals("LISTO") && !e.estado().equals("YA_APLICADO")) {
                throw new Rechazo(HttpStatus.CONFLICT,
                        e.o().clave() + " está en estado " + e.estado() + ": no se graba nada.", previo);
            }
        }

        Map<String, Object> resultado = new LinkedHashMap<>();
        for (Estado e : estados) {
            Objeto o = e.o();
            if (e.estado().equals("YA_APLICADO")) {
                resultado.put(o.clave(), Map.of("include", o.include(), "resultado", "ya estaba activo con @006; no se grabó"));
                continue;
            }
            List<String> paraAdt = fuenteParaAdt(e);
            Map<String, Object> v = new LinkedHashMap<>();
            resultado.put(o.clave(), v);
            try {
                v.put("adt", adt.grabarInactivo(o.uriAdt(), paraAdt, tr));
            } catch (AdtRfc.AdtError x) {
                v.put("error", x.getMessage());
                v.put("respuestaAdt", resumen(x.respuesta));
                r.put("resultado", resultado);
                throw new Rechazo(HttpStatus.BAD_GATEWAY, o.clave() + ": " + x.getMessage(), r);
            }
            v.putAll(verificarGrabado(e));
            // El Ctrl+F2 de SE80, sobre la versión inactiva recién grabada.
            v.put("verificacionSintaxis", resumen(adt.verificarSintaxis(o.uriAdt(), "inactive")));
            if (!Boolean.TRUE.equals(v.get("ok"))) {
                r.put("resultado", resultado);
                throw new Rechazo(HttpStatus.INTERNAL_SERVER_ERROR,
                        o.clave() + " se grabó pero la verificación posterior no cuadra. Revisar en SE80 antes de seguir.", r);
            }
        }
        r.put("resultado", resultado);
        r.put("siguientePaso", List.of(
                "Revisar verificacionSintaxis en esta respuesta: si trae errores, NO activar.",
                "SE80 → grupo ZGF_CON_PORTAL → el include grabado aparece como inactivo.",
                "Verificar (Ctrl+F2). Si hay errores, anotar línea y mensaje y NO activar.",
                "Activar (Ctrl+F3) solo los objetos de la orden " + tr + ".",
                "Volver atrás antes de activar: Utilidades → Versiones → borrar la versión inactiva."));
        return r;
    }

    private Map<String, Object> verificarGrabado(Estado e) throws JCoException {
        Objeto o = e.o();
        Map<String, Object> v = new LinkedHashMap<>();
        v.put("include", o.include());
        v.put("lineasGrabadas", e.objetivo().size());

        Map<String, Object> ultima = Texto.diferencia(e.objetivo(), rfc.leer(o.include(), true), 15);
        v.put("ultimaVersionEsElObjetivo", ultima.get("iguales"));
        if (!Boolean.TRUE.equals(ultima.get("iguales"))) {
            v.put("diferenciaUltimaVersion", ultima);
        }
        // Si la activa cambió, SAVE_INACTIVE no se respetó: el código quedó
        // activo sin pasar por Verificar. Se avisa en voz alta.
        boolean activaIntacta = Texto.iguales(e.activo(), rfc.leer(o.include(), false));
        v.put("activaSinCambios", activaIntacta);
        if (!activaIntacta) {
            v.put("ALERTA", "La versión activa cambió: el código quedó ACTIVO sin Verificar. Ir a SE80 ya y Verificar.");
        }
        List<Map<String, String>> inact = inactivos(o.include());
        v.put("versionInactiva", inact == null ? "no se pudo consultar" : inact);

        v.put("ok", Boolean.TRUE.equals(ultima.get("iguales")) && activaIntacta);
        return v;
    }

    private Object verificarOrden(String orden, boolean omitir) throws JCoException {
        if (omitir) {
            return Map.of("numero", orden, "verificada", false);
        }
        if (!rfc.disponible(FuenteAbapRfc.TABLA)) {
            throw new Rechazo(HttpStatus.CONFLICT, "No se puede verificar la orden: RFC_READ_TABLE no disponible. "
                    + "Para seguir sin verificarla: omitirChequeoOrden=true.", Map.of());
        }
        List<Map<String, String>> filas = rfc.leerTabla("E070",
                List.of("TRKORR", "TRFUNCTION", "TRSTATUS", "AS4USER", "STRKORR"), "TRKORR", orden);
        if (filas.isEmpty()) {
            throw new Rechazo(HttpStatus.BAD_REQUEST, "La orden " + orden + " no existe en este sistema", Map.of());
        }
        Map<String, String> f = filas.get(0);
        if (!"D".equals(f.get("TRSTATUS"))) {
            throw new Rechazo(HttpStatus.CONFLICT, "La orden " + orden + " no está modificable (TRSTATUS="
                    + f.get("TRSTATUS") + ")", Map.of("orden", f));
        }
        return f;
    }
}
