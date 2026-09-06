package pe.bnv.pocrfc.config;

import com.sap.conn.jco.ext.DestinationDataEventListener;
import com.sap.conn.jco.ext.DestinationDataProvider;

import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Sustituto del servicio de destinos de BTP.
 *
 * Dentro de Cloud Foundry, JCoDestinationManager.getDestination(nombre) resuelve
 * contra el servicio de conectividad y el Cloud Connector. Fuera de BTP ese
 * mecanismo no existe: se registra este proveedor y JCo conecta directo al
 * servidor SAP por la red. Los sitios de llamada no cambian.
 */
public class EnvDestinationDataProvider implements DestinationDataProvider {

    private final Map<String, Properties> destinos = new ConcurrentHashMap<>();

    public void registrar(String nombre, Properties propiedades) {
        destinos.put(nombre, propiedades);
    }

    @Override
    public Properties getDestinationProperties(String nombre) {
        Properties p = destinos.get(nombre);
        if (p == null) {
            throw new RuntimeException("No hay configuración para el destino '" + nombre
                    + "'. Destinos registrados: " + destinos.keySet());
        }
        return p;
    }

    @Override
    public void setDestinationDataEventListener(DestinationDataEventListener listener) {
        // sin recarga en caliente: la configuración se lee una vez al arrancar
    }

    @Override
    public boolean supportsEvents() {
        return false;
    }
}
