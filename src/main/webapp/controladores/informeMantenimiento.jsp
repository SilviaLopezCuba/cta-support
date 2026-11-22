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
    // Informe: informeMantenimiento
    // Recibe fechaInicio / fechaFin (yyyy-MM-dd, del <input type="date">)
    //
    // modo = "general"       -> solo filtra por rango de fechas (comportamiento original)
    // modo = "personalizado" -> ademas permite filtrar por estado, sala,
    //                           tecnico ejecutor y numero de mantenimiento
    //
    // Los Tecnicos SIEMPRE ven unicamente los mantenimientos que ellos
    // cerraron (estado = 'Finalizado' y id_tecnico_ejecuta = idTecnico de
    // la sesion), sin importar lo que se haya enviado desde el formulario.
    try {
        // accion=combos -> devuelve los combos de Tecnico (ejecutor) y Sala
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
                condRol = "m.id_tecnico_ejecuta = " + idTecSes + " AND m.estado = 'Finalizado'";
            }
            java.util.List<Integer> permitidos = InformeVistaUtil.consultarIds(conexion, "SELECT m.id_mantenimiento FROM public.mantenimientos_preventivos m WHERE m.id_mantenimiento IN (" + csv + ") AND (" + condRol + ") ORDER BY m.id_mantenimiento");
            String errInd = emitirComprobantes(response, application, conexion, "comprobanteMantenimiento",
                    new String[]{"comprobanteMantenimientoEquipos", "comprobanteMantenimientoMateriales"}, "ID_MANTENIMIENTO", permitidos, "comprobante_mantenimiento", (Integer) session.getAttribute("idUsuario"));
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
            estadosPermitidos.add("Programado");
            estadosPermitidos.add("En Proceso");
            estadosPermitidos.add("Finalizado");
            estadosPermitidos.add("Cancelado");
            condiciones.add(InformeUtil.condicionExacta("m.estado", request.getParameter("estado"), estadosPermitidos));

            condiciones.add(InformeUtil.condicionEntero("m.id_sala", request.getParameter("idSala")));
            condiciones.add(InformeUtil.condicionTexto("m.numero_mantenimiento", request.getParameter("numeroMantenimiento")));

            // El filtro de tecnico solo se respeta si el usuario NO es Tecnico.
            if (!esTecnico) {
                condiciones.add(InformeUtil.condicionEntero("m.id_tecnico_ejecuta", request.getParameter("idTecnico")));
            }
        }

        // Restriccion obligatoria: un Tecnico solo ve lo que el mismo cerro.
        if (esTecnico) {
            if (idTecnicoSesion == null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: la sesion no tiene un tecnico asociado");
                return;
            }
            condiciones.add("m.id_tecnico_ejecuta = " + idTecnicoSesion);
            condiciones.add("m.estado = 'Finalizado'");
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
        String origenInf = "FROM public.mantenimientos_preventivos m "
                            + "LEFT JOIN public.salas s ON m.id_sala = s.id_sala "
                            + "LEFT JOIN public.tecnicos t ON m.id_tecnico_ejecuta = t.id_tecnico "
                            + "LEFT JOIN public.usuarios u ON t.id_usuario = u.id_usuario "
                            + "LEFT JOIN public.personas p ON u.id_persona = p.id_persona "
                            + "LEFT JOIN LATERAL (SELECT count(*) FILTER (WHERE dd.resultado IN ('OK', 'Reparado')) AS c_ok, count(*) FILTER (WHERE dd.resultado = 'Requirió repuesto') AS c_rep, count(*) FILTER (WHERE dd.resultado = 'No reparable') AS c_nr, count(*) FILTER (WHERE dd.resultado = 'Derivado a ticket') AS c_der FROM public.mantenimientos_preventivos_detalle dd WHERE dd.id_mantenimiento = m.id_mantenimiento) rm ON true "
                            + "WHERE m.fecha_programada BETWEEN CAST(? AS date) AND CAST(? AS date) "
                            + "AND (" + filtrosSql + ")";
        String[][] metricasInf = {
            {"Total de mantenimientos", "COUNT(*)", "N", "fa-calendar-check", "info"},
            {"Programados", "COUNT(*) FILTER (WHERE m.estado = 'Programado')", "N", "fa-calendar-alt", "warning"},
            {"En proceso", "COUNT(*) FILTER (WHERE m.estado = 'En Proceso')", "N", "fa-tools", "primary"},
            {"Finalizados", "COUNT(*) FILTER (WHERE m.estado = 'Finalizado')", "N", "fa-check-circle", "success"},
            {"Cancelados", "COUNT(*) FILTER (WHERE m.estado = 'Cancelado')", "N", "fa-ban", "secondary"},
            {"Equipos OK", "COALESCE(SUM(rm.c_ok), 0)", "N", "fa-thumbs-up", "success"},
            {"Requirieron repuesto", "COALESCE(SUM(rm.c_rep), 0)", "N", "fa-cogs", "warning"},
            {"No reparables", "COALESCE(SUM(rm.c_nr), 0)", "N", "fa-power-off", "danger"},
            {"Derivados a ticket", "COALESCE(SUM(rm.c_der), 0)", "N", "fa-share", "info"}
        };
        String accion = request.getParameter("accion");
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Mantenimiento Preventivo")
                .columnas("m.numero_mantenimiento AS numero, to_char(m.fecha_programada, 'DD/MM/YYYY') AS fecha_programada, m.estado AS estado, s.nombre_sala AS nombre_sala, COALESCE(p.apellido || ', ' || p.nombre, 'Sin asignar') AS tecnico, to_char(m.fecha_fin, 'DD/MM/YYYY') AS fecha_fin, COALESCE(m.observacion_inicial, '—') AS obs_inicial, COALESCE(NULLIF(concat_ws(', ', CASE WHEN rm.c_ok > 0 THEN 'OK: ' || rm.c_ok END, CASE WHEN rm.c_rep > 0 THEN 'Con repuesto: ' || rm.c_rep END, CASE WHEN rm.c_nr > 0 THEN 'No reparables: ' || rm.c_nr END, CASE WHEN rm.c_der > 0 THEN 'A ticket: ' || rm.c_der END), ''), '—') AS resultados",
                        "N° Mantenimiento", "Fecha programada", "Estado", "Sala", "Técnico", "Fecha fin", "Observación inicial", "Resultado de los equipos")
                .origen(origenInf)
                .idRegistro("m.id_mantenimiento")
                .orden("m.fecha_programada")
                .filtro("Tipo de informe", personalizado ? "Personalizado" : "General");
            if (personalizado) {
                inf.filtro("Estado", request.getParameter("estado"))
                   .filtro("Sala", InformeVistaUtil.etiqueta(conexion, "SELECT nombre_sala FROM public.salas WHERE id_sala = ?", request.getParameter("idSala")))
                   .filtro("N\u00b0 Mantenimiento", request.getParameter("numeroMantenimiento"));
                if (!esTecnico) {
                    inf.filtro("T\u00e9cnico (ejecutor)", InformeVistaUtil.etiqueta(conexion,
                            "SELECT p.apellido || ', ' || p.nombre FROM public.tecnicos tc LEFT JOIN public.usuarios u ON tc.id_usuario = u.id_usuario "
                            + "LEFT JOIN public.personas p ON u.id_persona = p.id_persona WHERE tc.id_tecnico = ?", request.getParameter("idTecnico")));
                }
            }
            if (esTecnico) {
                inf.filtro("Restringido a", "Solo los mantenimientos que usted finaliz\u00f3");
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
            String errDet = emitirComprobantes(response, application, conexion, "comprobanteMantenimiento",
                    new String[]{"comprobanteMantenimientoEquipos", "comprobanteMantenimientoMateriales"}, "ID_MANTENIMIENTO", idsFiltrados, "comprobante_mantenimiento_detallado", (Integer) session.getAttribute("idUsuario"));
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
        enviarInformePdf(response, application, conexion, "informeMantenimiento", parametros, "informe_mantenimiento");

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
