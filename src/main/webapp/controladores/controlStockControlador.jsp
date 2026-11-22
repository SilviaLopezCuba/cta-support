<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@page import="com.mycompany.pro.util.ComprobanteUtil"%>
<%@include file="../config/conexion.jsp"%>
<%@include file="../config/inventarioComun.jsp"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _f(java.util.Date d, String def) { return d == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _fh(java.sql.Timestamp t, String def) { return t == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
%>

<%
    // Controlador de Control de Stock / Inventario (maestro-detalle)
    // Maestro:  catálogo de repuestos + insumos (stock actual vs. mínimo)
    // Detalle:  solicitudes_compra / solicitudes_compra_detalle
    // Genera un formulario imprimible de Solicitud de Compra con los
    // artículos cuyo stock está por debajo del mínimo.
    // Acceso restringido: solo el rol Administrador puede usar este controlador.
    // Fase 6: el Encargado de depósito también arma pedidos y registra lo que llega;
    // los ajustes de inventario siguen siendo solo del Administrador.
    String rolStock = (String) session.getAttribute("nombreRol");
    boolean esAdminStock = "Administrador".equals(rolStock);
    String tipoPre = request.getParameter("tipo");
    boolean accionDeAjuste = "registrarAjuste".equals(tipoPre) || "modificarAjuste".equals(tipoPre) || "eliminarAjuste".equals(tipoPre);
    if (!(esAdminStock || ("Encargado de depósito".equals(rolStock) && !accionDeAjuste))) {
        response.setContentType("text/plain;charset=UTF-8");
        response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
        out.print(accionDeAjuste ? "error: los ajustes de inventario los registra solo el Administrador" : "error: acceso restringido al Administrador y al Encargado de depósito");
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
        return;
    }

    String tipo = request.getParameter("tipo");

    try {
        // 1. Listar inventario completo (repuestos + insumos) con su estado
        if ("listarInventario".equals(tipo)) {
            String sqlUnion = "SELECT 'R' AS tipo, r.id_repuesto AS id_item, r.nombre, " +
                         "COALESCE(m.nombre_marca,'-') AS marca, r.stock, r.stock_minimo " +
                         "FROM public.catalogo_repuestos r LEFT JOIN public.marcas m ON r.id_marca = m.id_marca " +
                         "UNION ALL " +
                         "SELECT 'I' AS tipo, i.id_insumo AS id_item, i.nombre, " +
                         "COALESCE(m.nombre_marca,'-') AS marca, i.stock, i.stock_minimo " +
                         "FROM public.catalogo_insumos i LEFT JOIN public.marcas m ON i.id_marca = m.id_marca";
            // Los artículos faltantes (stock <= stock_minimo) se listan primero
            PreparedStatement ps = conexion.prepareStatement(
                "SELECT * FROM (" + sqlUnion + ") t ORDER BY (stock <= stock_minimo) DESC, nombre ASC");
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                String tipoItem = rs.getString("tipo");
                double stock = rs.getDouble("stock");
                double stockMin = rs.getDouble("stock_minimo");
                boolean faltante = stock <= stockMin;
                String badgeTipo = "R".equals(tipoItem) ? "<span class='badge badge-primary'>Repuesto</span>" : "<span class='badge badge-info'>Insumo</span>";
                String badgeEstado = faltante
                        ? (stock <= 0 ? "<span class='badge badge-danger'>Agotado</span>" : "<span class='badge badge-warning'>Bajo mínimo</span>")
                        : "<span class='badge badge-success'>OK</span>";
                long sugerido = faltante ? (long) Math.max(1, Math.ceil(stockMin - stock)) : 1;
                String nombreEscapado = rs.getString("nombre").replace("'", "&#39;").replace("\"", "&quot;");
%>
                <tr class="<%= faltante ? "table-warning" : "" %> fila-item"
                    data-faltante="<%= faltante %>">
                    <td class="text-center">
                        <input type="checkbox" class="chk-item"
                               data-tipo="<%= tipoItem %>" data-id="<%= rs.getInt("id_item") %>"
                               data-nombre="<%= nombreEscapado %>"
                               data-stock="<%= stock %>" data-stockmin="<%= stockMin %>"
                               <%= faltante ? "checked" : "" %>>
                    </td>
                    <td><%= badgeTipo %></td>
                    <td><%= rs.getString("nombre") %></td>
                    <td><%= rs.getString("marca") %></td>
                    <td class="text-right"><%= com.mycompany.pro.util.NumUtil.entero(stock) %></td>
                    <td class="text-right"><%= com.mycompany.pro.util.NumUtil.entero(stockMin) %></td>
                    <td class="text-center"><%= badgeEstado %></td>
                    <td class="text-center">
                        <input type="number" class="form-control form-control-sm txt-cantidad"
                               style="width:85px;display:inline-block;" min="1" step="1" value="<%= sugerido %>">
                    </td>
                    <td class="text-center">
                        <button type="button" class="btn btn-outline-danger btn-sm"
                                onclick="abrirAjuste('<%= tipoItem %>', <%= rs.getInt("id_item") %>, '<%= nombreEscapado %>', <%= stock %>)">
                            <i class="fas fa-exclamation-triangle"></i> Ajustar
                        </button>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='9' class='text-center text-muted py-3'>No hay artículos registrados en el catálogo.</td></tr>");
            }
            return;
        }

        // 2. Obtener todos los faltantes en JSON (para "Cargar faltantes")
        if ("obtenerFaltantes".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            String sql = "SELECT * FROM (" +
                         "SELECT 'R' AS tipo, r.id_repuesto AS id_item, r.nombre, r.stock, r.stock_minimo " +
                         "FROM public.catalogo_repuestos r " +
                         "UNION ALL " +
                         "SELECT 'I' AS tipo, i.id_insumo AS id_item, i.nombre, i.stock, i.stock_minimo " +
                         "FROM public.catalogo_insumos i" +
                         ") t WHERE stock <= stock_minimo ORDER BY nombre ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            JSONArray items = new JSONArray();
            while (rs.next()) {
                JSONObject item = new JSONObject();
                item.put("tipo", rs.getString("tipo"));
                item.put("id", rs.getInt("id_item"));
                item.put("nombre", rs.getString("nombre"));
                item.put("stock", com.mycompany.pro.util.NumUtil.entero(rs.getBigDecimal("stock")));
                item.put("stockMinimo", com.mycompany.pro.util.NumUtil.entero(rs.getBigDecimal("stock_minimo")));
                items.put(item);
            }
            rs.close(); ps.close();
            JSONObject json = new JSONObject();
            json.put("ok", true);
            json.put("items", items);
            out.print(json.toString());
            return;
        }

        // 3. Guardar Solicitud de Compra (cabecera + detalle)
        if ("guardarSolicitud".equals(tipo)) {
            Integer idUsuario = (Integer) session.getAttribute("idUsuario");
            String observaciones = request.getParameter("observaciones");
            Integer detCount = tryParseInt(request.getParameter("det_count"));
            Integer idDonantePedido = tryParseInt(request.getParameter("id_donante"));

            if (idUsuario == null) {
                out.print("error: sesión no válida");
                return;
            }
            if (idDonantePedido == null) {
                out.print("error: seleccione la institución a la que se dirige el pedido");
                return;
            }
            if (detCount == null || detCount == 0) {
                out.print("error: agregue al menos un artículo a la solicitud");
                return;
            }

            try {
                conexion.setAutoCommit(false);

                PreparedStatement psCab = conexion.prepareStatement(
                    "INSERT INTO public.solicitudes_compra (id_usuario_solicita, observaciones, id_donante) VALUES (?, ?, ?) " +
                    "RETURNING id_solicitud, numero_solicitud");
                psCab.setInt(1, idUsuario);
                psCab.setString(2, observaciones != null ? observaciones.trim() : null);
                psCab.setInt(3, idDonantePedido);
                ResultSet rsCab = psCab.executeQuery();
                rsCab.next();
                int idSolicitud = rsCab.getInt("id_solicitud");
                String numeroGenerado = rsCab.getString("numero_solicitud");
                rsCab.close(); psCab.close();

                for (int i = 0; i < detCount; i++) {
                    String rawTipo = request.getParameter("det_tipo_" + i);
                    int itemId = Integer.parseInt(request.getParameter("det_id_" + i));
                    double stockActual = Double.parseDouble(request.getParameter("det_stock_" + i));
                    double stockMinimo = Double.parseDouble(request.getParameter("det_stockmin_" + i));
                    double cantidad = Double.parseDouble(request.getParameter("det_cantidad_" + i));

                    PreparedStatement psDet = conexion.prepareStatement(
                        "INSERT INTO public.solicitudes_compra_detalle (id_solicitud, id_repuesto, id_insumo, stock_actual, stock_minimo, cantidad_solicitada) " +
                        "VALUES (?, ?, ?, ?, ?, ?)");
                    psDet.setInt(1, idSolicitud);
                    if ("R".equals(rawTipo)) {
                        psDet.setInt(2, itemId);
                        psDet.setNull(3, Types.INTEGER);
                    } else {
                        psDet.setNull(2, Types.INTEGER);
                        psDet.setInt(3, itemId);
                    }
                    psDet.setDouble(4, stockActual);
                    psDet.setDouble(5, stockMinimo);
                    psDet.setDouble(6, cantidad);
                    psDet.executeUpdate();
                    psDet.close();
                }

                conexion.commit();
                out.print("success|" + idSolicitud + "|" + numeroGenerado);
            } catch (Exception ex) {
                conexion.rollback();
                out.print("Error: " + ex.getMessage());
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // Fase 6: instituciones a las que se puede dirigir un pedido
        if ("cargarInstituciones".equals(tipo)) {
            out.print("<option value=''>-- Institución a la que se pide --</option>");
            try (ResultSet rsIn = conexion.prepareStatement("SELECT id_donante, nombre FROM public.donantes ORDER BY nombre").executeQuery()) {
                while (rsIn.next()) out.print("<option value='" + rsIn.getInt(1) + "'>" + h(rsIn.getString(2)) + "</option>");
            }
            return;
        }

        // Fase 6: el pedido se marca como enviado a la institución
        if ("marcarEnviada".equals(tipo)) {
            PreparedStatement psEnv = conexion.prepareStatement(
                "UPDATE public.solicitudes_compra SET estado = 'Enviada', fecha_envio = CURRENT_TIMESTAMP, id_usuario_envia = ? " +
                "WHERE id_solicitud = ? AND estado = 'Generada'");
            psEnv.setInt(1, (Integer) session.getAttribute("idUsuario"));
            psEnv.setInt(2, Integer.parseInt(request.getParameter("idSolicitud")));
            int filasEnv = psEnv.executeUpdate();
            psEnv.close();
            out.print(filasEnv > 0 ? "success" : "error: el pedido ya fue enviado");
            return;
        }

        // 4. Listar historial de solicitudes de compra
        if ("listarSolicitudes".equals(tipo)) {
            String sql = "SELECT s.id_solicitud, s.numero_solicitud, s.fecha_solicitud, s.estado, s.fecha_envio, " +
                         "COALESCE(dn.nombre, '-') AS institucion, " +
                         "(SELECT string_agg(r.numero_recepcion || ' (' || r.estado || ')', ', ') FROM public.recepciones r WHERE r.id_solicitud_origen = s.id_solicitud) AS recepciones, " +
                         "p.nombre AS usu_nombre, p.apellido AS usu_apellido, " +
                         "(SELECT COUNT(*) FROM public.solicitudes_compra_detalle d WHERE d.id_solicitud = s.id_solicitud) AS cant_items " +
                         "FROM public.solicitudes_compra s " +
                         "LEFT JOIN public.usuarios u ON s.id_usuario_solicita = u.id_usuario " +
                         "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                         "LEFT JOIN public.donantes dn ON dn.id_donante = s.id_donante " +
                         "ORDER BY s.fecha_solicitud DESC LIMIT 50";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                String usuario = rs.getString("usu_apellido") != null
                        ? rs.getString("usu_apellido") + ", " + rs.getString("usu_nombre") : "-";
                String badgeEstado = "Generada".equals(rs.getString("estado")) ? "badge-warning"
                        : "Enviada".equals(rs.getString("estado")) ? "badge-info"
                        : "Recibida parcial".equals(rs.getString("estado")) ? "badge-primary"
                        : "Recibida".equals(rs.getString("estado")) ? "badge-success"
                        : "Cancelada".equals(rs.getString("estado")) ? "badge-danger" : "badge-secondary";
                // 'recibida' = ya no admite más recepciones (completa o cancelada)
                boolean recibida = "Recibida".equals(rs.getString("estado")) || "Cancelada".equals(rs.getString("estado"));
                boolean anulable = "Generada".equals(rs.getString("estado")) || "Enviada".equals(rs.getString("estado"));
%>
                <tr>
                    <td><%= rs.getString("numero_solicitud") %></td>
                    <td><%= _fh(rs.getTimestamp("fecha_solicitud"), "-") %></td>
                    <td><%= h(rs.getString("institucion")) %><small class="d-block text-muted">Pidió: <%= h(usuario) %></small></td>
                    <td class="text-center"><span class="badge badge-secondary"><%= rs.getInt("cant_items") %></span></td>
                    <td class="text-center"><span class="badge <%= badgeEstado %>"><%= rs.getString("estado") %></span>
                        <% if (rs.getTimestamp("fecha_envio") != null) { %><small class="d-block text-muted">Enviado <%= _fh(rs.getTimestamp("fecha_envio"), "-") %></small><% } %>
                        <% if (rs.getString("recepciones") != null) { %><small class="d-block text-muted"><%= h(rs.getString("recepciones")) %></small><% } %></td>
                    <td class="text-center">
                        <button class="btn btn-secondary btn-sm" onclick="imprimirSolicitud(<%= rs.getInt("id_solicitud") %>)" title="Imprimir">
                            <i class="fas fa-print"></i>
                        </button>
                        <% if ("Generada".equals(rs.getString("estado"))) { %>
                        <button class="btn btn-info btn-sm" onclick="marcarEnviada(<%= rs.getInt("id_solicitud") %>, '<%= hj(rs.getString("numero_solicitud")) %>')" title="Marcar como enviado a la institución">
                            <i class="fas fa-paper-plane"></i> Enviado
                        </button>
                        <% } %>
                        <% if (!recibida && !"Generada".equals(rs.getString("estado"))) { %>
                        <button class="btn btn-success btn-sm" onclick="abrirRecepcion(<%= rs.getInt("id_solicitud") %>, '<%= hj(rs.getString("numero_solicitud")) %>')" title="Registrar lo que llegó">
                            <i class="fas fa-truck-loading"></i> Recibir
                        </button>
                        <% } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='6' class='text-center text-muted py-3'>Todavía no se generaron solicitudes de compra.</td></tr>");
            }
            return;
        }

        // Anular solicitud de compra (SOLO Administrador). Cabecera + detalle en UNA transacción:
        //  - solo si está 'Generada' o 'Enviada' (sin nada recibido: no hay stock que revertir)
        //  - la solicitud pasa a 'Cancelada' con motivo, fecha y usuario que anula
        // El estado Cancelado fue eliminado del sistema: la acción queda deshabilitada.
        if ("anularSolicitud".equals(tipo)) {
            out.print("error: la anulación de solicitudes fue deshabilitada");
            return;
        }
        if ("anularSolicitudDeshabilitada".equals(tipo)) {
            Integer idUsuarioAnula = (Integer) session.getAttribute("idUsuario");
            if (idUsuarioAnula == null || !Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("error: solo el administrador puede anular solicitudes");
                return;
            }
            Integer idSolAnula = tryParseInt(request.getParameter("idSolicitud"));
            String motivoAnula = request.getParameter("motivo");
            if (idSolAnula == null || motivoAnula == null || motivoAnula.trim().length() < 5) {
                out.print("error: indique la solicitud y un motivo de al menos 5 caracteres");
                return;
            }
            try {
                conexion.setAutoCommit(false);

                PreparedStatement psEst = conexion.prepareStatement(
                    "SELECT estado FROM public.solicitudes_compra WHERE id_solicitud = ? FOR UPDATE");
                psEst.setInt(1, idSolAnula);
                ResultSet rsEst = psEst.executeQuery();
                String estadoActual = rsEst.next() ? rsEst.getString(1) : null;
                rsEst.close(); psEst.close();
                if (!"Generada".equals(estadoActual) && !"Enviada".equals(estadoActual)) {
                    throw new SQLException("La solicitud no existe o ya tiene recepciones / está cancelada.");
                }

                PreparedStatement psChk = conexion.prepareStatement(
                    "SELECT COUNT(*) FROM public.solicitudes_compra_detalle WHERE id_solicitud = ? AND cantidad_recibida > 0");
                psChk.setInt(1, idSolAnula);
                ResultSet rsChk = psChk.executeQuery();
                rsChk.next();
                int conRecepcion = rsChk.getInt(1);
                rsChk.close(); psChk.close();
                if (conRecepcion > 0) {
                    throw new SQLException("La solicitud ya tiene artículos recibidos; no se puede anular.");
                }

                PreparedStatement psAn = conexion.prepareStatement(
                    "UPDATE public.solicitudes_compra SET estado = 'Cancelada', motivo_anulacion = ?, "
                    + "fecha_anulacion = CURRENT_TIMESTAMP, id_usuario_anula = ? WHERE id_solicitud = ?");
                psAn.setString(1, motivoAnula.trim());
                psAn.setInt(2, idUsuarioAnula);
                psAn.setInt(3, idSolAnula);
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

        // 5. Comprobante en PDF (JasperReports) de una Solicitud de Reposición
        if ("comprobantePdf".equals(tipo)) {
            Integer idSolicitud = tryParseInt(request.getParameter("idSolicitud"));
            if (idSolicitud == null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: ID inválido");
                return;
            }
            java.util.List<Integer> ids = new java.util.ArrayList<Integer>();
            ids.add(idSolicitud);
            byte[] bytes = ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteSolicitudReposicion", new String[]{"comprobanteSolicitudReposicionDetalle"},
                    "ID_SOLICITUD", ids, (Integer) session.getAttribute("idUsuario"));
            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            response.setHeader("Content-Disposition", "inline; filename=solicitud_reposicion_" + idSolicitud + ".pdf");
            javax.servlet.ServletOutputStream salida = response.getOutputStream();
            salida.write(bytes, 0, bytes.length);
            salida.flush();
            salida.close();
            return;
        }

        // 6. Listar inventario general de EQUIPOS (con estado)
        if ("listarEquiposStock".equals(tipo)) {
            String sql = "SELECT e.id_equipo, COALESCE(e.codigo_patrimonial, 'Sin código') AS codigo_patrimonial, e.modelo, " +
                         "CASE WHEN e.estado = 'Activo' THEN 'Activo' ELSE COALESCE((SELECT nombre_motivo FROM public.motivos_inactivo mi WHERE mi.id_motivo = e.id_motivo_inactivo), 'Inactivo') END AS estado, " +
                         "COALESCE(m.nombre_marca,'-') AS marca, COALESCE(c.nombre_categoria,'-') AS categoria, " +
                         "COALESCE(s.nombre_sala,'-') AS sala " +
                         "FROM public.equipos e " +
                         "LEFT JOIN public.marcas m ON e.id_marca = m.id_marca " +
                         "LEFT JOIN public.categorias c ON e.id_categoria = c.id_categoria " +
                         "LEFT JOIN public.salas s ON e.id_sala = s.id_sala " +
                         "ORDER BY (e.estado <> 'Activo') DESC, e.codigo_patrimonial ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                boolean activo = "Activo".equals(rs.getString("estado"));
                String badgeEstado = activo
                        ? "<span class='badge badge-success'>Activo</span>"
                        : "<span class='badge badge-danger'>" + rs.getString("estado") + "</span>";
                String nombreEscapado = (rs.getString("codigo_patrimonial") + " - " + rs.getString("modelo")).replace("'", "&#39;").replace("\"", "&quot;");
%>
                <tr class="<%= activo ? "" : "table-danger" %> fila-equipo">
                    <td><b class="text-primary"><%= rs.getString("codigo_patrimonial") %></b></td>
                    <td><%= rs.getString("modelo") %></td>
                    <td><%= rs.getString("marca") %></td>
                    <td><%= rs.getString("categoria") %></td>
                    <td><%= rs.getString("sala") %></td>
                    <td class="text-center"><%= badgeEstado %></td>
                    <td class="text-center">
                        <% if (activo) { %>
                        <button type="button" class="btn btn-outline-danger btn-sm"
                                onclick="abrirAjuste('E', <%= rs.getInt("id_equipo") %>, '<%= nombreEscapado %>')">
                            <i class="fas fa-exclamation-triangle"></i> Ajustar
                        </button>
                        <% } else { %>
                        <span class="text-muted">-</span>
                        <% } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='7' class='text-center text-muted py-3'>No hay equipos registrados.</td></tr>");
            }
            return;
        }

        // 7. Registrar un ajuste de inventario (robo / pérdida / rotura / etc.)
        //    - Repuesto o Insumo: cambia el stock a un valor nuevo indicado.
        //    - Equipo: lo marca como "De baja" (deja de estar disponible).
        if ("registrarAjuste".equals(tipo)) {
            Integer idUsuario = (Integer) session.getAttribute("idUsuario");
            String tipoItem = request.getParameter("tipoItem");     // R, I o E
            Integer idItem = tryParseInt(request.getParameter("idItem"));
            String motivo = request.getParameter("motivo");
            String observaciones = request.getParameter("observaciones");

            if (idUsuario == null) { out.print("error: sesión no válida"); return; }
            if (idItem == null || (!"R".equals(tipoItem) && !"I".equals(tipoItem) && !"E".equals(tipoItem))) {
                out.print("error: artículo inválido"); return;
            }
            if (motivo == null || motivo.trim().isEmpty()) {
                out.print("error: debe indicar el motivo del ajuste"); return;
            }

            try {
                conexion.setAutoCommit(false);
                Double cantAnterior = null, cantNueva = null;

                if ("E".equals(tipoItem)) {
                    // Fase 1: el equipo pasa a estado Inactivo con su motivo (tabla motivos_inactivo).
                    // Robo / Pérdida se descuentan; Rotura = Daño irreparable y otros = Descompuesto:
                    // siguen en el inventario y vuelven al Depósito.
                    String nombreMotivo = motivo.trim();
                    if ("Rotura".equalsIgnoreCase(nombreMotivo)) nombreMotivo = "Daño irreparable";
                    if (!"Robo".equalsIgnoreCase(nombreMotivo) && !"Pérdida".equalsIgnoreCase(nombreMotivo)
                            && !"Daño irreparable".equalsIgnoreCase(nombreMotivo)) nombreMotivo = "Descompuesto";
                    PreparedStatement psUpd = conexion.prepareStatement(
                        "UPDATE public.equipos e SET estado = 'Inactivo', fecha_inactivo = CURRENT_DATE, observacion_inactivo = ?, " +
                        "id_motivo_inactivo = m.id_motivo, " +
                        "id_sala = CASE WHEN m.descuenta THEN e.id_sala ELSE (SELECT id_sala FROM public.salas WHERE es_deposito) END " +
                        "FROM public.motivos_inactivo m " +
                        "WHERE lower(m.nombre_motivo) = lower(?) AND e.id_equipo = ? AND e.estado = 'Activo'");
                    psUpd.setString(1, observaciones != null && !observaciones.trim().isEmpty() ? observaciones.trim() : motivo.trim());
                    psUpd.setString(2, nombreMotivo);
                    psUpd.setInt(3, idItem);
                    int filas = psUpd.executeUpdate();
                    psUpd.close();
                    if (filas == 0) {
                        conexion.rollback();
                        out.print("error: el equipo no existe o ya estaba de baja");
                        return;
                    }
                } else {
                    String tabla = "R".equals(tipoItem) ? "public.catalogo_repuestos" : "public.catalogo_insumos";
                    String colId = "R".equals(tipoItem) ? "id_repuesto" : "id_insumo";
                    String cantidadNuevaStr = request.getParameter("cantidadNueva");
                    if (cantidadNuevaStr == null || cantidadNuevaStr.trim().isEmpty()) {
                        conexion.rollback();
                        out.print("error: debe indicar el nuevo stock");
                        return;
                    }
                    cantNueva = Double.parseDouble(cantidadNuevaStr.trim());
                    if (cantNueva < 0) {
                        conexion.rollback();
                        out.print("error: el stock no puede ser negativo");
                        return;
                    }

                    PreparedStatement psSel = conexion.prepareStatement(
                        "SELECT stock FROM " + tabla + " WHERE " + colId + " = ? FOR UPDATE");
                    psSel.setInt(1, idItem);
                    ResultSet rsSel = psSel.executeQuery();
                    if (!rsSel.next()) {
                        rsSel.close(); psSel.close(); conexion.rollback();
                        out.print("error: el artículo no existe");
                        return;
                    }
                    cantAnterior = rsSel.getDouble("stock");
                    rsSel.close(); psSel.close();

                    // Contexto para el kardex (trigger en la base)
                    try (PreparedStatement psCtx = conexion.prepareStatement("SELECT public.fn_kardex_contexto('AJUSTE', 'AJUSTE', NULL, ?, NULL)")) {
                        psCtx.setString(1, motivo.trim() + (observaciones != null && !observaciones.trim().isEmpty() ? " - " + observaciones.trim() : ""));
                        psCtx.execute();
                    }
                    // Daño irreparable: lo que baja del stock disponible queda registrado como stock dañado.
                    // Robo / pérdida / otros: se descuenta.
                    boolean porDanio = "Rotura".equalsIgnoreCase(motivo.trim()) || "Daño irreparable".equalsIgnoreCase(motivo.trim());
                    PreparedStatement psUpd = conexion.prepareStatement(
                        "UPDATE " + tabla + " SET stock = ?" + (porDanio ? ", stock_danado = stock_danado + GREATEST(stock - ?, 0)" : "") + " WHERE " + colId + " = ?");
                    psUpd.setDouble(1, cantNueva);
                    if (porDanio) { psUpd.setDouble(2, cantNueva); psUpd.setInt(3, idItem); }
                    else psUpd.setInt(2, idItem);
                    psUpd.executeUpdate();
                    psUpd.close();
                }

                PreparedStatement psAj = conexion.prepareStatement(
                    "INSERT INTO public.ajustes_inventario (tipo, id_item, cantidad_anterior, cantidad_nueva, motivo, observaciones, id_usuario) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?)");
                psAj.setString(1, tipoItem);
                psAj.setInt(2, idItem);
                if (cantAnterior != null) { psAj.setDouble(3, cantAnterior); } else { psAj.setNull(3, Types.DOUBLE); }
                if (cantNueva != null) { psAj.setDouble(4, cantNueva); } else { psAj.setNull(4, Types.DOUBLE); }
                psAj.setString(5, motivo.trim());
                psAj.setString(6, observaciones != null ? observaciones.trim() : null);
                psAj.setInt(7, idUsuario);
                psAj.executeUpdate();
                psAj.close();

                conexion.commit();
                out.print("success");
            } catch (Exception ex) {
                conexion.rollback();
                out.print("error: " + ex.getMessage());
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // 8. Historial de ajustes de inventario
        if ("listarAjustes".equals(tipo)) {
            String sql = "SELECT a.id_ajuste, a.tipo, a.cantidad_anterior, a.cantidad_nueva, a.motivo, a.observaciones, a.fecha_ajuste, " +
                         "p.nombre AS usu_nombre, p.apellido AS usu_apellido, " +
                         "CASE a.tipo " +
                         "  WHEN 'R' THEN (SELECT nombre FROM public.catalogo_repuestos WHERE id_repuesto = a.id_item) " +
                         "  WHEN 'I' THEN (SELECT nombre FROM public.catalogo_insumos WHERE id_insumo = a.id_item) " +
                         "  ELSE (SELECT codigo_patrimonial || ' - ' || modelo FROM public.equipos WHERE id_equipo = a.id_item) " +
                         "END AS nombre_item " +
                         "FROM public.ajustes_inventario a " +
                         "LEFT JOIN public.usuarios u ON a.id_usuario = u.id_usuario " +
                         "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                         "ORDER BY a.fecha_ajuste DESC LIMIT 100";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                String tipoItem = rs.getString("tipo");
                String badgeTipo = "R".equals(tipoItem) ? "<span class='badge badge-primary'>Repuesto</span>"
                        : "I".equals(tipoItem) ? "<span class='badge badge-info'>Insumo</span>"
                        : "<span class='badge badge-secondary'>Equipo</span>";
                String usuario = rs.getString("usu_apellido") != null
                        ? rs.getString("usu_apellido") + ", " + rs.getString("usu_nombre") : "-";
                String cantidades = "E".equals(tipoItem) ? "-"
                        : com.mycompany.pro.util.NumUtil.entero(rs.getObject("cantidad_anterior")) + " &rarr; " + com.mycompany.pro.util.NumUtil.entero(rs.getObject("cantidad_nueva"));
%>
                <tr>
                    <td><%= _fh(rs.getTimestamp("fecha_ajuste"), "-") %></td>
                    <td><%= badgeTipo %></td>
                    <td><%= rs.getString("nombre_item") %></td>
                    <td class="text-center"><span class="badge badge-warning"><%= rs.getString("motivo") %></span></td>
                    <td class="text-center"><%= cantidades %></td>
                    <td><%= rs.getString("observaciones") != null ? rs.getString("observaciones") : "-" %></td>
                    <td><%= usuario %></td>
                    <td class="text-center">
<%                  if (Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                        String obsAttr = rs.getString("observaciones") == null ? "" : rs.getString("observaciones")
                                .replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;"); %>
                        <button type="button" class="btn btn-warning btn-xs btn-edit-ajuste" title="Modificar motivo / observaciones"
                                data-id="<%= rs.getInt("id_ajuste") %>" data-motivo="<%= rs.getString("motivo") %>" data-obs="<%= obsAttr %>">
                            <i class="fas fa-edit"></i></button>
<%                  } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='8' class='text-center text-muted py-3'>Todavía no se registraron ajustes de inventario.</td></tr>");
            }
            return;
        }

        // 8-bis. Modificar o eliminar un registro del historial de ajustes (SOLO Administrador).
        //        Es solo el registro de auditoría: no toca el stock del artículo.
        if ("modificarAjuste".equals(tipo) || "eliminarAjuste".equals(tipo)) {
            if (!Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("error: solo el administrador puede modificar el historial de ajustes");
                return;
            }
            Integer idAjuste = tryParseInt(request.getParameter("idAjuste"));
            if (idAjuste == null) {
                out.print("error: ajuste inválido");
                return;
            }
            if ("eliminarAjuste".equals(tipo)) {
                out.print("error: los ajustes de inventario no se eliminan (quedan en el historial de movimientos de stock)");
                return;
            }
            if ("eliminarAjusteDeshabilitado".equals(tipo)) {
                PreparedStatement psD = conexion.prepareStatement("DELETE FROM public.ajustes_inventario WHERE id_ajuste = ?");
                psD.setInt(1, idAjuste);
                int filasD = psD.executeUpdate();
                psD.close();
                out.print(filasD > 0 ? "success" : "error: el ajuste ya no existe");
                return;
            }
            String motivoAj = request.getParameter("motivo");
            String obsAj = request.getParameter("observaciones");
            if (motivoAj == null || motivoAj.trim().isEmpty() || motivoAj.trim().length() > 30) {
                out.print("error: indique un motivo válido");
                return;
            }
            PreparedStatement psU = conexion.prepareStatement(
                "UPDATE public.ajustes_inventario SET motivo = ?, observaciones = ? WHERE id_ajuste = ?");
            psU.setString(1, motivoAj.trim());
            psU.setString(2, (obsAj == null || obsAj.trim().isEmpty()) ? null : obsAj.trim());
            psU.setInt(3, idAjuste);
            int filasU = psU.executeUpdate();
            psU.close();
            out.print(filasU > 0 ? "success" : "error: el ajuste ya no existe");
            return;
        }

        // 9. Detalle de una solicitud, con lo ya recibido de cada item
        //    (para la pantalla de "Recibir" por número de ticket/solicitud)
        if ("detalleSolicitud".equals(tipo)) {
            Integer idSolicitud = tryParseInt(request.getParameter("idSolicitud"));
            if (idSolicitud == null) {
                out.print("<tr><td colspan='6' class='text-center text-danger py-3'>Solicitud inválida.</td></tr>");
                return;
            }
            String sql = "SELECT d.id_repuesto, d.id_insumo, d.cantidad_solicitada, d.cantidad_recibida, " +
                         "COALESCE(r.ultimo_costo, i.ultimo_costo, 0) AS ultimo_costo, " +
                         "(SELECT COALESCE(sum(ra.cantidad), 0) FROM public.recepciones rc JOIN public.recepciones_detalle_articulos ra ON ra.id_recepcion = rc.id_recepcion " +
                         " WHERE rc.id_solicitud_origen = d.id_solicitud AND rc.estado <> 'Confirmada' " +
                         " AND ra.id_repuesto IS NOT DISTINCT FROM d.id_repuesto AND ra.id_insumo IS NOT DISTINCT FROM d.id_insumo) AS en_revision, " +
                         "CASE WHEN d.id_repuesto IS NOT NULL THEN 'R' ELSE 'I' END AS tipoItem, " +
                         "COALESCE(r.nombre, i.nombre) AS nombre, COALESCE(r.stock, i.stock) AS stock_actual " +
                         "FROM public.solicitudes_compra_detalle d " +
                         "LEFT JOIN public.catalogo_repuestos r ON d.id_repuesto = r.id_repuesto " +
                         "LEFT JOIN public.catalogo_insumos i ON d.id_insumo = i.id_insumo " +
                         "WHERE d.id_solicitud = ? ORDER BY nombre ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ps.setInt(1, idSolicitud);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            while (rs.next()) {
                cont++;
                String tipoItem = rs.getString("tipoItem");
                int idItem = "R".equals(tipoItem) ? rs.getInt("id_repuesto") : rs.getInt("id_insumo");
                double solicitada = rs.getDouble("cantidad_solicitada");
                double recibida = rs.getDouble("cantidad_recibida");
                double enRevision = rs.getDouble("en_revision");
                double pendiente = Math.max(0, solicitada - recibida - enRevision);
                String badgeTipo = "R".equals(tipoItem) ? "<span class='badge badge-primary'>Repuesto</span>" : "<span class='badge badge-info'>Insumo</span>";
%>
                <tr>
                    <td><%= badgeTipo %></td>
                    <td><%= rs.getString("nombre") %></td>
                    <td class="text-center"><%= com.mycompany.pro.util.NumUtil.entero(solicitada) %></td>
                    <td class="text-center"><%= com.mycompany.pro.util.NumUtil.entero(recibida) %>
                        <% if (enRevision > 0) { %><small class="d-block text-warning"><%= com.mycompany.pro.util.NumUtil.entero(enRevision) %> por confirmar</small><% } %></td>
                    <td class="text-center">
                        <input type="number" class="form-control form-control-sm txt-recibir-ahora" style="width:90px;display:inline-block;"
                               data-tipo="<%= tipoItem %>" data-id="<%= idItem %>" data-max="<%= (long) pendiente %>" min="0" step="1"
                               value="<%= (long) pendiente %>" <%= pendiente <= 0 ? "disabled" : "" %> aria-label="Cantidad recibida">
                    </td>
                    <td class="text-center">
                        <input type="number" class="form-control form-control-sm txt-costo-ahora" style="width:110px;display:inline-block;"
                               min="0" step="1" value="<%= rs.getBigDecimal("ultimo_costo").setScale(0, java.math.RoundingMode.HALF_UP).toPlainString() %>"
                               <%= pendiente <= 0 ? "disabled" : "" %> aria-label="Costo unitario">
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='6' class='text-center text-muted py-3'>La solicitud no tiene items.</td></tr>");
            }
            return;
        }

        // 10. Registrar la recepción (ingreso al inventario) de una solicitud,
        //     identificada por su número de ticket / solicitud (id_solicitud).
        // Lo que llega de un pedido se registra como una Recepción (concepto
        // "Reposición") vinculada al pedido y entra directamente al stock.
        if ("registrarRecepcion".equals(tipo)) {
            Integer idSolicitud = tryParseInt(request.getParameter("idSolicitud"));
            Integer detCount = tryParseInt(request.getParameter("det_count"));
            String nroComprobante = request.getParameter("nroComprobante");
            Integer idUsuarioRec = (Integer) session.getAttribute("idUsuario");
            if (idSolicitud == null) { out.print("error: solicitud inválida"); return; }
            if (detCount == null || detCount == 0) { out.print("error: no hay items para recibir"); return; }
            if (nroComprobante == null || nroComprobante.trim().isEmpty()) { out.print("error: ingrese el número de comprobante (remisión, nota o factura) de lo que llegó"); return; }

            try {
                conexion.setAutoCommit(false);
                Integer idDonantePed;
                try (PreparedStatement psEst = conexion.prepareStatement(
                        "SELECT estado, id_donante FROM public.solicitudes_compra WHERE id_solicitud = ? FOR UPDATE")) {
                    psEst.setInt(1, idSolicitud);
                    try (ResultSet rsEst = psEst.executeQuery()) {
                        if (!rsEst.next()) throw new Exception("La solicitud no existe.");
                        String est = rsEst.getString("estado");
                        if (!"Enviada".equals(est) && !"Recibida parcial".equals(est))
                            throw new Exception("Solo se reciben pedidos enviados a la institución (estado actual: " + est + ").");
                        idDonantePed = rsEst.getObject("id_donante") == null ? null : rsEst.getInt("id_donante");
                    }
                }
                if (idDonantePed == null) throw new Exception("El pedido no tiene institución: es un pedido anterior a la fase 6. Regístrelo como una recepción común.");

                int idConceptoRep;
                try (ResultSet rsC = conexion.prepareStatement(
                        "SELECT id_concepto FROM public.conceptos_entrada WHERE lower(nombre_concepto) = 'reposición' LIMIT 1").executeQuery()) {
                    if (!rsC.next()) throw new Exception("Falta el concepto de entrada 'Reposición' (script de la fase 1).");
                    idConceptoRep = rsC.getInt(1);
                }

                int idRecepcion; String numeroRec;
                try (PreparedStatement psR = conexion.prepareStatement(
                        "INSERT INTO public.recepciones (id_concepto, id_donante, nro_comprobante, observacion, id_usuario_registro, id_solicitud_origen) " +
                        "VALUES (?, ?, ?, (SELECT 'Reposición del pedido ' || numero_solicitud FROM public.solicitudes_compra WHERE id_solicitud = ?), ?, ?) " +
                        "RETURNING id_recepcion, numero_recepcion")) {
                    psR.setInt(1, idConceptoRep);
                    psR.setInt(2, idDonantePed);
                    psR.setString(3, nroComprobante.trim());
                    psR.setInt(4, idSolicitud);
                    psR.setInt(5, idUsuarioRec);
                    psR.setInt(6, idSolicitud);
                    try (ResultSet rsR = psR.executeQuery()) { rsR.next(); idRecepcion = rsR.getInt(1); numeroRec = rsR.getString(2); }
                }

                int lineas = 0;
                for (int i = 0; i < detCount; i++) {
                    String rawTipo = request.getParameter("det_tipo_" + i);
                    Integer itemId = tryParseInt(request.getParameter("det_id_" + i));
                    java.math.BigDecimal cant, costo;
                    try { cant = new java.math.BigDecimal(request.getParameter("det_cantidad_" + i).trim()); } catch (Exception exNum) { continue; }
                    try { costo = new java.math.BigDecimal(request.getParameter("det_costo_" + i).trim()); } catch (Exception exNum) { costo = java.math.BigDecimal.ZERO; }
                    if (itemId == null || cant.signum() <= 0) continue;
                    if (costo.signum() < 0) throw new Exception("El costo no puede ser negativo.");
                    String colDet = "R".equals(rawTipo) ? "id_repuesto" : "id_insumo";

                    // No se puede recibir más de lo que falta (descontando lo que ya está en otras recepciones sin confirmar)
                    try (PreparedStatement psP = conexion.prepareStatement(
                            "SELECT d.cantidad_solicitada - d.cantidad_recibida - " +
                            "  (SELECT COALESCE(sum(ra.cantidad), 0) FROM public.recepciones rc JOIN public.recepciones_detalle_articulos ra ON ra.id_recepcion = rc.id_recepcion " +
                            "   WHERE rc.id_solicitud_origen = d.id_solicitud AND rc.estado <> 'Confirmada' AND rc.id_recepcion <> ? AND ra." + colDet + " = d." + colDet + ") " +
                            "FROM public.solicitudes_compra_detalle d WHERE d.id_solicitud = ? AND d." + colDet + " = ?")) {
                        psP.setInt(1, idRecepcion);
                        psP.setInt(2, idSolicitud);
                        psP.setInt(3, itemId);
                        try (ResultSet rsP = psP.executeQuery()) {
                            if (!rsP.next()) throw new Exception("Un artículo no pertenece al pedido.");
                            if (cant.compareTo(rsP.getBigDecimal(1)) > 0)
                                throw new Exception("No puede recibir más de lo que falta del pedido (falta " + rsP.getBigDecimal(1).stripTrailingZeros().toPlainString() + ").");
                        }
                    }
                    try (PreparedStatement psD = conexion.prepareStatement(
                            "INSERT INTO public.recepciones_detalle_articulos (id_recepcion, " + colDet + ", cantidad, costo_unitario) VALUES (?, ?, ?, ?)")) {
                        psD.setInt(1, idRecepcion);
                        psD.setInt(2, itemId);
                        psD.setBigDecimal(3, cant);
                        psD.setBigDecimal(4, costo);
                        psD.executeUpdate();
                    }
                    lineas++;
                }
                if (lineas == 0) throw new Exception("Indique la cantidad recibida de al menos un artículo.");
                aplicarRecepcion(conexion, idRecepcion, idUsuarioRec);   // entra directo al stock
                conexion.commit();
                out.print("success|" + numeroRec);
            } catch (Exception ex) {
                conexion.rollback();
                out.print("error: " + mensajeError(ex));
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

    } catch (Exception e) {
        out.print("Error crítico en el controlador: " + e.getMessage());
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    private Integer tryParseInt(String value) {
        if (value == null || value.trim().isEmpty()) return null;
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
%>
