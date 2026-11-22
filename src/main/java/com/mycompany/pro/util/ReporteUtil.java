package com.mycompany.pro.util;

import java.io.File;
import java.util.concurrent.ConcurrentHashMap;
import javax.servlet.ServletContext;
import net.sf.jasperreports.engine.JasperCompileManager;
import net.sf.jasperreports.engine.JasperReport;

/**
 * Carga reportes JasperReports directamente desde su .jrxml, compilandolos en
 * memoria y guardandolos en cache (se recompilan solo si el .jrxml cambia).
 * Asi no hace falta tener ningun .jasper en el servidor ni acordarse de
 * recompilar: un .jasper viejo o ausente ya no puede romper un reporte.
 */
public final class ReporteUtil {

    private static final class Entrada {
        final long modificado;
        final JasperReport reporte;
        Entrada(long modificado, JasperReport reporte) {
            this.modificado = modificado;
            this.reporte = reporte;
        }
    }

    private static final ConcurrentHashMap<String, Entrada> CACHE = new ConcurrentHashMap<>();

    private ReporteUtil() {
    }

    /** nombre: sin extension, p. ej. "reporte_personas". */
    public static JasperReport cargar(ServletContext contexto, String nombre) throws Exception {
        String ruta = contexto.getRealPath("/reportes/" + nombre + ".jrxml");
        if (ruta == null) {
            throw new Exception("No se pudo resolver la ruta del reporte " + nombre);
        }
        File archivo = new File(ruta);
        if (!archivo.exists()) {
            throw new Exception("No se encontró /reportes/" + nombre + ".jrxml");
        }
        long modificado = archivo.lastModified();
        Entrada e = CACHE.get(nombre);
        if (e == null || e.modificado != modificado) {
            JasperReport compilado = JasperCompileManager.compileReport(archivo.getAbsolutePath());
            e = new Entrada(modificado, compilado);
            CACHE.put(nombre, e);
        }
        return e.reporte;
    }
}
