<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%><%@page import="com.mycompany.pro.util.InformeVistaUtil"%><%@page import="com.mycompany.pro.util.InformeUtil"%><%@page import="com.mycompany.pro.util.ComprobanteUtil"%><%@include file="../config/conexion.jsp"%><%@include file="../config/informeComun.jsp"%><%
    // Informe de Material para Técnicos
    //  accion=datos   -> indicadores + tabla en pantalla
    //  (sin accion)   -> PDF general del período con los mismos filtros
    //  accion=combos  -> opciones de los filtros (JSON)
    //  accion=detalle / comprobante -> comprobantes detallados en PDF
    String rolInf = (String) session.getAttribute("nombreRol");
    boolean esAdminInf = "Administrador".equals(rolInf), esEncInf = "Encargado de depósito".equals(rolInf), esTecInf = "Técnico".equals(rolInf);
    Integer idUsuarioInf = (Integer) session.getAttribute("idUsuario");
    try {
        if (!(esAdminInf || esEncInf || esTecInf) || idUsuarioInf == null) {
            response.setContentType("text/plain;charset=UTF-8");
            out.print("error: no tiene permiso para este informe");
            return;
        }
        String accion = request.getParameter("accion");
        if ("combos".equals(accion)) {
            response.setContentType("application/json;charset=UTF-8");
            org.json.JSONObject jc = new org.json.JSONObject();
            {
                StringBuilder sbc = new StringBuilder("<option value=''>-- Todos --</option>");
                try (java.sql.ResultSet rc = conexion.prepareStatement("SELECT DISTINCT u.id_usuario, COALESCE(p.apellido || ', ' || p.nombre, u.login) FROM public.solicitudes_material s JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona ORDER BY 2").executeQuery()) {
                    while (rc.next()) sbc.append("<option value='").append(rc.getInt(1)).append("'>").append(h(rc.getString(2))).append("</option>");
                }
                jc.put("idUsuario", sbc.toString());
            }
            out.print(jc.toString());
            return;
        }
        if ("comprobante".equals(accion)) {
            java.util.List<Integer> pedidos = InformeVistaUtil.parsearIds(request.getParameter("ids"));
            StringBuilder csv = new StringBuilder();
            for (Integer idp : pedidos) { if (csv.length() > 0) csv.append(","); csv.append(idp.intValue()); }
            if (csv.length() == 0) { response.setContentType("text/plain;charset=UTF-8"); out.print("error: no se indico ningun registro"); return; }
            java.util.List<Integer> permitidos = InformeVistaUtil.consultarIds(conexion, "SELECT s.id_solicitud " + "FROM public.solicitudes_material s JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona LEFT JOIN public.v_solicitud_stock vs ON vs.id_solicitud = s.id_solicitud" + " WHERE s.id_solicitud IN (" + csv + ")" + (esTecInf ? " AND s.id_usuario_solicita = " + idUsuarioInf + "" : "") + " ORDER BY s.id_solicitud");
            String errC = enviarComprobantesInf(response, application, conexion, permitidos, idUsuarioInf, "comprobante_material");
            if (errC != null) { response.setContentType("text/plain;charset=UTF-8"); out.print(errC); }
            return;
        }
        String fechaDesde = request.getParameter("fechaInicio");
        String fechaHasta = request.getParameter("fechaFin");
        if (fechaDesde == null || fechaDesde.trim().isEmpty() || fechaHasta == null || fechaHasta.trim().isEmpty()) {
            response.setContentType("text/plain;charset=UTF-8");
            out.print("error: debe indicar Fecha Inicio y Fecha Fin");
            return;
        }
        java.util.List<String> condiciones = new java.util.ArrayList<String>();
        condiciones.add(InformeUtil.condicionExacta("s.estado", request.getParameter("estado"), new java.util.HashSet<String>(java.util.Arrays.asList("Pendiente", "En espera", "Entregada", "Entregada parcial", "Rechazada"))));
        condiciones.add(InformeUtil.condicionExacta("s.prioridad", request.getParameter("prioridad"), new java.util.HashSet<String>(java.util.Arrays.asList("Critica", "Alta", "Media", "Baja", "Urgente", "Normal"))));
        condiciones.add(InformeUtil.condicionExacta("s.tipo_orden", request.getParameter("tipoOrden"), new java.util.HashSet<String>(java.util.Arrays.asList("T", "M"))));
        if (!esTecInf) condiciones.add(InformeUtil.condicionEntero("s.id_usuario_solicita", request.getParameter("idUsuario")));
        // El técnico solo ve lo suyo, sin importar lo que se envíe desde el formulario
        if (esTecInf) condiciones.add("s.id_usuario_solicita = " + idUsuarioInf + "");
        String filtros = InformeUtil.combinar(condiciones.toArray(new String[0]));
        if (filtros == null || filtros.trim().isEmpty()) filtros = "1=1";
        String origen = "FROM public.solicitudes_material s JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona LEFT JOIN public.v_solicitud_stock vs ON vs.id_solicitud = s.id_solicitud WHERE s.fecha_solicitud::date BETWEEN CAST(? AS date) AND CAST(? AS date)" + " AND (" + filtros + ")";
        String[][] metricas = {
            {"Pedidos", "COUNT(*)", "N", "fa-toolbox", "info"},
            {"Pendientes", "COUNT(*) FILTER (WHERE s.estado = 'Pendiente')", "N", "fa-hourglass-half", "warning"},
            {"En espera de stock", "COUNT(*) FILTER (WHERE s.estado = 'En espera')", "N", "fa-box-open", "danger"},
            {"Entregados", "COUNT(*) FILTER (WHERE s.estado = 'Entregada')", "N", "fa-check-circle", "success"},
            {"Entregados en parte", "COUNT(*) FILTER (WHERE s.estado = 'Entregada parcial')", "N", "fa-adjust", "primary"},
            {"Rechazados", "COUNT(*) FILTER (WHERE s.estado = 'Rechazada')", "N", "fa-ban", "secondary"},
            {"Urgentes o críticos", "COUNT(*) FILTER (WHERE s.prioridad IN ('Critica', 'Urgente'))", "N", "fa-exclamation-triangle", "danger"},
            {"Días promedio hasta la entrega", "AVG(EXTRACT(EPOCH FROM (s.fecha_entrega - s.fecha_solicitud)) / 86400.0) FILTER (WHERE s.estado LIKE 'Entregada%')", "D", "fa-stopwatch", "info"},
            {"Devoluciones de estas órdenes", "(SELECT count(*) FROM public.devoluciones_material dv WHERE (dv.tipo_orden || '-' || dv.id_orden) = ANY (array_agg(s.tipo_orden || '-' || s.id_orden)))", "N", "fa-undo", "secondary"}
        };
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Material para Técnicos")
                .columnas("s.numero AS numero, to_char(s.fecha_solicitud, 'DD/MM/YYYY HH24:MI') AS fecha, CASE WHEN s.tipo_orden = 'T' THEN COALESCE((SELECT 'Ticket ' || t.numero_ticket FROM public.ticket t WHERE t.id_ticket = s.id_orden), 'Ticket') ELSE COALESCE((SELECT 'Mant. ' || m.numero_mantenimiento FROM public.mantenimientos_preventivos m WHERE m.id_mantenimiento = s.id_orden), 'Mant.') END AS orden, COALESCE(p.apellido || ', ' || p.nombre, u.login) AS tecnico, CASE s.prioridad WHEN 'Critica' THEN 'Crítica' ELSE s.prioridad END AS prioridad, CASE WHEN s.estado IN ('Pendiente', 'En espera') AND vs.hay_stock THEN s.estado || ' (hay stock)' ELSE s.estado END AS estado, (SELECT string_agg(COALESCE(cr.nombre, ci.nombre) || ': ' || replace(rtrim(to_char(d.cantidad_solicitada, 'FM999999990.99'), '.'), '.', ',') || ' / ' || replace(rtrim(to_char(d.cantidad_entregada, 'FM999999990.99'), '.'), '.', ','), ', ' ORDER BY d.id_detalle) FROM public.solicitudes_material_detalle d LEFT JOIN public.catalogo_repuestos cr ON d.tipo_articulo = 'R' AND cr.id_repuesto = d.id_articulo LEFT JOIN public.catalogo_insumos ci ON d.tipo_articulo = 'I' AND ci.id_insumo = d.id_articulo WHERE d.id_solicitud = s.id_solicitud) AS articulos, replace(rtrim(to_char(round((EXTRACT(EPOCH FROM (COALESCE(s.fecha_entrega, now()) - s.fecha_solicitud)) / 86400.0)::numeric, 1), 'FM999999990.99'), '.'), '.', ',') AS dias, COALESCE(s.motivo_rechazo, s.observacion_entrega, '') AS comentario",
                        "N° Pedido", "Fecha", "Orden", "Técnico", "Urgencia", "Estado", "Artículos (pedido / entregado)", "Días", "Comentario del depósito")
                .origen(origen)
                .orden("s.fecha_solicitud, s.id_solicitud")
                .idRegistro("s.id_solicitud");
            { String v_estado = request.getParameter("estado"); inf.filtro("Estado", v_estado == null || v_estado.isEmpty() ? null : ("Pendiente".equals(v_estado) ? "Pendiente" : "En espera".equals(v_estado) ? "En espera" : "Entregada".equals(v_estado) ? "Entregada" : "Entregada parcial".equals(v_estado) ? "Entregada parcial" : "Rechazada".equals(v_estado) ? "Rechazada" : v_estado)); }
            { String v_prioridad = request.getParameter("prioridad"); inf.filtro("Urgencia", v_prioridad == null || v_prioridad.isEmpty() ? null : ("Critica".equals(v_prioridad) ? "Crítica" : "Alta".equals(v_prioridad) ? "Alta" : "Media".equals(v_prioridad) ? "Media" : "Baja".equals(v_prioridad) ? "Baja" : "Urgente".equals(v_prioridad) ? "Urgente" : "Normal".equals(v_prioridad) ? "Normal" : v_prioridad)); }
            { String v_tipoOrden = request.getParameter("tipoOrden"); inf.filtro("Orden", v_tipoOrden == null || v_tipoOrden.isEmpty() ? null : ("T".equals(v_tipoOrden) ? "Tickets" : "M".equals(v_tipoOrden) ? "Mantenimientos" : v_tipoOrden)); }
            if (!esTecInf) inf.filtro("Técnico", InformeVistaUtil.etiqueta(conexion, "SELECT COALESCE(p.apellido || ', ' || p.nombre, u.login) FROM public.usuarios u LEFT JOIN public.personas p ON p.id_persona = u.id_persona WHERE u.id_usuario = ?", request.getParameter("idUsuario")));
            if (esTecInf) inf.filtro("Restringido a", "Solo sus propios pedidos");
            if ("datos".equals(accion)) {
                response.setContentType("text/html;charset=UTF-8");
                try {
                    out.print(metricasHtml(conexion, origen, metricas, fechaDesde, fechaHasta));
                    out.print(InformeVistaUtil.pantalla(conexion, inf, fechaDesde, fechaHasta));
                } catch (Exception exVista) {
                    out.print(InformeVistaUtil.errorHtml(exVista));
                    exVista.printStackTrace();
                }
                return;
            }
            String errD = enviarComprobantesInf(response, application, conexion, InformeVistaUtil.listarIds(conexion, inf, fechaDesde, fechaHasta), idUsuarioInf, "comprobante_material_detallado");
            if (errD != null) { response.setContentType("text/plain;charset=UTF-8"); out.print(errD); }
            return;
        }
        // PDF general
        java.util.Map<String, Object> par = new java.util.HashMap<String, Object>();
        par.put("DESDE", fechaDesde);
        par.put("HASTA", fechaHasta);
        par.put("FILTROS", filtros);
        par.put("USUARIO_GENERA", ComprobanteUtil.nombreUsuario(conexion, idUsuarioInf));
        par.put("RESUMEN", resumenInforme(conexion, origen, metricas, fechaDesde, fechaHasta));
        enviarInformePdf(response, application, conexion, "informeMaterial", par, "informeMaterial");
    } catch (Exception ex) {
        response.setContentType("text/plain;charset=UTF-8");
        out.print("error al generar el informe: " + mensajeError(ex));
        ex.printStackTrace();
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    /** PDF con un comprobante por cada registro. Devuelve el mensaje de error, o null si el PDF ya se envió. */
    private String enviarComprobantesInf(javax.servlet.http.HttpServletResponse resp, javax.servlet.ServletContext ctx, java.sql.Connection cn,
                                       java.util.List<Integer> ids, Integer idUsuario, String archivo) throws Exception {
        if (ids == null || ids.isEmpty()) return "No hay registros para imprimir.";
        if (ids.size() > ComprobanteUtil.MAX_COMPROBANTES)
            return "El informe detallado admite hasta " + ComprobanteUtil.MAX_COMPROBANTES + " registros (se encontraron " + ids.size() + "). Acote el periodo o los filtros.";
        byte[] bytes = ComprobanteUtil.generar(cn, ctx.getRealPath("reportes"), "comprobanteEntregaMaterial", new String[]{"comprobanteEntregaMaterialDetalle"}, "ID_SOLICITUD", ids, idUsuario);
        resp.setContentType("application/pdf");
        resp.setContentLength(bytes.length);
        resp.setHeader("Content-Disposition", "inline; filename=" + archivo + ".pdf");
        javax.servlet.ServletOutputStream so = resp.getOutputStream();
        so.write(bytes, 0, bytes.length);
        so.flush();
        so.close();
        return null;
    }
%>
