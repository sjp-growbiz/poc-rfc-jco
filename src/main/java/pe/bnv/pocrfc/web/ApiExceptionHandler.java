package pe.bnv.pocrfc.web;

import com.sap.conn.jco.AbapException;
import com.sap.conn.jco.JCoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Distinguir el tipo de fallo es el objetivo de la POC.
 *
 *   AbapException  -> el transporte funciona; falló la lógica de negocio.
 *                     Para efectos de factibilidad, esto es un ÉXITO.
 *   JCoException   -> falló la conexión, el logon o la librería nativa.
 *                     Aquí sí hay algo que resolver en red o en la imagen.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(AbapException.class)
    public ResponseEntity<Map<String, Object>> abap(AbapException e) {
        log.warn("Excepción ABAP: {}", e.getKey(), e);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("tipo", "ABAP");
        r.put("veredicto", "El transporte funciona. El error viene de la lógica del módulo de función.");
        r.put("key", e.getKey());
        r.put("mensaje", e.getMessageText());
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(r);
    }

    @ExceptionHandler(JCoException.class)
    public ResponseEntity<Map<String, Object>> jco(JCoException e) {
        log.error("Excepción JCo grupo {}: {}", e.getGroup(), e.getKey(), e);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("tipo", "JCO");
        r.put("veredicto", "No se completó la conexión: revisar red, puertos, credenciales o librería nativa.");
        r.put("grupo", e.getGroup());
        r.put("key", e.getKey());
        r.put("mensaje", e.getMessageText());
        return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(r);
    }

    @ExceptionHandler(Throwable.class)
    public ResponseEntity<Map<String, Object>> otro(Throwable e) {
        log.error("Error no esperado", e);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("tipo", e.getClass().getName());
        r.put("mensaje", String.valueOf(e.getMessage()));
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(r);
    }
}
