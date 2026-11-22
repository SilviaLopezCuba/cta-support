package com.mycompany.pro.util;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Cantidades sin decimales para mostrar en pantalla (stock, cantidades, etc.). */
public final class NumUtil {

    private NumUtil() {
    }

    /** Redondea (half-up) a entero y devuelve el valor como BigDecimal sin decimales; null se mantiene null. */
    public static BigDecimal entero(BigDecimal valor) {
        return valor == null ? null : valor.setScale(0, RoundingMode.HALF_UP);
    }

    /** Devuelve la cantidad como texto sin decimales, p. ej. 12.00 -> "12". */
    public static String entero(double valor) {
        return String.valueOf(Math.round(valor));
    }

    public static String entero(Object valor) {
        if (valor == null) {
            return "-";
        }
        if (valor instanceof Number) {
            return String.valueOf(Math.round(((Number) valor).doubleValue()));
        }
        return String.valueOf(valor);
    }
}
