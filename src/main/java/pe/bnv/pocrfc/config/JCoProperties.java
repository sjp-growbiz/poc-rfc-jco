package pe.bnv.pocrfc.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Datos de conexión al sistema SAP. Fuera de BTP no existe el servicio de
 * destinos, así que estos valores los aporta el entorno (variables JCO_*).
 */
@ConfigurationProperties(prefix = "jco")
public class JCoProperties {

    /** Nombre lógico del destino. Es el mismo que usan los backends actuales. */
    private String destino = "S4HANA_DEST_RFC";

    private String ashost;   // host del servidor de aplicación
    private String sysnr;    // número de sistema, dos dígitos
    private String client;   // mandante
    private String user;
    private String passwd;
    private String lang = "ES";
    private String poolCapacity = "3";
    private String peakLimit = "10";
    /** 0 = sin SNC. Ponerlo a 1 exige el resto de propiedades snc.*. */
    private String sncMode = "0";

    public String getDestino() { return destino; }
    public void setDestino(String v) { destino = v; }
    public String getAshost() { return ashost; }
    public void setAshost(String v) { ashost = v; }
    public String getSysnr() { return sysnr; }
    public void setSysnr(String v) { sysnr = v; }
    public String getClient() { return client; }
    public void setClient(String v) { client = v; }
    public String getUser() { return user; }
    public void setUser(String v) { user = v; }
    public String getPasswd() { return passwd; }
    public void setPasswd(String v) { passwd = v; }
    public String getLang() { return lang; }
    public void setLang(String v) { lang = v; }
    public String getPoolCapacity() { return poolCapacity; }
    public void setPoolCapacity(String v) { poolCapacity = v; }
    public String getPeakLimit() { return peakLimit; }
    public void setPeakLimit(String v) { peakLimit = v; }
    public String getSncMode() { return sncMode; }
    public void setSncMode(String v) { sncMode = v; }
}
