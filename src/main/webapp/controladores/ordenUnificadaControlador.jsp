<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.time.LocalDate"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@include file="../config/conexion.jsp"%>
<%@include file="../config/inventarioComun.jsp"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _f(java.util.Date d, String def) { return d == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _fh(java.sql.Timestamp t, String def) { return t == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }

    /**
     * PRIMERA REVISIÓN del ticket: diagnóstico + urgencia + cómo sigue.
     * Se pide al tomar el ticket (o al abrir uno asignado que nadie revisó).
     * Devuelve el mensaje de error, o null si los datos están bien.
     */
    private static String validarRevision(String diag, String prio, String sigue, String fecha) {
        if (diag == null || diag.trim().length() < 10) return "Escribí el diagnóstico inicial (al menos 10 caracteres): qué encontraste.";
        if (!java.util.Arrays.asList("Baja", "Media", "Alta", "Critica").contains(prio)) return "Elegí la urgencia del ticket.";
        if (!java.util.Arrays.asList("proceso", "repuesto", "resuelto").contains(sigue)) return "Elegí cómo sigue el ticket.";
        if (!"resuelto".equals(sigue)) {
            if (fecha == null || !fecha.matches("\\d{4}-\\d{2}-\\d{2}")) return "Indicá la fecha de seguimiento (cuándo lo retomás).";
            if (java.time.LocalDate.parse(fecha).isBefore(java.time.LocalDate.now())) return "La fecha de seguimiento no puede ser anterior a hoy.";
        }
        return null;
    }

    /** Guarda la primera revisión (dentro de la transacción de quien llama). Devuelve las filas actualizadas. */
    private static int aplicarRevision(Connection c, int idTicket, String diag, String prio, String sigue, String fecha,
                                       int idUsuario, Integer idTecnico, boolean esAdmin) throws SQLException {
        int filas;
        try (PreparedStatement ps = c.prepareStatement(
                "UPDATE public.ticket SET diagnostico = ?, prioridad = ?, fecha_revision = CURRENT_TIMESTAMP, estado = ?, " +
                "fecha_seguimiento = ?, fecha_inicio = COALESCE(fecha_inicio, CURRENT_TIMESTAMP) " +
                "WHERE id_ticket = ? AND estado IN ('Pendiente', 'Asignado', 'En Proceso', 'Esperando Repuesto')" +
                (esAdmin ? "" : " AND id_tecnico_asignado = ?"))) {
            String d = diag.trim();
            ps.setString(1, d);
            ps.setString(2, prio);
            ps.setString(3, "repuesto".equals(sigue) ? "Esperando Repuesto" : "En Proceso");
            if ("resuelto".equals(sigue)) ps.setNull(4, Types.TIMESTAMP);
            else ps.setTimestamp(4, Timestamp.valueOf(fecha + " 00:00:00"));
            ps.setInt(5, idTicket);
            if (!esAdmin) ps.setInt(6, idTecnico == null ? -1 : idTecnico);
            filas = ps.executeUpdate();
        }
        if (filas > 0) {
            String como = "repuesto".equals(sigue) ? "necesita repuesto" : ("resuelto".equals(sigue) ? "se resuelve en el momento" : "se repara");
            String desc = "Urgencia " + ("Critica".equals(prio) ? "Crítica" : prio) + ", " + como + ". Diagnóstico: " + diag.trim();
            try (PreparedStatement ps = c.prepareStatement(
                    "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, 'Primera revisión', ?)")) {
                ps.setInt(1, idTicket);
                ps.setInt(2, idUsuario);
                ps.setString(3, desc.length() > 500 ? desc.substring(0, 500) : desc);
                ps.executeUpdate();
            }
        }
        return filas;
    }
%>

<%
    // Controlador de la Mesa de Ayuda para TÉCNICO (y ADMINISTRADOR)
    String tipo = request.getParameter("tipo");

    // Estados que el técnico puede elegir al procesar un ticket asignado (no puede devolverlo a Pendiente).
    final String[] ESTADOS_FINALIZABLES_DESDE_FORM = {"En Proceso", "Esperando Repuesto", "Resuelto", "Cerrado"};
    final String[] PRIORIDADES_VALIDAS = {"Baja", "Media", "Alta", "Critica"};

    try {
        // Anulacion de ticket (solo Administrador). Cabecera + detalle en una transaccion:
        // pasa el ticket a 'Cancelado' y deja la constancia en ticket_detalle (historial).
        // Solo se anulan tickets activos: los cerrados/resueltos ya tienen materiales descontados.
        // El estado Cancelado fue eliminado del sistema: la acción queda deshabilitada.
        if ("anularTicket".equals(tipo)) {
            out.print("error: la anulación de tickets fue deshabilitada");
            return;
        }
        if ("anularTicketDeshabilitado".equals(tipo)) {
            Integer idUsuarioAnula = (Integer) session.getAttribute("idUsuario");
            if (idUsuarioAnula == null || !Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("error: solo el administrador puede anular tickets");
                return;
            }
            Integer idTicketAnula = tryParseInt(request.getParameter("idTicket"));
            String motivoAnula = request.getParameter("motivo");
            if (idTicketAnula == null || motivoAnula == null || motivoAnula.trim().length() < 5) {
                out.print("error: indique el ticket y un motivo de al menos 5 caracteres");
                return;
            }
            try {
                conexion.setAutoCommit(false);
                PreparedStatement psCtxA = conexion.prepareStatement("SELECT set_config('app.current_user_id', ?, true)");
                psCtxA.setString(1, String.valueOf(idUsuarioAnula));
                psCtxA.execute();
                psCtxA.close();

                PreparedStatement psAn = conexion.prepareStatement(
                        "UPDATE public.ticket SET estado = 'Cancelado', observacion_final = ?, " +
                        "fecha_seguimiento = NULL, fecha_fin = CURRENT_TIMESTAMP " +
                        "WHERE id_ticket = ? AND estado IN ('Pendiente','Asignado','En Proceso','Esperando Repuesto')");
                psAn.setString(1, motivoAnula.trim());
                psAn.setInt(2, idTicketAnula);
                int filasAn = psAn.executeUpdate();
                psAn.close();
                if (filasAn == 0) {
                    throw new SQLException("El ticket no existe o ya está finalizado.");
                }

                PreparedStatement psHistA = conexion.prepareStatement(
                        "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, 'Anulación', ?)");
                psHistA.setInt(1, idTicketAnula);
                psHistA.setInt(2, idUsuarioAnula);
                psHistA.setString(3, motivoAnula.trim());
                psHistA.executeUpdate();
                psHistA.close();

                conexion.commit();
                out.print("success");
            } catch (Exception exAn) {
                conexion.rollback();
                out.print("error: " + exAn.getMessage());
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // 1. Bandeja: Tickets Pendientes (sin técnico)
        if ("listarPendientes".equals(tipo)) {
            // Verificación por ROL real (tabla roles), no por un id_usuario fijo.
            boolean esAdminAsignador = Boolean.TRUE.equals(session.getAttribute("esAdmin"));

            // Si es el admin autorizado, preparamos el combo de técnicos disponibles
            // una sola vez para reutilizarlo en cada fila (evita repetir la consulta).
            String comboTecnicosHtml = "";
            if (esAdminAsignador) {
                StringBuilder tecSel = new StringBuilder("<option value=''>-- Técnico --</option>");
                PreparedStatement psTecSel = conexion.prepareStatement(
                        "SELECT t.id_tecnico, p.nombre, p.apellido FROM public.tecnicos t " +
                        "JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                        "JOIN public.personas p ON u.id_persona = p.id_persona " +
                        "WHERE t.estado_disponibilidad = true ORDER BY p.apellido");
                ResultSet rsTecSel = psTecSel.executeQuery();
                while (rsTecSel.next()) {
                    tecSel.append("<option value='").append(rsTecSel.getInt("id_tecnico")).append("'>")
                          .append(rsTecSel.getString("apellido")).append(", ").append(rsTecSel.getString("nombre")).append("</option>");
                }
                rsTecSel.close(); psTecSel.close();
                comboTecnicosHtml = tecSel.toString();
            }

            // Esta bandeja muestra: (a) los tickets sin técnico (Pendiente) y (b) los que un técnico
            // dejó "Esperando Repuesto" (conservan su técnico, pero se ven aquí para que el
            // administrador y el resto del equipo sepan que están detenidos).
            Integer idTecSesionPend = (Integer) session.getAttribute("idTecnico");
            String sql = "SELECT t.id_ticket, t.numero_ticket, t.fecha_creacion, t.tipo_falla, t.estado, " +
                         "t.prioridad, t.id_tecnico_asignado, t.fecha_seguimiento, " +
                         "e.codigo_patrimonial, e.modelo, s.nombre_sala, " +
                         "pt.nombre AS tec_nombre, pt.apellido AS tec_apellido, " + sqlMaterialOrden("T", "t.id_ticket") +
                         "FROM public.ticket t " +
                         "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo " +
                         "LEFT JOIN public.salas s ON t.id_sala = s.id_sala " +
                         "LEFT JOIN public.tecnicos tc ON t.id_tecnico_asignado = tc.id_tecnico " +
                         "LEFT JOIN public.usuarios ut ON tc.id_usuario = ut.id_usuario " +
                         "LEFT JOIN public.personas pt ON ut.id_persona = pt.id_persona " +
                         "WHERE t.estado IN ('Pendiente', 'Esperando Repuesto') " +
                         "ORDER BY CASE WHEN t.estado = 'Pendiente' THEN 0 ELSE 1 END, CASE t.prioridad " +
                         "  WHEN 'Critica' THEN 1 WHEN 'Alta' THEN 2 WHEN 'Media' THEN 3 ELSE 4 END, " +
                         "t.fecha_creacion ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                int idTicketRow = rs.getInt("id_ticket");
                String codPat = rs.getString("codigo_patrimonial") != null ? rs.getString("codigo_patrimonial") : "S/N";
                String modelo = rs.getString("modelo") != null ? rs.getString("modelo") : "Equipo General";
                String sala = rs.getString("nombre_sala") != null ? rs.getString("nombre_sala") : "Aula Común";
                String prioridad = rs.getString("prioridad");
                String badgePrio = badgePrioridad(prioridad);
                String estadoRow = rs.getString("estado");
                boolean esperaRepuesto = "Esperando Repuesto".equals(estadoRow);
                boolean esMioRow = esperaRepuesto && idTecSesionPend != null
                        && rs.getInt("id_tecnico_asignado") == idTecSesionPend.intValue();
                String tecRow = rs.getString("tec_apellido") != null
                        ? esc(rs.getString("tec_apellido")) + ", " + esc(rs.getString("tec_nombre"))
                        : "Sin técnico";
                String segRow = _f(rs.getTimestamp("fecha_seguimiento"), null);
%>
                <tr>
                    <td><%= rs.getString("numero_ticket") %></td>
                    <td><span class="badge <%= badgePrio %>"><%= "Critica".equals(prioridad) ? "Crítica" : prioridad %></span></td>
                    <td><span class="badge badge-info"><%= sala %></span></td>
                    <td><%= codPat + " (" + modelo + ")" %></td>
                    <td><%= _fh(rs.getTimestamp("fecha_creacion"), "Ahora") %></td>
                    <td><%= rs.getString("tipo_falla") != null ? rs.getString("tipo_falla") : "" %></td>
                    <td>
                        <span class="badge <%= badgeEstado(estadoRow) %>"><%= estadoRow %></span>
                        <div class="small text-muted"><%= tecRow %><%= (esperaRepuesto && segRow != null) ? " · seguimiento " + segRow : "" %></div>
<%                      if (esperaRepuesto) { %><div class="mt-1"><%= badgeMaterial(rs) %></div><% } %>
                    </td>
                    <td class="text-center">
<%                      if (esAdminAsignador) { %>
<%                          if (!esperaRepuesto) { %>
                        <button class="btn btn-warning btn-sm font-weight-bold shadow-sm mb-1" title="Tomar este ticket yo mismo (Administrador)" onclick="tomarTicket(<%= idTicketRow %>, this)">
                            <i class="fas fa-hands-helping"></i> Tomar
                        </button>
<%                          } else { %>
                        <button class="btn btn-primary btn-sm shadow-sm mb-1" title="Abrir para atender / cerrar" onclick="continuarTicket(<%= idTicketRow %>, '<%= rs.getString("numero_ticket") %>')">
                            <i class="fas fa-redo"></i> Atender / Cerrar
                        </button>
<%                          } %>
                        <div class="input-group input-group-sm" style="min-width:190px;">
                            <select class="form-control form-control-sm" id="selTecAdmin_<%= idTicketRow %>"><%= comboTecnicosHtml %></select>
                            <div class="input-group-append">
                                <button class="btn btn-outline-primary btn-sm" title="Asignar / reasignar técnico (solo Administrador)"
                                        onclick="asignarTecnicoManual(<%= idTicketRow %>, document.getElementById('selTecAdmin_<%= idTicketRow %>').value)">
                                    <i class="fas fa-user-cog"></i> <%= esperaRepuesto ? "Reasignar" : "Asignar" %>
                                </button>
                            </div>
                        </div>
<%                      } else if (esMioRow) { %>
                        <button class="btn btn-primary btn-sm shadow-sm" title="Es tu ticket: continuar cuando tengas el repuesto" onclick="continuarTicket(<%= idTicketRow %>, '<%= rs.getString("numero_ticket") %>')">
                            <i class="fas fa-redo"></i> Continuar
                        </button>
<%                      } else if (esperaRepuesto) { %>
                        <span class="small text-muted">Lo atiende el técnico asignado</span>
<%                      } else { %>
                        <button class="btn btn-warning btn-sm font-weight-bold shadow-sm" onclick="tomarTicket(<%= idTicketRow %>, this)">
                            <i class="fas fa-hands-helping"></i> Tomar
                        </button>
<%                      } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='8' class='text-center text-muted py-3'>No hay tickets pendientes en este momento.</td></tr>");
            }
        }

        // 1b. Panel de Supervisión del Administrador
        // Requisito de negocio: el Administrador debe poder ver, en tiempo
        // real, TODOS los casos activos (Pendiente / Asignado / En Proceso /
        // Esperando Repuesto) de TODOS los técnicos, con el técnico asignado
        // a cada uno, y reasignarlo desde el mismo panel. A diferencia de
        // "Mis Tickets en Curso" (bandeja 2), que está acotada al técnico
        // logueado, esta bandeja no filtra por id_tecnico_asignado: por eso
        // se valida el rol explícitamente antes de exponer los datos.
        if ("listarActivosAdmin".equals(tipo)) {
            if (!Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("<tr><td colspan='8' class='text-center text-danger py-3'>Acceso restringido: solo un Administrador puede ver este panel.</td></tr>");
                return;
            }

            // Combo de técnicos disponibles, reutilizado en cada fila para poder reasignar sin recargar la página.
            StringBuilder tecSel = new StringBuilder("<option value=''>-- Técnico --</option>");
            PreparedStatement psTecSel = conexion.prepareStatement(
                    "SELECT t.id_tecnico, p.nombre, p.apellido FROM public.tecnicos t " +
                    "JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                    "JOIN public.personas p ON u.id_persona = p.id_persona " +
                    "WHERE t.estado_disponibilidad = true ORDER BY p.apellido");
            ResultSet rsTecSel = psTecSel.executeQuery();
            while (rsTecSel.next()) {
                tecSel.append("<option value='").append(rsTecSel.getInt("id_tecnico")).append("'>")
                      .append(esc(rsTecSel.getString("apellido"))).append(", ").append(esc(rsTecSel.getString("nombre"))).append("</option>");
            }
            rsTecSel.close(); psTecSel.close();
            String comboTecnicosHtml = tecSel.toString();

            String sql = "SELECT t.id_ticket, t.numero_ticket, t.estado, t.prioridad, t.fecha_creacion, t.id_tecnico_asignado, " +
                         "e.codigo_patrimonial, e.modelo, s.nombre_sala, " +
                         "p.nombre AS tec_nombre, p.apellido AS tec_apellido " +
                         "FROM public.ticket t " +
                         "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo " +
                         "LEFT JOIN public.salas s ON t.id_sala = s.id_sala " +
                         "LEFT JOIN public.tecnicos tc ON t.id_tecnico_asignado = tc.id_tecnico " +
                         "LEFT JOIN public.usuarios u ON tc.id_usuario = u.id_usuario " +
                         "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                         "WHERE t.estado IN ('Pendiente', 'Asignado', 'En Proceso', 'Esperando Repuesto') " +
                         "ORDER BY CASE t.prioridad " +
                         "  WHEN 'Critica' THEN 1 WHEN 'Alta' THEN 2 WHEN 'Media' THEN 3 ELSE 4 END, " +
                         "t.fecha_creacion ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                int idTicketRow = rs.getInt("id_ticket");
                String codPat = rs.getString("codigo_patrimonial") != null ? rs.getString("codigo_patrimonial") : "S/N";
                String modelo = rs.getString("modelo") != null ? rs.getString("modelo") : "Equipo General";
                String sala = rs.getString("nombre_sala") != null ? rs.getString("nombre_sala") : "Aula Común";
                String prioridad = rs.getString("prioridad");
                String estado = rs.getString("estado");
                String tecnico = rs.getString("tec_apellido") != null
                        ? esc(rs.getString("tec_apellido")) + ", " + esc(rs.getString("tec_nombre"))
                        : (rs.getObject("id_tecnico_asignado") != null
                            ? "<span class='text-danger' title='El técnico asignado no tiene usuario/persona vinculados; reasigne el ticket'>Técnico #" + rs.getInt("id_tecnico_asignado") + " (datos incompletos)</span>"
                            : "<span class='text-muted'>Sin asignar</span>");
%>
                <tr>
                    <td><%= esc(rs.getString("numero_ticket")) %></td>
                    <td><span class="badge <%= badgeEstado(estado) %>"><%= estado %></span></td>
                    <td><span class="badge <%= badgePrioridad(prioridad) %>"><%= "Critica".equals(prioridad) ? "Crítica" : prioridad %></span></td>
                    <td><%= esc(sala) + " - " + esc(codPat) + " (" + esc(modelo) + ")" %></td>
                    <td><%= _fh(rs.getTimestamp("fecha_creacion"), "-") %></td>
                    <td><%= tecnico %></td>
                    <td class="text-center">
<%                      if (rs.getObject("id_tecnico_asignado") == null) { %>
                        <button class="btn btn-warning btn-sm font-weight-bold shadow-sm" title="Tomar este ticket yo mismo" onclick="tomarTicket(<%= idTicketRow %>, this)">
                            <i class="fas fa-hands-helping"></i> Tomar
                        </button>
<%                      } else { %>
                        <button class="btn btn-primary btn-sm font-weight-bold shadow-sm" title="Abrir para atender / cerrar" onclick="continuarTicket(<%= idTicketRow %>, '<%= esc(rs.getString("numero_ticket")) %>')">
                            <i class="fas fa-redo"></i> Atender / Cerrar
                        </button>
<%                      } %>
                    </td>
                    <td class="text-center">
                        <div class="input-group input-group-sm" style="min-width:190px;">
                            <select class="form-control form-control-sm" id="selTecAdminSup_<%= idTicketRow %>"><%= comboTecnicosHtml %></select>
                            <div class="input-group-append">
                                <button class="btn btn-outline-primary btn-sm" title="Asignar / reasignar técnico (solo Administrador)"
                                        onclick="asignarTecnicoManual(<%= idTicketRow %>, document.getElementById('selTecAdminSup_<%= idTicketRow %>').value)">
                                    <i class="fas fa-user-cog"></i> <%= rs.getObject("id_tecnico_asignado") != null ? "Reasignar" : "Asignar" %>
                                </button>
                            </div>
                        </div>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='8' class='text-center text-muted py-3'>No hay casos activos en este momento.</td></tr>");
            }
        }

        // 2. Bandeja: Mis Tickets en Curso
        if ("listarEnCurso".equals(tipo)) {
            Integer idTecnico = (Integer) session.getAttribute("idTecnico");
            if (idTecnico == null) {
                out.print("<tr><td colspan='7' class='text-center text-muted py-3'>" +
                          (Boolean.TRUE.equals(session.getAttribute("esAdmin"))
                              ? "Como Administrador puede tomar, atender, cerrar y reasignar cualquier ticket desde el panel de supervisión."
                              : "Su usuario no está vinculado a un técnico (tabla Técnicos). Pida al administrador que lo vincule.") +
                          "</td></tr>");
                return;
            }
            String sql = "SELECT t.id_ticket, t.numero_ticket, t.estado, t.prioridad, t.fecha_seguimiento, t.fecha_revision, " +
                         "e.codigo_patrimonial, e.modelo, s.nombre_sala, " + sqlMaterialOrden("T", "t.id_ticket") +
                         "FROM public.ticket t " +
                         "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo " +
                         "LEFT JOIN public.salas s ON t.id_sala = s.id_sala " +
                         "WHERE t.id_tecnico_asignado = ? AND t.estado IN ('Asignado','En Proceso','Esperando Repuesto') " +
                         "ORDER BY (t.fecha_revision IS NOT NULL), CASE t.prioridad " +
                         "  WHEN 'Critica' THEN 1 WHEN 'Alta' THEN 2 WHEN 'Media' THEN 3 ELSE 4 END, " +
                         "t.fecha_seguimiento ASC NULLS FIRST";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ps.setInt(1, idTecnico);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            LocalDate hoy = LocalDate.now();
            while (rs.next()) {
                cont++;
                String codPat = rs.getString("codigo_patrimonial") != null ? rs.getString("codigo_patrimonial") : "S/N";
                String modelo = rs.getString("modelo") != null ? rs.getString("modelo") : "Equipo General";
                String sala = rs.getString("nombre_sala") != null ? rs.getString("nombre_sala") : "Aula Común";
                String prioridad = rs.getString("prioridad");
                String estado = rs.getString("estado");
                Timestamp fechaSeg = rs.getTimestamp("fecha_seguimiento");

                String seguimientoHtml;
                if (fechaSeg == null) {
                    seguimientoHtml = "<span class='badge badge-secondary'>Sin fecha</span>";
                } else {
                    LocalDate fechaSegLocal = fechaSeg.toLocalDateTime().toLocalDate();
                    String texto = _f(fechaSeg);
                    if (fechaSegLocal.isBefore(hoy)) {
                        seguimientoHtml = "<span class='badge badge-danger'>Vencido: " + texto + "</span>";
                    } else if (fechaSegLocal.isEqual(hoy)) {
                        seguimientoHtml = "<span class='badge badge-warning'>Hoy: " + texto + "</span>";
                    } else {
                        seguimientoHtml = "<span class='badge badge-secondary'>" + texto + "</span>";
                    }
                }
%>
                <tr>
                    <td><%= rs.getString("numero_ticket") %></td>
                    <td><span class="badge <%= badgePrioridad(prioridad) %>"><%= "Critica".equals(prioridad) ? "Crítica" : prioridad %></span></td>
                    <td><span class="badge <%= badgeEstado(estado) %>"><%= estado %></span>
<%                  if (rs.getTimestamp("fecha_revision") == null) { %>
                        <div class="mt-1"><span class="badge badge-danger" title="Abrilo y hacé la primera revisión"><i class="fas fa-exclamation-circle"></i> Sin revisar</span></div>
<%                  } %>
                    </td>
                    <td><span class="badge badge-light border"><%= sala + " - " + modelo + " (" + codPat + ")" %></span></td>
                    <td><%= badgeMaterial(rs) %></td>
                    <td><%= seguimientoHtml %></td>
                    <td class="text-center">
                        <button class="btn btn-primary btn-sm font-weight-bold shadow-sm" onclick="continuarTicket(<%= rs.getInt("id_ticket") %>, '<%= rs.getString("numero_ticket") %>')">
                            <i class="fas fa-redo"></i> Continuar / Cerrar
                        </button>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='7' class='text-center text-muted py-3'>No tienes tickets en curso.</td></tr>");
            }
        }

        // 3. Bandeja: Historial de Tickets Solucionados
        if ("listarResueltos".equals(tipo)) {
            String sql = "SELECT t.id_ticket, t.numero_ticket, t.estado, t.prioridad, t.fecha_fin, t.tiempo_resolucion, " +
                         "e.modelo, e.codigo_patrimonial, p.nombre AS tec_nombre, p.apellido AS tec_apellido " +
                         "FROM public.ticket t " +
                         "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo " +
                         "LEFT JOIN public.tecnicos tc ON t.id_tecnico_asignado = tc.id_tecnico " +
                         "LEFT JOIN public.usuarios u ON tc.id_usuario = u.id_usuario " +
                         "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                         "WHERE t.estado IN ('Resuelto','Cerrado') " +
                         // El técnico solo ve el historial de sus propios tickets; el admin ve todos
                         (Boolean.TRUE.equals(session.getAttribute("esAdmin")) ? "" : "AND t.id_tecnico_asignado = ? ") +
                         "ORDER BY t.fecha_fin DESC NULLS LAST LIMIT 50";
            PreparedStatement ps = conexion.prepareStatement(sql);
            if (!Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                Integer idTecHist = (Integer) session.getAttribute("idTecnico");
                ps.setInt(1, idTecHist == null ? -1 : idTecHist);
            }
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                String tecnico = rs.getString("tec_apellido") != null
                        ? rs.getString("tec_apellido") + ", " + rs.getString("tec_nombre")
                        : "Sin asignar";
                String equipo = rs.getString("modelo") != null
                        ? rs.getString("modelo") + " (" + rs.getString("codigo_patrimonial") + ")"
                        : "-";
                Timestamp fechaFin = rs.getTimestamp("fecha_fin");
                Integer tiempoRes = rs.getObject("tiempo_resolucion") != null ? rs.getInt("tiempo_resolucion") : null;
                String tiempoTxt = tiempoRes != null ? (tiempoRes + " min") : "-";
%>
                <tr>
                    <td><%= rs.getString("numero_ticket") %></td>
                    <td><span class="badge <%= badgeEstado(rs.getString("estado")) %>"><%= rs.getString("estado") %></span></td>
                    <td><span class="badge <%= badgePrioridad(rs.getString("prioridad")) %>"><%= "Critica".equals(rs.getString("prioridad")) ? "Crítica" : rs.getString("prioridad") %></span></td>
                    <td><%= equipo %></td>
                    <td><%= tecnico %></td>
                    <td><%= _fh(fechaFin) %></td>
                    <td class="text-right"><%= tiempoTxt %></td>
                    <td class="text-center">
                        <button class="btn btn-secondary btn-sm" onclick="imprimirTicket(<%= rs.getInt("id_ticket") %>)">
                            <i class="fas fa-print"></i>
                        </button>
<%                      if (Boolean.TRUE.equals(session.getAttribute("esAdmin")) && !"Cancelado".equals(rs.getString("estado"))) { %>
                        <button class="btn btn-info btn-sm" title="Materiales del ticket" onclick="verMaterialesTicket(<%= rs.getInt("id_ticket") %>, '<%= rs.getString("numero_ticket") %>')">
                            <i class="fas fa-tools"></i>
                        </button>
<%                      } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='8' class='text-center text-muted py-3'>Todavía no hay tickets solucionados.</td></tr>");
            }
        }

        // Materiales de un ticket ya resuelto/cerrado (ticket_repuesto): consulta, modificación y baja.
        // SOLO Administrador. Cada cambio ajusta el stock del catálogo en la misma transacción.
        if ("listarMaterialesTicket".equals(tipo)) {
            if (!Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("[]");
                return;
            }
            Integer idTicketMat = tryParseInt(request.getParameter("idTicket"));
            JSONArray lista = new JSONArray();
            if (idTicketMat != null) {
                PreparedStatement psL = conexion.prepareStatement(
                    "SELECT tr.id, tr.cantidad, tr.precio_unitario, COALESCE(r.nombre, i.nombre) AS descripcion, "
                    + "CASE WHEN tr.id_repuesto IS NOT NULL THEN 'Repuesto' ELSE 'Insumo' END AS categoria "
                    + "FROM public.ticket_repuesto tr "
                    + "LEFT JOIN public.catalogo_repuestos r ON tr.id_repuesto = r.id_repuesto "
                    + "LEFT JOIN public.catalogo_insumos i ON tr.id_insumo = i.id_insumo "
                    + "WHERE tr.id_ticket = ? ORDER BY tr.id");
                psL.setInt(1, idTicketMat);
                ResultSet rsL = psL.executeQuery();
                while (rsL.next()) {
                    JSONObject it = new JSONObject();
                    it.put("id", rsL.getInt("id"));
                    it.put("categoria", rsL.getString("categoria"));
                    it.put("descripcion", rsL.getString("descripcion"));
                    it.put("cantidad", rsL.getBigDecimal("cantidad"));
                    it.put("precio", rsL.getBigDecimal("precio_unitario"));
                    lista.put(it);
                }
                rsL.close(); psL.close();
            }
            response.setContentType("application/json;charset=UTF-8");
            out.print(lista.toString());
            return;
        }

        // Fase 3: los materiales de un ticket finalizado ya no se corrigen tocando el stock:
        // lo que no se usó se devuelve al depósito antes de finalizar (queda en el kardex).
        if ("modificarMaterialTicket".equals(tipo) || "quitarMaterialTicket".equals(tipo)) {
            out.print("error: los materiales de un ticket finalizado no se modifican; el sobrante se devuelve al depósito antes de finalizar");
            return;
        }
        if ("modificarMaterialTicketDeshabilitado".equals(tipo)) {
            boolean esQuitar = false;
            if (!Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("error: solo el administrador puede modificar los materiales de un ticket");
                return;
            }
            Integer idMat = tryParseInt(request.getParameter("idMaterial"));
            java.math.BigDecimal cantNueva = null, precioNuevo = null;
            if (!esQuitar) {
                try { cantNueva = new java.math.BigDecimal(request.getParameter("cantidad").replace(",", ".")); } catch (Exception ex) {}
                try { precioNuevo = new java.math.BigDecimal(request.getParameter("precio").replace(",", ".")); } catch (Exception ex) {}
                if (cantNueva == null || cantNueva.signum() <= 0 || precioNuevo == null || precioNuevo.signum() < 0) {
                    out.print("error: indique una cantidad mayor a cero y un precio válido");
                    return;
                }
            }
            if (idMat == null) {
                out.print("error: material inválido");
                return;
            }
            try {
                conexion.setAutoCommit(false);
                PreparedStatement psSel = conexion.prepareStatement(
                    "SELECT tr.id_ticket, tr.id_repuesto, tr.id_insumo, tr.cantidad, t.estado "
                    + "FROM public.ticket_repuesto tr JOIN public.ticket t ON t.id_ticket = tr.id_ticket "
                    + "WHERE tr.id = ? FOR UPDATE OF tr");
                psSel.setInt(1, idMat);
                ResultSet rsSel = psSel.executeQuery();
                if (!rsSel.next()) { throw new SQLException("el material ya no existe"); }
                int idTicketMat = rsSel.getInt("id_ticket");
                boolean esRep = rsSel.getObject("id_repuesto") != null;
                int idItem = esRep ? rsSel.getInt("id_repuesto") : rsSel.getInt("id_insumo");
                java.math.BigDecimal cantAnt = rsSel.getBigDecimal("cantidad");
                String estadoTk = rsSel.getString("estado");
                rsSel.close(); psSel.close();
                if ("Cancelado".equals(estadoTk)) { throw new SQLException("el ticket está anulado"); }

                String tablaMat = esRep ? "public.catalogo_repuestos" : "public.catalogo_insumos";
                String colMat = esRep ? "id_repuesto" : "id_insumo";
                // diferencia > 0: se consume más stock; < 0 (o baja): se devuelve stock
                java.math.BigDecimal diferencia = esQuitar ? cantAnt.negate() : cantNueva.subtract(cantAnt);

                PreparedStatement psSt = conexion.prepareStatement(
                    "SELECT stock FROM " + tablaMat + " WHERE " + colMat + " = ? FOR UPDATE");
                psSt.setInt(1, idItem);
                ResultSet rsSt = psSt.executeQuery();
                java.math.BigDecimal stockActual = rsSt.next() ? rsSt.getBigDecimal(1) : null;
                rsSt.close(); psSt.close();
                if (stockActual == null) { throw new SQLException("el artículo no existe en el catálogo"); }
                if (diferencia.signum() > 0 && stockActual.compareTo(diferencia) < 0) {
                    throw new SQLException("stock insuficiente (disponible: " + stockActual.stripTrailingZeros().toPlainString() + ")");
                }
                PreparedStatement psAj = conexion.prepareStatement(
                    "UPDATE " + tablaMat + " SET stock = stock - ? WHERE " + colMat + " = ?");
                psAj.setBigDecimal(1, diferencia);
                psAj.setInt(2, idItem);
                psAj.executeUpdate();
                psAj.close();

                if (esQuitar) {
                    PreparedStatement psDel = conexion.prepareStatement("DELETE FROM public.ticket_repuesto WHERE id = ?");
                    psDel.setInt(1, idMat);
                    psDel.executeUpdate();
                    psDel.close();
                } else {
                    PreparedStatement psUp = conexion.prepareStatement(
                        "UPDATE public.ticket_repuesto SET cantidad = ?, precio_unitario = ? WHERE id = ?");
                    psUp.setBigDecimal(1, cantNueva);
                    psUp.setBigDecimal(2, precioNuevo);
                    psUp.setInt(3, idMat);
                    psUp.executeUpdate();
                    psUp.close();
                }

                // Constancia en el historial del ticket (ticket_detalle)
                PreparedStatement psHist = conexion.prepareStatement(
                    "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, ?, ?)");
                psHist.setInt(1, idTicketMat);
                psHist.setInt(2, (Integer) session.getAttribute("idUsuario"));
                psHist.setString(3, esQuitar ? "Material quitado" : "Material modificado");
                psHist.setString(4, esQuitar
                        ? "Se quitó un material (cantidad " + cantAnt.stripTrailingZeros().toPlainString() + "); el stock fue devuelto."
                        : "Cantidad " + cantAnt.stripTrailingZeros().toPlainString() + " -> " + cantNueva.stripTrailingZeros().toPlainString()
                          + ", precio unitario " + precioNuevo.stripTrailingZeros().toPlainString() + ".");
                psHist.executeUpdate();
                psHist.close();

                conexion.commit();
                out.print("success");
            } catch (Exception exMt) {
                conexion.rollback();
                out.print("error: " + exMt.getMessage());
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // 4. Tomar Ticket (DESHABILITADO)
        // 4. Tomar Ticket (autoasignación por el técnico)
        // Complementa a "asignarTecnicoManual": un ticket "Pendiente" (sin
        // técnico) puede ser tomado directamente por cualquier técnico
        // logueado, o asignado manualmente por un Administrador. Solo
        // aplica a tickets que sigan sin técnico asignado.
        if ("tomarTicket".equals(tipo)) {
            Integer idTicket = tryParseInt(request.getParameter("idTicket"));
            Integer idTecnico = (Integer) session.getAttribute("idTecnico");

            if (idTicket == null) {
                out.print("error: ticket invalido");
                return;
            }
            boolean esAdminTomar = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
            Integer idUsuarioTomar = (Integer) session.getAttribute("idUsuario");
            // Nadie toma un ticket sin revisarlo: diagnóstico, urgencia y cómo sigue
            String revDiag = request.getParameter("rev_diagnostico"), revPrio = request.getParameter("rev_prioridad"),
                   revSigue = request.getParameter("rev_sigue"), revFecha = request.getParameter("rev_fecha");
            String errRev = validarRevision(revDiag, revPrio, revSigue, revFecha);
            if (errRev != null) { out.print("error: " + errRev); return; }

            // ADMINISTRADOR: puede tomar cualquier ticket que siga activo (aunque sea de otro
            // técnico). Si además está vinculado a un técnico, el ticket queda a su nombre;
            // si no, queda en curso con el técnico que ya tenía y el admin lo atiende/cierra.
            if (esAdminTomar) {
                String sqlAdmin;
                if (idTecnico != null) {
                    sqlAdmin = "UPDATE public.ticket SET id_tecnico_asignado = ?, " +
                               "estado = CASE WHEN estado = 'Pendiente' THEN 'Asignado' ELSE estado END, " +
                               "fecha_inicio = COALESCE(fecha_inicio, CURRENT_TIMESTAMP) " +
                               "WHERE id_ticket = ? AND estado NOT IN ('Resuelto','Cerrado','Cancelado')";
                } else {
                    sqlAdmin = "UPDATE public.ticket SET " +
                               "estado = CASE WHEN estado IN ('Pendiente','Asignado') THEN 'En Proceso' ELSE estado END, " +
                               "fecha_inicio = COALESCE(fecha_inicio, CURRENT_TIMESTAMP) " +
                               "WHERE id_ticket = ? AND estado NOT IN ('Resuelto','Cerrado','Cancelado')";
                }
                int filasAdm = 0;
                try {
                    conexion.setAutoCommit(false);
                    // Transacción propia para que el trigger de historial sepa quién actúa.
                    PreparedStatement psCtxT = conexion.prepareStatement("SELECT set_config('app.current_user_id', ?, true)");
                    psCtxT.setString(1, String.valueOf(idUsuarioTomar));
                    psCtxT.execute();
                    psCtxT.close();

                    PreparedStatement psAdm = conexion.prepareStatement(sqlAdmin);
                    int pos = 1;
                    if (idTecnico != null) psAdm.setInt(pos++, idTecnico);
                    psAdm.setInt(pos, idTicket);
                    filasAdm = psAdm.executeUpdate();
                    psAdm.close();
                    if (filasAdm > 0) aplicarRevision(conexion, idTicket, revDiag, revPrio, revSigue, revFecha, idUsuarioTomar, idTecnico, true);
                    conexion.commit();
                } catch (Exception exAdm) {
                    conexion.rollback();
                    out.print("error: " + exAdm.getMessage());
                    return;
                } finally {
                    conexion.setAutoCommit(true);
                }
                out.print(filasAdm > 0 ? "success" : "error: el ticket no existe o ya está finalizado");
                return;
            }

            if (idTecnico == null) {
                out.print("error: su usuario no es un tecnico y no puede tomar tickets. Use la opcion 'Asignar' para elegir un tecnico.");
                return;
            }

            String sqlTomar = "UPDATE public.ticket SET id_tecnico_asignado = ?, " +
                    "estado = 'Asignado', fecha_inicio = COALESCE(fecha_inicio, CURRENT_TIMESTAMP) " +
                    "WHERE id_ticket = ? AND estado = 'Pendiente' AND id_tecnico_asignado IS NULL";
            int filasTomar;
            try {
                conexion.setAutoCommit(false);
                PreparedStatement psTomar = conexion.prepareStatement(sqlTomar);
                psTomar.setInt(1, idTecnico);
                psTomar.setInt(2, idTicket);
                filasTomar = psTomar.executeUpdate();
                psTomar.close();
                if (filasTomar > 0) aplicarRevision(conexion, idTicket, revDiag, revPrio, revSigue, revFecha, idUsuarioTomar, idTecnico, false);
                conexion.commit();
            } catch (Exception exT) {
                conexion.rollback();
                out.print("error: " + exT.getMessage());
                return;
            } finally {
                conexion.setAutoCommit(true);
            }

            out.print(filasTomar > 0 ? "success" : "error: el ticket ya fue tomado o asignado por otra persona");
            return;
        }

        // 4b. Primera revisión de un ticket ya asignado (el Administrador lo asignó y nadie lo revisó)
        if ("primeraRevision".equals(tipo)) {
            Integer idTicket = tryParseInt(request.getParameter("idTicket"));
            boolean esAdminRev = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
            Integer idUsuarioRev = (Integer) session.getAttribute("idUsuario");
            String revDiag = request.getParameter("rev_diagnostico"), revPrio = request.getParameter("rev_prioridad"),
                   revSigue = request.getParameter("rev_sigue"), revFecha = request.getParameter("rev_fecha");
            if (idTicket == null) { out.print("error: ticket invalido"); return; }
            String errRev = validarRevision(revDiag, revPrio, revSigue, revFecha);
            if (errRev != null) { out.print("error: " + errRev); return; }
            int filasRev;
            try {
                conexion.setAutoCommit(false);
                filasRev = aplicarRevision(conexion, idTicket, revDiag, revPrio, revSigue, revFecha, idUsuarioRev,
                                           (Integer) session.getAttribute("idTecnico"), esAdminRev);
                conexion.commit();
            } catch (Exception exR) {
                conexion.rollback();
                out.print("error: " + exR.getMessage());
                return;
            } finally {
                conexion.setAutoCommit(true);
            }
            out.print(filasRev > 0 ? "success" : "error: el ticket no es suyo o ya está finalizado");
            return;
        }

        // 5. Obtener Ticket (JSON)
        if ("obtenerTicket".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            Integer idTicket = tryParseInt(request.getParameter("idTicket"));
            Integer idTecnico = (Integer) session.getAttribute("idTecnico");
            JSONObject json = new JSONObject();

            if (idTicket == null) {
                json.put("ok", false).put("error", "ID de ticket no recibido o inválido.");
                out.print(json.toString());
                return;
            }
            boolean esAdminObt = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
            if (idTecnico == null && !esAdminObt) {
                json.put("ok", false).put("error", "Sesión inválida: No se encontró idTecnico.");
                out.print(json.toString());
                return;
            }

            String sql = "SELECT t.id_tecnico_asignado, t.numero_ticket, t.estado, t.prioridad, " +
                         "t.diagnostico, t.observacion_final, t.fecha_seguimiento, t.fecha_revision, " +
                         "e.modelo, e.codigo_patrimonial, s.nombre_sala " +
                         "FROM public.ticket t " +
                         "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo " +
                         "LEFT JOIN public.salas s ON t.id_sala = s.id_sala " +
                         "WHERE t.id_ticket = ?";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ps.setInt(1, idTicket);
            ResultSet rs = ps.executeQuery();

            if (rs.next()) {
                int asignadoA = rs.getInt("id_tecnico_asignado");
                boolean esNulo = rs.wasNull();

                if (esNulo && !esAdminObt) {
                    json.put("ok", false).put("error", "El ticket no ha sido tomado aún.");
                } else if (!esAdminObt && asignadoA != idTecnico.intValue()) {
                    json.put("ok", false).put("error", "Este ticket pertenece a otro técnico.");
                } else {
                    json.put("ok", true);
                    json.put("idTicket", idTicket);
                    json.put("numeroTicket", rs.getString("numero_ticket"));
                    json.put("estado", rs.getString("estado"));
                    json.put("prioridad", rs.getString("prioridad"));
                    json.put("revisado", rs.getTimestamp("fecha_revision") != null);
                    json.put("diagnostico", rs.getString("diagnostico") != null ? rs.getString("diagnostico") : "");
                    json.put("comentario", rs.getString("observacion_final") != null ? rs.getString("observacion_final") : "");
                    json.put("fechaSeguimiento", rs.getTimestamp("fecha_seguimiento") != null ? rs.getTimestamp("fecha_seguimiento").toString().substring(0, 10) : "");
                    String equipo = (rs.getString("modelo") != null ? rs.getString("modelo") : "Equipo General")
                            + (rs.getString("codigo_patrimonial") != null ? " (" + rs.getString("codigo_patrimonial") + ")" : "");
                    json.put("equipo", equipo);
                    json.put("sala", rs.getString("nombre_sala") != null ? rs.getString("nombre_sala") : "-");
                }
            } else {
                json.put("ok", false).put("error", "El ticket no existe.");
            }
            rs.close(); ps.close();
            out.print(json.toString());
            return;
        }

        // 6. Cargar combos
        // Fase 4: catálogo de servicios como casillas; marca los ya registrados en el ticket
        if ("cargarServicios".equals(tipo)) {
            Integer idTicketSv = tryParseInt(request.getParameter("idTicket"));
            StringBuilder sbSv = new StringBuilder();
            try (PreparedStatement psSv = conexion.prepareStatement(
                    "SELECT c.id_servicio, c.nombre_servicio, c.descripcion, " +
                    "       EXISTS (SELECT 1 FROM public.ticket_servicios ts WHERE ts.id_ticket = ? AND ts.id_servicio = c.id_servicio) AS marcado, " +
                    "       (SELECT ts.detalle FROM public.ticket_servicios ts WHERE ts.id_ticket = ? AND ts.id_servicio = c.id_servicio) AS detalle, " +
                    "       lower(trim(c.nombre_servicio)) = 'otros' AS es_otros " +
                    "FROM public.catalogo_servicios c WHERE c.activo ORDER BY (lower(trim(c.nombre_servicio)) = 'otros'), c.nombre_servicio")) {
                psSv.setInt(1, idTicketSv == null ? -1 : idTicketSv);
                psSv.setInt(2, idTicketSv == null ? -1 : idTicketSv);
                try (ResultSet rsSv = psSv.executeQuery()) {
                    while (rsSv.next()) {
                        int idSv = rsSv.getInt("id_servicio");
                        boolean otros = rsSv.getBoolean("es_otros");
                        sbSv.append("<div class='custom-control custom-checkbox'><input type='checkbox' class='custom-control-input chk-servicio").append(otros ? " chk-otros" : "").append("' id='srv_").append(idSv)
                            .append("' value='").append(idSv).append("'").append(rsSv.getBoolean("marcado") ? " checked" : "")
                            .append(otros ? " onchange=\"$('#servicioOtroTexto').toggleClass('d-none', !this.checked)\"" : "").append(">")
                            .append("<label class='custom-control-label font-weight-normal' for='srv_").append(idSv).append("'")
                            .append(rsSv.getString("descripcion") == null ? "" : " title='" + h(rsSv.getString("descripcion")) + "'").append(">")
                            .append(h(rsSv.getString("nombre_servicio"))).append("</label></div>");
                        if (otros) {
                            sbSv.append("<input type='text' id='servicioOtroTexto' maxlength='255' class='form-control form-control-sm mt-1").append(rsSv.getBoolean("marcado") ? "" : " d-none")
                                .append("' placeholder='Describa qué se hizo' aria-label='Descripción del otro servicio' value='")
                                .append(h(rsSv.getString("detalle") == null ? "" : rsSv.getString("detalle"))).append("'>");
                        }
                    }
                }
            }
            out.print(sbSv.length() == 0 ? "<span class='text-muted'>No hay servicios cargados en el catálogo.</span>" : sbSv.toString());
            return;
        }

        if ("cargarCombosTecnicoYMat".equals(tipo)) {
            response.setContentType("text/html;charset=UTF-8");

            // Combo de técnicos disponibles (solo lo usa el panel de asignación manual del admin).
            // Aislado: si falla, no debe arrastrar consigo al combo de materiales.
            StringBuilder tecHTML = new StringBuilder("<option value=''>-- Técnico --</option>");
            try {
                String sqlTec = "SELECT t.id_tecnico, p.nombre, p.apellido FROM public.tecnicos t " +
                                "JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                                "JOIN public.personas p ON u.id_persona = p.id_persona " +
                                "WHERE t.estado_disponibilidad = true ORDER BY p.apellido";
                PreparedStatement psT = conexion.prepareStatement(sqlTec);
                ResultSet rsT = psT.executeQuery();
                while (rsT.next()) {
                    tecHTML.append("<option value='").append(rsT.getInt("id_tecnico")).append("'>")
                           .append(rsT.getString("apellido")).append(", ").append(rsT.getString("nombre")).append("</option>");
                }
                rsT.close(); psT.close();
            } catch (Exception exTec) {
                System.err.println("[ordenUnificada] combo tecnicos fallo: " + exTec.getMessage());
            }

            // Combo de materiales (repuestos + insumos con stock > 0), con precio_referencia.
            // Este modulo no consulta datos de compras: el stock se gestiona en Control de Inventario.
            String matHTML = null;
            Integer idTicketMat = tryParseInt(request.getParameter("idTicket"));
            if (idTicketMat == null) {
                matHTML = "<option value=''>-- Abra un ticket para ver el material en su poder --</option>";
            } else {
                try {
                    matHTML = construirOpcionesSaldo(conexion, idTicketMat);
                } catch (Exception exSaldo) {
                    System.err.println("[ordenUnificada] combo saldo fallo: " + exSaldo.getMessage());
                }
            }
            for (int modoPrecio = 1; modoPrecio <= 2 && matHTML == null; modoPrecio++) {
                try {
                    matHTML = construirOpcionesMateriales(conexion, modoPrecio);
                } catch (Exception exMat) {
                    System.err.println("[ordenUnificada] combo materiales (modo " + modoPrecio + ") fallo: " + exMat.getMessage());
                }
            }
            if (matHTML == null) {
                matHTML = "<option value=''>-- Error al cargar articulos (ver log del servidor) --</option>";
            }

            out.print(tecHTML.toString() + "|||" + matHTML);
            return;
        }

        // 6b. Asignación / Reasignación manual de técnico
        // SOLO usuarios con rol "Administrador" pueden usarla. Cubre dos
        // casos: (a) asignar un ticket que quedó Pendiente porque no había
        // ningún técnico disponible al momento de crearse, y (b) reasignar
        // un ticket ya asignado a otro técnico.
        if ("asignarTecnicoManual".equals(tipo)) {
            Integer idUsuario = (Integer) session.getAttribute("idUsuario");
            if (idUsuario == null || !Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("error: no tiene permisos para asignar o reasignar técnicos");
                return;
            }

            Integer idTicket = tryParseInt(request.getParameter("idTicket"));
            Integer idTecnicoAsignar = tryParseInt(request.getParameter("idTecnico"));
            if (idTicket == null || idTecnicoAsignar == null) {
                out.print("error: debe seleccionar un ticket y un técnico válidos");
                return;
            }

            PreparedStatement psChk = conexion.prepareStatement(
                    "SELECT estado_disponibilidad FROM public.tecnicos WHERE id_tecnico = ?");
            psChk.setInt(1, idTecnicoAsignar);
            ResultSet rsChk = psChk.executeQuery();
            if (!rsChk.next()) {
                out.print("error: el técnico seleccionado no existe");
                rsChk.close(); psChk.close();
                return;
            }
            // El Administrador puede reasignar manualmente incluso a un técnico
            // que en este momento figure como no disponible (p. ej. una
            // excepción operativa), pero se lo advertimos explícitamente en
            // vez de fallar en silencio, ya que el combo normalmente solo
            // ofrece técnicos disponibles.
            boolean tecnicoDisponible = rsChk.getBoolean("estado_disponibilidad");
            rsChk.close(); psChk.close();

            try {
                PreparedStatement psCtx = conexion.prepareStatement("SELECT set_config('app.current_user_id', ?, true)");
                psCtx.setString(1, String.valueOf(idUsuario));
                psCtx.execute();
                psCtx.close();
            } catch (Exception e) {}

            String sqlAsig = "UPDATE public.ticket SET id_tecnico_asignado = ?, " +
                    "estado = CASE WHEN estado = 'Pendiente' THEN 'Asignado' ELSE estado END, " +
                    "fecha_inicio = COALESCE(fecha_inicio, CURRENT_TIMESTAMP) " +
                    "WHERE id_ticket = ? AND estado NOT IN ('Resuelto','Cerrado','Cancelado')";
            PreparedStatement psAsig = conexion.prepareStatement(sqlAsig);
            psAsig.setInt(1, idTecnicoAsignar);
            psAsig.setInt(2, idTicket);
            int filas = psAsig.executeUpdate();
            psAsig.close();

            if (filas == 0) {
                out.print("error: el ticket no existe o ya está finalizado");
            } else {
                out.print(tecnicoDisponible ? "success" : "success: atención, el técnico está marcado como no disponible");
            }
            return;
        }

        // 7. Procesar Cierre
        if ("procesarCierre".equals(tipo)) {
            Integer idTicket = tryParseInt(request.getParameter("idTicket"));
            String diagnostico = request.getParameter("diagnostico");
            String comentario = request.getParameter("comentario");
            String estadoFinal = request.getParameter("estado");
            String prioridad = request.getParameter("prioridad");
            String fechaSeguimientoStr = request.getParameter("fechaSeguimiento");
            Integer detCount = tryParseInt(request.getParameter("det_count"));
            Integer idUsuario = (Integer) session.getAttribute("idUsuario");
            Integer idTecnico = (Integer) session.getAttribute("idTecnico");

            // La observación final solo es obligatoria cuando el ticket se resuelve o se cierra
            boolean cierraTicket = "Resuelto".equals(estadoFinal) || "Cerrado".equals(estadoFinal);
            if (comentario == null) comentario = "";
            if (idTicket == null || diagnostico == null || diagnostico.trim().isEmpty() ||
                (cierraTicket && comentario.trim().isEmpty()) || estadoFinal == null || detCount == null) {
                out.print("error: datos incompletos");
                return;
            }
            boolean esAdminCierre = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
            if (idUsuario == null || (idTecnico == null && !esAdminCierre)) {
                out.print("error: sesión no válida");
                return;
            }
            try (PreparedStatement psRv = conexion.prepareStatement("SELECT fecha_revision FROM public.ticket WHERE id_ticket = ?")) {
                psRv.setInt(1, idTicket);
                try (ResultSet rsRv = psRv.executeQuery()) {
                    if (rsRv.next() && rsRv.getTimestamp(1) == null) {
                        out.print("error: primero hacé la primera revisión del ticket (diagnóstico, urgencia y cómo sigue)");
                        return;
                    }
                }
            }
            if (!contiene(ESTADOS_FINALIZABLES_DESDE_FORM, estadoFinal)) {
                out.print("error: estado no permitido");
                return;
            }
            if (prioridad == null || !contiene(PRIORIDADES_VALIDAS, prioridad)) {
                out.print("error: prioridad no válida");
                return;
            }

            boolean finaliza = "Resuelto".equals(estadoFinal) || "Cerrado".equals(estadoFinal);

            java.sql.Date fechaSeguimiento = null;
            if (!finaliza) {
                if (fechaSeguimientoStr == null || fechaSeguimientoStr.trim().isEmpty()) {
                    out.print("error: debe indicar una fecha de seguimiento");
                    return;
                }
                try {
                    LocalDate fechaLocal = LocalDate.parse(fechaSeguimientoStr.trim());
                    if (fechaLocal.isBefore(LocalDate.now())) {
                        out.print("error: la fecha de seguimiento no puede ser anterior a hoy");
                        return;
                    }
                    fechaSeguimiento = java.sql.Date.valueOf(fechaLocal);
                } catch (Exception ex) {
                    out.print("error: fecha de seguimiento inválida");
                    return;
                }
            }

            try {
                conexion.setAutoCommit(false);

                if (idUsuario != null) {
                    try {
                        PreparedStatement psCtx = conexion.prepareStatement("SELECT set_config('app.current_user_id', ?, true)");
                        psCtx.setString(1, String.valueOf(idUsuario));
                        psCtx.execute();
                        psCtx.close();
                    } catch (Exception e) {}
                }

                String sqlUpdate;
                if (finaliza) {
                    sqlUpdate = "UPDATE public.ticket SET diagnostico = ?, observacion_final = COALESCE(?, observacion_final), estado = ?, prioridad = ?, " +
                                "fecha_seguimiento = NULL, fecha_fin = CURRENT_TIMESTAMP, " +
                                "tiempo_resolucion = EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(fecha_inicio, CURRENT_TIMESTAMP)))/60 " +
                                "WHERE id_ticket = ?" + (esAdminCierre ? "" : " AND id_tecnico_asignado = ?");
                } else {
                    sqlUpdate = "UPDATE public.ticket SET diagnostico = ?, observacion_final = COALESCE(?, observacion_final), estado = ?, prioridad = ?, " +
                                "fecha_seguimiento = ? WHERE id_ticket = ?" + (esAdminCierre ? "" : " AND id_tecnico_asignado = ?");
                }
                PreparedStatement psUp = conexion.prepareStatement(sqlUpdate);
                psUp.setString(1, diagnostico.trim());
                psUp.setString(2, comentario.trim().isEmpty() ? null : comentario.trim());
                psUp.setString(3, estadoFinal);
                psUp.setString(4, prioridad);
                if (finaliza) {
                    psUp.setInt(5, idTicket);
                    if (!esAdminCierre) psUp.setInt(6, idTecnico);
                } else {
                    psUp.setDate(5, fechaSeguimiento);
                    psUp.setInt(6, idTicket);
                    if (!esAdminCierre) psUp.setInt(7, idTecnico);
                }
                int filas = psUp.executeUpdate();
                psUp.close();

                if (filas == 0) {
                    throw new SQLException(esAdminCierre ? "El ticket no existe." : "El ticket no existe o no está asignado a su cuenta.");
                }

                // Validación de materiales: cantidades enteras > 0 y stock suficiente
                // (se suman las cantidades del mismo artículo antes de comparar).
                java.util.Map<String, java.math.BigDecimal> totalPorItem = new java.util.LinkedHashMap<String, java.math.BigDecimal>();
                for (int i = 0; i < detCount; i++) {
                    String tipoChk = "R".equals(request.getParameter("det_tipo_" + i)) ? "R" : "I";
                    java.math.BigDecimal cantChk;
                    try {
                        cantChk = new java.math.BigDecimal(request.getParameter("det_cantidad_" + i).trim());
                        Integer.parseInt(request.getParameter("det_id_" + i).trim());
                    } catch (Exception exCant) {
                        throw new SQLException("cantidad de material inválida");
                    }
                    if (cantChk.signum() <= 0 || cantChk.stripTrailingZeros().scale() > 0) {
                        throw new SQLException("las cantidades de material deben ser números enteros mayores a cero");
                    }
                    String claveChk = tipoChk + "-" + request.getParameter("det_id_" + i).trim();
                    java.math.BigDecimal previo = totalPorItem.get(claveChk);
                    totalPorItem.put(claveChk, previo == null ? cantChk : previo.add(cantChk));
                }
                for (java.util.Map.Entry<String, java.math.BigDecimal> en : totalPorItem.entrySet()) {
                    boolean esRepChk = en.getKey().startsWith("R-");
                    int idChk = Integer.parseInt(en.getKey().substring(2));
                    // Fase 3: solo se puede usar el material que el técnico tiene en su poder para este ticket
                    // (entregado por el depósito y confirmado). Registrar el uso ya no descuenta stock.
                    PreparedStatement psStk = conexion.prepareStatement(
                        "SELECT COALESCE(r.nombre, i.nombre) AS nombre, v.saldo FROM (SELECT 1) x " +
                        "LEFT JOIN public.v_material_orden v ON v.tipo_orden = 'T' AND v.id_orden = ? AND v.tipo_articulo = ? AND v.id_articulo = ? " +
                        "LEFT JOIN public.catalogo_repuestos r ON ? = 'R' AND r.id_repuesto = ? " +
                        "LEFT JOIN public.catalogo_insumos i ON ? = 'I' AND i.id_insumo = ?");
                    String taChk = esRepChk ? "R" : "I";
                    psStk.setInt(1, idTicket); psStk.setString(2, taChk); psStk.setInt(3, idChk);
                    psStk.setString(4, taChk); psStk.setInt(5, idChk); psStk.setString(6, taChk); psStk.setInt(7, idChk);
                    ResultSet rsStk = psStk.executeQuery();
                    rsStk.next();
                    java.math.BigDecimal disp = rsStk.getBigDecimal("saldo");
                    String nomChk = rsStk.getString("nombre");
                    rsStk.close(); psStk.close();
                    if (disp == null || disp.compareTo(en.getValue()) < 0) {
                        throw new SQLException("no tiene en su poder suficiente " + (nomChk == null ? "material" : nomChk) + " para este ticket (en su poder: "
                            + (disp == null ? "0" : disp.stripTrailingZeros().toPlainString()) + "). Pídalo al depósito.");
                    }
                }

                for (int i = 0; i < detCount; i++) {
                    String rawTipo = request.getParameter("det_tipo_" + i);
                    int itemId = Integer.parseInt(request.getParameter("det_id_" + i));
                    double cantidad = Double.parseDouble(request.getParameter("det_cantidad_" + i));
                    double precioUnitario = Double.parseDouble(request.getParameter("det_precio_" + i));

                    String sqlDet = "INSERT INTO public.ticket_repuesto (id_ticket, id_repuesto, id_insumo, cantidad, precio_unitario) " +
                                    "VALUES (?, ?, ?, ?, ?)";
                    PreparedStatement psDet = conexion.prepareStatement(sqlDet);
                    psDet.setInt(1, idTicket);
                    if ("R".equals(rawTipo)) {
                        psDet.setInt(2, itemId);
                        psDet.setNull(3, Types.INTEGER);
                    } else {
                        psDet.setNull(2, Types.INTEGER);
                        psDet.setInt(3, itemId);
                    }
                    psDet.setDouble(4, cantidad);
                    psDet.setDouble(5, precioUnitario);
                    psDet.executeUpdate();
                    psDet.close();
                }


                // Fase 3: al finalizar, todo el material entregado para el ticket debe estar rendido
                // (usado en el ticket o devuelto) y no puede haber pedidos sin atender.
                if (finaliza) {
                    try (PreparedStatement psRend = conexion.prepareStatement(
                            "SELECT string_agg(articulo || ' (' || trim(to_char(saldo + sin_confirmar, 'FM999999990.##')) || ')', ', ') " +
                            "FROM public.v_material_orden WHERE tipo_orden = 'T' AND id_orden = ? AND (saldo > 0 OR sin_confirmar > 0)")) {
                        psRend.setInt(1, idTicket);
                        try (ResultSet rsRend = psRend.executeQuery()) {
                            if (rsRend.next() && rsRend.getString(1) != null)
                                throw new SQLException("No puede finalizar: tiene material sin usar ni devolver (" + rsRend.getString(1) + "). Regístrelo como usado o devuélvalo al depósito.");
                        }
                    }
                    // Lo que quedó esperando stock ya no hace falta: se anula con constancia
                    try (PreparedStatement psEsp = conexion.prepareStatement(
                            "UPDATE public.solicitudes_material SET estado = 'Rechazada', motivo_rechazo = 'Anulado: el ticket se finalizó sin este material', " +
                            "fecha_entrega = CURRENT_TIMESTAMP WHERE tipo_orden = 'T' AND id_orden = ? AND estado = 'En espera'")) {
                        psEsp.setInt(1, idTicket);
                        psEsp.executeUpdate();
                    }
                    try (PreparedStatement psPend = conexion.prepareStatement(
                            "SELECT count(*) FROM public.solicitudes_material WHERE tipo_orden = 'T' AND id_orden = ? AND estado = 'Pendiente'")) {
                        psPend.setInt(1, idTicket);
                        try (ResultSet rsPend = psPend.executeQuery()) {
                            if (rsPend.next() && rsPend.getInt(1) > 0)
                                throw new SQLException("No puede finalizar: hay pedidos de material pendientes de entrega para este ticket.");
                        }
                    }
                }

                // Fase 4: servicios realizados (catálogo). Se reemplaza la selección completa.
                String serviciosParam = request.getParameter("servicios");
                java.util.List<Integer> servicios = new java.util.ArrayList<Integer>();
                if (serviciosParam != null) {
                    for (String sv : serviciosParam.split(",")) {
                        Integer idSv = tryParseInt(sv);
                        if (idSv != null && !servicios.contains(idSv)) servicios.add(idSv);
                    }
                }
                if (finaliza && servicios.isEmpty()) {
                    throw new SQLException("Indique al menos un servicio realizado para resolver o cerrar el ticket.");
                }
                String servicioOtro = request.getParameter("servicioOtro") == null ? "" : request.getParameter("servicioOtro").trim();
                if (servicioOtro.length() > 255) servicioOtro = servicioOtro.substring(0, 255);
                try (PreparedStatement psDelSv = conexion.prepareStatement("DELETE FROM public.ticket_servicios WHERE id_ticket = ?")) {
                    psDelSv.setInt(1, idTicket);
                    psDelSv.executeUpdate();
                }
                if (!servicios.isEmpty()) {
                    StringBuilder nombresSv = new StringBuilder();
                    try (PreparedStatement psSv = conexion.prepareStatement(
                            "INSERT INTO public.ticket_servicios (id_ticket, id_servicio, id_usuario, detalle) " +
                            "SELECT ?, id_servicio, ?, CASE WHEN lower(trim(nombre_servicio)) = 'otros' THEN ? END FROM public.catalogo_servicios WHERE id_servicio = ? AND activo RETURNING " +
                            "(SELECT nombre_servicio FROM public.catalogo_servicios c WHERE c.id_servicio = ticket_servicios.id_servicio), detalle, " +
                            "(SELECT lower(trim(nombre_servicio)) = 'otros' FROM public.catalogo_servicios c WHERE c.id_servicio = ticket_servicios.id_servicio)")) {
                        for (Integer idSv : servicios) {
                            psSv.setInt(1, idTicket);
                            psSv.setInt(2, idUsuario);
                            psSv.setString(3, servicioOtro.isEmpty() ? null : servicioOtro);
                            psSv.setInt(4, idSv);
                            try (ResultSet rsSv = psSv.executeQuery()) {
                                if (!rsSv.next()) throw new SQLException("Uno de los servicios elegidos ya no está disponible.");
                                if (rsSv.getBoolean(3) && servicioOtro.length() < 5) throw new SQLException("Marcó \"Otros\": describa qué se hizo (al menos 5 caracteres).");
                                nombresSv.append(nombresSv.length() > 0 ? ", " : "").append(rsSv.getString(1)).append(rsSv.getString(2) == null ? "" : " (" + rsSv.getString(2) + ")");
                            }
                        }
                    }
                    if (finaliza) {
                        try (PreparedStatement psHs = conexion.prepareStatement(
                                "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, 'Servicios realizados', ?)")) {
                            psHs.setInt(1, idTicket);
                            psHs.setInt(2, idUsuario);
                            psHs.setString(3, nombresSv.toString());
                            psHs.executeUpdate();
                        }
                    }
                }

                String sqlHist = "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) " +
                                 "VALUES (?, ?, 'Observación final', ?)";
                if (!comentario.trim().isEmpty()) {
                    PreparedStatement psHist = conexion.prepareStatement(sqlHist);
                    psHist.setInt(1, idTicket);
                    psHist.setInt(2, idUsuario);
                    psHist.setString(3, comentario.trim());
                    psHist.executeUpdate();
                    psHist.close();
                }

                // El equipo no tiene arreglo: pasa a Inactivo y queda para retirar de la sala
                String bajaNumero = null;
                if (finaliza && "true".equals(request.getParameter("noReparable"))) {
                    Integer idMotivoNR = tryParseInt(request.getParameter("motivoNoReparable"));
                    Integer idEquipoNR = null; String numTicketNR = "#" + idTicket;
                    try (PreparedStatement psEq = conexion.prepareStatement("SELECT id_equipo, numero_ticket FROM public.ticket WHERE id_ticket = ?")) {
                        psEq.setInt(1, idTicket);
                        try (ResultSet rsEq = psEq.executeQuery()) {
                            if (rsEq.next()) { idEquipoNR = (Integer) rsEq.getObject(1); if (rsEq.getString(2) != null) numTicketNR = rsEq.getString(2); }
                        }
                    }
                    if (idEquipoNR == null) throw new SQLException("El ticket no tiene un equipo asociado para dar de baja.");
                    bajaNumero = bajaPorOrden(conexion, idEquipoNR, idMotivoNR, "Ticket " + numTicketNR, diagnostico, idUsuario);
                    try (PreparedStatement psHs = conexion.prepareStatement(
                            "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, 'Equipo no reparable', ?)")) {
                        psHs.setInt(1, idTicket); psHs.setInt(2, idUsuario);
                        psHs.setString(3, "El equipo pasó a inactivo" + (bajaNumero == null ? "" : " (" + bajaNumero + ")") + ". Queda para retirar de la sala.");
                        psHs.executeUpdate();
                    }
                }

                conexion.commit();
                out.print(bajaNumero == null ? "success" : "success|" + bajaNumero);

            } catch (Exception ex) {
                conexion.rollback();
                out.print("Error: " + mensajeError(ex));
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // Motivos posibles cuando el equipo no tiene arreglo (no se descuenta: sigue en el inventario)
        if ("motivosNoReparable".equals(tipo)) {
            StringBuilder sbM = new StringBuilder();
            try (ResultSet rsM = conexion.prepareStatement(
                    "SELECT id_motivo, nombre_motivo FROM public.motivos_inactivo WHERE activo AND aplica_equipos AND NOT descuenta " +
                    "AND lower(nombre_motivo) NOT LIKE 'correcci%' ORDER BY (lower(nombre_motivo) LIKE 'daño%') DESC, nombre_motivo").executeQuery()) {
                while (rsM.next()) sbM.append("<option value='").append(rsM.getInt(1)).append("'>").append(h(rsM.getString(2))).append("</option>");
            }
            out.print(sbM);
            return;
        }

        // 8-bis. Comprobante en PDF formal (JasperReports, con membrete)
        if ("comprobantePdf".equals(tipo)) {
            Integer idTicketPdf = tryParseInt(request.getParameter("idTicket"));
            if (idTicketPdf == null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: ID inválido");
                return;
            }
            java.util.List<Integer> idsPdf = new java.util.ArrayList<Integer>();
            idsPdf.add(idTicketPdf);
            byte[] bytesPdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteTicket", new String[]{"comprobanteTicketMateriales", "comprobanteTicketHistorial", "comprobanteTicketAdjuntos"},
                    "ID_TICKET", idsPdf, (Integer) session.getAttribute("idUsuario"));
            response.setContentType("application/pdf");
            response.setContentLength(bytesPdf.length);
            response.setHeader("Content-Disposition", "inline; filename=comprobante_ticket_" + idTicketPdf + ".pdf");
            javax.servlet.ServletOutputStream salidaPdf = response.getOutputStream();
            salidaPdf.write(bytesPdf, 0, bytesPdf.length);
            salidaPdf.flush();
            salidaPdf.close();
            return;
        }

        // 8. Obtener comprobante (CON JSONArray)
        if ("obtenerComprobanteTicket".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            Integer idTicket = tryParseInt(request.getParameter("idTicket"));
            JSONObject json = new JSONObject();

            if (idTicket == null) {
                json.put("ok", false).put("error", "ID inválido");
                out.print(json.toString());
                return;
            }

            String sqlCab = "SELECT t.numero_ticket, t.estado, t.prioridad, t.tipo_falla, t.descripcion, " +
                            "t.diagnostico, t.observacion_final, t.fecha_creacion, t.fecha_inicio, t.fecha_fin, t.tiempo_resolucion, " +
                            "s.nombre_sala, e.codigo_patrimonial, e.modelo, " +
                            "ptec.nombre AS tec_nombre, ptec.apellido AS tec_apellido, " +
                            "psol.nombre AS sol_nombre, psol.apellido AS sol_apellido " +
                            "FROM public.ticket t " +
                            "LEFT JOIN public.salas s ON t.id_sala = s.id_sala " +
                            "LEFT JOIN public.equipos e ON t.id_equipo = e.id_equipo " +
                            "LEFT JOIN public.tecnicos tc ON t.id_tecnico_asignado = tc.id_tecnico " +
                            "LEFT JOIN public.usuarios utec ON tc.id_usuario = utec.id_usuario " +
                            "LEFT JOIN public.personas ptec ON utec.id_persona = ptec.id_persona " +
                            "LEFT JOIN public.usuarios usol ON t.id_usuario_solicita = usol.id_usuario " +
                            "LEFT JOIN public.personas psol ON usol.id_persona = psol.id_persona " +
                            "WHERE t.id_ticket = ?";
            PreparedStatement psCab = conexion.prepareStatement(sqlCab);
            psCab.setInt(1, idTicket);
            ResultSet rsCab = psCab.executeQuery();

            if (!rsCab.next()) {
                json.put("ok", false).put("error", "El ticket no existe");
                out.print(json.toString());
                return;
            }

            String sqlUsu = "SELECT p.nombre, p.apellido, d.fecha " +
                            "FROM public.ticket_detalle d " +
                            "JOIN public.usuarios u ON d.id_usuario = u.id_usuario " +
                            "JOIN public.personas p ON u.id_persona = p.id_persona " +
                            "WHERE d.id_ticket = ? ORDER BY d.fecha DESC LIMIT 1";
            PreparedStatement psUsu = conexion.prepareStatement(sqlUsu);
            psUsu.setInt(1, idTicket);
            ResultSet rsUsu = psUsu.executeQuery();
            String usuarioRegistro = "No registrado";
            if (rsUsu.next()) {
                usuarioRegistro = rsUsu.getString("apellido") + ", " + rsUsu.getString("nombre");
            }
            rsUsu.close(); psUsu.close();

            json.put("ok", true);
            json.put("idTicket", idTicket);
            json.put("numeroTicket", rsCab.getString("numero_ticket"));
            json.put("estado", rsCab.getString("estado"));
            json.put("prioridad", rsCab.getString("prioridad"));
            json.put("tipoFalla", rsCab.getString("tipo_falla") != null ? rsCab.getString("tipo_falla") : "-");
            json.put("descripcion", rsCab.getString("descripcion") != null ? rsCab.getString("descripcion") : "-");
            json.put("diagnostico", rsCab.getString("diagnostico") != null ? rsCab.getString("diagnostico") : "-");
            json.put("observacionFinal", rsCab.getString("observacion_final") != null ? rsCab.getString("observacion_final") : "-");
            json.put("sala", rsCab.getString("nombre_sala") != null ? rsCab.getString("nombre_sala") : "-");
            String equipo = rsCab.getString("modelo") != null
                    ? rsCab.getString("modelo") + " (" + rsCab.getString("codigo_patrimonial") + ")" : "-";
            json.put("equipo", equipo);
            json.put("tecnico", rsCab.getString("tec_apellido") != null
                    ? rsCab.getString("tec_apellido") + ", " + rsCab.getString("tec_nombre") : "Sin asignar");
            json.put("solicitante", rsCab.getString("sol_apellido") != null
                    ? rsCab.getString("sol_apellido") + ", " + rsCab.getString("sol_nombre") : "-");
            json.put("fechaCreacion", _fh(rsCab.getTimestamp("fecha_creacion")));
            json.put("fechaFin", _fh(rsCab.getTimestamp("fecha_fin")));
            Integer tiempoRes = rsCab.getObject("tiempo_resolucion") != null ? rsCab.getInt("tiempo_resolucion") : null;
            json.put("tiempoResolucion", tiempoRes != null ? (tiempoRes + " min") : "-");
            json.put("usuarioRegistro", usuarioRegistro);
            rsCab.close(); psCab.close();

            String sqlMat = "SELECT tr.cantidad, tr.precio_unitario, tr.subtotal, " +
                            "COALESCE(r.nombre, i.nombre) AS descripcion, " +
                            "CASE WHEN tr.id_repuesto IS NOT NULL THEN 'Repuesto' ELSE 'Insumo' END AS categoria " +
                            "FROM public.ticket_repuesto tr " +
                            "LEFT JOIN public.catalogo_repuestos r ON tr.id_repuesto = r.id_repuesto " +
                            "LEFT JOIN public.catalogo_insumos i ON tr.id_insumo = i.id_insumo " +
                            "WHERE tr.id_ticket = ?";
            PreparedStatement psMat = conexion.prepareStatement(sqlMat);
            psMat.setInt(1, idTicket);
            ResultSet rsMat = psMat.executeQuery();
            JSONArray materiales = new JSONArray();
            while (rsMat.next()) {
                JSONObject item = new JSONObject();
                item.put("categoria", rsMat.getString("categoria"));
                item.put("descripcion", rsMat.getString("descripcion"));
                item.put("cantidad", rsMat.getBigDecimal("cantidad"));
                item.put("precio", rsMat.getBigDecimal("precio_unitario"));
                item.put("subtotal", rsMat.getBigDecimal("subtotal"));
                materiales.put(item);
            }
            rsMat.close(); psMat.close();
            json.put("materiales", materiales);

            out.print(json.toString());
            return;
        }
    } catch (Exception e) {
        out.print("Error crítico en el controlador: " + e.getMessage());
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    // Arma las <option> de repuestos e insumos con stock.
    // modoPrecio: 1 = precio_referencia, 2 = sin precio (recurso si la columna falla).
    private String construirOpcionesMateriales(Connection cn, int modoPrecio) throws SQLException {
        String[][] grupos = {
            {"REPUESTOS", "R", "catalogo_repuestos", "id_repuesto", "Sin repuestos con stock disponible"},
            {"INSUMOS",   "I", "catalogo_insumos",   "id_insumo",   "Sin insumos con stock disponible"}
        };
        StringBuilder sb = new StringBuilder("<option value=''>-- Seleccione Artículo --</option>");
        for (String[] g : grupos) {
            String tabla = g[2], idCol = g[3];
            String precioExpr;
            if (modoPrecio == 1) {
                precioExpr = "x.precio_referencia";
            } else {
                precioExpr = "0";
            }
            PreparedStatement ps = cn.prepareStatement("SELECT x." + idCol + " AS id_item, x.nombre, x.stock, " + precioExpr +
                                                       " AS ultimo_precio FROM public." + tabla + " x WHERE x.stock > 0 ORDER BY x.nombre");
            ResultSet rs = ps.executeQuery();
            sb.append("<optgroup label='").append(g[0]).append("'>");
            int cont = 0;
            while (rs.next()) {
                cont++;
                String stockTxt = rs.getBigDecimal("stock").stripTrailingZeros().toPlainString();
                sb.append("<option value='").append(g[1]).append("-").append(rs.getInt("id_item"))
                  .append("' data-precio='").append(rs.getDouble("ultimo_precio"))
                  .append("' data-stock='").append(stockTxt).append("'>")
                  .append(h(rs.getString("nombre"))).append(" (Stock: ").append(stockTxt).append(")</option>");
            }
            rs.close(); ps.close();
            if (cont == 0) {
                sb.append("<option value='' disabled>").append(g[4]).append("</option>");
            }
            sb.append("</optgroup>");
        }
        return sb.toString();
    }

    // Fase 3: <option> con el material que el técnico tiene en su poder para el ticket
    // (entregado y confirmado, menos lo usado y lo devuelto). data-stock = saldo.
    private String construirOpcionesSaldo(Connection cn, int idTicket) throws SQLException {
        StringBuilder sb = new StringBuilder("<option value=''>-- Material en su poder --</option>");
        int cont = 0;
        try (PreparedStatement ps = cn.prepareStatement(
                "SELECT v.tipo_articulo, v.id_articulo, v.articulo, v.saldo, " +
                "       COALESCE(r.ultimo_costo, i.ultimo_costo, 0) AS costo " +
                "FROM public.v_material_orden v " +
                "LEFT JOIN public.catalogo_repuestos r ON v.tipo_articulo = 'R' AND r.id_repuesto = v.id_articulo " +
                "LEFT JOIN public.catalogo_insumos i ON v.tipo_articulo = 'I' AND i.id_insumo = v.id_articulo " +
                "WHERE v.tipo_orden = 'T' AND v.id_orden = ? AND v.saldo > 0 ORDER BY v.articulo")) {
            ps.setInt(1, idTicket);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    cont++;
                    String saldoTxt = rs.getBigDecimal("saldo").stripTrailingZeros().toPlainString();
                    sb.append("<option value='").append(rs.getString("tipo_articulo")).append("-").append(rs.getInt("id_articulo"))
                      .append("' data-precio='").append(rs.getBigDecimal("costo").toPlainString())
                      .append("' data-stock='").append(saldoTxt).append("'>")
                      .append(h(rs.getString("articulo"))).append(" (en su poder: ").append(saldoTxt).append(")</option>");
                }
            }
        }
        if (cont == 0) sb.append("<option value='' disabled>No tiene material en su poder: use \"Pedir / devolver material\"</option>");
        return sb.toString();
    }

    private Integer tryParseInt(String value) {
        if (value == null || value.trim().isEmpty()) return null;
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * Escapa caracteres HTML especiales antes de insertar texto proveniente
     * de la base de datos dentro de markup construido en el servidor
     * (nombres de sala/equipo/técnico, etc.), para prevenir XSS almacenado
     * si esos valores llegan a contener caracteres como '<', '>' o '&'.
     */
    private String esc(String valor) {
        if (valor == null) return "";
        return valor.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&#39;");
    }

    private boolean contiene(String[] arr, String valor) {
        if (valor == null) return false;
        for (String s : arr) {
            if (s.equals(valor)) return true;
        }
        return false;
    }

    private String badgePrioridad(String prioridad) {
        if (prioridad == null) return "badge-secondary";
        switch (prioridad) {
            case "Critica": return "badge-danger";
            case "Alta": return "badge-warning";
            case "Media": return "badge-info";
            default: return "badge-secondary";
        }
    }

    private String badgeEstado(String estado) {
        if (estado == null) return "badge-secondary";
        switch (estado) {
            case "Pendiente": return "badge-warning";
            case "Asignado": return "badge-primary";
            case "En Proceso": return "badge-info";
            case "Esperando Repuesto": return "badge-dark";
            case "Resuelto": case "Cerrado": return "badge-success";
            case "Cancelado": return "badge-secondary";
            default: return "badge-secondary";
        }
    }
%>