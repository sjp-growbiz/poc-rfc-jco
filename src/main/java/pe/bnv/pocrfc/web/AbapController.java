package pe.bnv.pocrfc.web;

import com.sap.conn.jco.JCoException;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import pe.bnv.pocrfc.abap.AdtRfc;
import pe.bnv.pocrfc.abap.Cambio006Service;
import pe.bnv.pocrfc.abap.FuenteAbapRfc;
import pe.bnv.pocrfc.abap.TransporteCopiasService;

import java.io.IOException;
import java.util.Map;

/**
 * Despliegue del cambio ABAP @006 por RFC. Ver README, sección
 * "Desplegar ABAP @006 por RFC".
 *
 *   GET  /api/abap/capacidades              qué módulos RPY_* ofrece el sistema
 *   GET  /api/abap/fuente?include=X         fuente activa (texto plano)
 *   GET  /api/abap/006/comparar             lo activo contra actual/; guarda activo/
 *   POST /api/abap/006/aplicar?orden=...    graba @006 INACTIVO en la orden
 */
@RestController
@RequestMapping("/api/abap")
public class AbapController {

    private final FuenteAbapRfc rfc;
    private final Cambio006Service cambio;
    private final AdtRfc adt;
    private final TransporteCopiasService copias;

    public AbapController(FuenteAbapRfc rfc, Cambio006Service cambio, AdtRfc adt,
                          TransporteCopiasService copias) {
        this.copias = copias;
        this.rfc = rfc;
        this.cambio = cambio;
        this.adt = adt;
    }

    /** Consulta ADT de solo lectura (GET), para diagnosticar. uri empieza por /sap/bc/adt/. */
    @GetMapping("/adt")
    public Map<String, Object> adt(@RequestParam String uri,
                                   @RequestParam(defaultValue = "*/*") String accept) throws JCoException {
        if (!uri.startsWith("/sap/bc/adt/")) {
            throw new IllegalArgumentException("uri debe empezar por /sap/bc/adt/");
        }
        AdtRfc.Respuesta r = adt.pedir("GET", uri, Map.of("Accept", accept), null);
        Map<String, Object> m = new java.util.LinkedHashMap<>();
        m.put("status", r.status() + " " + r.motivo());
        m.put("cabeceras", r.cabeceras());
        m.put("cuerpo", r.cuerpo());
        return m;
    }

    /** Lectura de una tabla con un filtro de igualdad (RFC_READ_TABLE). Solo lee. */
    @GetMapping("/tabla")
    public java.util.List<Map<String, String>> tabla(@RequestParam String tabla,
                                                     @RequestParam java.util.List<String> campos,
                                                     @RequestParam String filtro,
                                                     @RequestParam String valor) throws JCoException {
        return rfc.leerTabla(tabla.toUpperCase(), campos, filtro.toUpperCase(), valor);
    }

    @GetMapping("/capacidades")
    public Map<String, Object> capacidades() throws JCoException {
        return rfc.capacidades();
    }

    @GetMapping(value = "/fuente", produces = MediaType.TEXT_PLAIN_VALUE + ";charset=UTF-8")
    public String fuente(@RequestParam String include,
                         @RequestParam(defaultValue = "false") boolean ultimaVersion) throws JCoException {
        return String.join("\n", rfc.leer(include.trim().toUpperCase(), ultimaVersion)) + "\n";
    }

    @GetMapping("/006/comparar")
    public Map<String, Object> comparar(@RequestParam(required = false) String objeto)
            throws JCoException, IOException {
        return cambio.comparar(objeto);
    }

    /** Verificación de sintaxis (Ctrl+F2) de lo grabado. No modifica nada en SAP. */
    @GetMapping("/006/verificar")
    public Map<String, Object> verificar(@RequestParam(required = false) String objeto,
                                         @RequestParam(defaultValue = "active") String version)
            throws JCoException {
        if (!version.equals("active") && !version.equals("inactive")) {
            throw new IllegalArgumentException("version debe ser active o inactive");
        }
        return cambio.verificar(objeto, version);
    }

    /** Crea un transporte de copias con los objetos de las órdenes de origen. No libera. */
    @PostMapping("/transporte/copias")
    public Map<String, Object> copias(@RequestParam java.util.List<String> origen,
                                      @RequestParam String destino,
                                      @RequestParam String texto,
                                      @RequestParam(required = false) java.util.List<String> excluir)
            throws JCoException {
        return copias.crear(origen, destino, texto, excluir);
    }

    /** Inserta en un transporte de copias los objetos de las órdenes de origen. */
    @PostMapping("/transporte/copias/agregar")
    public Map<String, Object> agregar(@RequestParam String orden,
                                       @RequestParam java.util.List<String> origen,
                                       @RequestParam(required = false) java.util.List<String> excluir)
            throws JCoException {
        return copias.agregar(orden, origen, excluir);
    }

    /** Borra un transporte de copias sin liberar (solo tipo T modificable). */
    @PostMapping("/transporte/borrar")
    public Map<String, Object> borrar(@RequestParam String orden,
                                      @RequestParam(defaultValue = "false") boolean confirmar)
            throws JCoException {
        return copias.borrar(orden, confirmar);
    }

    /** Importa una orden liberada en el sistema conectado (solo los de abap.importar-en). */
    @PostMapping("/transporte/importar")
    public Map<String, Object> importar(@RequestParam String sistema,
                                        @RequestParam String mandante,
                                        @RequestParam String orden,
                                        @RequestParam(defaultValue = "false") boolean confirmar)
            throws JCoException {
        return copias.importar(sistema, mandante, orden, confirmar);
    }

    /** Libera un transporte de copias (solo tipo T). */
    @PostMapping("/transporte/liberar")
    public Map<String, Object> liberar(@RequestParam String orden,
                                       @RequestParam(defaultValue = "false") boolean confirmar)
            throws JCoException {
        return copias.liberar(orden, confirmar);
    }

    @PostMapping("/006/aplicar")
    public Map<String, Object> aplicar(@RequestParam String orden,
                                       @RequestParam(defaultValue = "todos") String objeto,
                                       @RequestParam(defaultValue = "false") boolean confirmar,
                                       @RequestParam(defaultValue = "false") boolean omitirChequeoOrden)
            throws JCoException, IOException {
        return cambio.aplicar(orden, objeto, confirmar, omitirChequeoOrden);
    }
}
