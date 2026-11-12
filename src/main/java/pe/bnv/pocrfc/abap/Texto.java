package pe.bnv.pocrfc.abap;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Utilidades de texto para comparar fuente ABAP del repositorio con la de SAP.
 *
 * Lo que SAP devuelve por RFC no trae espacios al final de línea (el editor los
 * quita) y los archivos del repo vienen con CRLF. Comparar "ignorando espacios"
 * es: quitar los espacios finales de cada línea y las líneas vacías del final.
 * Mayúsculas y sangría sí cuentan: un Pretty Printer aplicado en SAP es un
 * cambio real que hay que ver antes de pisar el código.
 */
public final class Texto {

    private Texto() {}

    public static List<String> leerArchivo(Path p) throws IOException {
        String s = Files.readString(p, StandardCharsets.UTF_8);
        if (!s.isEmpty() && s.charAt(0) == '﻿') {
            s = s.substring(1);
        }
        List<String> lineas = new ArrayList<>(List.of(s.split("\r?\n", -1)));
        // split deja un elemento vacío tras el último salto de línea
        if (!lineas.isEmpty() && lineas.get(lineas.size() - 1).isEmpty()) {
            lineas.remove(lineas.size() - 1);
        }
        return lineas;
    }

    /** Se escribe con CRLF, como el resto de los .abap del repositorio. */
    public static void escribirArchivo(Path p, List<String> lineas) throws IOException {
        Files.createDirectories(p.getParent());
        Files.writeString(p, String.join("\r\n", lineas) + "\r\n", StandardCharsets.UTF_8);
    }

    public static List<String> normalizar(List<String> lineas) {
        List<String> r = new ArrayList<>(lineas.size());
        for (String l : lineas) {
            r.add(l.replaceAll("\\s+$", ""));
        }
        while (!r.isEmpty() && r.get(r.size() - 1).isEmpty()) {
            r.remove(r.size() - 1);
        }
        return r;
    }

    public static boolean iguales(List<String> a, List<String> b) {
        return normalizar(a).equals(normalizar(b));
    }

    /**
     * Diferencia como un solo bloque: prefijo y sufijo comunes y el tramo del
     * medio que difiere en cada lado. No es un diff completo, pero alcanza para
     * decidir si se puede pegar o no, y no cuesta memoria con includes de
     * miles de líneas.
     */
    public static Map<String, Object> diferencia(List<String> esperado, List<String> encontrado, int maxLineas) {
        List<String> a = normalizar(esperado);
        List<String> b = normalizar(encontrado);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("iguales", a.equals(b));
        r.put("lineasEsperado", a.size());
        r.put("lineasEncontrado", b.size());
        if (a.equals(b)) {
            return r;
        }
        int ini = 0;
        while (ini < a.size() && ini < b.size() && a.get(ini).equals(b.get(ini))) {
            ini++;
        }
        int finA = a.size() - 1;
        int finB = b.size() - 1;
        while (finA >= ini && finB >= ini && a.get(finA).equals(b.get(finB))) {
            finA--;
            finB--;
        }
        r.put("primeraLineaDistinta", ini + 1);
        r.put("esperado", tramo(a, ini, finA, maxLineas));
        r.put("encontrado", tramo(b, ini, finB, maxLineas));
        return r;
    }

    private static List<String> tramo(List<String> l, int desde, int hasta, int max) {
        List<String> r = new ArrayList<>();
        for (int i = desde; i <= hasta && r.size() < max; i++) {
            r.add(String.format("%5d| %s", i + 1, l.get(i)));
        }
        int total = hasta - desde + 1;
        if (total > max) {
            r.add("... " + (total - max) + " líneas más");
        }
        return r;
    }

    /** Líneas de comentario (*) con que empieza una rutina copiada: su cabecera. */
    public static int lineasCabecera(List<String> rutina) {
        int n = 0;
        while (n < rutina.size() && rutina.get(n).startsWith("*")) {
            n++;
        }
        return n;
    }

    /**
     * Ubica una rutina FORM dentro de un include: desde las {@code cabecera}
     * líneas de comentario que preceden al FORM hasta su ENDFORM, ambos
     * inclusive. La cabecera se cuenta en la copia del repo y no se deduce del
     * include: SE80 suele poner encima otro bloque (*& Form lotes_modif) que no
     * es parte de lo que se reemplaza.
     *
     * @return {inicio, fin} como índices base 0
     */
    public static int[] ubicarForm(List<String> include, String nombreForm, int cabecera) {
        String sentencia = "FORM " + nombreForm.toUpperCase(Locale.ROOT);
        int form = -1;
        for (int i = 0; i < include.size(); i++) {
            String u = include.get(i).trim().toUpperCase(Locale.ROOT);
            if (u.equals(sentencia) || u.startsWith(sentencia + " ") || u.startsWith(sentencia + ".")) {
                if (form >= 0) {
                    throw new IllegalStateException("La rutina " + nombreForm + " aparece dos veces (líneas "
                            + (form + 1) + " y " + (i + 1) + ")");
                }
                form = i;
            }
        }
        if (form < 0) {
            throw new IllegalStateException("No encuentro FORM " + nombreForm + " en el include");
        }
        int inicio = form - cabecera;
        if (inicio < 0) {
            throw new IllegalStateException("FORM " + nombreForm + " no tiene " + cabecera + " líneas encima");
        }
        for (int i = inicio; i < form; i++) {
            if (!include.get(i).startsWith("*")) {
                throw new IllegalStateException("Encima de FORM " + nombreForm + " no hay " + cabecera
                        + " líneas de comentario (línea " + (i + 1) + ")");
            }
        }
        for (int i = form + 1; i < include.size(); i++) {
            String u = include.get(i).trim().toUpperCase(Locale.ROOT);
            if (u.startsWith("ENDFORM")) {
                return new int[] {inicio, i};
            }
            if (u.startsWith("FORM ")) {
                break;
            }
        }
        throw new IllegalStateException("FORM " + nombreForm + " sin ENDFORM antes de la rutina siguiente");
    }

    public static List<String> extraerForm(List<String> include, String nombreForm, int cabecera) {
        int[] r = ubicarForm(include, nombreForm, cabecera);
        return new ArrayList<>(include.subList(r[0], r[1] + 1));
    }

    /** El include con la rutina reemplazada; el resto queda idéntico. */
    public static List<String> reemplazarForm(List<String> include, String nombreForm, int cabecera,
                                              List<String> nueva) {
        int[] r = ubicarForm(include, nombreForm, cabecera);
        List<String> out = new ArrayList<>(include.subList(0, r[0]));
        out.addAll(nueva);
        out.addAll(include.subList(r[1] + 1, include.size()));
        return out;
    }
}
