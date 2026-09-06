package pe.bnv.pocrfc.config;

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
