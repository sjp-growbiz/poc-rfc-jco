package pe.bnv.pocrfc.abap;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Despliegue de fuente ABAP por RFC (variables ABAP_*).
 *
 * La escritura viene apagada: se enciende a propósito, para un sistema y un
 * momento concretos, y se vuelve a apagar.
 */
@ConfigurationProperties(prefix = "abap")
public class AbapProperties {

    /** Carpeta abap/ del repositorio (montada en el contenedor). */
    private String dir = "/app/abap";

    /** Sin esto en true, /aplicar se niega. */
    private boolean escritura = false;

    /** Valor de SAVE_INACTIVE en RPY_PROGRAM_UPDATE: cualquier valor no vacío graba inactivo. */
    private String marcaInactivo = "X";

    /** Sistemas (SID) donde se permite importar órdenes. Producción no va aquí. */
    private java.util.List<String> importarEn = java.util.List.of("QS4");

    public java.util.List<String> getImportarEn() { return importarEn; }
    public void setImportarEn(java.util.List<String> v) { importarEn = v; }
    public String getDir() { return dir; }
    public void setDir(String v) { dir = v; }
    public boolean isEscritura() { return escritura; }
    public void setEscritura(boolean v) { escritura = v; }
    public String getMarcaInactivo() { return marcaInactivo; }
    public void setMarcaInactivo(String v) { marcaInactivo = v; }
}
