<%@page contentType="application/pdf" pageEncoding="UTF-8"%>
<%@page import="java.io.File"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.HashSet"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.Set"%>
<%@page import="javax.servlet.ServletOutputStream"%>
<%@page import="net.sf.jasperreports.engine.JasperCompileManager"%>
<%@page import="net.sf.jasperreports.engine.JasperFillManager"%>
<%@page import="net.sf.jasperreports.engine.JasperPrint"%>
<%@page import="net.sf.jasperreports.engine.JasperExportManager"%>
<%@page import="com.mycompany.pro.util.InformeVistaUtil"%>
<%@page import="com.mycompany.pro.util.ComprobanteUtil"%>
<%@page import="com.mycompany.pro.util.InformeUtil"%>
<%@include file="../config/conexion.jsp"%><%@include file="../config/informeComun.jsp"%>
<%
    // Informe: informeInventario (Control de Inventario -> Solicitudes de
    // Reposicion generadas). Recibe fechaInicio / fechaFin (yyyy-MM-dd).
    //
    // modo = "general"       -> solo filtra por rango de fechas (comportamiento original)
    // modo = "personalizado" -> ademas permite filtrar por estado, solicitante
    //                           y numero de solicitud (igual que informeMantenimiento)
    //
    // Acceso restringido: solo el rol Administrador puede ver este informe,
    // igual que el modulo "Control de Inventario".
    if (!"Administrador".equals((String) session.getAttribute("nombreRol")) && !"Encargado de depósito".equals((String) session.getAttribute("nombreRol"))) {
        response.setContentType("text/plain;charset=UTF-8");
        response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
        out.print("error: acceso restringido al Administrador");
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
        return;
    }
    try {
        // accion=combos -> devuelve el combo de Solicitantes para el
        // formulario de filtro personalizado.
        if ("combos".equals(request.getParameter("accion"))) {
            response.setContentType("text/html;charset=UTF-8");
            out.print("<SOLICITANTES>");
            out.print("<option value=''>-- Todos --</option>");
            java.sql.PreparedStatement psSol = conexion.prepareStatement(
                "SELECT DISTINCT u.id_usuario, p.apellido, p.nombre FROM public.solicitudes_compra s " +
                "JOIN public.usuarios u ON s.id_usuario_solicita = u.id_usuario " +
                "JOIN public.personas p ON u.id_persona = p.id_persona " +
                "ORDER BY p.apellido, p.nombre");
            java.sql.ResultSet rsSol = psSol.executeQuery();
            while (rsSol.next()) {
                out.print("<option value='" + rsSol.getInt("id_usuario") + "'>" +
                        rsSol.getString("apellido") + ", " + rsSol.getString("nombre") + "</option>");
            }
            rsSol.close();
            psSol.close();
            out.print("</SOLICITANTES>");
            return;
        }

        // accion=comprobante&ids=1,2,3 -> comprobante individual (o de varios
        // registros seleccionados) de Solicitud de Reposicion.
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
            java.util.List<Integer> permitidos = InformeVistaUtil.consultarIds(conexion, "SELECT s.id_solicitud FROM public.solicitudes_compra s WHERE s.id_solicitud IN (" + csv + ") ORDER BY s.id_solicitud");
            String errInd = emitirComprobantes(response, application, conexion, "comprobanteSolicitudReposicion",
                    new String[]{"comprobanteSolicitudReposicionDetalle"}, "ID_SOLICITUD", permitidos, "comprobante_solicitud_reposicion", (Integer) session.getAttribute("idUsuario"));
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

        String modo = request.getParameter("modo");
        boolean personalizado = "personalizado".equals(modo);

        java.util.List<String> condiciones = new java.util.ArrayList<String>();

        if (personalizado) {
            Set<String> estadosPermitidos = new HashSet<String>();
            estadosPermitidos.add("Generada");
            estadosPermitidos.add("Enviada");
            estadosPermitidos.add("Recibida parcial");
            estadosPermitidos.add("Cancelada");
            estadosPermitidos.add("Recibida");
            condiciones.add(InformeUtil.condicionExacta("s.estado", request.getParameter("estado"), estadosPermitidos));

            condiciones.add(InformeUtil.condicionEntero("s.id_usuario_solicita", request.getParameter("idSolicitante")));
            condiciones.add(InformeUtil.condicionTexto("s.numero_solicitud", request.getParameter("numeroSolicitud")));
        }

        String filtros = InformeUtil.combinar(condiciones.toArray(new String[0]));

        // accion=datos   -> fragmento HTML para la pantalla principal
        //                   (filtros aplicados, totales, resumen y tabla).
        // accion=detalle -> PDF con un comprobante por CADA registro filtrado
        //                   ("Imprimir detallado"): incluye todo lo registrado.
        // Ambas usan EXACTAMENTE los mismos filtros que el PDF general, asi
        // los tres muestran los mismos registros.
        String accion = request.getParameter("accion");
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            String filtrosSql = (filtros == null || filtros.trim().isEmpty()) ? "1=1" : filtros;
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Pedidos de Reposición")
                .columnas("s.numero_solicitud, s.fecha_solicitud, s.estado, "
                        + "COALESCE(p.apellido || ', ' || p.nombre, '-') AS solicitante, "
                        + "(SELECT COUNT(*) FROM public.solicitudes_compra_detalle x WHERE x.id_solicitud = s.id_solicitud) AS items, "
                        + "(SELECT COUNT(*) FROM public.solicitudes_compra_detalle x WHERE x.id_solicitud = s.id_solicitud "
                        + "AND x.cantidad_recibida < x.cantidad_solicitada) AS pendientes",
                        "N\u00b0 Solicitud", "Fecha", "Estado", "Solicitante", "Art\u00edculos", "Items pendientes")
                .origen("FROM public.solicitudes_compra s "
                        + "LEFT JOIN public.usuarios u ON s.id_usuario_solicita = u.id_usuario "
                        + "LEFT JOIN public.personas p ON u.id_persona = p.id_persona "
                        + "WHERE s.fecha_solicitud::date BETWEEN CAST(? AS date) AND CAST(? AS date) "
                        + "AND (" + filtrosSql + ")")
                .idRegistro("s.id_solicitud")
                .orden("s.fecha_solicitud, s.id_solicitud")
                .metrica("Solicitudes generadas", "COUNT(*)", "N", "fa-boxes", "info")
                .metrica("Generadas", "COUNT(*) FILTER (WHERE s.estado = 'Generada')", "N", "fa-file-alt", "warning")
                .metrica("Enviadas", "COUNT(*) FILTER (WHERE s.estado = 'Enviada')", "N", "fa-paper-plane", "primary")
                .metrica("Recibidas parcial", "COUNT(*) FILTER (WHERE s.estado = 'Recibida parcial')", "N", "fa-truck-loading", "secondary")
                .metrica("Recibidas", "COUNT(*) FILTER (WHERE s.estado = 'Recibida')", "N", "fa-check-circle", "success")
                .metrica("Canceladas", "COUNT(*) FILTER (WHERE s.estado = 'Cancelada')", "N", "fa-ban", "danger")
                .grupo("Por estado", "s.estado", null)
                .grupo("Por solicitante", "COALESCE(p.apellido || ', ' || p.nombre, '-')", null)
                .filtro("Tipo de informe", personalizado ? "Personalizado" : "General");
            if (personalizado) {
                inf.filtro("Estado", request.getParameter("estado"))
                   .filtro("Solicitante", InformeVistaUtil.etiqueta(conexion,
                            "SELECT p.apellido || ', ' || p.nombre FROM public.usuarios u LEFT JOIN public.personas p ON u.id_persona = p.id_persona WHERE u.id_usuario = ?", request.getParameter("idSolicitante")))
                   .filtro("N\u00b0 Solicitud", request.getParameter("numeroSolicitud"));
            }

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
            String errDet = emitirComprobantes(response, application, conexion, "comprobanteSolicitudReposicion",
                    new String[]{"comprobanteSolicitudReposicionDetalle"}, "ID_SOLICITUD", idsFiltrados, "comprobante_inventario_detallado", (Integer) session.getAttribute("idUsuario"));
            if (errDet != null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print(errDet);
            }
            return;
        }

        // El .jasper compilado se busca primero; si no existe, se compila
        // al vuelo desde el .jrxml (comodo en desarrollo).
        Map parametros = new HashMap();
        parametros.put("DESDE", fechaDesde);
        parametros.put("HASTA", fechaHasta);
        parametros.put("FILTROS", filtros);
        parametros.put("USUARIO_GENERA", ComprobanteUtil.nombreUsuario(conexion, (Integer) session.getAttribute("idUsuario")));
        // Usa el reporte ya compilado en memoria (más rápido)
        enviarInformePdf(response, application, conexion, "informeInventario", parametros, "informe_inventario");

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
                    + " registros (se encontraron " + ids.size() + "). Acote el periodo.";
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
