<%@page contentType="application/pdf" pageEncoding="UTF-8"%>
<%@page import="java.io.File"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="javax.servlet.ServletOutputStream"%>
<%@page import="net.sf.jasperreports.engine.JasperCompileManager"%>
<%@page import="net.sf.jasperreports.engine.JasperFillManager"%>
<%@page import="net.sf.jasperreports.engine.JasperPrint"%>
<%@page import="net.sf.jasperreports.engine.JasperExportManager"%>
<%@page import="com.mycompany.pro.util.InformeVistaUtil"%>
<%@page import="com.mycompany.pro.util.ComprobanteUtil"%>
<%@include file="../config/conexion.jsp"%>
<%
    // Informe: informeDonaciones
    // Recibe fechaInicio / fechaFin (yyyy-MM-dd, del <input type="date">)
    try {
        // accion=comprobante&ids=1,2,3 -> comprobante individual (o de varios
        // registros seleccionados). No requiere fechas; respeta la restriccion
        // por rol (un Tecnico solo puede imprimir lo que le corresponde).
        if ("comprobante".equals(request.getParameter("accion"))) {
            java.util.List<Integer> pedidos = InformeVistaUtil.parsearIds(request.getParameter("ids"));
            if (pedidos.isEmpty()) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: no se indico ningun registro");
                return;
            }
            StringBuilder csvIds = new StringBuilder();
            for (Integer idPedido : pedidos) {
                if (csvIds.length() > 0) { csvIds.append(","); }
                csvIds.append(idPedido.intValue());
            }
            String csv = csvIds.toString();
            java.util.List<Integer> permitidos = InformeVistaUtil.consultarIds(conexion, "SELECT d.id_donacion FROM public.donaciones d WHERE d.id_donacion IN (" + csv + ") ORDER BY d.id_donacion");
            String errInd = emitirComprobantes(response, application, conexion, "comprobanteDonacion",
                    new String[]{"comprobanteDonacionDetalle"}, "ID_DONACION", permitidos, "comprobante_donacion", (Integer) session.getAttribute("idUsuario"));
            if (errInd != null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print(errInd);
            }
            return;
        }

        String fechaDesde = request.getParameter("fechaInicio");
        String fechaHasta = request.getParameter("fechaFin");

        if (fechaDesde == null || fechaDesde.trim().isEmpty()
                || fechaHasta == null || fechaHasta.trim().isEmpty()) {
            response.setContentType("text/plain;charset=UTF-8");
            out.print("error: debe indicar Fecha Inicio y Fecha Fin");
            return;
        }

        // accion=datos   -> fragmento HTML para la pantalla principal
        //                   (filtros aplicados, totales, resumen y tabla).
        // accion=detalle -> PDF con un comprobante por CADA registro filtrado
        //                   ("Imprimir detallado"): incluye todo lo registrado.
        // Ambas usan EXACTAMENTE los mismos filtros y restricciones de rol
        // que el PDF general, asi los tres muestran los mismos registros.
        String accion = request.getParameter("accion");
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Donaciones Recibidas")
                .columnas("d.id_donacion, d.nro_comprobante, d.fecha_donacion, n.nombre AS donante, "
                        + "(SELECT COUNT(*) FROM public.donaciones_detalle x WHERE x.id_donacion = d.id_donacion) AS articulos, "
                        + "(SELECT COALESCE(SUM(x.cantidad), 0) FROM public.donaciones_detalle x WHERE x.id_donacion = d.id_donacion) AS unidades",
                        "ID", "N\u00b0 Comprobante", "Fecha", "Donante", "Art\u00edculos", "Unidades recibidas")
                .origen("FROM public.donaciones d "
                        + "JOIN public.donantes n ON d.id_donante = n.id_donante "
                        + "WHERE d.estado = 'Registrada' AND d.fecha_donacion BETWEEN CAST(? AS date) AND CAST(? AS date)")
                .idRegistro("d.id_donacion")
                .orden("d.fecha_donacion, d.id_donacion")
                .metrica("Donaciones recibidas", "COUNT(*)", "N", "fa-hand-holding-heart", "success")
                .metrica("Donantes distintos", "COUNT(DISTINCT d.id_donante)", "N", "fa-users", "info")
                .metrica("Art\u00edculos registrados", "COALESCE(SUM((SELECT COUNT(*) FROM public.donaciones_detalle x WHERE x.id_donacion = d.id_donacion)), 0)", "N", "fa-boxes", "primary")
                .metrica("Unidades recibidas", "COALESCE(SUM((SELECT SUM(x.cantidad) FROM public.donaciones_detalle x WHERE x.id_donacion = d.id_donacion)), 0)", "M", "fa-cubes", "warning")
                .grupo("Por donante", "n.nombre", null)
                .filtro("Tipo de informe", "General");

            if ("datos".equals(accion)) {
                response.setContentType("text/html;charset=UTF-8");
                try {
                    out.print(InformeVistaUtil.pantalla(conexion, inf, fechaDesde, fechaHasta));
                } catch (Exception exVista) {
                    out.print(InformeVistaUtil.errorHtml(exVista));
                    exVista.printStackTrace();
                }
                return;
            }
            java.util.List<Integer> idsFiltrados = InformeVistaUtil.listarIds(conexion, inf, fechaDesde, fechaHasta);
            String errDet = emitirComprobantes(response, application, conexion, "comprobanteDonacion",
                    new String[]{"comprobanteDonacionDetalle"}, "ID_DONACION", idsFiltrados, "comprobante_donacion_detallado", (Integer) session.getAttribute("idUsuario"));
            if (errDet != null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print(errDet);
            }
            return;
        }

        // El .jasper compilado se busca primero; si no existe, se compila
        // al vuelo desde el .jrxml (comodo en desarrollo).
        String rutaJrxml = application.getRealPath("reportes/informeDonaciones.jrxml");
        String rutaJasper = application.getRealPath("reportes/informeDonaciones.jasper");

        File archivoJasper = new File(rutaJasper);
        // Recompila si falta el .jasper o si el .jrxml se modificó después.
        if (!archivoJasper.exists() || new File(rutaJrxml).lastModified() > archivoJasper.lastModified()) {
            JasperCompileManager.compileReportToFile(rutaJrxml, rutaJasper);
        }

        Map parametros = new HashMap();
        parametros.put("DESDE", fechaDesde);
        parametros.put("HASTA", fechaHasta);
        parametros.put("USUARIO_GENERA", ComprobanteUtil.nombreUsuario(conexion, (Integer) session.getAttribute("idUsuario")));
        parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));

        JasperPrint jasperPrint = JasperFillManager.fillReport(rutaJasper, parametros, conexion);
        byte[] bytes = JasperExportManager.exportReportToPdf(jasperPrint);

        response.setContentType("application/pdf");
        response.setContentLength(bytes.length);
        response.setHeader("Content-Disposition", "inline; filename=informe_donaciones.pdf");

        ServletOutputStream salida = response.getOutputStream();
        salida.write(bytes, 0, bytes.length);
        salida.flush();
        salida.close();

    } catch (Exception ex) {
        response.setContentType("text/plain;charset=UTF-8");
        out.print("error al generar el informe: " + mensajeError(ex));
        ex.printStackTrace();
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    /** Genera un PDF con un comprobante por cada id. Devuelve un mensaje de error, o null si el PDF ya se envio. */
    private String emitirComprobantes(javax.servlet.http.HttpServletResponse resp, javax.servlet.ServletContext ctx,
            java.sql.Connection cn, String reporte, String[] subreportes, String paramId,
            java.util.List<Integer> ids, String nombreArchivo, Integer idUsuario) throws Exception {
        if (ids == null || ids.isEmpty()) {
            return "No hay registros para imprimir.";
        }
        if (ids.size() > ComprobanteUtil.MAX_COMPROBANTES) {
            return "El informe detallado admite hasta " + ComprobanteUtil.MAX_COMPROBANTES
                    + " registros (se encontraron " + ids.size() + "). Acote el periodo o los filtros.";
        }
        byte[] bytes = ComprobanteUtil.generar(cn, ctx.getRealPath("reportes"), reporte, subreportes, paramId, ids, idUsuario);
        resp.setContentType("application/pdf");
        resp.setContentLength(bytes.length);
        resp.setHeader("Content-Disposition", "inline; filename=" + nombreArchivo + ".pdf");
        javax.servlet.ServletOutputStream salida = resp.getOutputStream();
        salida.write(bytes, 0, bytes.length);
        salida.flush();
        salida.close();
        return null;
    }
%>
