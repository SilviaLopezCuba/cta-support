<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@include file="../config/conexion.jsp"%>
<%@include file="../config/inventarioComun.jsp"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _f(java.util.Date d, String def) { return d == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _fh(java.sql.Timestamp t, String def) { return t == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
%>

<%
    // Controlador de Mantenimiento Preventivo
    String tipo = request.getParameter("tipo");

    try {
        // Contexto del usuario logueado. El servidor es la única fuente de verdad:
        // nunca se confía en lo que envíe el navegador para saber quién es o qué puede ver.
        //  - Administrador: ve y gestiona todo.
        //  - Técnico: solo ve y gestiona los mantenimientos que se le asignaron.
        boolean esAdmin = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
        Integer idTecnicoSesion = (Integer) session.getAttribute("idTecnico");
        if (!esAdmin && idTecnicoSesion == null) {
            out.print("error: su usuario no tiene permisos para gestionar mantenimientos");
            return;
        }

        // Combos: tecnicos y salas para programar
        if ("cargarCombosProgramar".equals(tipo)) {
            if (!esAdmin) {
                out.print("error: solo el administrador puede programar mantenimientos");
                return;
            }
            StringBuilder tecHTML = new StringBuilder("<option value=''>-- Seleccione Técnico --</option>");
            PreparedStatement psT = conexion.prepareStatement(
                "SELECT t.id_tecnico, p.nombre, p.apellido FROM public.tecnicos t " +
                "JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                "JOIN public.personas p ON u.id_persona = p.id_persona " +
                // Misma regla que la asignación de tickets: solo técnicos disponibles
                "WHERE t.estado_disponibilidad = true " +
                "ORDER BY p.apellido");
            ResultSet rsT = psT.executeQuery();
            while (rsT.next()) {
                String nombreCompleto = rsT.getString("apellido") + ", " + rsT.getString("nombre");
                tecHTML.append("<option value='").append(rsT.getInt("id_tecnico")).append("'>")
                       .append(nombreCompleto)
                       .append("</option>");
            }
            rsT.close(); psT.close();

            // Fase 5: salas agrupadas por departamento; el Depósito primero (para reparar equipos)
            StringBuilder salaHTML = new StringBuilder("<option value=''>-- Seleccione Sala --</option>");
            PreparedStatement psS = conexion.prepareStatement(
                "SELECT s.id_sala, s.nombre_sala, s.es_deposito, COALESCE(d.nombre_departamento, 'Sin departamento') AS depto " +
                "FROM public.salas s LEFT JOIN public.departamentos d ON d.id_departamento = s.id_departamento " +
                "ORDER BY s.es_deposito DESC, d.nombre_departamento NULLS LAST, s.nombre_sala");
            ResultSet rsS = psS.executeQuery();
            String grupoSala = null;
            while (rsS.next()) {
                boolean dep = rsS.getBoolean("es_deposito");
                String grupo = dep ? "Depósito (reparación de equipos)" : "Dpto. " + rsS.getString("depto");
                if (!grupo.equals(grupoSala)) {
                    if (grupoSala != null) salaHTML.append("</optgroup>");
                    salaHTML.append("<optgroup label='").append(h(grupo)).append("'>");
                    grupoSala = grupo;
                }
                salaHTML.append("<option value='").append(rsS.getInt("id_sala")).append("' data-deposito='").append(dep).append("'>")
                        .append(h(rsS.getString("nombre_sala"))).append("</option>");
            }
            if (grupoSala != null) salaHTML.append("</optgroup>");
            rsS.close(); psS.close();

            out.print(tecHTML.toString() + "|||" + salaHTML.toString());
            return;
        }

        // Equipos de una sala
        if ("cargarEquiposPorSala".equals(tipo)) {
            if (!esAdmin) {
                out.print("error: solo el administrador puede programar mantenimientos");
                return;
            }
            Integer idSala = tryParseInt(request.getParameter("idSala"));
            if (idSala == null) {
                out.print("");
                return;
            }
            // Fase 5: en una sala, los equipos activos; en el Depósito, también los inactivos que se
            // pueden reparar (descompuesto / daño). Un equipo en otro mantenimiento abierto no se repite.
            String sql = "SELECT e.id_equipo, e.codigo_patrimonial, e.modelo, e.estado, c.nombre_categoria, mi.nombre_motivo, " +
                         "       (SELECT m.numero_mantenimiento FROM public.mantenimientos_preventivos_detalle d " +
                         "        JOIN public.mantenimientos_preventivos m ON m.id_mantenimiento = d.id_mantenimiento " +
                         "        WHERE d.id_equipo = e.id_equipo AND m.estado IN ('Programado', 'En Proceso') LIMIT 1) AS en_mantenimiento " +
                         "FROM public.equipos e " +
                         "JOIN public.salas s ON s.id_sala = e.id_sala " +
                         "LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria " +
                         "LEFT JOIN public.motivos_inactivo mi ON mi.id_motivo = e.id_motivo_inactivo " +
                         "WHERE e.id_sala = ? AND (e.estado = 'Activo' OR (s.es_deposito AND NOT COALESCE(mi.descuenta, false))) " +
                         "ORDER BY e.estado, c.nombre_categoria, e.codigo_patrimonial NULLS LAST, e.id_equipo";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ps.setInt(1, idSala);
            ResultSet rs = ps.executeQuery();
            StringBuilder html = new StringBuilder();
            int cont = 0, ocupados = 0;
            while (rs.next()) {
                cont++;
                int idEq = rs.getInt("id_equipo");
                String ocupado = rs.getString("en_mantenimiento");
                if (ocupado != null) ocupados++;
                String modelo = rs.getString("modelo") != null ? rs.getString("modelo") : "Equipo General";
                html.append("<div class='custom-control custom-checkbox mb-1'>")
                    .append("<input type='checkbox' class='custom-control-input chk-equipo' id='eq_").append(idEq).append("' value='").append(idEq).append("'")
                    .append(ocupado != null ? " disabled" : "").append(">")
                    .append("<label class='custom-control-label' for='eq_").append(idEq).append("'>")
                    .append(rs.getString("nombre_categoria") == null ? "" : "<span class='text-muted'>" + h(rs.getString("nombre_categoria")) + ":</span> ")
                    .append(h(rs.getString("codigo_patrimonial") == null ? "Sin código" : rs.getString("codigo_patrimonial"))).append(" - ").append(h(modelo))
                    .append("Inactivo".equals(rs.getString("estado")) ? " <span class='badge badge-secondary'>" + h(rs.getString("nombre_motivo")) + "</span>" : "")
                    .append(ocupado != null ? " <span class='text-danger small'>— está en " + h(ocupado) + " (sin terminar). Terminalo o cancelalo para poder elegirlo.</span>" : "")
                    .append("</label></div>");
            }
            rs.close(); ps.close();
            if (cont == 0) {
                html.append("<span class='text-muted small'>Esta sala no tiene equipos para mantenimiento.</span>");
            } else {
                if (ocupados > 0) {
                    html.insert(0, "<div class='alert alert-warning py-1 px-2 mb-2 small'>" + (ocupados == cont
                        ? "Todos los equipos de esta sala ya están en un mantenimiento sin terminar. Terminá o cancelá ese mantenimiento para programar otro."
                        : ocupados + " de " + cont + " equipos ya están en otro mantenimiento sin terminar y no se pueden elegir.") + "</div>");
                }
                html.insert(ocupados > 0 ? html.indexOf("</div>") + 6 : 0, "<div class='custom-control custom-checkbox mb-2 border-bottom pb-1'><input type='checkbox' class='custom-control-input' id='eq_todos' "
                        + "onclick=\"$('.chk-equipo:not(:disabled)').prop('checked', this.checked)\"><label class='custom-control-label font-weight-bold' for='eq_todos'>"
                        + "Seleccionar todos (" + cont + ")</label></div>");
            }
            out.print(html.toString());
            return;
        }

        // Fase 5: calendario del mes (todos los roles con acceso; el técnico ve solo los suyos)
        if ("calendario".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            String mes = request.getParameter("mes");   // yyyy-MM
            java.time.YearMonth ym;
            try { ym = java.time.YearMonth.parse(mes); } catch (Exception exMes) { ym = java.time.YearMonth.now(); }
            JSONArray lista = new JSONArray();
            try (PreparedStatement psCal = conexion.prepareStatement(
                    "SELECT m.id_mantenimiento, m.numero_mantenimiento, m.fecha_programada, m.estado, s.nombre_sala, " +
                    "       COALESCE(p.apellido || ', ' || p.nombre, '-') AS tecnico, " +
                    "       (SELECT count(*) FROM public.mantenimientos_preventivos_detalle d WHERE d.id_mantenimiento = m.id_mantenimiento) AS equipos " +
                    "FROM public.mantenimientos_preventivos m " +
                    "LEFT JOIN public.salas s ON s.id_sala = m.id_sala " +
                    "LEFT JOIN public.tecnicos t ON t.id_tecnico = COALESCE(m.id_tecnico_ejecuta, m.id_tecnico) " +
                    "LEFT JOIN public.usuarios u ON u.id_usuario = t.id_usuario LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "WHERE m.fecha_programada >= ? AND m.fecha_programada < ? AND m.estado <> 'Cancelado' " +
                    (esAdmin ? "" : "AND (m.id_tecnico = ? OR m.id_tecnico_ejecuta = ?) ") +
                    "ORDER BY m.fecha_programada, m.numero_mantenimiento")) {
                psCal.setDate(1, java.sql.Date.valueOf(ym.atDay(1)));
                psCal.setDate(2, java.sql.Date.valueOf(ym.plusMonths(1).atDay(1)));
                if (!esAdmin) { psCal.setInt(3, idTecnicoSesion); psCal.setInt(4, idTecnicoSesion); }
                try (ResultSet rsCal = psCal.executeQuery()) {
                    while (rsCal.next()) {
                        lista.put(new JSONObject()
                            .put("fecha", rsCal.getDate("fecha_programada").toString())
                            .put("numero", rsCal.getString("numero_mantenimiento"))
                            .put("estado", rsCal.getString("estado"))
                            .put("sala", rsCal.getString("nombre_sala") == null ? "-" : rsCal.getString("nombre_sala"))
                            .put("tecnico", rsCal.getString("tecnico"))
                            .put("equipos", rsCal.getInt("equipos")));
                    }
                }
            }
            out.print(new JSONObject().put("mes", ym.toString()).put("items", lista).toString());
            return;
        }

        // Programar Mantenimiento - CORREGIDO CON LOGS
        if ("programarMantenimiento".equals(tipo)) {
            if (!esAdmin) {
                out.print("error: solo el administrador puede programar mantenimientos");
                return;
            }
            try {
                Integer idUsuario = (Integer) session.getAttribute("idUsuario");
                String idTecnicoStr = request.getParameter("idTecnico");
                String idSalaStr = request.getParameter("idSala");
                String fechaProgramada = request.getParameter("fechaProgramada");
                String observaciones = request.getParameter("observaciones");
                String eqCountStr = request.getParameter("eq_count");

                // Validaciones
                if (idUsuario == null) {
                    out.print("error: sesion no valida - idUsuario es null");
                    return;
                }
                
                Integer idTecnico = tryParseInt(idTecnicoStr);
                Integer idSala = tryParseInt(idSalaStr);
                Integer eqCount = tryParseInt(eqCountStr);

                if (idTecnico == null || idTecnico <= 0) {
                    out.print("error: seleccione un tecnico valido - valor recibido: " + idTecnicoStr);
                    return;
                }
                if (idSala == null || idSala <= 0) {
                    out.print("error: seleccione una sala valida - valor recibido: " + idSalaStr);
                    return;
                }
                if (fechaProgramada == null || fechaProgramada.trim().isEmpty()) {
                    out.print("error: seleccione una fecha programada");
                    return;
                }
                try {
                    if (java.time.LocalDate.parse(fechaProgramada.trim()).isBefore(java.time.LocalDate.now())) {
                        out.print("error: la fecha programada no puede ser anterior a hoy");
                        return;
                    }
                } catch (Exception exFecha) {
                    out.print("error: fecha programada inválida");
                    return;
                }
                if (eqCount == null || eqCount == 0) {
                    out.print("error: seleccione al menos un equipo - eqCount: " + eqCountStr);
                    return;
                }

                // Verificar que los IDs existen en la base de datos

                // Verificar tecnico
                PreparedStatement psVerif = conexion.prepareStatement("SELECT id_tecnico FROM public.tecnicos WHERE id_tecnico = ?");
                psVerif.setInt(1, idTecnico);
                ResultSet rsVerif = psVerif.executeQuery();
                if (!rsVerif.next()) {
                    rsVerif.close(); psVerif.close();
                    out.print("error: el tecnico con ID " + idTecnico + " no existe");
                    return;
                }
                rsVerif.close(); psVerif.close();

                // Verificar sala
                psVerif = conexion.prepareStatement("SELECT id_sala FROM public.salas WHERE id_sala = ?");
                psVerif.setInt(1, idSala);
                rsVerif = psVerif.executeQuery();
                if (!rsVerif.next()) {
                    rsVerif.close(); psVerif.close();
                    out.print("error: la sala con ID " + idSala + " no existe");
                    return;
                }
                rsVerif.close(); psVerif.close();

                // Verificar equipos
                for (int i = 0; i < eqCount; i++) {
                    String eqIdParam = request.getParameter("eq_id_" + i);
                    if (eqIdParam == null || eqIdParam.trim().isEmpty()) {
                        out.print("error: no se recibio el equipo " + i);
                        return;
                    }
                    int idEquipo = Integer.parseInt(eqIdParam.trim());
                    
                    psVerif = conexion.prepareStatement(
                        "SELECT e.id_equipo, " +
                        "       EXISTS (SELECT 1 FROM public.mantenimientos_preventivos_detalle d JOIN public.mantenimientos_preventivos m ON m.id_mantenimiento = d.id_mantenimiento " +
                        "               WHERE d.id_equipo = e.id_equipo AND m.estado IN ('Programado', 'En Proceso')) AS ocupado " +
                        "FROM public.equipos e WHERE e.id_equipo = ? AND e.id_sala = ?");
                    psVerif.setInt(1, idEquipo);
                    psVerif.setInt(2, idSala);
                    rsVerif = psVerif.executeQuery();
                    if (!rsVerif.next()) {
                        rsVerif.close(); psVerif.close();
                        out.print("error: un equipo elegido no pertenece a la sala seleccionada");
                        return;
                    }
                    if (rsVerif.getBoolean("ocupado")) {
                        rsVerif.close(); psVerif.close();
                        out.print("error: un equipo elegido ya está en otro mantenimiento abierto");
                        return;
                    }
                    rsVerif.close(); psVerif.close();
                }

                conexion.setAutoCommit(false);

                PreparedStatement psCab = conexion.prepareStatement(
                    "INSERT INTO public.mantenimientos_preventivos (id_tecnico, id_sala, fecha_programada, observaciones) " +
                    "VALUES (?, ?, ?, ?) RETURNING id_mantenimiento, numero_mantenimiento");
                psCab.setInt(1, idTecnico);
                psCab.setInt(2, idSala);
                psCab.setDate(3, java.sql.Date.valueOf(fechaProgramada));
                psCab.setString(4, observaciones != null && !observaciones.trim().isEmpty() ? observaciones.trim() : null);
                
                ResultSet rsCab = psCab.executeQuery();
                
                if (!rsCab.next()) {
                    String msg = "error: no se pudo insertar el mantenimiento - no retorno ID";
                    System.out.println("ERROR: " + msg);
                    rsCab.close(); psCab.close();
                    out.print(msg);
                    return;
                }
                
                int idMantenimiento = rsCab.getInt("id_mantenimiento");
                String numeroGenerado = rsCab.getString("numero_mantenimiento");
                rsCab.close(); psCab.close();

                int equiposInsertados = 0;
                for (int i = 0; i < eqCount; i++) {
                    String eqIdParam = request.getParameter("eq_id_" + i);
                    int idEquipo = Integer.parseInt(eqIdParam.trim());
                    
                    PreparedStatement psDet = conexion.prepareStatement(
                        "INSERT INTO public.mantenimientos_preventivos_detalle (id_mantenimiento, id_equipo) VALUES (?, ?)");
                    psDet.setInt(1, idMantenimiento);
                    psDet.setInt(2, idEquipo);
                    int res = psDet.executeUpdate();
                    psDet.close();
                    
                    if (res > 0) {
                        equiposInsertados++;
                    }
                }

                if (equiposInsertados == 0) {
                    throw new Exception("No se pudo insertar ningun equipo en el mantenimiento");
                }

                conexion.commit();

                // RESPUESTA EXITOSA - SOLO "success"
                out.print("success");
                
            } catch (Exception ex) {
                conexion.rollback();
                ex.printStackTrace();
                out.print("error: " + ex.getMessage());
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // Bandeja 1: Programados (sin tomar)
        //  - Administrador: ve TODOS y puede asignar/reasignar el técnico.
        //  - Técnico: ve SOLO los que se le asignaron (id_tecnico = él) y puede tomarlos.
        // Anular mantenimiento preventivo (SOLO Administrador). Cabecera + detalle en UNA transacción:
        //  - solo si está 'Programado' o 'En Proceso' (los 'Finalizado' ya cerraron sus materiales)
        //  - devuelve al stock los materiales ya consumidos (mantenimiento_repuesto)
        //  - deja constancia: motivo/fecha/usuario en la cabecera y el motivo en la observación de cada equipo
        // El estado Cancelado fue eliminado del sistema: la acción queda deshabilitada.
        if ("anularMantenimiento".equals(tipo)) {
            out.print("error: la anulación de mantenimientos fue deshabilitada");
            return;
        }
        if ("anularMantenimientoDeshabilitado".equals(tipo)) {
            Integer idUsuarioAnula = (Integer) session.getAttribute("idUsuario");
            if (idUsuarioAnula == null || !esAdmin) {
                out.print("error: solo el administrador puede anular mantenimientos");
                return;
            }
            Integer idManAnula = tryParseInt(request.getParameter("idMantenimiento"));
            String motivoAnula = request.getParameter("motivo");
            if (idManAnula == null || motivoAnula == null || motivoAnula.trim().length() < 5) {
                out.print("error: indique el mantenimiento y un motivo de al menos 5 caracteres");
                return;
            }
            try {
                conexion.setAutoCommit(false);

                PreparedStatement psEst = conexion.prepareStatement(
                    "SELECT estado FROM public.mantenimientos_preventivos WHERE id_mantenimiento = ? FOR UPDATE");
                psEst.setInt(1, idManAnula);
                ResultSet rsEst = psEst.executeQuery();
                String estadoActual = rsEst.next() ? rsEst.getString(1) : null;
                rsEst.close(); psEst.close();
                if (!"Programado".equals(estadoActual) && !"En Proceso".equals(estadoActual)) {
                    throw new SQLException("El mantenimiento no existe o ya está finalizado/cancelado.");
                }

                // Devolver al stock lo consumido por este mantenimiento
                PreparedStatement psMat = conexion.prepareStatement(
                    "SELECT mr.id_repuesto, mr.id_insumo, mr.cantidad FROM public.mantenimiento_repuesto mr "
                    + "JOIN public.mantenimientos_preventivos_detalle d ON mr.id_detalle = d.id_detalle "
                    + "WHERE d.id_mantenimiento = ?");
                psMat.setInt(1, idManAnula);
                ResultSet rsMat = psMat.executeQuery();
                while (rsMat.next()) {
                    boolean esRepuesto = rsMat.getObject("id_repuesto") != null;
                    int idItem = esRepuesto ? rsMat.getInt("id_repuesto") : rsMat.getInt("id_insumo");
                    String tablaItem = esRepuesto ? "public.catalogo_repuestos" : "public.catalogo_insumos";
                    String colItem = esRepuesto ? "id_repuesto" : "id_insumo";
                    PreparedStatement psRev = conexion.prepareStatement(
                        "UPDATE " + tablaItem + " SET stock = stock + ? WHERE " + colItem + " = ?");
                    psRev.setBigDecimal(1, rsMat.getBigDecimal("cantidad"));
                    psRev.setInt(2, idItem);
                    psRev.executeUpdate();
                    psRev.close();
                }
                rsMat.close(); psMat.close();

                // Constancia en el detalle (observación de cada equipo)
                PreparedStatement psDet = conexion.prepareStatement(
                    "UPDATE public.mantenimientos_preventivos_detalle "
                    + "SET observacion = CASE WHEN observacion IS NULL OR observacion = '' THEN '' ELSE observacion || ' | ' END || ? "
                    + "WHERE id_mantenimiento = ?");
                psDet.setString(1, "Anulado: " + motivoAnula.trim());
                psDet.setInt(2, idManAnula);
                psDet.executeUpdate();
                psDet.close();

                PreparedStatement psAn = conexion.prepareStatement(
                    "UPDATE public.mantenimientos_preventivos SET estado = 'Cancelado', motivo_anulacion = ?, "
                    + "fecha_anulacion = CURRENT_TIMESTAMP, id_usuario_anula = ? WHERE id_mantenimiento = ?");
                psAn.setString(1, motivoAnula.trim());
                psAn.setInt(2, idUsuarioAnula);
                psAn.setInt(3, idManAnula);
                psAn.executeUpdate();
                psAn.close();

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

        if ("listarProgramados".equals(tipo)) {
            String comboTecnicosHtml = esAdmin ? comboTecnicos(conexion) : "";

            String sql = "SELECT m.id_mantenimiento, m.numero_mantenimiento, m.fecha_programada, m.id_tecnico, " +
                         "s.nombre_sala, p.nombre AS tec_nombre, p.apellido AS tec_apellido, " +
                         "(SELECT COUNT(*) FROM public.mantenimientos_preventivos_detalle d WHERE d.id_mantenimiento = m.id_mantenimiento) AS cant_equipos " +
                         "FROM public.mantenimientos_preventivos m " +
                         "LEFT JOIN public.salas s ON m.id_sala = s.id_sala " +
                         "LEFT JOIN public.tecnicos t ON m.id_tecnico = t.id_tecnico " +
                         "LEFT JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                         "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                         "WHERE m.estado = 'Programado' " +
                         (esAdmin ? "" : "AND m.id_tecnico = ? ") +
                         "ORDER BY m.fecha_programada ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            if (!esAdmin) ps.setInt(1, idTecnicoSesion);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                int idManRow = rs.getInt("id_mantenimiento");
                int idTecRow = rs.getInt("id_tecnico");
                String tecnico = rs.getString("tec_apellido") != null
                        ? rs.getString("tec_apellido") + ", " + rs.getString("tec_nombre") : "Sin asignar";
                String sala = rs.getString("nombre_sala") != null ? rs.getString("nombre_sala") : "Sin sala";
                // Deja preseleccionado en el combo al técnico actualmente asignado
                String comboFila = comboTecnicosHtml.replace("value='" + idTecRow + "'", "value='" + idTecRow + "' selected");
%>
                <tr>
                    <td><%= rs.getString("numero_mantenimiento") %></td>
                    <td><%= _f(rs.getDate("fecha_programada")) %></td>
                    <td><span class="badge badge-info"><%= sala %></span></td>
                    <td><%= tecnico %></td>
                    <td class="text-center"><span class="badge badge-secondary"><%= rs.getInt("cant_equipos") %></span></td>
                    <td class="text-center">
<%                      if (esAdmin) { %>
                        <button class="btn btn-warning btn-sm font-weight-bold shadow-sm mb-1" title="Tomar este mantenimiento yo mismo (Administrador)" onclick="tomarMantenimiento(<%= idManRow %>, this)">
                            <i class="fas fa-hands-helping"></i> Tomar
                        </button>
                        <div class="input-group input-group-sm" style="min-width:190px;">
                            <select class="form-control form-control-sm" id="selTecAdminMan_<%= idManRow %>"><%= comboFila %></select>
                            <div class="input-group-append">
                                <button class="btn btn-outline-primary btn-sm" title="Asignar / reasignar técnico"
                                        onclick="asignarMantenimiento(<%= idManRow %>, document.getElementById('selTecAdminMan_<%= idManRow %>').value)">
                                    <i class="fas fa-user-cog"></i> Asignar
                                </button>
                            </div>
                        </div>
<%                      } else { %>
                        <button class="btn btn-warning btn-sm font-weight-bold shadow-sm" onclick="tomarMantenimiento(<%= idManRow %>, this)">
                            <i class="fas fa-hands-helping"></i> Tomar
                        </button>
<%                      } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='6' class='text-center text-muted py-3'>" +
                          (esAdmin ? "No hay mantenimientos programados." : "No tienes mantenimientos asignados pendientes.") +
                          "</td></tr>");
            }
            return;
        }

        // Asignar / Reasignar Mantenimiento (SOLO Administrador)
        //  - Programado: cambia el técnico asignado. El mantenimiento sigue
        //    "Programado" y el técnico deberá tomarlo él mismo.
        //  - En Proceso: traspasa el mantenimiento (y su avance) al nuevo técnico.
        if ("asignarMantenimiento".equals(tipo)) {
            if (!esAdmin) {
                out.print("error: no tiene permisos para asignar mantenimientos");
                return;
            }

            Integer idMantenimiento = tryParseInt(request.getParameter("idMantenimiento"));
            Integer idTecnicoAsignar = tryParseInt(request.getParameter("idTecnico"));
            if (idMantenimiento == null || idTecnicoAsignar == null) {
                out.print("error: debe seleccionar un mantenimiento y un tecnico validos");
                return;
            }

            PreparedStatement psChk = conexion.prepareStatement("SELECT id_tecnico FROM public.tecnicos WHERE id_tecnico = ?");
            psChk.setInt(1, idTecnicoAsignar);
            ResultSet rsChk = psChk.executeQuery();
            if (!rsChk.next()) {
                rsChk.close(); psChk.close();
                out.print("error: el tecnico seleccionado no existe");
                return;
            }
            rsChk.close(); psChk.close();

            String sqlAsig = "UPDATE public.mantenimientos_preventivos SET id_tecnico = ?, " +
                             "id_tecnico_ejecuta = CASE WHEN estado = 'En Proceso' THEN ? ELSE id_tecnico_ejecuta END " +
                             "WHERE id_mantenimiento = ? AND estado IN ('Programado', 'En Proceso')";
            PreparedStatement psAsig = conexion.prepareStatement(sqlAsig);
            psAsig.setInt(1, idTecnicoAsignar);
            psAsig.setInt(2, idTecnicoAsignar);
            psAsig.setInt(3, idMantenimiento);
            int filas = psAsig.executeUpdate();
            psAsig.close();

            out.print(filas > 0 ? "success" : "error: el mantenimiento ya esta finalizado o no existe");
            return;
        }

        // Bandeja 2: En Curso
        //  - Técnico: solo los suyos (id_tecnico_ejecuta = él).
        //  - Administrador: todos, con opción de ver/gestionar y reasignar.
        if ("listarEnCurso".equals(tipo)) {
            String comboTecnicosHtml = esAdmin ? comboTecnicos(conexion) : "";
            int cols = esAdmin ? 7 : 6;

            String sql = "SELECT m.id_mantenimiento, m.numero_mantenimiento, m.fecha_programada, m.id_tecnico_ejecuta, s.nombre_sala, " +
                         sqlMaterialOrden("M", "m.id_mantenimiento") + ", " +
                         "p.nombre AS tec_nombre, p.apellido AS tec_apellido, " +
                         "(SELECT COUNT(*) FROM public.mantenimientos_preventivos_detalle d WHERE d.id_mantenimiento = m.id_mantenimiento) AS total_eq, " +
                         "(SELECT COUNT(*) FROM public.mantenimientos_preventivos_detalle d WHERE d.id_mantenimiento = m.id_mantenimiento AND d.realizado = true) AS eq_ok " +
                         "FROM public.mantenimientos_preventivos m " +
                         "LEFT JOIN public.salas s ON m.id_sala = s.id_sala " +
                         "LEFT JOIN public.tecnicos t ON m.id_tecnico_ejecuta = t.id_tecnico " +
                         "LEFT JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                         "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                         "WHERE m.estado = 'En Proceso' " +
                         (esAdmin ? "" : "AND m.id_tecnico_ejecuta = ? ") +
                         "ORDER BY m.fecha_programada ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            if (!esAdmin) ps.setInt(1, idTecnicoSesion);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                int idManRow = rs.getInt("id_mantenimiento");
                int idTecRow = rs.getInt("id_tecnico_ejecuta");
                String tecnico = rs.getString("tec_apellido") != null
                        ? rs.getString("tec_apellido") + ", " + rs.getString("tec_nombre") : "-";
                String comboFila = comboTecnicosHtml.replace("value='" + idTecRow + "'", "value='" + idTecRow + "' selected");
%>
                <tr>
                    <td><%= rs.getString("numero_mantenimiento") %></td>
                    <td><span class="badge badge-info"><%= rs.getString("nombre_sala") %></span></td>
                    <td><%= _f(rs.getDate("fecha_programada")) %></td>
<%                  if (esAdmin) { %>
                    <td><%= tecnico %></td>
<%                  } %>
                    <td class="text-center"><span class="badge badge-secondary"><%= rs.getInt("eq_ok") %> / <%= rs.getInt("total_eq") %></span>
<%                  if (rs.getInt("mat_detiene") > 0) { %>
                        <div class="mt-1"><span class="badge badge-dark" title="El técnico indicó que no puede seguir hasta que llegue el material">Detenido: esperando material</span></div>
<%                  } %>
                    </td>
                    <td><%= badgeMaterial(rs) %></td>
                    <td class="text-center">
<%                  if (esAdmin) { %>
<%                      boolean esMioAdm = idTecnicoSesion != null && idTecRow == idTecnicoSesion.intValue(); %>
                        <button class="btn btn-warning btn-sm font-weight-bold shadow-sm mb-1" title="Tomar este mantenimiento (se conserva el avance)"
                                data-tecnico="<%= h(tecnico) %>" data-mio="<%= esMioAdm ? "1" : "0" %>" onclick="tomarMantenimientoEnCurso(<%= idManRow %>, this)">
                            <i class="fas fa-hands-helping"></i> Tomar
                        </button>
                        <div class="input-group input-group-sm" style="min-width:230px;">
                            <select class="form-control form-control-sm" id="selTecAdminCurso_<%= idManRow %>"><%= comboFila %></select>
                            <div class="input-group-append">
                                <button class="btn btn-outline-primary btn-sm" title="Reasignar técnico"
                                        onclick="asignarMantenimiento(<%= idManRow %>, document.getElementById('selTecAdminCurso_<%= idManRow %>').value)">
                                    <i class="fas fa-user-cog"></i>
                                </button>
                                <button class="btn btn-primary btn-sm" title="Ver / gestionar" onclick="continuarMantenimiento(<%= idManRow %>)">
                                    <i class="fas fa-eye"></i>
                                </button>
                            </div>
                        </div>
<%                  } else { %>
                        <button class="btn btn-primary btn-sm font-weight-bold shadow-sm" onclick="continuarMantenimiento(<%= idManRow %>)">
                            <i class="fas fa-redo"></i> Continuar
                        </button>
<%                  } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='" + cols + "' class='text-center text-muted py-3'>" +
                          (esAdmin ? "No hay mantenimientos en curso." : "No tienes mantenimientos en curso.") +
                          "</td></tr>");
            }
            return;
        }

        // Tomar Mantenimiento
        // Solo el técnico al que el administrador se lo asignó puede tomarlo.
        if ("tomarMantenimiento".equals(tipo)) {
            Integer idMantenimiento = tryParseInt(request.getParameter("idMantenimiento"));

            if (idMantenimiento == null) {
                out.print("error: mantenimiento invalido");
                return;
            }
            int res;
            if (esAdmin) {
                // ADMINISTRADOR: puede tomar cualquier mantenimiento programado o en curso (aunque lo
                // esté haciendo otro técnico: el avance se conserva). Si está vinculado a un técnico,
                // él pasa a figurar como ejecutor; si no, queda el técnico que ya tenía y el admin lo gestiona.
                PreparedStatement psAdm = conexion.prepareStatement(
                    "UPDATE public.mantenimientos_preventivos SET " +
                    "id_tecnico_ejecuta = COALESCE(?, id_tecnico_ejecuta, id_tecnico), estado = 'En Proceso', " +
                    "fecha_inicio = COALESCE(fecha_inicio, CURRENT_TIMESTAMP) " +
                    "WHERE id_mantenimiento = ? AND estado IN ('Programado', 'En Proceso')");
                if (idTecnicoSesion != null) psAdm.setInt(1, idTecnicoSesion); else psAdm.setNull(1, Types.INTEGER);
                psAdm.setInt(2, idMantenimiento);
                res = psAdm.executeUpdate();
                psAdm.close();
                out.print(res > 0 ? "success" : "error: el mantenimiento ya está finalizado o anulado");
                return;
            }
            if (idTecnicoSesion == null) {
                out.print("error: su usuario no es un tecnico y no puede tomar mantenimientos.");
                return;
            }

            String sqlUpdate = "UPDATE public.mantenimientos_preventivos SET id_tecnico_ejecuta = ?, estado = 'En Proceso', " +
                               "fecha_inicio = CURRENT_TIMESTAMP " +
                               "WHERE id_mantenimiento = ? AND estado = 'Programado' AND id_tecnico = ?";
            PreparedStatement ps = conexion.prepareStatement(sqlUpdate);
            ps.setInt(1, idTecnicoSesion);
            ps.setInt(2, idMantenimiento);
            ps.setInt(3, idTecnicoSesion);
            res = ps.executeUpdate();
            ps.close();

            out.print(res > 0 ? "success" : "error: el mantenimiento no esta asignado a usted, ya fue tomado o cambio de estado");
            return;
        }

        // Obtener Mantenimiento (JSON)
        // Observación inicial: lo que se encontró al llegar a la sala. Sin ella no se puede pedir material.
        if ("guardarObservacionInicial".equals(tipo)) {
            Integer idMantenimiento = tryParseInt(request.getParameter("idMantenimiento"));
            String obsIni = request.getParameter("observacion") == null ? "" : request.getParameter("observacion").trim();
            if (idMantenimiento == null) { out.print("error: mantenimiento invalido"); return; }
            if (obsIni.length() < 10) { out.print("error: escribí la observación inicial (al menos 10 caracteres): cómo encontraste la sala y los equipos"); return; }
            if (obsIni.length() > 500) obsIni = obsIni.substring(0, 500);
            if (!puedeAccederMantenimiento(conexion, idMantenimiento, esAdmin, idTecnicoSesion, true)) {
                out.print("error: no tiene permisos sobre este mantenimiento o ya no esta en proceso");
                return;
            }
            try (PreparedStatement psOi = conexion.prepareStatement(
                    "UPDATE public.mantenimientos_preventivos SET observacion_inicial = ?, fecha_observacion = COALESCE(fecha_observacion, CURRENT_TIMESTAMP) " +
                    "WHERE id_mantenimiento = ? AND estado = 'En Proceso'")) {
                psOi.setString(1, obsIni);
                psOi.setInt(2, idMantenimiento);
                out.print(psOi.executeUpdate() > 0 ? "success" : "error: el mantenimiento no está en proceso");
            }
            return;
        }

        if ("obtenerMantenimiento".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            Integer idMantenimiento = tryParseInt(request.getParameter("idMantenimiento"));
            JSONObject json = new JSONObject();

            if (idMantenimiento == null) {
                json.put("ok", false).put("error", "ID invalido");
                out.print(json.toString());
                return;
            }
            if (!puedeAccederMantenimiento(conexion, idMantenimiento, esAdmin, idTecnicoSesion, true)) {
                json.put("ok", false).put("error", "No tiene permisos sobre este mantenimiento o ya no esta en proceso");
                out.print(json.toString());
                return;
            }

            String sqlCab = "SELECT m.numero_mantenimiento, m.estado, m.fecha_programada, m.observaciones, m.observacion_inicial, s.nombre_sala, COALESCE(s.es_deposito, false) AS es_deposito, " +
                            "       (SELECT COALESCE(p.nombre || ' ' || p.apellido, u.login) FROM public.tecnicos t JOIN public.usuarios u ON u.id_usuario = t.id_usuario " +
                            "        LEFT JOIN public.personas p ON p.id_persona = u.id_persona WHERE t.id_tecnico = COALESCE(m.id_tecnico_ejecuta, m.id_tecnico)) AS tecnico " +
                            "FROM public.mantenimientos_preventivos m LEFT JOIN public.salas s ON m.id_sala = s.id_sala " +
                            "WHERE m.id_mantenimiento = ?";
            PreparedStatement psCab = conexion.prepareStatement(sqlCab);
            psCab.setInt(1, idMantenimiento);
            ResultSet rsCab = psCab.executeQuery();
            if (!rsCab.next()) {
                json.put("ok", false).put("error", "El mantenimiento no existe");
                out.print(json.toString());
                return;
            }
            json.put("ok", true);
            json.put("idMantenimiento", idMantenimiento);
            json.put("numeroMantenimiento", rsCab.getString("numero_mantenimiento"));
            json.put("estado", rsCab.getString("estado"));
            json.put("sala", rsCab.getString("nombre_sala") != null ? rsCab.getString("nombre_sala") : "-");
            json.put("esDeposito", rsCab.getBoolean("es_deposito"));
            json.put("fechaProgramada", _f(rsCab.getDate("fecha_programada")));
            json.put("observaciones", rsCab.getString("observaciones") != null ? rsCab.getString("observaciones") : "");
            json.put("tecnico", rsCab.getString("tecnico") != null ? rsCab.getString("tecnico") : "-");
            json.put("observacionInicial", rsCab.getString("observacion_inicial") != null ? rsCab.getString("observacion_inicial") : "");
            rsCab.close(); psCab.close();

            // Material usado en todo el mantenimiento (no por equipo)
            JSONArray matGlobal = new JSONArray();
            try (PreparedStatement psMg = conexion.prepareStatement(
                    "SELECT mr.id, mr.cantidad, COALESCE(r.nombre, i.nombre) AS descripcion, " +
                    "CASE WHEN mr.id_repuesto IS NOT NULL THEN 'Repuesto' ELSE 'Insumo' END AS categoria " +
                    "FROM public.mantenimiento_repuesto mr JOIN public.mantenimientos_preventivos_detalle d ON d.id_detalle = mr.id_detalle " +
                    "LEFT JOIN public.catalogo_repuestos r ON mr.id_repuesto = r.id_repuesto " +
                    "LEFT JOIN public.catalogo_insumos i ON mr.id_insumo = i.id_insumo " +
                    "WHERE d.id_mantenimiento = ? ORDER BY mr.id")) {
                psMg.setInt(1, idMantenimiento);
                try (ResultSet rsMg = psMg.executeQuery()) {
                    while (rsMg.next()) matGlobal.put(new JSONObject().put("id", rsMg.getInt("id")).put("categoria", rsMg.getString("categoria"))
                            .put("descripcion", rsMg.getString("descripcion")).put("cantidad", rsMg.getBigDecimal("cantidad").stripTrailingZeros().toPlainString()));
                }
            }
            json.put("materiales", matGlobal);

            String sqlDet = "SELECT d.id_detalle, d.id_equipo, d.realizado, d.observacion, d.resultado, " +
                            "e.codigo_patrimonial, e.modelo, e.estado AS estado_equipo, " +
                            "(SELECT COALESCE(t.numero_ticket, '#' || t.id_ticket) FROM public.ticket t WHERE t.id_ticket = d.id_ticket_derivado) AS ticket_derivado " +
                            "FROM public.mantenimientos_preventivos_detalle d JOIN public.equipos e ON d.id_equipo = e.id_equipo " +
                            "WHERE d.id_mantenimiento = ? ORDER BY e.codigo_patrimonial";
            PreparedStatement psDet = conexion.prepareStatement(sqlDet);
            psDet.setInt(1, idMantenimiento);
            ResultSet rsDet = psDet.executeQuery();
            JSONArray equipos = new JSONArray();
            while (rsDet.next()) {
                JSONObject eq = new JSONObject();
                int idDetalle = rsDet.getInt("id_detalle");
                eq.put("idDetalle", idDetalle);
                eq.put("idEquipo", rsDet.getInt("id_equipo"));
                eq.put("equipo", (rsDet.getString("codigo_patrimonial") == null ? "Sin código" : rsDet.getString("codigo_patrimonial")) + " - " + (rsDet.getString("modelo") != null ? rsDet.getString("modelo") : "Equipo General"));
                eq.put("resultado", rsDet.getString("resultado") != null ? rsDet.getString("resultado") : "");
                eq.put("ticketDerivado", rsDet.getString("ticket_derivado") != null ? rsDet.getString("ticket_derivado") : "");
                eq.put("estadoEquipo", rsDet.getString("estado_equipo"));
                eq.put("realizado", rsDet.getBoolean("realizado"));
                eq.put("observacion", rsDet.getString("observacion") != null ? rsDet.getString("observacion") : "");

                PreparedStatement psMat = conexion.prepareStatement(
                    "SELECT mr.id, mr.cantidad, COALESCE(r.nombre, i.nombre) AS descripcion, " +
                    "CASE WHEN mr.id_repuesto IS NOT NULL THEN 'Repuesto' ELSE 'Insumo' END AS categoria " +
                    "FROM public.mantenimiento_repuesto mr " +
                    "LEFT JOIN public.catalogo_repuestos r ON mr.id_repuesto = r.id_repuesto " +
                    "LEFT JOIN public.catalogo_insumos i ON mr.id_insumo = i.id_insumo " +
                    "WHERE mr.id_detalle = ? ORDER BY mr.id");
                psMat.setInt(1, idDetalle);
                ResultSet rsMat = psMat.executeQuery();
                JSONArray materiales = new JSONArray();
                while (rsMat.next()) {
                    JSONObject m = new JSONObject();
                    m.put("id", rsMat.getInt("id"));
                    m.put("categoria", rsMat.getString("categoria"));
                    m.put("descripcion", rsMat.getString("descripcion"));
                    m.put("cantidad", rsMat.getBigDecimal("cantidad"));
                    materiales.put(m);
                }
                rsMat.close(); psMat.close();
                eq.put("materiales", materiales);
                equipos.put(eq);
            }
            rsDet.close(); psDet.close();
            json.put("equipos", equipos);

            out.print(json.toString());
            return;
        }

        // Combo de Materiales
        if ("cargarComboMateriales".equals(tipo)) {
            // Se aisla en su propio try/catch para que, si algo falla, el
            // <select> reciba siempre una <option> válida en vez de texto
            // suelto (el texto de un error insertado como HTML dentro de un
            // <select> es descartado por el navegador y el combo queda
            // vacío en pantalla, aunque la petición haya "funcionado").
            response.setContentType("text/html;charset=UTF-8");
            StringBuilder matHTML = new StringBuilder("<option value=''>-- Material en su poder --</option>");
            Integer idMantMat = tryParseInt(request.getParameter("idMantenimiento"));
            try {
                // Fase 3: solo el material entregado (y confirmado) para este mantenimiento, menos lo usado y devuelto
                int contSaldo = 0;
                PreparedStatement psSaldo = conexion.prepareStatement(
                    "SELECT tipo_articulo, id_articulo, articulo, saldo FROM public.v_material_orden " +
                    "WHERE tipo_orden = 'M' AND id_orden = ? AND saldo > 0 ORDER BY articulo");
                psSaldo.setInt(1, idMantMat == null ? -1 : idMantMat);
                ResultSet rsSaldo = psSaldo.executeQuery();
                while (rsSaldo.next()) {
                    contSaldo++;
                    matHTML.append("<option value='").append(rsSaldo.getString("tipo_articulo")).append("-").append(rsSaldo.getInt("id_articulo")).append("'>")
                           .append(h(rsSaldo.getString("articulo"))).append(" (en su poder: ").append(rsSaldo.getBigDecimal("saldo").stripTrailingZeros().toPlainString()).append(")</option>");
                }
                rsSaldo.close(); psSaldo.close();
                if (contSaldo == 0) matHTML.append("<option value='' disabled>No tiene material recibido: pídalo al depósito</option>");
                if (true) { out.print(matHTML.toString()); return; }
                matHTML.append("<optgroup label='REPUESTOS'>");
                PreparedStatement psR = conexion.prepareStatement("SELECT id_repuesto, nombre, stock FROM public.catalogo_repuestos WHERE stock > 0 ORDER BY nombre");
                ResultSet rsR = psR.executeQuery();
                int contR = 0;
                while (rsR.next()) {
                    contR++;
                    matHTML.append("<option value='R-").append(rsR.getInt("id_repuesto")).append("'>")
                           .append(h(rsR.getString("nombre"))).append(" (Stock: ").append(rsR.getBigDecimal("stock").stripTrailingZeros().toPlainString()).append(")</option>");
                }
                rsR.close(); psR.close();
                if (contR == 0) {
                    matHTML.append("<option value='' disabled>Sin repuestos con stock disponible</option>");
                }
                matHTML.append("</optgroup><optgroup label='INSUMOS'>");
                PreparedStatement psI = conexion.prepareStatement("SELECT id_insumo, nombre, stock FROM public.catalogo_insumos WHERE stock > 0 ORDER BY nombre");
                ResultSet rsI = psI.executeQuery();
                int contI = 0;
                while (rsI.next()) {
                    contI++;
                    matHTML.append("<option value='I-").append(rsI.getInt("id_insumo")).append("'>")
                           .append(h(rsI.getString("nombre"))).append(" (Stock: ").append(rsI.getBigDecimal("stock").stripTrailingZeros().toPlainString()).append(")</option>");
                }
                rsI.close(); psI.close();
                if (contI == 0) {
                    matHTML.append("<option value='' disabled>Sin insumos con stock disponible</option>");
                }
                matHTML.append("</optgroup>");
            } catch (Exception exMat) {
                matHTML = new StringBuilder("<option value=''>-- Error al cargar articulos --</option>");
            }
            out.print(matHTML.toString());
            return;
        }

        // Agregar Material
        if ("agregarMaterial".equals(tipo)) {
            Integer idDetalle = tryParseInt(request.getParameter("idDetalle"));
            Integer idMantGlobal = tryParseInt(request.getParameter("idMantenimiento"));
            if (idDetalle == null && idMantGlobal != null) {
                // Material de todo el mantenimiento: se registra en el primer equipo (solo como soporte técnico del dato)
                try (PreparedStatement psPri = conexion.prepareStatement(
                        "SELECT MIN(id_detalle) FROM public.mantenimientos_preventivos_detalle WHERE id_mantenimiento = ?")) {
                    psPri.setInt(1, idMantGlobal);
                    try (ResultSet rsPri = psPri.executeQuery()) { if (rsPri.next() && rsPri.getObject(1) != null) idDetalle = rsPri.getInt(1); }
                }
            }
            String rawTipo = request.getParameter("tipoItem");
            Integer itemId = tryParseInt(request.getParameter("itemId"));
            Double cantidad = null;
            try { cantidad = Double.parseDouble(request.getParameter("cantidad")); } catch (Exception ex) {}

            if (idDetalle == null || rawTipo == null || itemId == null || cantidad == null || cantidad <= 0) {
                out.print("error: datos incompletos para registrar el material");
                return;
            }
            if (!puedeAccederDetalle(conexion, idDetalle, esAdmin, idTecnicoSesion)) {
                out.print("error: no tiene permisos sobre este mantenimiento");
                return;
            }

            try {
                String sqlIns = "INSERT INTO public.mantenimiento_repuesto (id_detalle, id_repuesto, id_insumo, cantidad) VALUES (?, ?, ?, ?)";
                PreparedStatement ps = conexion.prepareStatement(sqlIns);
                ps.setInt(1, idDetalle);
                if ("R".equals(rawTipo)) {
                    ps.setInt(2, itemId);
                    ps.setNull(3, Types.INTEGER);
                } else {
                    ps.setNull(2, Types.INTEGER);
                    ps.setInt(3, itemId);
                }
                ps.setDouble(4, cantidad);
                ps.executeUpdate();
                ps.close();
                out.print("success");
            } catch (SQLException exSql) {
                out.print("error: " + mensajeError(exSql));
            }
            return;
        }

        // Quitar Material (por si se eligió mal un artículo)
        // Solo en mantenimientos En Proceso y solo el técnico que lo ejecuta o el administrador.
        if ("quitarMaterial".equals(tipo)) {
            Integer idMaterial = tryParseInt(request.getParameter("idMaterial"));
            if (idMaterial == null) {
                out.print("error: material invalido");
                return;
            }

            PreparedStatement psDet = conexion.prepareStatement("SELECT id_detalle FROM public.mantenimiento_repuesto WHERE id = ?");
            psDet.setInt(1, idMaterial);
            ResultSet rsDet = psDet.executeQuery();
            Integer idDetalleMat = rsDet.next() ? Integer.valueOf(rsDet.getInt(1)) : null;
            rsDet.close(); psDet.close();

            if (idDetalleMat == null) {
                out.print("error: el material ya no existe");
                return;
            }
            if (!puedeAccederDetalle(conexion, idDetalleMat, esAdmin, idTecnicoSesion)) {
                out.print("error: no tiene permisos sobre este mantenimiento");
                return;
            }

            try {
                conexion.setAutoCommit(false);
                PreparedStatement psSel = conexion.prepareStatement(
                    "SELECT mr.id_repuesto, mr.id_insumo, mr.cantidad, m.estado FROM public.mantenimiento_repuesto mr "
                    + "JOIN public.mantenimientos_preventivos_detalle d ON mr.id_detalle = d.id_detalle "
                    + "JOIN public.mantenimientos_preventivos m ON d.id_mantenimiento = m.id_mantenimiento "
                    + "WHERE mr.id = ? FOR UPDATE OF mr");
                psSel.setInt(1, idMaterial);
                ResultSet rsSel = psSel.executeQuery();
                if (!rsSel.next()) { throw new SQLException("el material ya no existe"); }
                boolean esRep = rsSel.getObject("id_repuesto") != null;
                int idItem = esRep ? rsSel.getInt("id_repuesto") : rsSel.getInt("id_insumo");
                java.math.BigDecimal cantMat = rsSel.getBigDecimal("cantidad");
                String estadoMant = rsSel.getString("estado");
                rsSel.close(); psSel.close();
                if (!"Programado".equals(estadoMant) && !"En Proceso".equals(estadoMant)) {
                    throw new SQLException("solo se pueden quitar materiales de mantenimientos Programados o En Proceso");
                }

                // Fase 3: registrar o quitar un uso NO toca el stock (se descontó al entregar).
                // Al quitarlo, el material vuelve a quedar en poder del técnico para usarlo o devolverlo.

                PreparedStatement psDel = conexion.prepareStatement("DELETE FROM public.mantenimiento_repuesto WHERE id = ?");
                psDel.setInt(1, idMaterial);
                psDel.executeUpdate();
                psDel.close();

                conexion.commit();
                out.print("success");
            } catch (Exception exQ) {
                conexion.rollback();
                out.print("error: " + mensajeError(exQ));
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // Modificar la cantidad de un material ya registrado (ajusta el stock por la diferencia).
        // Solo en mantenimientos Programado / En Proceso y solo el técnico que lo ejecuta o el administrador.
        if ("modificarMaterial".equals(tipo)) {
            Integer idMaterial = tryParseInt(request.getParameter("idMaterial"));
            java.math.BigDecimal cantNueva = null;
            try { cantNueva = new java.math.BigDecimal(request.getParameter("cantidad").replace(",", ".")); } catch (Exception ex) {}
            if (idMaterial == null || cantNueva == null || cantNueva.signum() <= 0) {
                out.print("error: indique un material y una cantidad mayor a cero");
                return;
            }
            PreparedStatement psDet = conexion.prepareStatement("SELECT id_detalle FROM public.mantenimiento_repuesto WHERE id = ?");
            psDet.setInt(1, idMaterial);
            ResultSet rsDet = psDet.executeQuery();
            Integer idDetalleMat = rsDet.next() ? Integer.valueOf(rsDet.getInt(1)) : null;
            rsDet.close(); psDet.close();
            if (idDetalleMat == null) {
                out.print("error: el material ya no existe");
                return;
            }
            if (!puedeAccederDetalle(conexion, idDetalleMat, esAdmin, idTecnicoSesion)) {
                out.print("error: no tiene permisos sobre este mantenimiento");
                return;
            }
            try {
                conexion.setAutoCommit(false);
                PreparedStatement psSel = conexion.prepareStatement(
                    "SELECT mr.id_repuesto, mr.id_insumo, mr.cantidad, m.estado FROM public.mantenimiento_repuesto mr "
                    + "JOIN public.mantenimientos_preventivos_detalle d ON mr.id_detalle = d.id_detalle "
                    + "JOIN public.mantenimientos_preventivos m ON d.id_mantenimiento = m.id_mantenimiento "
                    + "WHERE mr.id = ? FOR UPDATE OF mr");
                psSel.setInt(1, idMaterial);
                ResultSet rsSel = psSel.executeQuery();
                if (!rsSel.next()) { throw new SQLException("el material ya no existe"); }
                boolean esRep = rsSel.getObject("id_repuesto") != null;
                int idItem = esRep ? rsSel.getInt("id_repuesto") : rsSel.getInt("id_insumo");
                java.math.BigDecimal cantAnt = rsSel.getBigDecimal("cantidad");
                String estadoMant = rsSel.getString("estado");
                rsSel.close(); psSel.close();
                if (!"Programado".equals(estadoMant) && !"En Proceso".equals(estadoMant)) {
                    throw new SQLException("solo se pueden modificar materiales de mantenimientos Programados o En Proceso");
                }
                // Fase 3: cambiar la cantidad usada no toca el stock; la base valida que no
                // supere el material en poder del técnico para este mantenimiento.
                PreparedStatement psUp = conexion.prepareStatement("UPDATE public.mantenimiento_repuesto SET cantidad = ? WHERE id = ?");
                psUp.setBigDecimal(1, cantNueva);
                psUp.setInt(2, idMaterial);
                psUp.executeUpdate();
                psUp.close();
                conexion.commit();
                out.print("success");
            } catch (Exception exM) {
                conexion.rollback();
                out.print("error: " + mensajeError(exM));
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // Marcar como OK (o Reparado en el Depósito) todos los equipos que todavía no tienen resultado
        if ("marcarTodosOk".equals(tipo)) {
            Integer idMant = tryParseInt(request.getParameter("idMantenimiento"));
            if (idMant == null || !puedeAccederMantenimiento(conexion, idMant, esAdmin, idTecnicoSesion, true)) {
                out.print("error: no tiene permisos sobre este mantenimiento o ya no está en proceso");
                return;
            }
            try (PreparedStatement ps = conexion.prepareStatement(
                    "UPDATE public.mantenimientos_preventivos_detalle d SET realizado = true, " +
                    "resultado = CASE WHEN (SELECT COALESCE(s.es_deposito, false) FROM public.mantenimientos_preventivos m LEFT JOIN public.salas s ON s.id_sala = m.id_sala WHERE m.id_mantenimiento = d.id_mantenimiento) THEN 'Reparado' ELSE 'OK' END " +
                    "WHERE d.id_mantenimiento = ? AND d.resultado IS NULL")) {
                ps.setInt(1, idMant);
                out.print("success|" + ps.executeUpdate());
            } catch (SQLException exT) {
                out.print("error: " + mensajeError(exT));
            }
            return;
        }

        // Marcar Equipo (Fase 5: con resultado)
        //   Sala:     OK | Requirió repuesto | Derivado a ticket (crea un ticket correctivo para el equipo)
        //             | No reparable (al finalizar, el equipo pasa a inactivo y queda para retirar de la sala)
        //   Depósito: Reparado (vuelve a Activo al finalizar) | Sin reparación
        if ("marcarEquipo".equals(tipo)) {
            Integer idDetalle = tryParseInt(request.getParameter("idDetalle"));
            Boolean realizado = "true".equals(request.getParameter("realizado"));
            String observacion = request.getParameter("observacion");
            String resultado = request.getParameter("resultado");
            if (resultado != null && resultado.trim().isEmpty()) resultado = null;

            if (idDetalle == null) {
                out.print("error: detalle invalido");
                return;
            }
            if (!puedeAccederDetalle(conexion, idDetalle, esAdmin, idTecnicoSesion)) {
                out.print("error: no tiene permisos sobre este mantenimiento");
                return;
            }
            if (!realizado) resultado = null;
            if (realizado && resultado == null) {
                out.print("error: elija el resultado de la revisión del equipo");
                return;
            }

            try {
                conexion.setAutoCommit(false);
                int idEquipoDet, idSalaDet; boolean deposito; Integer ticketPrevio; String numeroMant;
                Integer idTecnicoMant;
                try (PreparedStatement psD = conexion.prepareStatement(
                        "SELECT d.id_equipo, d.id_ticket_derivado, m.numero_mantenimiento, m.estado, " +
                        "       COALESCE(m.id_tecnico_ejecuta, m.id_tecnico) AS id_tecnico, e.id_sala, COALESCE(s.es_deposito, false) AS es_deposito " +
                        "FROM public.mantenimientos_preventivos_detalle d " +
                        "JOIN public.mantenimientos_preventivos m ON m.id_mantenimiento = d.id_mantenimiento " +
                        "JOIN public.equipos e ON e.id_equipo = d.id_equipo LEFT JOIN public.salas s ON s.id_sala = m.id_sala " +
                        "WHERE d.id_detalle = ? FOR UPDATE OF d")) {
                    psD.setInt(1, idDetalle);
                    try (ResultSet rsD = psD.executeQuery()) {
                        if (!rsD.next()) throw new Exception("El equipo ya no está en el mantenimiento.");
                        if (!"Programado".equals(rsD.getString("estado")) && !"En Proceso".equals(rsD.getString("estado")))
                            throw new Exception("El mantenimiento ya no está abierto.");
                        idEquipoDet = rsD.getInt("id_equipo");
                        ticketPrevio = rsD.getObject("id_ticket_derivado") == null ? null : rsD.getInt("id_ticket_derivado");
                        numeroMant = rsD.getString("numero_mantenimiento");
                        idTecnicoMant = rsD.getObject("id_tecnico") == null ? null : rsD.getInt("id_tecnico");
                        idSalaDet = rsD.getInt("id_sala");
                        deposito = rsD.getBoolean("es_deposito");
                    }
                }
                if (resultado != null) {
                    java.util.List<String> validos = deposito
                            ? java.util.Arrays.asList("Reparado", "Sin reparación")
                            : java.util.Arrays.asList("OK", "Requirió repuesto", "Derivado a ticket", "No reparable");
                    if (!validos.contains(resultado)) throw new Exception("Resultado no válido para este equipo.");
                }
                if (ticketPrevio != null && !"Derivado a ticket".equals(resultado)) {
                    throw new Exception("Este equipo ya se derivó a un ticket correctivo: el resultado no se puede cambiar.");
                }

                Integer ticketNuevo = ticketPrevio;
                if ("Derivado a ticket".equals(resultado) && ticketPrevio == null) {
                    if (observacion == null || observacion.trim().length() < 10)
                        throw new Exception("Para derivar a un ticket describa la falla en la observación del equipo (al menos 10 caracteres).");
                    Integer idUsuarioDer = (Integer) session.getAttribute("idUsuario");
                    try (PreparedStatement psCtx = conexion.prepareStatement("SELECT set_config('app.current_user_id', ?, true)")) {
                        psCtx.setString(1, String.valueOf(idUsuarioDer));
                        psCtx.execute();
                    }
                    // El ticket queda asignado al mismo técnico del mantenimiento
                    try (PreparedStatement psT = conexion.prepareStatement(
                            "INSERT INTO public.ticket (id_usuario_solicita, id_rol_solicita, id_sala, id_equipo, tipo_falla, descripcion, estado, prioridad, " +
                            "                           id_tipo_falla, id_tecnico_asignado, fecha_inicio) " +
                            "SELECT u.id_usuario, u.id_rol, ?, ?, COALESCE(tf.nombre_tipo_falla, 'Otro'), ?, " +
                            "       CASE WHEN ?::integer IS NULL THEN 'Pendiente' ELSE 'Asignado' END, 'Media', tf.id_tipo_falla, ?::integer, " +
                            "       CASE WHEN ?::integer IS NULL THEN NULL ELSE CURRENT_TIMESTAMP END " +
                            "FROM public.usuarios u " +
                            "LEFT JOIN public.tipos_falla tf ON lower(tf.nombre_tipo_falla) = 'otro' AND tf.id_categoria IS NULL " +
                            "WHERE u.id_usuario = ? LIMIT 1 RETURNING id_ticket")) {
                        psT.setInt(1, idSalaDet);
                        psT.setInt(2, idEquipoDet);
                        psT.setString(3, "Derivado del mantenimiento " + numeroMant + ": " + observacion.trim());
                        if (idTecnicoMant == null) { psT.setNull(4, Types.INTEGER); psT.setNull(5, Types.INTEGER); psT.setNull(6, Types.INTEGER); }
                        else { psT.setInt(4, idTecnicoMant); psT.setInt(5, idTecnicoMant); psT.setInt(6, idTecnicoMant); }
                        psT.setInt(7, idUsuarioDer);
                        try (ResultSet rsT = psT.executeQuery()) {
                            if (!rsT.next()) throw new Exception("No se pudo crear el ticket correctivo.");
                            ticketNuevo = rsT.getInt(1);
                        }
                    }
                }

                try (PreparedStatement ps = conexion.prepareStatement(
                        "UPDATE public.mantenimientos_preventivos_detalle SET realizado = ?, observacion = ?, resultado = ?, id_ticket_derivado = ? WHERE id_detalle = ?")) {
                    ps.setBoolean(1, realizado);
                    ps.setString(2, observacion != null ? observacion.trim() : null);
                    ps.setString(3, resultado);
                    if (ticketNuevo == null) ps.setNull(4, Types.INTEGER); else ps.setInt(4, ticketNuevo);
                    ps.setInt(5, idDetalle);
                    ps.executeUpdate();
                }
                conexion.commit();
                out.print(ticketNuevo != null && !ticketNuevo.equals(ticketPrevio) ? "success|ticket" : "success");
            } catch (Exception exMarc) {
                conexion.rollback();
                out.print("error: " + mensajeError(exMarc));
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // Finalizar Mantenimiento
        if ("finalizarMantenimiento".equals(tipo)) {
            Integer idMantenimiento = tryParseInt(request.getParameter("idMantenimiento"));

            if (idMantenimiento == null) {
                out.print("error: mantenimiento invalido");
                return;
            }

            // No se puede finalizar si queda algún equipo sin revisar
            PreparedStatement psPend = conexion.prepareStatement(
                "SELECT COUNT(*) FROM public.mantenimientos_preventivos_detalle " +
                "WHERE id_mantenimiento = ? AND COALESCE(realizado, false) = false");
            psPend.setInt(1, idMantenimiento);
            ResultSet rsPend = psPend.executeQuery();
            int pendientes = rsPend.next() ? rsPend.getInt(1) : 0;
            rsPend.close(); psPend.close();
            if (pendientes > 0) {
                out.print("error: quedan " + pendientes + " equipo(s) sin marcar como revisados");
                return;
            }

            // Fase 3: no se finaliza con material sin rendir ni pedidos sin atender
            try (PreparedStatement psRend = conexion.prepareStatement(
                    "SELECT string_agg(articulo || ' (' || trim(to_char(saldo + sin_confirmar, 'FM999999990.##')) || ')', ', ') " +
                    "FROM public.v_material_orden WHERE tipo_orden = 'M' AND id_orden = ? AND (saldo > 0 OR sin_confirmar > 0)")) {
                psRend.setInt(1, idMantenimiento);
                try (ResultSet rsRend = psRend.executeQuery()) {
                    if (rsRend.next() && rsRend.getString(1) != null) {
                        out.print("error: tiene material sin usar ni devolver (" + rsRend.getString(1) + "). Regístrelo como usado en algún equipo o entréguelo al depósito para que registre la devolución.");
                        return;
                    }
                }
            }
            try (PreparedStatement psPendMat = conexion.prepareStatement(
                    "SELECT count(*) FROM public.solicitudes_material WHERE tipo_orden = 'M' AND id_orden = ? AND estado = 'Pendiente'")) {
                psPendMat.setInt(1, idMantenimiento);
                try (ResultSet rsPendMat = psPendMat.executeQuery()) {
                    if (rsPendMat.next() && rsPendMat.getInt(1) > 0) {
                        out.print("error: hay pedidos de material pendientes de entrega para este mantenimiento");
                        return;
                    }
                }
            }

            // Un técnico solo puede cerrar los mantenimientos que él ejecuta;
            // el administrador puede cerrar cualquiera que esté en proceso.
            // Fase 5: cada equipo debe tener su resultado
            try (PreparedStatement psRes = conexion.prepareStatement(
                    "SELECT count(*) FROM public.mantenimientos_preventivos_detalle WHERE id_mantenimiento = ? AND resultado IS NULL")) {
                psRes.setInt(1, idMantenimiento);
                try (ResultSet rsRes = psRes.executeQuery()) {
                    if (rsRes.next() && rsRes.getInt(1) > 0) {
                        out.print("error: falta indicar el resultado de " + rsRes.getInt(1) + " equipo(s)");
                        return;
                    }
                }
            }

            int res;
            try {
                conexion.setAutoCommit(false);
                String sql = "UPDATE public.mantenimientos_preventivos SET estado = 'Finalizado', fecha_fin = CURRENT_TIMESTAMP " +
                             "WHERE id_mantenimiento = ? AND estado = 'En Proceso'" +
                             (esAdmin ? "" : " AND id_tecnico_ejecuta = ?");
                PreparedStatement ps = conexion.prepareStatement(sql);
                ps.setInt(1, idMantenimiento);
                if (!esAdmin) ps.setInt(2, idTecnicoSesion);
                res = ps.executeUpdate();
                ps.close();
                if (res > 0) {
                    // Lo que quedó esperando stock ya no hace falta: se anula con constancia
                    try (PreparedStatement psEsp = conexion.prepareStatement(
                            "UPDATE public.solicitudes_material SET estado = 'Rechazada', motivo_rechazo = 'Anulado: el mantenimiento se finalizó sin este material', " +
                            "fecha_entrega = CURRENT_TIMESTAMP WHERE tipo_orden = 'M' AND id_orden = ? AND estado = 'En espera'")) {
                        psEsp.setInt(1, idMantenimiento);
                        psEsp.executeUpdate();
                    }
                    // Equipos del Depósito reparados: vuelven a Activo (siguen en el Depósito, listos para asignarse)
                    try (PreparedStatement psRep = conexion.prepareStatement(
                            "UPDATE public.equipos e SET estado = 'Activo' " +
                            "FROM public.mantenimientos_preventivos_detalle d " +
                            "WHERE d.id_mantenimiento = ? AND d.resultado = 'Reparado' AND d.id_equipo = e.id_equipo " +
                            "AND e.estado = 'Inactivo' " +
                            "AND NOT EXISTS (SELECT 1 FROM public.motivos_inactivo mi WHERE mi.id_motivo = e.id_motivo_inactivo AND mi.descuenta)")) {
                        psRep.setInt(1, idMantenimiento);
                        psRep.executeUpdate();
                    }
                    // Equipos sin arreglo: pasan a inactivos y quedan para retirar de la sala
                    java.util.List<Object[]> noRep = new java.util.ArrayList<Object[]>();
                    try (PreparedStatement psNR = conexion.prepareStatement(
                            "SELECT d.id_equipo, d.observacion, m.numero_mantenimiento FROM public.mantenimientos_preventivos_detalle d " +
                            "JOIN public.mantenimientos_preventivos m ON m.id_mantenimiento = d.id_mantenimiento WHERE d.id_mantenimiento = ? AND d.resultado = 'No reparable'")) {
                        psNR.setInt(1, idMantenimiento);
                        try (ResultSet rsNR = psNR.executeQuery()) { while (rsNR.next()) noRep.add(new Object[]{rsNR.getInt(1), rsNR.getString(2), rsNR.getString(3)}); }
                    }
                    Integer idUsuarioNR = (Integer) session.getAttribute("idUsuario");
                    for (Object[] nr : noRep) bajaPorOrden(conexion, (Integer) nr[0], null, "Mantenimiento " + nr[2], (String) nr[1], idUsuarioNR);
                }
                conexion.commit();
            } catch (Exception exFin) {
                conexion.rollback();
                out.print("error: " + mensajeError(exFin));
                return;
            } finally {
                conexion.setAutoCommit(true);
            }

            out.print(res > 0 ? "success" : "error: no se pudo finalizar el mantenimiento (no es suyo o ya no esta en proceso)");
            return;
        }

        // Historial Finalizados
        if ("listarFinalizados".equals(tipo)) {
            String sql = "SELECT m.id_mantenimiento, m.numero_mantenimiento, m.fecha_fin, s.nombre_sala, " +
                         "p.nombre AS tec_nombre, p.apellido AS tec_apellido " +
                         "FROM public.mantenimientos_preventivos m " +
                         "LEFT JOIN public.salas s ON m.id_sala = s.id_sala " +
                         "LEFT JOIN public.tecnicos t ON m.id_tecnico_ejecuta = t.id_tecnico " +
                         "LEFT JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                         "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                         "WHERE m.estado = 'Finalizado' " +
                         (esAdmin ? "" : "AND m.id_tecnico_ejecuta = ? ") +
                         "ORDER BY m.fecha_fin DESC LIMIT 50";
            PreparedStatement ps = conexion.prepareStatement(sql);
            if (!esAdmin) ps.setInt(1, idTecnicoSesion);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                String tecnico = rs.getString("tec_apellido") != null
                        ? rs.getString("tec_apellido") + ", " + rs.getString("tec_nombre") : "-";
%>
                <tr>
                    <td><%= rs.getString("numero_mantenimiento") %></td>
                    <td><span class="badge badge-info"><%= rs.getString("nombre_sala") %></span></td>
                    <td><%= tecnico %></td>
                    <td><%= _fh(rs.getTimestamp("fecha_fin"), "-") %></td>
                    <td class="text-center">
                        <button class="btn btn-secondary btn-sm" onclick="imprimirMantenimiento(<%= rs.getInt("id_mantenimiento") %>)">
                            <i class="fas fa-print"></i>
                        </button>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='5' class='text-center text-muted py-3'>Todavía no hay mantenimientos finalizados.</td></tr>");
            }
            return;
        }

        // Comprobante formal en PDF (JasperReports, con membrete)
        if ("comprobantePdf".equals(tipo)) {
            Integer idManPdf = tryParseInt(request.getParameter("idMantenimiento"));
            if (idManPdf == null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: ID inválido");
                return;
            }
            if (!puedeAccederMantenimiento(conexion, idManPdf, esAdmin, idTecnicoSesion, false)) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: no tiene permisos sobre este mantenimiento");
                return;
            }
            java.util.List<Integer> idsPdf = new java.util.ArrayList<Integer>();
            idsPdf.add(idManPdf);
            byte[] bytesPdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteMantenimiento", new String[]{"comprobanteMantenimientoEquipos", "comprobanteMantenimientoMateriales"},
                    "ID_MANTENIMIENTO", idsPdf, (Integer) session.getAttribute("idUsuario"));
            response.setContentType("application/pdf");
            response.setContentLength(bytesPdf.length);
            response.setHeader("Content-Disposition", "inline; filename=comprobante_mantenimiento_" + idManPdf + ".pdf");
            javax.servlet.ServletOutputStream salidaPdf = response.getOutputStream();
            salidaPdf.write(bytesPdf, 0, bytesPdf.length);
            salidaPdf.flush();
            salidaPdf.close();
            return;
        }

        // Comprobante Imprimible
        if ("obtenerComprobanteMantenimiento".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            Integer idMantenimiento = tryParseInt(request.getParameter("idMantenimiento"));
            JSONObject json = new JSONObject();

            if (idMantenimiento == null) {
                json.put("ok", false).put("error", "ID invalido");
                out.print(json.toString());
                return;
            }
            if (!puedeAccederMantenimiento(conexion, idMantenimiento, esAdmin, idTecnicoSesion, false)) {
                json.put("ok", false).put("error", "No tiene permisos sobre este mantenimiento");
                out.print(json.toString());
                return;
            }

            String sqlCab = "SELECT m.numero_mantenimiento, m.estado, m.fecha_programada, m.fecha_inicio, m.fecha_fin, " +
                            "m.observaciones, s.nombre_sala, ptec.nombre AS tec_nombre, ptec.apellido AS tec_apellido " +
                            "FROM public.mantenimientos_preventivos m " +
                            "LEFT JOIN public.salas s ON m.id_sala = s.id_sala " +
                            "LEFT JOIN public.tecnicos t ON m.id_tecnico_ejecuta = t.id_tecnico " +
                            "LEFT JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                            "LEFT JOIN public.personas ptec ON u.id_persona = ptec.id_persona " +
                            "WHERE m.id_mantenimiento = ?";
            PreparedStatement psCab = conexion.prepareStatement(sqlCab);
            psCab.setInt(1, idMantenimiento);
            ResultSet rsCab = psCab.executeQuery();
            if (!rsCab.next()) {
                json.put("ok", false).put("error", "El mantenimiento no existe");
                out.print(json.toString());
                return;
            }
            json.put("ok", true);
            json.put("numeroMantenimiento", rsCab.getString("numero_mantenimiento"));
            json.put("estado", rsCab.getString("estado"));
            json.put("sala", rsCab.getString("nombre_sala") != null ? rsCab.getString("nombre_sala") : "-");
            json.put("tecnico", rsCab.getString("tec_apellido") != null
                    ? rsCab.getString("tec_apellido") + ", " + rsCab.getString("tec_nombre") : "-");
            json.put("fechaProgramada", _f(rsCab.getDate("fecha_programada")));
            json.put("fechaInicio", _fh(rsCab.getTimestamp("fecha_inicio")));
            json.put("fechaFin", _fh(rsCab.getTimestamp("fecha_fin")));
            json.put("observaciones", rsCab.getString("observaciones") != null ? rsCab.getString("observaciones") : "-");
            rsCab.close(); psCab.close();

            String sqlDet = "SELECT d.id_detalle, d.realizado, d.observacion, e.codigo_patrimonial, e.modelo " +
                            "FROM public.mantenimientos_preventivos_detalle d JOIN public.equipos e ON d.id_equipo = e.id_equipo " +
                            "WHERE d.id_mantenimiento = ? ORDER BY e.codigo_patrimonial";
            PreparedStatement psDet = conexion.prepareStatement(sqlDet);
            psDet.setInt(1, idMantenimiento);
            ResultSet rsDet = psDet.executeQuery();
            JSONArray equipos = new JSONArray();
            while (rsDet.next()) {
                JSONObject eq = new JSONObject();
                int idDetalle = rsDet.getInt("id_detalle");
                eq.put("equipo", rsDet.getString("codigo_patrimonial") + " - " + (rsDet.getString("modelo") != null ? rsDet.getString("modelo") : "Equipo General"));
                eq.put("realizado", rsDet.getBoolean("realizado"));
                eq.put("observacion", rsDet.getString("observacion") != null ? rsDet.getString("observacion") : "-");

                PreparedStatement psMat = conexion.prepareStatement(
                    "SELECT mr.cantidad, COALESCE(r.nombre, i.nombre) AS descripcion, " +
                    "CASE WHEN mr.id_repuesto IS NOT NULL THEN 'Repuesto' ELSE 'Insumo' END AS categoria " +
                    "FROM public.mantenimiento_repuesto mr " +
                    "LEFT JOIN public.catalogo_repuestos r ON mr.id_repuesto = r.id_repuesto " +
                    "LEFT JOIN public.catalogo_insumos i ON mr.id_insumo = i.id_insumo " +
                    "WHERE mr.id_detalle = ? ORDER BY mr.id");
                psMat.setInt(1, idDetalle);
                ResultSet rsMat = psMat.executeQuery();
                JSONArray materiales = new JSONArray();
                while (rsMat.next()) {
                    JSONObject m = new JSONObject();
                    m.put("categoria", rsMat.getString("categoria"));
                    m.put("descripcion", rsMat.getString("descripcion"));
                    m.put("cantidad", rsMat.getBigDecimal("cantidad"));
                    materiales.put(m);
                }
                rsMat.close(); psMat.close();
                eq.put("materiales", materiales);
                equipos.put(eq);
            }
            rsDet.close(); psDet.close();
            json.put("equipos", equipos);

            out.print(json.toString());
            return;
        }

    } catch (Exception e) {
        out.print("Error critico en el controlador: " + e.getMessage());
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    // Combo <option> con todos los técnicos (para asignar / reasignar).
    private String comboTecnicos(Connection cn) throws SQLException {
        StringBuilder sb = new StringBuilder("<option value=''>-- Técnico --</option>");
        PreparedStatement ps = cn.prepareStatement(
                "SELECT t.id_tecnico, p.nombre, p.apellido, COALESCE(t.estado_disponibilidad, false) AS disp FROM public.tecnicos t " +
                "JOIN public.usuarios u ON t.id_usuario = u.id_usuario " +
                "JOIN public.personas p ON u.id_persona = p.id_persona " +
                "ORDER BY p.apellido");
        ResultSet rs = ps.executeQuery();
        while (rs.next()) {
            // Se listan todos para que el combo muestre al técnico actual aunque figure como no disponible
            sb.append("<option value='").append(rs.getInt("id_tecnico")).append("'>")
              .append(rs.getString("apellido")).append(", ").append(rs.getString("nombre"))
              .append(rs.getBoolean("disp") ? "" : " (no disponible)").append("</option>");
        }
        rs.close(); ps.close();
        return sb.toString();
    }

    // ¿Puede el usuario actual operar sobre este mantenimiento?
    //  - Administrador: siempre.
    //  - Técnico: solo si él es quien lo ejecuta (lo tomó).
    // soloEnProceso = true además exige que siga "En Proceso" (para editar/gestionar).
    private boolean puedeAccederMantenimiento(Connection cn, int idMant, boolean esAdmin, Integer idTec, boolean soloEnProceso) throws SQLException {
        if (!esAdmin && idTec == null) return false;
        StringBuilder sql = new StringBuilder("SELECT 1 FROM public.mantenimientos_preventivos WHERE id_mantenimiento = ?");
        if (soloEnProceso) sql.append(" AND estado = 'En Proceso'");
        if (!esAdmin) sql.append(" AND id_tecnico_ejecuta = ?");
        PreparedStatement ps = cn.prepareStatement(sql.toString());
        ps.setInt(1, idMant);
        if (!esAdmin) ps.setInt(2, idTec);
        ResultSet rs = ps.executeQuery();
        boolean ok = rs.next();
        rs.close(); ps.close();
        return ok;
    }

    // Igual que el anterior, pero partiendo de un id_detalle (equipo dentro del mantenimiento).
    private boolean puedeAccederDetalle(Connection cn, int idDetalle, boolean esAdmin, Integer idTec) throws SQLException {
        PreparedStatement ps = cn.prepareStatement("SELECT id_mantenimiento FROM public.mantenimientos_preventivos_detalle WHERE id_detalle = ?");
        ps.setInt(1, idDetalle);
        ResultSet rs = ps.executeQuery();
        Integer idMant = rs.next() ? Integer.valueOf(rs.getInt(1)) : null;
        rs.close(); ps.close();
        if (idMant == null) return false;
        return puedeAccederMantenimiento(cn, idMant, esAdmin, idTec, true);
    }

    private Integer tryParseInt(String value) {
        if (value == null || value.trim().isEmpty()) return null;
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
%>