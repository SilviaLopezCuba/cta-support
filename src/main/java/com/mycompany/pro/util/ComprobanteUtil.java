package com.mycompany.pro.util;

import java.io.File;
import java.sql.Connection;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import net.sf.jasperreports.engine.JRParameter;
import net.sf.jasperreports.engine.JRPrintPage;
import net.sf.jasperreports.engine.JasperCompileManager;
import net.sf.jasperreports.engine.JasperExportManager;
import net.sf.jasperreports.engine.JasperFillManager;
import net.sf.jasperreports.engine.JasperPrint;
import net.sf.jasperreports.engine.JasperReport;
import net.sf.jasperreports.engine.util.JRLoader;

/**
 * Genera comprobantes (Ticket, Donacion, Mantenimiento, Solicitud de reposicion) en JasperReports.
 * Un solo PDF puede reunir varios comprobantes (uno por registro): sirve para
 * imprimir un registro individual, varios seleccionados o todo lo filtrado.
 *
 * Rendimiento: antes se recompilaba el reporte principal y todos sus subreportes
 * en CADA impresion (cada compilacion invoca al compilador de Java y tarda cientos
 * de milisegundos). Ahora:
 *  - un .jrxml se compila a .jasper solo si el .jasper no existe o es mas viejo que el .jrxml;
 *  - el reporte principal ya compilado se guarda en memoria y se reutiliza mientras
 *    el .jasper no cambie.
 * Se conserva la proteccion original: si alguien edita un .jrxml, el siguiente
 * pedido detecta la fecha nueva y recompila.
 */
public class ComprobanteUtil {

    public static final int MAX_COMPROBANTES = 500;

    /** Nombre del logo (membrete) esperado dentro de la carpeta de reportes. */
    private static final String LOGO_ARCHIVO = "logo_cta.jpg";

    /** Reportes principales ya cargados en memoria: ruta del .jasper -> (fecha, reporte). */
    private static final ConcurrentHashMap<String, Object[]> CACHE = new ConcurrentHashMap<>();

    /** Compatibilidad: version sin usuario de impresion (los informes anteriores la siguen usando). */
    public static byte[] generar(Connection cn, String dirReportes, String principal, String[] subreportes,
            String paramId, List<Integer> ids) throws Exception {
        return generar(cn, dirReportes, principal, subreportes, paramId, ids, null);
    }

    /**
     * @param dirReportes carpeta con los .jrxml (se compilan a .jasper si aun no existen o cambiaron)
     * @param principal   nombre del reporte principal, sin extension (ej. "comprobanteTicket")
     * @param subreportes nombres de los subreportes que usa, sin extension
     * @param paramId     nombre del parametro Integer del reporte (ej. "ID_TICKET")
     * @param ids         registros a imprimir, uno por comprobante
     * @param idUsuario   usuario que imprime (sale en el encabezado); puede ser null
     */
    public static byte[] generar(Connection cn, String dirReportes, String principal, String[] subreportes,
            String paramId, List<Integer> ids, Integer idUsuario) throws Exception {
        if (ids == null || ids.isEmpty()) {
            throw new IllegalArgumentException("No hay registros para imprimir.");
        }
        if (!dirReportes.endsWith(File.separator) && !dirReportes.endsWith("/")) {
            dirReportes = dirReportes + File.separator;
        }
        for (String sub : subreportes) {
            compilarSiCambio(dirReportes, sub);
        }
        JasperReport reporte = cargarPrincipal(dirReportes, principal);

        String quien = nombreUsuario(cn, idUsuario);
        Locale local = new Locale("es", "PY");
        JasperPrint total = null;
        for (Integer id : ids) {
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put(paramId, id);
            parametros.put("SUBREPORT_DIR", dirReportes);
            parametros.put("USUARIO_IMPRESION", quien);
            parametros.put("LOGO_PATH", dirReportes + LOGO_ARCHIVO);
            parametros.put(JRParameter.REPORT_LOCALE, local);
            JasperPrint jp;
            try {
                jp = JasperFillManager.fillReport(reporte, parametros, cn);
            } catch (net.sf.jasperreports.engine.JRException ex) {
                Throwable causa = ex;
                while (causa.getCause() != null) {
                    causa = causa.getCause();
                }
                throw new Exception("Reporte " + principal + ": " + causa.getMessage(), ex);
            }
            if (jp.getPages() == null || jp.getPages().isEmpty()) {
                continue;
            }
            if (total == null) {
                total = jp;
            } else {
                for (JRPrintPage pagina : jp.getPages()) {
                    total.addPage(pagina);
                }
            }
        }
        if (total == null) {
            throw new IllegalArgumentException("No se encontraron los registros solicitados.");
        }
        return JasperExportManager.exportReportToPdf(total);
    }

    /** Nombre "Apellido, Nombre" del usuario que imprime/genera, o null si no hay sesión. */
    public static String nombreUsuario(Connection cn, Integer idUsuario) {
        if (idUsuario == null) {
            return null;
        }
        try {
            java.sql.PreparedStatement ps = cn.prepareStatement(
                    "SELECT p.apellido || ', ' || p.nombre FROM public.usuarios u JOIN public.personas p ON u.id_persona = p.id_persona WHERE u.id_usuario = ?");
            try {
                ps.setInt(1, idUsuario);
                java.sql.ResultSet rs = ps.executeQuery();
                String n = rs.next() ? rs.getString(1) : null;
                rs.close();
                return n;
            } finally {
                ps.close();
            }
        } catch (java.sql.SQLException e) {
            return null;
        }
    }

    /**
     * Compila el .jrxml solo si el .jasper falta o es mas viejo que el .jrxml.
     * synchronized: evita que dos impresiones simultaneas escriban el mismo .jasper a la vez.
     */
    public static synchronized void compilarSiCambio(String dir, String nombre) throws Exception {
        File fuente = new File(dir + nombre + ".jrxml");
        File compilado = new File(dir + nombre + ".jasper");
        if (!compilado.exists() || (fuente.exists() && fuente.lastModified() > compilado.lastModified())) {
            JasperCompileManager.compileReportToFile(fuente.getAbsolutePath(), compilado.getAbsolutePath());
        }
    }

    /** Reporte principal compilado, desde memoria si el .jasper no cambio desde la ultima vez. */
    private static JasperReport cargarPrincipal(String dir, String nombre) throws Exception {
        compilarSiCambio(dir, nombre);
        String ruta = dir + nombre + ".jasper";
        long fecha = new File(ruta).lastModified();
        Object[] e = CACHE.get(ruta);
        if (e == null || (Long) e[0] != fecha) {
            e = new Object[]{fecha, (JasperReport) JRLoader.loadObjectFromFile(ruta)};
            CACHE.put(ruta, e);
        }
        return (JasperReport) e[1];
    }
}
