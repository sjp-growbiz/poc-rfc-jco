package pe.bnv.pocrfc.web;

import com.sap.conn.jco.JCoException;
import org.springframework.web.bind.annotation.*;
import pe.bnv.pocrfc.model.TipoCambioDto;
import pe.bnv.pocrfc.service.TipoCambioService;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

@RestController
@RequestMapping("/api/tipo-cambio")
public class TipoCambioController {

    private static final DateTimeFormatter SAP = DateTimeFormatter.ofPattern("yyyyMMdd");

    private final TipoCambioService servicio;

    public TipoCambioController(TipoCambioService servicio) {
        this.servicio = servicio;
    }

    /**
     * GET /api/tipo-cambio?curr=PEN&fecha=20260906&moneda=USD
     * fecha y moneda son opcionales: sin fecha usa hoy, sin moneda devuelve todo.
     */
    @GetMapping
    public List<TipoCambioDto> consultar(
            @RequestParam(defaultValue = "PEN") String curr,
            @RequestParam(required = false) String fecha,
            @RequestParam(required = false) String moneda) throws JCoException {
        String f = (fecha == null || fecha.isBlank()) ? LocalDate.now().format(SAP) : fecha;
        return servicio.consultar(curr, f, moneda);
    }
}
