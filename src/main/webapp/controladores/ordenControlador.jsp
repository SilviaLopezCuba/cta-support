<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@include file="../config/conexion.jsp"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _f(java.util.Date d, String def) { return d == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _fh(java.sql.Timestamp t, String def) { return t == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
%>

<%
    // ordenControlador.jsp
    // Controlador de SOLICITUDES DE SOPORTE para ALUMNO y MAESTRO.
    // Estos roles NUNCA generan ordenes de reparacion directamente: solo
    // crean un Ticket en estado 'Pendiente' que despues atiende un Tecnico.
    String tipo = request.getParameter("tipo");

    try {
        // Combos de Sala y Equipo para el formulario de solicitud
        if ("cargarSalasYEquipos".equals(tipo)) {
            // Fase 4: Departamento -> Sala -> Equipo. El Depósito no aparece (no se piden asistencias ahí).
            out.print("<DEPTOS><option value=''>-- Seleccione el departamento --</option>");
            try (PreparedStatement psD = conexion.prepareStatement(
                    "SELECT d.id_departamento, d.nombre_departamento FROM public.departamentos d " +
                    "WHERE d.activo AND EXISTS (SELECT 1 FROM public.salas s WHERE s.id_departamento = d.id_departamento) ORDER BY d.nombre_departamento");
                 ResultSet rsD = psD.executeQuery()) {
                while (rsD.next()) out.print("<option value='" + rsD.getInt(1) + "'>" + esc(rsD.getString(2)) + "</option>");
            }
            out.print("</DEPTOS><SALAS>");
            out.print("<option value=''>-- Seleccione la Sala / Aula --</option>");
            try (PreparedStatement psS = conexion.prepareStatement(
                    "SELECT id_sala, nombre_sala, id_departamento FROM public.salas WHERE NOT es_deposito AND id_departamento IS NOT NULL ORDER BY nombre_sala");
                 ResultSet rsS = psS.executeQuery()) {
                while (rsS.next()) {
                    out.print("<option value='" + rsS.getInt("id_sala") + "' data-depto='" + rsS.getInt("id_departamento") + "'>" + esc(rsS.getString("nombre_sala")) + "</option>");
                }
            }
            out.print("</SALAS><EQUIPOS>");
            out.print("<option value=''>-- Seleccione el Equipo en Falla --</option>");
            // data-sala filtra por sala; data-categoria trae los tipos de falla de ese tipo de equipo
            try (PreparedStatement psE = conexion.prepareStatement(
                    "SELECT e.id_equipo, e.id_sala, e.id_categoria, e.codigo_patrimonial, e.modelo, c.nombre_categoria " +
                    "FROM public.equipos e LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria " +
                    "JOIN public.salas s ON s.id_sala = e.id_sala AND NOT s.es_deposito " +
                    "WHERE e.estado = 'Activo' ORDER BY c.nombre_categoria, e.codigo_patrimonial");
                 ResultSet rsE = psE.executeQuery()) {
                while (rsE.next()) {
                    out.print("<option value='" + rsE.getInt("id_equipo") + "' data-sala='" + rsE.getInt("id_sala") + "' data-categoria='"
                            + (rsE.getObject("id_categoria") == null ? "" : rsE.getInt("id_categoria")) + "'>"
                            + esc(rsE.getString("nombre_categoria") == null ? "" : rsE.getString("nombre_categoria") + ": ")
                            + esc(rsE.getString("codigo_patrimonial")) + " - " + esc(rsE.getString("modelo")) + "</option>");
                }
            }
            out.print("</EQUIPOS>");
        }

        // Comprobante de la solicitud (PDF) para quien la hizo: solo datos de la solicitud
        // y su estado, sin el detalle del trabajo técnico.
        if ("comprobantePdf".equals(tipo)) {
            Integer idUsuarioPdf = (Integer) session.getAttribute("idUsuario");
            boolean adminPdf = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
            int idTicketPdf = Integer.parseInt(request.getParameter("idTicket"));
            try (PreparedStatement psDue = conexion.prepareStatement("SELECT id_usuario_solicita FROM public.ticket WHERE id_ticket = ?")) {
                psDue.setInt(1, idTicketPdf);
                try (ResultSet rsDue = psDue.executeQuery()) {
                    if (idUsuarioPdf == null || !rsDue.next() || (!adminPdf && rsDue.getInt(1) != idUsuarioPdf)) {
                        response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
                        out.print("error: solo puede imprimir sus propias solicitudes");
                        return;
                    }
                }
            }
            java.util.List<Integer> idsPdf = new java.util.ArrayList<Integer>();
            idsPdf.add(idTicketPdf);
            byte[] pdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteSolicitud", new String[0], "ID_TICKET", idsPdf, idUsuarioPdf);
            response.setContentType("application/pdf");
            response.setContentLength(pdf.length);
            response.setHeader("Content-Disposition", "inline; filename=solicitud_" + idTicketPdf + ".pdf");
            javax.servlet.ServletOutputStream salidaPdf = response.getOutputStream();
            salidaPdf.write(pdf, 0, pdf.length);
            salidaPdf.flush();
            salidaPdf.close();
            return;
        }

        // Registrar una nueva solicitud (Ticket) con asignación automática.
        // Solo pueden Alumno (id_rol=4) y Maestro (id_rol=3).
        // Todo ocurre en UNA sola transacción: o se guarda el ticket
        // (con su asignación) o no se guarda nada.
        if ("guardarTicket".equals(tipo)) {
            Integer idUsuario = (Integer) session.getAttribute("idUsuario");
            Integer idRol = (Integer) session.getAttribute("idRol");
            if (idUsuario == null || idRol == null) {
                out.print("error: sesión no válida, inicie sesión nuevamente");
                return;
            }
            // Fase 4: cualquier usuario puede pedir asistencia (alumno, maestro, encargado,
            // administrador); el técnico no, porque es quien la atiende.
            boolean puedeSolicitar = !"Técnico".equals((String) session.getAttribute("nombreRol"));
            if (!puedeSolicitar) {
                out.print("error: su rol no tiene permiso para crear solicitudes");
                return;
            }

            String idEqParam = request.getParameter("id_equipo");
            String idSaParam = request.getParameter("id_sala");
            String idTipoFallaParam = request.getParameter("id_tipo_falla");
            String descripcion = request.getParameter("descripcion");

            if (idEqParam == null || idEqParam.isEmpty() || idSaParam == null || idSaParam.isEmpty()
                    || idTipoFallaParam == null || idTipoFallaParam.trim().isEmpty()
                    || descripcion == null || descripcion.trim().length() < 10) {
                out.print("error: complete todos los campos; en la descripción explique el problema (al menos 10 caracteres)");
                return;
            }
            // El tipo de falla tiene que ser del catálogo y corresponder a la categoría del equipo (o ser general)
            String tipoFalla;
            int idTipoFalla = Integer.parseInt(idTipoFallaParam.trim());
            try (PreparedStatement psTf = conexion.prepareStatement(
                    "SELECT tf.nombre_tipo_falla FROM public.tipos_falla tf, public.equipos e " +
                    "WHERE tf.id_tipo_falla = ? AND tf.activo AND e.id_equipo = ? " +
                    "AND (tf.id_categoria IS NULL OR tf.id_categoria = e.id_categoria)")) {
                psTf.setInt(1, idTipoFalla);
                psTf.setInt(2, Integer.parseInt(idEqParam));
                try (ResultSet rsTf = psTf.executeQuery()) {
                    if (!rsTf.next()) {
                        out.print("error: el tipo de falla no corresponde a ese equipo");
                        return;
                    }
                    tipoFalla = rsTf.getString(1);
                }
            }

            // El equipo tiene que pertenecer a la sala indicada
            try (PreparedStatement psChk = conexion.prepareStatement(
                    "SELECT 1 FROM public.equipos WHERE id_equipo = ? AND id_sala = ? AND estado = 'Activo'")) {
                psChk.setInt(1, Integer.parseInt(idEqParam));
                psChk.setInt(2, Integer.parseInt(idSaParam));
                try (ResultSet rsChk = psChk.executeQuery()) {
                    if (!rsChk.next()) {
                        out.print("error: el equipo seleccionado no pertenece a esa sala");
                        return;
                    }
                }
            }

            boolean autoCommitOriginal = conexion.getAutoCommit();
            try {
                conexion.setAutoCommit(false);

                // Le informamos al trigger de historial quién realiza la acción.
                // (true = válido solo durante esta transacción, por eso va dentro de ella)
                PreparedStatement psCtx = conexion.prepareStatement("SELECT set_config('app.current_user_id', ?, true)");
                psCtx.setString(1, String.valueOf(idUsuario));
                psCtx.execute();
                psCtx.close();

                String sqlTicket = "INSERT INTO public.ticket " +
                        "(id_usuario_solicita, id_rol_solicita, id_sala, id_equipo, tipo_falla, descripcion, estado, prioridad, id_tipo_falla) " +
                        "VALUES (?, ?, ?, ?, ?, ?, 'Pendiente', 'Media', ?) RETURNING id_ticket";
                PreparedStatement ps = conexion.prepareStatement(sqlTicket);
                ps.setInt(1, idUsuario);
                ps.setInt(2, idRol);
                ps.setInt(3, Integer.parseInt(idSaParam));
                ps.setInt(4, Integer.parseInt(idEqParam));
                ps.setString(5, tipoFalla.trim());
                ps.setString(6, descripcion.trim());
                ps.setInt(7, idTipoFalla);
                ResultSet rsNuevo = ps.executeQuery();

                if (!rsNuevo.next()) {
                    rsNuevo.close(); ps.close();
                    conexion.rollback();
                    out.print("error: no se pudo registrar la solicitud");
                    return;
                }
                int idTicketNuevo = rsNuevo.getInt("id_ticket");
                rsNuevo.close(); ps.close();

                // ASIGNACIÓN AUTOMÁTICA
                // Se asigna al técnico DISPONIBLE (estado_disponibilidad = true)
                // con MENOS tickets activos (Asignado / En Proceso /
                // Esperando Repuesto). El FOR UPDATE bloquea la fila del
                // técnico hasta el COMMIT para evitar que dos solicitudes
                // simultáneas elijan al mismo técnico.
                // Si no hay técnico disponible, el ticket queda 'Pendiente'
                // para que un Administrador lo asigne manualmente.
                Integer idTecnicoAsignado = seleccionarTecnicoMenosCargado(conexion);
                if (idTecnicoAsignado != null) {
                    String sqlAsignar = "UPDATE public.ticket SET id_tecnico_asignado = ?, " +
                            "estado = 'Asignado', fecha_inicio = CURRENT_TIMESTAMP " +
                            "WHERE id_ticket = ?";
                    PreparedStatement psAsignar = conexion.prepareStatement(sqlAsignar);
                    psAsignar.setInt(1, idTecnicoAsignado);
                    psAsignar.setInt(2, idTicketNuevo);
                    psAsignar.executeUpdate();
                    psAsignar.close();
                }

                conexion.commit();
                // Se devuelve el id para que la vista pueda subir los archivos adjuntos del ticket.
                out.print("success:" + idTicketNuevo);
            } catch (Exception exTx) {
                try { conexion.rollback(); } catch (SQLException exRb) { }
                out.print("error: no se pudo registrar la solicitud (" + exTx.getMessage() + ")");
            } finally {
                try { conexion.setAutoCommit(autoCommitOriginal); } catch (SQLException exAc) { }
            }
        }

        // Listar SOLO las solicitudes del usuario logueado
        if ("listarTicketsAlumno".equals(tipo)) {
            Integer idUsuario = (Integer) session.getAttribute("idUsuario");
            if (idUsuario == null) {
                out.print("<tr><td colspan='7' class='text-center text-muted'>Sesión no válida</td></tr>");
                return;
            }

            String sqlMisTickets = "SELECT tk.id_ticket, tk.numero_ticket, tk.fecha_creacion, tk.estado, tk.prioridad, tk.tipo_falla, " +
                    "e.modelo, p.nombre AS tec_nombre, p.apellido AS tec_apellido " +
                    "FROM public.ticket tk " +
                    "LEFT JOIN public.equipos e ON tk.id_equipo = e.id_equipo " +
                    "LEFT JOIN public.tecnicos t ON tk.id_tecnico_asignado = t.id_tecnico " +
                    "LEFT JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                    "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                    "WHERE tk.id_usuario_solicita = ? " +
                    "ORDER BY tk.id_ticket DESC LIMIT 10";
            PreparedStatement ps = conexion.prepareStatement(sqlMisTickets);
            ps.setInt(1, idUsuario);
            ResultSet rs = ps.executeQuery();
            boolean hay = false;
            while (rs.next()) {
                hay = true;
                String estado = rs.getString("estado");
                String badge = "Pendiente".equalsIgnoreCase(estado) ? "badge-warning" :
                        "Cerrado".equalsIgnoreCase(estado) || "Resuelto".equalsIgnoreCase(estado) ? "badge-success" :
                        "Cancelado".equalsIgnoreCase(estado) ? "badge-secondary" : "badge-info";

                String prioridad = rs.getString("prioridad");
                String badgePrio = "Critica".equalsIgnoreCase(prioridad) ? "badge-danger" :
                        "Alta".equalsIgnoreCase(prioridad) ? "badge-warning" : "badge-secondary";

                String tecnico = rs.getString("tec_apellido") != null
                        ? rs.getString("tec_apellido") + ", " + rs.getString("tec_nombre")
                        : "Sin asignar";

                Timestamp fc = rs.getTimestamp("fecha_creacion");
                String fecha = _fh(fc);

                out.print("<tr>");
                out.print("<td>" + esc(rs.getString("numero_ticket")) + "</td>");
                out.print("<td>" + (rs.getString("modelo") != null ? esc(rs.getString("modelo")) : "-")
                        + (rs.getString("tipo_falla") != null ? "<small class='d-block text-muted'>" + esc(rs.getString("tipo_falla")) + "</small>" : "") + "</td>");
                out.print("<td>" + fecha + "</td>");
                out.print("<td><span class='badge " + badge + "'>" + esc(estado) + "</span></td>");
                out.print("<td><span class='badge " + badgePrio + "'>" + esc("Critica".equalsIgnoreCase(prioridad) ? "Crítica" : prioridad) + "</span></td>");
                out.print("<td>" + esc(tecnico) + "</td>");
                out.print("<td class='text-center'><button type='button' class='btn btn-outline-primary btn-sm' title='Imprimir comprobante de la solicitud' "
                        + "aria-label='Imprimir comprobante del ticket " + esc(rs.getString("numero_ticket")) + "' "
                        + "onclick=\"window.open('../controladores/ordenControlador.jsp?tipo=comprobantePdf&idTicket=" + rs.getInt("id_ticket") + "', '_blank')\">"
                        + "<i class='fas fa-print' aria-hidden='true'></i></button></td>");
                out.print("</tr>");
            }
            rs.close(); ps.close();
            if (!hay) {
                out.print("<tr><td colspan='7' class='text-center text-muted py-3'>No tienes solicitudes registradas.</td></tr>");
            }
        }
    } catch (Exception e) {
        out.print("error: error crítico en el controlador (" + e.getMessage() + ")");
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    /** Escapa texto para imprimirlo de forma segura dentro de HTML. */
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    /**
     * Elige el técnico a asignar a un ticket nuevo.
     * Criterio: entre los técnicos con estado_disponibilidad = true, se
     * elige el que tenga MENOS tickets activos (Asignado / En Proceso /
     * Esperando Repuesto) en este momento. A igualdad de carga, desempata
     * por id_tecnico (orden estable, efecto Round-Robin natural).
     * Debe llamarse dentro de una transacción (autoCommit=false) para que
     * el FOR UPDATE realmente bloquee la fila hasta el commit.
     * Devuelve null si no hay ningún técnico disponible.
     */
    private Integer seleccionarTecnicoMenosCargado(Connection conexion) throws SQLException {
        String sql =
            "SELECT t.id_tecnico " +
            "FROM public.tecnicos t " +
            "WHERE t.estado_disponibilidad = true " +
            "ORDER BY (" +
            "    SELECT COUNT(*) FROM public.ticket tk " +
            "    WHERE tk.id_tecnico_asignado = t.id_tecnico " +
            "      AND tk.estado IN ('Asignado', 'En Proceso', 'Esperando Repuesto')" +
            ") ASC, t.id_tecnico ASC " +
            "LIMIT 1 " +
            "FOR UPDATE";
        try (PreparedStatement ps = conexion.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt("id_tecnico") : null;
        }
    }
%>
