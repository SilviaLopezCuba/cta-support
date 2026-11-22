<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@include file="../config/conexion.jsp"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static final String DESC_EQ =
        "COALESCE(e.codigo_patrimonial, 'Sin código') || ' - ' || TRIM(COALESCE(c.nombre_categoria, '') || ' ' || COALESCE(m.nombre_marca, '') || ' ' || COALESCE(e.modelo, ''))" +
        " || COALESCE(' (S/N ' || e.nro_serie || ')', '')";
%>
<%
    // ------------------------------------------------------------------
    // MOVIMIENTOS DE EQUIPOS
    //   ASIGNACION:   del Depósito a una sala (con código patrimonial)
    //   RETIRO:       de una sala al Depósito
    //   BAJA:         pasa a Inactivo con un motivo
    //   REACTIVACION: un equipo reparado vuelve a Activo (en el Depósito)
    // ------------------------------------------------------------------
    String tipo = request.getParameter("tipo");
    String rolME = (String) session.getAttribute("nombreRol");
    boolean esAdminME = "Administrador".equals(rolME);
    Integer idUsuarioME = (Integer) session.getAttribute("idUsuario");
    try {
        if ((!esAdminME && !"Encargado de depósito".equals(rolME)) || idUsuarioME == null) {
            response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
            out.print("Error: acceso restringido al Administrador y al Encargado de depósito.");
            return;
        }

        if ("combos".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            JSONObject j = new JSONObject();
            StringBuilder sb = new StringBuilder("<option value=''>-- Seleccione la sala --</option>");
            String grupo = null;
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT s.id_sala, s.nombre_sala, d.nombre_departamento FROM public.salas s LEFT JOIN public.departamentos d ON d.id_departamento = s.id_departamento " +
                    "WHERE NOT s.es_deposito ORDER BY d.nombre_departamento NULLS LAST, s.nombre_sala").executeQuery()) {
                while (rs.next()) {
                    String g = rs.getString(3) == null ? "Sin departamento" : rs.getString(3);
                    if (!g.equals(grupo)) { if (grupo != null) sb.append("</optgroup>"); sb.append("<optgroup label='").append(h(g)).append("'>"); grupo = g; }
                    sb.append("<option value='").append(rs.getInt(1)).append("'>").append(h(rs.getString(2))).append("</option>");
                }
            }
            if (grupo != null) sb.append("</optgroup>");
            j.put("salas", sb.toString());
            sb = new StringBuilder("<option value=''>-- Seleccione el motivo --</option>");
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT id_motivo, nombre_motivo, descuenta FROM public.motivos_inactivo WHERE activo AND aplica_equipos ORDER BY descuenta, nombre_motivo").executeQuery()) {
                while (rs.next()) sb.append("<option value='").append(rs.getInt(1)).append("' data-descuenta='").append(rs.getBoolean(3)).append("'>")
                        .append(h(rs.getString(2))).append(rs.getBoolean(3) ? " (se descuenta del inventario)" : " (sigue en el inventario)").append("</option>");
            }
            j.put("motivos", sb.toString());
            out.print(j.toString());
        }

        // Equipos que se pueden elegir para cada movimiento
        else if ("equipos".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            String mov = request.getParameter("movimiento");
            String idSala = request.getParameter("idSala");
            String where;
            if ("ASIGNACION".equals(mov)) where = "e.estado = 'Activo' AND s.es_deposito";
            else if ("RETIRO".equals(mov)) where = "e.estado = 'Activo' AND NOT s.es_deposito AND e.id_sala = ?";
            else if ("BAJA".equals(mov)) where = "e.estado = 'Activo'" + (idSala == null || idSala.isEmpty() ? "" : " AND e.id_sala = ?");
            else where = "e.estado = 'Inactivo' AND NOT COALESCE(mi.descuenta, false)";
            JSONArray arr = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT e.id_equipo, " + DESC_EQ + " AS descripcion, e.codigo_patrimonial, s.nombre_sala, s.es_deposito, mi.nombre_motivo " +
                    "FROM public.equipos e JOIN public.salas s ON s.id_sala = e.id_sala " +
                    "LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria LEFT JOIN public.marcas m ON m.id_marca = e.id_marca " +
                    "LEFT JOIN public.motivos_inactivo mi ON mi.id_motivo = e.id_motivo_inactivo " +
                    "WHERE " + where + " ORDER BY c.nombre_categoria, e.codigo_patrimonial NULLS FIRST, e.id_equipo")) {
                if (where.contains("?")) ps.setInt(1, Integer.parseInt(idSala));
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) arr.put(new JSONObject().put("id", rs.getInt("id_equipo")).put("descripcion", rs.getString("descripcion"))
                            .put("codigo", rs.getString("codigo_patrimonial") == null ? "" : rs.getString("codigo_patrimonial"))
                            .put("ubicacion", rs.getBoolean("es_deposito") ? "Depósito" : rs.getString("nombre_sala"))
                            .put("motivo", rs.getString("nombre_motivo") == null ? "" : rs.getString("nombre_motivo")));
                }
            }
            out.print(arr.toString());
        }

        // Registrar el movimiento (cabecera + detalle) y aplicarlo a los equipos
        else if ("registrar".equals(tipo)) {
            JSONObject d = new JSONObject(request.getParameter("datos"));
            String mov = d.optString("movimiento");
            if (!java.util.Arrays.asList("ASIGNACION", "RETIRO", "BAJA", "REACTIVACION").contains(mov)) throw new Exception("Elija el tipo de movimiento.");
            JSONArray eqs = d.optJSONArray("equipos");
            if (eqs == null || eqs.length() == 0) throw new Exception("Agregue al menos un equipo.");
            String obs = d.optString("observacion", "").trim();
            String fecha = d.optString("fecha", "").trim();
            Integer idSalaDest = null, idMotivo = null;
            boolean descuenta = false;
            if ("ASIGNACION".equals(mov)) {
                try { idSalaDest = Integer.valueOf(d.get("idSalaDestino").toString()); } catch (Exception ex) { throw new Exception("Elija la sala de destino."); }
            }
            if ("BAJA".equals(mov)) {
                try { idMotivo = Integer.valueOf(d.get("idMotivo").toString()); } catch (Exception ex) { throw new Exception("Elija el motivo de la baja."); }
                if (obs.length() < 5) throw new Exception("Escribí una observación de la baja (qué pasó, N° de denuncia si fue robo, etc.).");
                try (PreparedStatement ps = conexion.prepareStatement("SELECT descuenta FROM public.motivos_inactivo WHERE id_motivo = ? AND activo AND aplica_equipos")) {
                    ps.setInt(1, idMotivo);
                    try (ResultSet rs = ps.executeQuery()) { if (!rs.next()) throw new Exception("Motivo no válido."); descuenta = rs.getBoolean(1); }
                }
                if (descuenta && !esAdminME) throw new Exception("Solo el Administrador puede registrar un robo o una pérdida.");
            }
            int idDeposito;
            try (ResultSet rs = conexion.prepareStatement("SELECT id_sala FROM public.salas WHERE es_deposito").executeQuery()) {
                if (!rs.next()) throw new Exception("No existe el Depósito.");
                idDeposito = rs.getInt(1);
            }
            String numero;
            try {
                conexion.setAutoCommit(false);
                int idMov;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.movimientos_equipos (tipo, id_sala_destino, id_motivo, fecha, observacion, id_usuario) VALUES (?, ?, ?, COALESCE(?, CURRENT_DATE), ?, ?) RETURNING id_movimiento, numero")) {
                    ps.setString(1, mov);
                    if ("ASIGNACION".equals(mov)) ps.setInt(2, idSalaDest);
                    else if ("RETIRO".equals(mov)) ps.setInt(2, idDeposito);
                    else ps.setNull(2, Types.INTEGER);
                    if (idMotivo == null) ps.setNull(3, Types.INTEGER); else ps.setInt(3, idMotivo);
                    ps.setDate(4, fecha.isEmpty() ? null : Date.valueOf(fecha));
                    ps.setString(5, obs.isEmpty() ? null : (obs.length() > 255 ? obs.substring(0, 255) : obs));
                    ps.setInt(6, idUsuarioME);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); idMov = rs.getInt(1); numero = rs.getString(2); }
                }
                try (PreparedStatement ps = conexion.prepareStatement("SELECT set_config('cta.obs_ubicacion', ?, true)")) { ps.setString(1, numero + (obs.isEmpty() ? "" : " - " + obs)); ps.execute(); }

                for (int i = 0; i < eqs.length(); i++) {
                    JSONObject e = eqs.getJSONObject(i);
                    int idEq = e.getInt("id");
                    String cod = e.optString("codigo", "").trim();
                    Integer origen; String desc;
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "SELECT e.id_sala, e.estado, s.es_deposito, " + DESC_EQ + " AS descripcion FROM public.equipos e JOIN public.salas s ON s.id_sala = e.id_sala " +
                            "LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria LEFT JOIN public.marcas m ON m.id_marca = e.id_marca WHERE e.id_equipo = ? FOR UPDATE OF e")) {
                        ps.setInt(1, idEq);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (!rs.next()) throw new Exception("Uno de los equipos ya no existe.");
                            origen = rs.getInt("id_sala"); desc = rs.getString("descripcion");
                            String est = rs.getString("estado"); boolean enDep = rs.getBoolean("es_deposito");
                            if ("ASIGNACION".equals(mov) && (!"Activo".equals(est) || !enDep)) throw new Exception(desc + ": ya no está disponible en el Depósito.");
                            if ("RETIRO".equals(mov) && (!"Activo".equals(est) || enDep)) throw new Exception(desc + ": no está en una sala.");
                            if ("BAJA".equals(mov) && !"Activo".equals(est)) throw new Exception(desc + ": ya está inactivo.");
                            if ("REACTIVACION".equals(mov) && !"Inactivo".equals(est)) throw new Exception(desc + ": ya está activo.");
                        }
                    }
                    String sql;
                    if ("ASIGNACION".equals(mov)) {
                        if (cod.isEmpty()) throw new Exception(desc + ": cargá el código patrimonial para ubicarlo en la sala.");
                        try (PreparedStatement ps = conexion.prepareStatement("SELECT 1 FROM public.equipos WHERE lower(trim(codigo_patrimonial)) = lower(?) AND id_equipo <> ?")) {
                            ps.setString(1, cod); ps.setInt(2, idEq);
                            try (ResultSet rs = ps.executeQuery()) { if (rs.next()) throw new Exception("El código patrimonial " + cod + " ya lo tiene otro equipo."); }
                        }
                        sql = "UPDATE public.equipos SET id_sala = ?, codigo_patrimonial = ? WHERE id_equipo = ?";
                        try (PreparedStatement ps = conexion.prepareStatement(sql)) { ps.setInt(1, idSalaDest); ps.setString(2, cod); ps.setInt(3, idEq); ps.executeUpdate(); }
                    } else if ("RETIRO".equals(mov)) {
                        try (PreparedStatement ps = conexion.prepareStatement("UPDATE public.equipos SET id_sala = ? WHERE id_equipo = ?")) { ps.setInt(1, idDeposito); ps.setInt(2, idEq); ps.executeUpdate(); }
                    } else if ("BAJA".equals(mov)) {
                        // Descompuesto / Daño irreparable: vuelve físicamente al Depósito. Robo / Pérdida: queda la última sala.
                        try (PreparedStatement ps = conexion.prepareStatement(
                                "UPDATE public.equipos SET estado = 'Inactivo', id_motivo_inactivo = ?, observacion_inactivo = ?, fecha_inactivo = COALESCE(?, CURRENT_DATE)" +
                                (descuenta ? "" : ", id_sala = " + idDeposito) + " WHERE id_equipo = ?")) {
                            ps.setInt(1, idMotivo); ps.setString(2, numero + " - " + obs); ps.setDate(3, fecha.isEmpty() ? null : Date.valueOf(fecha)); ps.setInt(4, idEq);
                            ps.executeUpdate();
                        }
                    } else {
                        try (PreparedStatement ps = conexion.prepareStatement(
                                "UPDATE public.equipos e SET estado = 'Activo' WHERE e.id_equipo = ? " +
                                "AND NOT EXISTS (SELECT 1 FROM public.motivos_inactivo m WHERE m.id_motivo = e.id_motivo_inactivo AND m.descuenta)")) {
                            ps.setInt(1, idEq);
                            if (ps.executeUpdate() == 0) throw new Exception(desc + ": fue dado de baja por robo o pérdida y no se puede reactivar.");
                        }
                    }
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.movimientos_equipos_detalle (id_movimiento, id_equipo, id_sala_origen, codigo_patrimonial) VALUES (?, ?, ?, ?)")) {
                        ps.setInt(1, idMov); ps.setInt(2, idEq); ps.setInt(3, origen); ps.setString(4, cod.isEmpty() ? null : cod);
                        ps.executeUpdate();
                    }
                }
                conexion.commit();
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
            out.print("success|" + numero);
        }

        // Equipos dados de baja por un técnico que todavía están en su sala
        else if ("porRetirar".equals(tipo)) {
            int filas = 0;
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT e.id_equipo, " + DESC_EQ + " AS descripcion, s.nombre_sala, d.nombre_departamento, mi.nombre_motivo, e.fecha_inactivo, e.observacion_inactivo " +
                    "FROM public.equipos e JOIN public.salas s ON s.id_sala = e.id_sala LEFT JOIN public.departamentos d ON d.id_departamento = s.id_departamento " +
                    "LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria LEFT JOIN public.marcas m ON m.id_marca = e.id_marca " +
                    "LEFT JOIN public.motivos_inactivo mi ON mi.id_motivo = e.id_motivo_inactivo " +
                    "WHERE e.estado = 'Inactivo' AND NOT s.es_deposito AND NOT COALESCE(mi.descuenta, false) ORDER BY e.fecha_inactivo, s.nombre_sala").executeQuery()) {
                while (rs.next()) {
                    filas++;
                    out.print("<tr><td>" + h(rs.getString("descripcion")) + "</td><td>" + (rs.getString("nombre_departamento") == null ? "" : "<small class='text-muted d-block'>" + h(rs.getString("nombre_departamento")) + "</small>")
                        + h(rs.getString("nombre_sala")) + "</td><td>" + h(rs.getString("nombre_motivo")) + "</td><td>" + _f(rs.getDate("fecha_inactivo")) + "</td>"
                        + "<td class='small'>" + h(rs.getString("observacion_inactivo") == null ? "" : rs.getString("observacion_inactivo")) + "</td>"
                        + "<td class='text-center'><button class='btn btn-success btn-sm text-nowrap' onclick='recibirEnDeposito(" + rs.getInt("id_equipo") + ")'><i class='fas fa-check'></i> Recibido en depósito</button></td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='6' class='text-center text-muted py-3'>No hay equipos para retirar de las salas.</td></tr>");
        }

        // El Encargado trajo el equipo al Depósito
        else if ("recibirEnDeposito".equals(tipo)) {
            int idEq = Integer.parseInt(request.getParameter("idEquipo"));
            String numero;
            try {
                conexion.setAutoCommit(false);
                int idDeposito, origen;
                try (ResultSet rs = conexion.prepareStatement("SELECT id_sala FROM public.salas WHERE es_deposito").executeQuery()) { rs.next(); idDeposito = rs.getInt(1); }
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT e.id_sala, s.es_deposito, e.estado FROM public.equipos e JOIN public.salas s ON s.id_sala = e.id_sala WHERE e.id_equipo = ? FOR UPDATE OF e")) {
                    ps.setInt(1, idEq);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new Exception("El equipo no existe.");
                        if (rs.getBoolean(2)) throw new Exception("El equipo ya está en el Depósito.");
                        if (!"Inactivo".equals(rs.getString(3))) throw new Exception("Solo se reciben así los equipos dados de baja. Para mover equipos activos usá \"Devolver al Depósito\".");
                        origen = rs.getInt(1);
                    }
                }
                int idMov;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.movimientos_equipos (tipo, id_sala_destino, observacion, id_usuario) VALUES ('RETIRO', ?, 'Equipo inactivo recibido en el Depósito', ?) RETURNING id_movimiento, numero")) {
                    ps.setInt(1, idDeposito); ps.setInt(2, idUsuarioME);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); idMov = rs.getInt(1); numero = rs.getString(2); }
                }
                try (PreparedStatement ps = conexion.prepareStatement("SELECT set_config('cta.obs_ubicacion', ?, true)")) { ps.setString(1, numero + " - recibido en el Depósito"); ps.execute(); }
                try (PreparedStatement ps = conexion.prepareStatement("UPDATE public.equipos SET id_sala = ? WHERE id_equipo = ?")) { ps.setInt(1, idDeposito); ps.setInt(2, idEq); ps.executeUpdate(); }
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.movimientos_equipos_detalle (id_movimiento, id_equipo, id_sala_origen) VALUES (?, ?, ?)")) {
                    ps.setInt(1, idMov); ps.setInt(2, idEq); ps.setInt(3, origen); ps.executeUpdate();
                }
                conexion.commit();
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
            out.print("success|" + numero);
        }

        else if ("listar".equals(tipo)) {
            String grupoL = request.getParameter("grupo");
            String[] tipos = "BAJA".equals(grupoL) ? new String[]{"BAJA", "REACTIVACION", "BAJA", "BAJA"}
                           : "ASIGNACION".equals(grupoL) ? new String[]{"ASIGNACION", "RETIRO", "RETIRO", "RETIRO"}
                           : new String[]{"ASIGNACION", "RETIRO", "BAJA", "REACTIVACION"};
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT mv.*, sd.nombre_sala AS destino, mi.nombre_motivo, COALESCE(p.nombre || ' ' || p.apellido, u.login) AS usuario, " +
                    "       (SELECT string_agg(" + DESC_EQ.replace("e.", "e.") + ", '<br>' ORDER BY d.id_detalle) FROM public.movimientos_equipos_detalle d " +
                    "        JOIN public.equipos e ON e.id_equipo = d.id_equipo LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria " +
                    "        LEFT JOIN public.marcas m ON m.id_marca = e.id_marca WHERE d.id_movimiento = mv.id_movimiento) AS equipos " +
                    "FROM public.movimientos_equipos mv LEFT JOIN public.salas sd ON sd.id_sala = mv.id_sala_destino " +
                    "LEFT JOIN public.motivos_inactivo mi ON mi.id_motivo = mv.id_motivo " +
                    "LEFT JOIN public.usuarios u ON u.id_usuario = mv.id_usuario LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "WHERE mv.tipo IN (?, ?, ?, ?) ORDER BY mv.id_movimiento DESC LIMIT 200")) {
                for (int k = 0; k < 4; k++) ps.setString(k + 1, tipos[k]);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        filas++;
                        String t = rs.getString("tipo");
                        String nombreTipo = "ASIGNACION".equals(t) ? "Asignación a sala" : "RETIRO".equals(t) ? "Devuelto al Depósito" : "BAJA".equals(t) ? "Baja" : "Reactivación";
                        String detalle = "ASIGNACION".equals(t) ? h(rs.getString("destino")) : "RETIRO".equals(t) ? "Depósito" : "BAJA".equals(t) ? h(rs.getString("nombre_motivo")) : "Depósito";
                        if (rs.getString("origen") != null) detalle += "<small class='d-block text-muted'>" + h(rs.getString("origen")) + "</small>";
                        String equipos = rs.getString("equipos") == null ? "" : h(rs.getString("equipos")).replace("&lt;br&gt;", "<br>");
                        out.print("<tr><td><b>" + h(rs.getString("numero")) + "</b></td><td>" + _f(rs.getDate("fecha")) + "</td><td>" + nombreTipo + "</td><td>" + detalle + "</td>"
                            + "<td class='small'>" + equipos + "</td><td>" + h(rs.getString("usuario")) + "</td><td class='small'>"
                            + (rs.getString("observacion") == null ? "" : h(rs.getString("observacion"))) + "</td></tr>");
                    }
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='7' class='text-center text-muted py-3'>Todavía no hay movimientos.</td></tr>");
        }
    } catch (Exception e) {
        out.print("Error: " + mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
