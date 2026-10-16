package pe.bnv.pocrfc.service;

import com.sap.conn.jco.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import pe.bnv.pocrfc.config.JCoProperties;
import pe.bnv.pocrfc.model.TipoCambioDto;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;

/**
 * Réplica de backend_zinvoice · ParametroServiceImpl.listaTipoCambio().
 * Mismo módulo de función, mismos parámetros, misma tabla de salida.
 */
@Service
public class TipoCambioService {

    private static final Logger log = LoggerFactory.getLogger(TipoCambioService.class);
    private static final String RFC = "ZBTP_OBTENER_TIPO_CAMBIO";

    private final JCoProperties props;
    private final RfcTrace trace;

    public TipoCambioService(JCoProperties props, RfcTrace trace) {
        this.props = props;
        this.trace = trace;
    }

    /**
     * Decodifica el GDATU de T_TCURR.
     *
     * SAP guarda esa fecha invertida —99999999 menos aaaammdd— para que el
     * orden natural del índice deje primero lo más reciente. Así, 79799092 es
     * 20200907, o sea el 7 de setiembre de 2020.
     *
     * Devuelve null si el valor no es una fecha: es una sonda, y una fila con
     * la fecha vacía es preferible a una consulta entera que se cae.
     */
    static LocalDate fechaDeGdatu(String gdatu) {
        if (gdatu == null || gdatu.isBlank()) {
            return null;
        }
        try {
            long invertida = Long.parseLong(gdatu.trim());
            return LocalDate.parse(String.format("%08d", 99_999_999L - invertida),
                    DateTimeFormatter.BASIC_ISO_DATE);
        } catch (NumberFormatException | DateTimeParseException e) {
            log.warn("GDATU '{}' no es una fecha invertida válida; la fila va sin fecha", gdatu);
            return null;
        }
    }

    /**
     * Asigna un valor avisando si no cabe en el campo.
     *
     * JCo trunca en silencio: mandar "04.09.2026" a un CHAR(8) deja "04.09.20"
     * y el módulo responde con datos de otro año, sin error de ningún tipo. Un
     * fallo así no se descubre mirando la respuesta, sólo el log.
     */
    private static void asignar(JCoParameterList entradas, String campo, String valor) {
        int cabe = entradas.getMetaData().getLength(campo);
        if (valor != null && valor.length() > cabe) {
            log.warn("{} es CHAR({}) y se le mandaron {} caracteres: \"{}\" viajará como \"{}\"",
                    campo, cabe, valor.length(), valor, valor.substring(0, cabe));
        }
        entradas.setValue(campo, valor);
    }

    public List<TipoCambioDto> consultar(String curr, String fecha, String filtroMoneda) throws JCoException {
        JCoDestination destino = JCoDestinationManager.getDestination(props.getDestino());
        JCoFunction f = destino.getRepository().getFunction(RFC);
        if (f == null) {
            throw new IllegalStateException("El módulo de función " + RFC + " no existe en el sistema");
        }

        JCoParameterList entradas = f.getImportParameterList();
        asignar(entradas, "I_CURR", curr);
        asignar(entradas, "I_FECHA", fecha);

        long t0 = System.currentTimeMillis();
        trace.ejecutar(f, destino);
        log.info("{} respondió en {} ms", RFC, System.currentTimeMillis() - t0);

        JCoTable tabla = f.getTableParameterList().getTable("T_TCURR");
        List<TipoCambioDto> filas = new ArrayList<>();
        for (int i = 0; i < tabla.getNumRows(); i++) {
            tabla.setRow(i);
            String origen = tabla.getString("FCURR");
            if (filtroMoneda != null && !filtroMoneda.isBlank() && !filtroMoneda.equalsIgnoreCase(origen)) {
                continue;
            }
            String gdatu = tabla.getString("GDATU");
            filas.add(new TipoCambioDto(
                    fechaDeGdatu(gdatu),
                    gdatu,
                    origen,
                    tabla.getString("TCURR"),
                    tabla.getBigDecimal("UKURS")));
        }
        return filas;
    }
}
