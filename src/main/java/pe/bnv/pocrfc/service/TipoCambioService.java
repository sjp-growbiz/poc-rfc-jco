package pe.bnv.pocrfc.service;

import com.sap.conn.jco.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import pe.bnv.pocrfc.config.JCoProperties;
import pe.bnv.pocrfc.model.TipoCambioDto;

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

    public TipoCambioService(JCoProperties props) {
        this.props = props;
    }

    public List<TipoCambioDto> consultar(String curr, String fecha, String filtroMoneda) throws JCoException {
        JCoDestination destino = JCoDestinationManager.getDestination(props.getDestino());
        JCoFunction f = destino.getRepository().getFunction(RFC);
        if (f == null) {
            throw new IllegalStateException("El módulo de función " + RFC + " no existe en el sistema");
        }

        JCoParameterList entradas = f.getImportParameterList();
        entradas.setValue("I_CURR", curr);
        entradas.setValue("I_FECHA", fecha);

        long t0 = System.currentTimeMillis();
        f.execute(destino);
        log.info("{} respondió en {} ms", RFC, System.currentTimeMillis() - t0);

        JCoTable tabla = f.getTableParameterList().getTable("T_TCURR");
        List<TipoCambioDto> filas = new ArrayList<>();
        for (int i = 0; i < tabla.getNumRows(); i++) {
            tabla.setRow(i);
            String origen = tabla.getString("FCURR");
            if (filtroMoneda != null && !filtroMoneda.isBlank() && !filtroMoneda.equalsIgnoreCase(origen)) {
                continue;
            }
            filas.add(new TipoCambioDto(
                    tabla.getString("GDATU"),
                    origen,
                    tabla.getString("TCURR"),
                    tabla.getBigDecimal("UKURS")));
        }
        return filas;
    }
}
