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
    // Informe: informeOrdenesCorrectivas
    // Recibe fechaInicio / fechaFin (yyyy-MM-dd, del <input type="date">)
    //
    // modo = "general"      -> solo filtra por rango de fechas (comportamiento original)
    // modo = "personalizado" -> ademas permite filtrar por estado, prioridad,
    //                           tecnico, numero de ticket, equipo y diagnostico
    //
    // Los Tecnicos SIEMPRE ven unicamente las ordenes que ellos cerraron:
    // se fuerza id_tecnico_asignado = idTecnico de la sesion sin importar
    // lo que se haya enviado desde el formulario.
    try {
        // accion=combos -> devuelve el combo de Tecnicos (HTML de <option>)
        // para el formulario de filtro personalizado. Solo lo usa el
        // Administrador; a un Tecnico no se le muestra ese filtro.
        if ("combos".equals(request.getParameter("accion"))) {
            response.setContentType("text/html;charset=UTF-8");
            out.print("<option value=''>-- Todos --</option>");
            java.sql.PreparedStatement psTec = conexion.prepareStatement(
                "SELECT tc.id_tecnico, p.apellido, p.nombre FROM public.tecnicos tc " +
                "LEFT JOIN public.usuarios u ON tc.id_usuario = u.id_usuario " +
                "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                "ORDER BY p.apellido, p.nombre");
            java.sql.ResultSet rsTec = psTec.executeQuery();
            while (rsTec.next()) {
                out.print("<option value='" + rsTec.getInt("id_tecnico") + "'>" +
                        rsTec.getString("apellido") + ", " + rsTec.getString("nombre") + "</option>");
            }
            rsTec.close();
            psTec.close();
            return;
        }

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
            String condRol = "1=1";
            if ("Técnico".equals((String) session.getAttribute("nombreRol"))) {
                Integer idTecSes = (Integer) session.getAttribute("idTecnico");
                if (idTecSes == null) {
                    response.setContentType("text/plain;charset=UTF-8");
                    out.print("error: la sesion no tiene un tecnico asociado");
                    return;
                }
                condRol = "t.id_tecnico_asignado = " + idTecSes + " AND t.estado IN ('Resuelto','Cerrado')";
            }
            java.util.List<Integer> permitidos = InformeVistaUtil.consultarIds(conexion, "SELECT t.id_ticket FROM public.ticket t WHERE t.id_ticket IN (" + csv + ") AND t.estado IN ('Resuelto','Cerrado') AND (" + condRol + ") ORDER BY t.id_ticket");
            String errInd = emitirComprobantes(response, application, conexion, "comprobanteTicket",
                    new String[]{"comprobanteTicketMateriales", "comprobanteTicketHistorial", "comprobanteTicketAdjuntos"}, "ID_TICKET", permitidos, "comprobante_ticket", (Integer) session.getAttribute("idUsuario"));
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

        String nombreRolSesion = (String) session.getAttribute("nombreRol");
        Integer idTecnicoSesion = (Integer) session.getAttribute("idTecnico");
        boolean esTecnico = "Técnico".equals(nombreRolSesion);

        java.util.List<String> condiciones = new java.util.ArrayList<String>();

        if (personalizado) {
            Set<String> estadosPermitidos = new HashSet<String>();
            estadosPermitidos.add("Resuelto");
            estadosPermitidos.add("Cerrado");
            condiciones.add(InformeUtil.condicionExacta("t.estado", request.getParameter("estado"), estadosPermitidos));

            Set<String> prioridadesPermitidas = new HashSet<String>();
            prioridadesPermitidas.add("Baja");
            prioridadesPermitidas.add("Media");
            prioridadesPermitidas.add("Alta");
            prioridadesPermitidas.add("Critica");
            condiciones.add(InformeUtil.condicionExacta("t.prioridad", request.getParameter("prioridad"), prioridadesPermitidas));

            condiciones.add(InformeUtil.condicionTexto("t.numero_ticket", request.getParameter("numeroTicket")));
            condiciones.add(InformeUtil.condicionTexto("t.diagnostico", request.getParameter("diagnostico")));

            String equipoTexto = InformeUtil.limpiar(request.getParameter("equipo"));
            if (equipoTexto != null) {
                String cond1 = InformeUtil.condicionTexto("e.modelo", equipoTexto);
                String cond2 = InformeUtil.condicionTexto("e.codigo_patrimonial", equipoTexto);
                condiciones.add("(" + cond1 + " OR " + cond2 + ")");
            }

            // El filtro de tecnico solo se respeta si el usuario NO es Tecnico
            // (un Tecnico jamas puede elegir ver ordenes de otro tecnico).
            if (!esTecnico) {
                condiciones.add(InformeUtil.condicionEntero("t.id_tecnico_asignado", request.getParameter("idTecnico")));
            }
        }

        // Restriccion obligatoria: un Tecnico solo ve lo que el mismo cerro.
        if (esTecnico) {
            if (idTecnicoSesion == null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: la sesion no tiene un tecnico asociado");
                return;
            }
            condiciones.add("t.id_tecnico_asignado = " + idTecnicoSesion);
            condiciones.add("t.estado IN ('Resuelto','Cerrado')");
        }

        String filtros = InformeUtil.combinar(condiciones.toArray(new String[0]));

        // accion=datos   -> fragmento HTML para la pantalla principal
        //                   (filtros aplicados, totales, resumen y tabla).
        // accion=detalle -> PDF con un comprobante por CADA registro filtrado
        //                   ("Imprimir detallado"): incluye todo lo registrado.
        // Ambas usan EXACTAMENTE los mismos filtros y restricciones de rol
        // que el PDF general, asi los tres muestran los mismos registros.
        String filtrosSqlInf = (filtros == null || filtros.trim().isEmpty()) ? "1=1" : filtros;
        String filtrosSql = filtrosSqlInf;
        String origenInf = "FROM public.ticket t "
                            + "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo "
                            + "LEFT JOIN public.tecnicos tc ON t.id_tecnico_asignado = tc.id_tecnico "
                            + "LEFT JOIN public.usuarios u ON tc.id_usuario = u.id_usuario "
                            + "LEFT JOIN public.personas p ON u.id_persona = p.id_persona "
                            + "LEFT JOIN public.salas s ON t.id_sala = s.id_sala "
                            + "LEFT JOIN public.usuarios us ON t.id_usuario_solicita = us.id_usuario "
                            + "LEFT JOIN public.personas ps ON us.id_persona = ps.id_persona "
                            + "LEFT JOIN LATERAL (SELECT mv.numero FROM public.movimientos_equipos mv WHERE mv.tipo = 'BAJA' AND mv.origen = 'Ticket ' || t.numero_ticket ORDER BY mv.id_movimiento DESC LIMIT 1) bj ON true "
                            + "WHERE t.estado IN ('Resuelto','Cerrado') "
                            + "AND t.fecha_fin::date BETWEEN CAST(? AS date) AND CAST(? AS date) "
                            + "AND (" + filtrosSql + ")";
        String[][] metricasInf = {
            {"Total de órdenes", "COUNT(*)", "N", "fa-clipboard-list", "info"},
            {"Resueltas", "COUNT(*) FILTER (WHERE t.estado = 'Resuelto')", "N", "fa-check-circle", "success"},
            {"Cerradas", "COUNT(*) FILTER (WHERE t.estado = 'Cerrado')", "N", "fa-lock", "secondary"},
            {"Reparados", "COUNT(*) FILTER (WHERE bj.numero IS NULL)", "N", "fa-tools", "primary"},
            {"No reparables", "COUNT(*) FILTER (WHERE bj.numero IS NOT NULL)", "N", "fa-power-off", "danger"},
            {"Con repuesto o insumo", "COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM public.ticket_repuesto tr WHERE tr.id_ticket = t.id_ticket))", "N", "fa-cogs", "warning"},
            {"Tiempo promedio (min)", "AVG(t.tiempo_resolucion)", "D", "fa-stopwatch", "info"}
        };
        String accion = request.getParameter("accion");
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Órdenes de Trabajo Correctivas")
                .columnas("t.numero_ticket AS numero_ticket, t.estado AS estado, CASE t.prioridad WHEN 'Critica' THEN 'Crítica' ELSE t.prioridad END AS prioridad, COALESCE(e.modelo || ' (' || e.codigo_patrimonial || ')', 'N/D') AS equipo, COALESCE(p.apellido || ', ' || p.nombre, 'Sin asignar') AS tecnico, to_char(t.fecha_fin, 'DD/MM/YYYY HH24:MI') AS fecha_fin, round(t.tiempo_resolucion)::int AS tiempo, COALESCE((SELECT string_agg(cs.nombre_servicio || CASE WHEN COALESCE(ts.detalle, '') <> '' THEN ' (' || ts.detalle || ')' ELSE '' END, ', ' ORDER BY ts.id) FROM public.ticket_servicios ts JOIN public.catalogo_servicios cs ON cs.id_servicio = ts.id_servicio WHERE ts.id_ticket = t.id_ticket), '—') AS servicios, COALESCE((SELECT string_agg(COALESCE(cr.nombre, ci.nombre) || ' x' || replace(rtrim(to_char(tr.cantidad, 'FM999999990.99'), '.'), '.', ','), ', ' ORDER BY tr.id) FROM public.ticket_repuesto tr LEFT JOIN public.catalogo_repuestos cr ON cr.id_repuesto = tr.id_repuesto LEFT JOIN public.catalogo_insumos ci ON ci.id_insumo = tr.id_insumo WHERE tr.id_ticket = t.id_ticket), '—') AS material, CASE WHEN bj.numero IS NOT NULL THEN 'No reparable (' || bj.numero || ')' ELSE 'Reparado' END AS resultado",
                        "N° Ticket", "Estado", "Urgencia", "Equipo", "Técnico", "Fecha fin", "Tiempo (min)", "Servicios realizados", "Material usado", "Resultado")
                .origen(origenInf)
                .idRegistro("t.id_ticket")
                .orden("t.fecha_fin")
                .filtro("Tipo de informe", personalizado ? "Personalizado" : "General");
            if (personalizado) {
                inf.filtro("Estado", request.getParameter("estado"))
                   .filtro("Prioridad", request.getParameter("prioridad"))
                   .filtro("N\u00b0 Ticket", request.getParameter("numeroTicket"))
                   .filtro("Equipo contiene", request.getParameter("equipo"))
                   .filtro("Diagn\u00f3stico contiene", request.getParameter("diagnostico"));
                if (!esTecnico) {
                    inf.filtro("T\u00e9cnico", InformeVistaUtil.etiqueta(conexion,
                            "SELECT p.apellido || ', ' || p.nombre FROM public.tecnicos tc LEFT JOIN public.usuarios u ON tc.id_usuario = u.id_usuario "
                            + "LEFT JOIN public.personas p ON u.id_persona = p.id_persona WHERE tc.id_tecnico = ?", request.getParameter("idTecnico")));
                }
            }
            if (esTecnico) {
                inf.filtro("Restringido a", "Solo las asistencias que usted cerr\u00f3");
            }

            if ("datos".equals(accion)) {
                response.setContentType("text/html;charset=UTF-8");
                try {
                    out.print(metricasHtml(conexion, origenInf, metricasInf, fechaDesde, fechaHasta));
                    out.print(InformeVistaUtil.pantalla(conexion, inf, fechaDesde, fechaHasta));
                } catch (Exception exVista) {
                    out.print(InformeVistaUtil.errorHtml(exVista));
                    exVista.printStackTrace();
                }
                return;
            }
            java.util.List<Integer> idsFiltrados = InformeVistaUtil.listarIds(conexion, inf, fechaDesde, fechaHasta);
            String errDet = emitirComprobantes(response, application, conexion, "comprobanteTicket",
                    new String[]{"comprobanteTicketMateriales", "comprobanteTicketHistorial", "comprobanteTicketAdjuntos"}, "ID_TICKET", idsFiltrados, "comprobante_ticket_detallado", (Integer) session.getAttribute("idUsuario"));
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
        parametros.put("FILTROS", filtrosSqlInf);
        parametros.put("RESUMEN", resumenInforme(conexion, origenInf, metricasInf, fechaDesde, fechaHasta));
        parametros.put("USUARIO_GENERA", ComprobanteUtil.nombreUsuario(conexion, (Integer) session.getAttribute("idUsuario")));
        // Usa el reporte ya compilado en memoria (más rápido)
        enviarInformePdf(response, application, conexion, "informeOrdenesCorrectivas", parametros, "informe_ordenes_correctivas");

    } catch (Exception ex) {
        response.setContentType("text/plain;charset=UTF-8");
        out.print("error al generar el informe: " + ex.getMessage());
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
