package com.mycompany.pro.util;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Utilidad para construir, de forma segura, la condicion SQL adicional que se
 * inyecta en los informes JasperReports mediante el parametro $P!{FILTROS}
 * (sustitucion directa de texto, sin comillas de parametro preparado).
 *
 * Como $P!{...} vuelca el texto tal cual dentro del WHERE del reporte, toda
 * condicion que se arme aqui pasa antes por una validacion/escape segun el
 * tipo de dato, para evitar inyeccion SQL:
 *  - Enteros (ids de tecnico, sala, equipo, etc.): se parsean con
 *    Integer.parseInt; si no es un numero valido, la condicion se descarta.
 *  - Valores de catalogo cerrado (estado, prioridad, etc.): solo se aceptan
 *    si estan dentro de la lista blanca (Set) que cada informe define.
 *  - Texto libre (numero de ticket, nombre, diagnostico): se escapan las
 *    comillas simples duplicandolas y se arma un ILIKE '%...%'.
 *
 * Si ninguna condicion es valida, se devuelve "1=1" para no romper el WHERE.
 */
public final class InformeUtil {

    private InformeUtil() {
    }

    /** Devuelve el texto tal cual si no es nulo/vacio, o null en caso contrario. */
    public static String limpiar(String valor) {
        if (valor == null) {
            return null;
        }
        String v = valor.trim();
        return v.isEmpty() ? null : v;
    }

    /**
     * Condicion de igualdad exacta para un valor de catalogo cerrado
     * (por ejemplo estado o prioridad). Solo se genera si el valor recibido
     * esta dentro de "permitidos"; de lo contrario devuelve null (se ignora).
     */
    public static String condicionExacta(String columna, String valorCrudo, Set<String> permitidos) {
        String valor = limpiar(valorCrudo);
        if (valor == null || permitidos == null || !permitidos.contains(valor)) {
            return null;
        }
        return columna + " = '" + valor.replace("'", "''") + "'";
    }

    /**
     * Condicion de igualdad para un id numerico (tecnico, sala, equipo, etc.).
     * Si el valor no es un entero valido, devuelve null (se ignora el filtro).
     */
    public static String condicionEntero(String columna, String valorCrudo) {
        String valor = limpiar(valorCrudo);
        if (valor == null) {
            return null;
        }
        try {
            int id = Integer.parseInt(valor);
            return columna + " = " + id;
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    /**
     * Condicion de busqueda parcial (LIKE) para texto libre, con las comillas
     * simples escapadas. Se recorta a 100 caracteres para evitar abusos.
     */
    public static String condicionTexto(String columna, String valorCrudo) {
        String valor = limpiar(valorCrudo);
        if (valor == null) {
            return null;
        }
        if (valor.length() > 100) {
            valor = valor.substring(0, 100);
        }
        String escapado = valor.replace("'", "''");
        return "UPPER(" + columna + ") LIKE UPPER('%" + escapado + "%')";
    }

    /** Combina condiciones (ignorando las nulas) con AND. Si no queda ninguna, devuelve "1=1". */
    public static String combinar(String... condiciones) {
        List<String> validas = new ArrayList<>();
        if (condiciones != null) {
            for (String c : condiciones) {
                if (c != null && !c.trim().isEmpty()) {
                    validas.add(c);
                }
            }
        }
        if (validas.isEmpty()) {
            return "1=1";
        }
        return "(" + String.join(") AND (", validas) + ")";
    }
}
