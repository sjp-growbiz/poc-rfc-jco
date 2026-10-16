package pe.bnv.pocrfc.config;

import com.sap.conn.jco.JCo;
import com.sap.conn.jco.ext.DestinationDataProvider;
import com.sap.conn.jco.ext.Environment;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.Properties;

@Component
public class JCoBootstrap {

    private static final Logger log = LoggerFactory.getLogger(JCoBootstrap.class);

    private final JCoProperties props;

    public JCoBootstrap(JCoProperties props) {
        this.props = props;
    }

    @PostConstruct
    void registrar() {
        // Antes de abrir cualquier conexión: el trace nativo no captura lo que
        // ya ocurrió.
        if (props.getTraceLevel() > 0) {
            boolean aConsola = "consola".equalsIgnoreCase(props.getTraceDestino());
            if (aConsola) {
                JCo.addTraceListener(new JCoConsoleTrace());
            }
            // setTrace es lo que enciende el nivel: sin él no se emite nada, ni
            // a archivo ni al listener, y por eso hace falta aunque el destino
            // sea la consola. Con un listener registrado JCo deja de escribir
            // los .trc —comprobado—, así que la ruta queda sin uso; se le pasa
            // el temporal para no crear un /app/trace que nadie va a llenar.
            String ruta = aConsola ? System.getProperty("java.io.tmpdir") : props.getTracePath();
            new java.io.File(ruta).mkdirs();
            JCo.setTrace(props.getTraceLevel(), ruta);

            log.warn("Trace nativo de JCo en nivel {} hacia {}. Es muy verboso y "
                    + "guarda los datos de la conexión: no dejarlo encendido.",
                    props.getTraceLevel(),
                    aConsola ? "la consola (logger com.sap.conn.jco.trace, nivel DEBUG)" : ruta);
        }

        Properties p = new Properties();
        p.setProperty(DestinationDataProvider.JCO_ASHOST, req(props.getAshost(), "JCO_ASHOST"));
        p.setProperty(DestinationDataProvider.JCO_SYSNR,  req(props.getSysnr(),  "JCO_SYSNR"));
        p.setProperty(DestinationDataProvider.JCO_CLIENT, req(props.getClient(), "JCO_CLIENT"));
        p.setProperty(DestinationDataProvider.JCO_USER,   req(props.getUser(),   "JCO_USER"));
        p.setProperty(DestinationDataProvider.JCO_PASSWD, req(props.getPasswd(), "JCO_PASSWD"));
        p.setProperty(DestinationDataProvider.JCO_LANG,   props.getLang());
        p.setProperty(DestinationDataProvider.JCO_POOL_CAPACITY, props.getPoolCapacity());
        p.setProperty(DestinationDataProvider.JCO_PEAK_LIMIT,    props.getPeakLimit());
        p.setProperty(DestinationDataProvider.JCO_SNC_MODE,      props.getSncMode());

        EnvDestinationDataProvider proveedor = new EnvDestinationDataProvider();
        proveedor.registrar(props.getDestino(), p);

        // registerDestinationDataProvider sólo admite una llamada por JVM
        Environment.registerDestinationDataProvider(proveedor);

        log.info("Destino '{}' registrado -> {}:{} mandante {} usuario {}",
                props.getDestino(), props.getAshost(), props.getSysnr(),
                props.getClient(), props.getUser());
    }

    private static String req(String valor, String nombre) {
        if (valor == null || valor.isBlank()) {
            throw new IllegalStateException("Falta la variable de entorno " + nombre);
        }
        return valor;
    }
}
