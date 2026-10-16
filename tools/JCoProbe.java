import com.sap.conn.jco.*;
import com.sap.conn.jco.ext.*;
import java.util.Properties;

/**
 * Sonda mínima, sin Spring y sin framework alguno.
 *
 * Existe para separar dos preguntas que la API mezcla:
 *   - ¿JCo funciona fuera de BTP, con esta red y estas credenciales?
 *   - ¿JCo 3.1.12 funciona sobre esta versión de Java?
 *
 * Compila y corre igual en Java 8 y en Java 21, así que permite repetir la
 * misma prueba cambiando sólo el JRE.
 *
 *   javac -cp sapjco3.jar -d /tmp/probe tools/JCoProbe.java
 *   java  -cp sapjco3.jar:/tmp/probe -Djava.library.path=. JCoProbe
 */
public class JCoProbe {

    static final String DESTINO = env("JCO_DESTINO", "S4HANA_DEST_RFC");
    static final String RFC     = env("JCO_RFC", "ZBTP_OBTENER_TIPO_CAMBIO");

    public static void main(String[] args) {
        paso("0 · entorno");
        System.out.println("   java      " + System.getProperty("java.version"));
        System.out.println("   os/arch   " + System.getProperty("os.name") + " " + System.getProperty("os.arch"));

        try {
            paso("1 · librería nativa");
            System.out.println("   JCo       " + JCo.getVersion());
        } catch (Throwable t) {
            fallo("no cargó libsapjco3.so. Revisar java.library.path, arquitectura y glibc", t);
            return;
        }

        try {
            Properties p = new Properties();
            p.setProperty(DestinationDataProvider.JCO_ASHOST, req("JCO_ASHOST"));
            p.setProperty(DestinationDataProvider.JCO_SYSNR,  req("JCO_SYSNR"));
            p.setProperty(DestinationDataProvider.JCO_CLIENT, req("JCO_CLIENT"));
            p.setProperty(DestinationDataProvider.JCO_USER,   req("JCO_USER"));
            p.setProperty(DestinationDataProvider.JCO_PASSWD, req("JCO_PASSWD"));
            p.setProperty(DestinationDataProvider.JCO_LANG,   env("JCO_LANG", "ES"));
            Environment.registerDestinationDataProvider(new Provider(DESTINO, p));

            paso("2 · conexión y logon");
            JCoDestination d = JCoDestinationManager.getDestination(DESTINO);
            long t0 = System.currentTimeMillis();
            d.ping();
            System.out.println("   ping OK en " + (System.currentTimeMillis() - t0) + " ms");

            paso("3 · metadata del módulo " + RFC);
            JCoFunction f = d.getRepository().getFunction(RFC);
            if (f == null) {
                System.out.println("   el módulo no existe en este sistema");
                return;
            }
            System.out.println("   metadata recuperada");

            paso("4 · ejecución");
            if ("ZBTP_OBTENER_TIPO_CAMBIO".equals(RFC)) {
                f.getImportParameterList().setValue("I_CURR", env("JCO_CURR", "PEN"));
                f.getImportParameterList().setValue("I_FECHA", env("JCO_FECHA", hoy()));
            }
            t0 = System.currentTimeMillis();
            f.execute(d);
            System.out.println("   ejecutó en " + (System.currentTimeMillis() - t0) + " ms");

            JCoParameterList tablas = f.getTableParameterList();
            if (tablas != null && tablas.getFieldCount() > 0) {
                JCoTable t = tablas.getTable(0);
                System.out.println("   tabla " + tablas.getMetaData().getName(0)
                        + " con " + t.getNumRows() + " filas");
                int max = Math.min(3, t.getNumRows());
                for (int i = 0; i < max; i++) { t.setRow(i); System.out.println("     " + t.toString()); }
            }
            System.out.println();
            System.out.println("VEREDICTO: la cadena completa funciona desde este servidor.");

        } catch (AbapException e) {
            System.out.println();
            System.out.println("VEREDICTO: el transporte FUNCIONA. Falló la lógica ABAP (" + e.getKey() + ").");
            System.out.println("Para la factibilidad de desplegar fuera de BTP, esto cuenta como éxito.");
        } catch (JCoException e) {
            fallo("grupo " + e.getGroup() + " · " + e.getKey()
                    + " — revisar red, puertos del gateway, credenciales o mandante", e);
        } catch (Throwable t) {
            fallo("error no esperado", t);
        }
    }

    static class Provider implements DestinationDataProvider {
        private final String nombre; private final Properties p;
        Provider(String nombre, Properties p) { this.nombre = nombre; this.p = p; }
        public Properties getDestinationProperties(String n) {
            if (!nombre.equals(n)) throw new RuntimeException("destino desconocido: " + n);
            return p;
        }
        public void setDestinationDataEventListener(DestinationDataEventListener l) {}
        public boolean supportsEvents() { return false; }
    }

    static void paso(String s) { System.out.println(); System.out.println("== " + s); }
    static void fallo(String m, Throwable t) {
        System.out.println();
        System.out.println("VEREDICTO: FALLA — " + m);
        System.out.println(t.getClass().getName() + ": " + t.getMessage());
    }
    static String env(String k, String def) {
        String v = System.getenv(k); return (v == null || v.isEmpty()) ? def : v;
    }
    static String req(String k) {
        String v = System.getenv(k);
        if (v == null || v.isEmpty()) throw new IllegalStateException("falta la variable " + k);
        return v;
    }
    static String hoy() {
        return new java.text.SimpleDateFormat("dd.MM.yyyy").format(new java.util.Date());
    }
}
