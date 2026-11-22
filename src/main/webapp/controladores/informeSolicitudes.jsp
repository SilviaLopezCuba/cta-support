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
    // Informe: Solicitudes de Asistencia
    // Recibe fechaInicio / fechaFin (yyyy-MM-dd, del <input type="date">)
    //
    // modo = "general"       -> solo filtra por rango de fechas (comportamiento original)
    // modo = "personalizado" -> ademas permite filtrar por estado, prioridad,
    //                           tipo de falla, sala, numero de ticket y solicitante
    //
    // Los Tecnicos SIEMPRE ven unicamente las asistencias que ellos mismos
    // cerraron (Resuelto/Cerrado con id_tecnico_asignado = idTecnico de la
    // sesion, de Alumnos y Maestros), sin importar lo que se envie desde el
    // formulario. Los datos generales solo los ve el administrador.
    try {
        // accion=combos -> devuelve los combos de Tecnico asignado y Sala
        // para el formulario de filtro personalizado. Solo lo usa el
        // Administrador; a un Tecnico no se le muestra ese filtro.
        if ("combos".equals(request.getParameter("accion"))) {
            response.setContentType("text/html;charset=UTF-8");
            out.print("<TECNICOS>");
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
            out.print("</TECNICOS><SALAS>");
            out.print("<option value=''>-- Todas --</option>");
            java.sql.PreparedStatement psSala = conexion.prepareStatement(
                "SELECT id_sala, nombre_sala FROM public.salas ORDER BY nombre_sala");
            java.sql.ResultSet rsSala = psSala.executeQuery();
            while (rsSala.next()) {
                out.print("<option value='" + rsSala.getInt("id_sala") + "'>" + rsSala.getString("nombre_sala") + "</option>");
            }
            rsSala.close();
            psSala.close();
            out.print("</SALAS>");
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
                condRol = "t.id_tecnico_asignado = " + idTecSes + " AND r.nombre_rol IN ('Alumno','Maestro') AND t.estado IN ('Resuelto','Cerrado')";
            }
            java.util.List<Integer> permitidos = InformeVistaUtil.consultarIds(conexion, "SELECT t.id_ticket FROM public.ticket t LEFT JOIN public.roles r ON t.id_rol_solicita = r.id_rol WHERE t.id_ticket IN (" + csv + ") AND (" + condRol + ") ORDER BY t.id_ticket");
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
            estadosPermitidos.add("Pendiente");
            estadosPermitidos.add("Asignado");
            estadosPermitidos.add("En Proceso");
            estadosPermitidos.add("Esperando Repuesto");
            estadosPermitidos.add("Resuelto");
            estadosPermitidos.add("Cerrado");
            // "Sin revisar": tickets tomados o asignados a los que nadie les hizo la primera revisión
            if ("Sin revisar".equals(request.getParameter("estado"))) {
                condiciones.add("(t.fecha_revision IS NULL AND t.estado IN ('Asignado', 'En Proceso', 'Esperando Repuesto'))");
            } else {
                condiciones.add(InformeUtil.condicionExacta("t.estado", request.getParameter("estado"), estadosPermitidos));
            }

            Set<String> prioridadesPermitidas = new HashSet<String>();
            prioridadesPermitidas.add("Baja");
            prioridadesPermitidas.add("Media");
            prioridadesPermitidas.add("Alta");
            prioridadesPermitidas.add("Critica");
            condiciones.add(InformeUtil.condicionExacta("t.prioridad", request.getParameter("prioridad"), prioridadesPermitidas));

            condiciones.add(InformeUtil.condicionTexto("t.tipo_falla", request.getParameter("tipoFalla")));
            condiciones.add(InformeUtil.condicionTexto("t.numero_ticket", request.getParameter("numeroTicket")));
            condiciones.add(InformeUtil.condicionEntero("t.id_sala", request.getParameter("idSala")));

            String solicitanteTexto = InformeUtil.limpiar(request.getParameter("solicitante"));
            if (solicitanteTexto != null) {
                String cond1 = InformeUtil.condicionTexto("per.apellido", solicitanteTexto);
                String cond2 = InformeUtil.condicionTexto("per.nombre", solicitanteTexto);
                condiciones.add("(" + cond1 + " OR " + cond2 + ")");
            }

            // El filtro de tecnico solo se respeta si el usuario NO es Tecnico.
            if (!esTecnico) {
                condiciones.add(InformeUtil.condicionEntero("t.id_tecnico_asignado", request.getParameter("idTecnico")));
            }
        }

        // Restriccion obligatoria: un Tecnico solo ve las asistencias que el
        // mismo cerro (Resuelto/Cerrado) y de las que es el tecnico asignado.
        if (esTecnico) {
            if (idTecnicoSesion == null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: la sesion no tiene un tecnico asociado");
                return;
            }
            condiciones.add("t.id_tecnico_asignado = " + idTecnicoSesion);
            condiciones.add("r.nombre_rol IN ('Alumno','Maestro')");
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
                            + "LEFT JOIN public.usuarios u ON t.id_usuario_solicita = u.id_usuario "
                            + "LEFT JOIN public.personas per ON u.id_persona = per.id_persona "
                            + "LEFT JOIN public.roles r ON t.id_rol_solicita = r.id_rol "
                            + "LEFT JOIN public.salas s ON t.id_sala = s.id_sala "
                            + "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo "
                            + "LEFT JOIN public.tecnicos tc ON t.id_tecnico_asignado = tc.id_tecnico "
                            + "LEFT JOIN public.usuarios ut ON tc.id_usuario = ut.id_usuario "
                            + "LEFT JOIN public.personas pt ON ut.id_persona = pt.id_persona "
                            + "WHERE t.fecha_creacion::date BETWEEN CAST(? AS date) AND CAST(? AS date) "
                            + "AND (" + filtrosSql + ")";
        String[][] metricasInf = {
            {"Total de solicitudes", "COUNT(*)", "N", "fa-list", "info"},
            {"Pendientes (sin técnico)", "COUNT(*) FILTER (WHERE t.estado = 'Pendiente')", "N", "fa-hourglass-half", "warning"},
            {"En curso", "COUNT(*) FILTER (WHERE t.estado IN ('Asignado','En Proceso','Esperando Repuesto'))", "N", "fa-tools", "primary"},
            {"Sin revisar", "COUNT(*) FILTER (WHERE t.fecha_revision IS NULL AND t.estado IN ('Asignado', 'En Proceso', 'Esperando Repuesto'))", "N", "fa-exclamation-circle", "danger"},
            {"Resueltas / Cerradas", "COUNT(*) FILTER (WHERE t.estado IN ('Resuelto','Cerrado'))", "N", "fa-check-circle", "success"},
            {"Horas promedio hasta revisar", "AVG(EXTRACT(EPOCH FROM (t.fecha_revision - t.fecha_creacion)) / 3600.0) FILTER (WHERE t.fecha_revision IS NOT NULL)", "D", "fa-stopwatch", "secondary"}
        };
        String accion = request.getParameter("accion");
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Solicitudes de Asistencia")
                .columnas("t.numero_ticket AS numero_ticket, to_char(t.fecha_creacion, 'DD/MM/YYYY HH24:MI') AS fecha, t.tipo_falla AS tipo_falla, t.estado AS estado, CASE t.prioridad WHEN 'Critica' THEN 'Crítica' ELSE t.prioridad END AS prioridad, COALESCE(per.apellido || ', ' || per.nombre, 'N/D') AS solicitante, s.nombre_sala AS nombre_sala, e.codigo_patrimonial AS equipo, CASE WHEN t.fecha_revision IS NOT NULL THEN to_char(t.fecha_revision, 'DD/MM/YYYY HH24:MI') WHEN t.estado IN ('Asignado', 'En Proceso', 'Esperando Repuesto') THEN 'Sin revisar' ELSE '—' END AS revision, CASE WHEN t.fecha_revision IS NOT NULL THEN replace(rtrim(to_char(round((EXTRACT(EPOCH FROM (t.fecha_revision - t.fecha_creacion)) / 3600.0)::numeric, 1), 'FM999999990.99'), '.'), '.', ',') ELSE '' END AS horas",
                        "N° Ticket", "Fecha", "Tipo de falla", "Estado", "Urgencia", "Solicitante", "Sala", "Equipo", "Primera revisión", "Horas hasta revisar")
                .origen(origenInf)
                .idRegistro("t.id_ticket")
                .orden("t.fecha_creacion")
                .filtro("Tipo de informe", personalizado ? "Personalizado" : "General");
            if (personalizado) {
                inf.filtro("Estado", request.getParameter("estado"))
                   .filtro("Prioridad", request.getParameter("prioridad"))
                   .filtro("Sala", InformeVistaUtil.etiqueta(conexion, "SELECT nombre_sala FROM public.salas WHERE id_sala = ?", request.getParameter("idSala")))
                   .filtro("N\u00b0 Ticket", request.getParameter("numeroTicket"))
                   .filtro("Tipo de falla contiene", request.getParameter("tipoFalla"))
                   .filtro("Solicitante contiene", request.getParameter("solicitante"));
                if (!esTecnico) {
                    inf.filtro("T\u00e9cnico asignado", InformeVistaUtil.etiqueta(conexion,
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
        enviarInformePdf(response, application, conexion, "informeSolicitudes", parametros, "informe_solicitudes");

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
