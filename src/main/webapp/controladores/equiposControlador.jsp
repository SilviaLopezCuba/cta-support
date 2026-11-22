<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@include file="../config/conexion.jsp"%>
<%@page import="net.sf.jasperreports.engine.JasperFillManager"%>
<%@page import="net.sf.jasperreports.engine.JasperPrint"%>
<%@page import="net.sf.jasperreports.engine.export.JRPdfExporter"%>
<%@page import="net.sf.jasperreports.export.SimpleExporterInput"%>
<%@page import="net.sf.jasperreports.export.SimpleOutputStreamExporterOutput"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="javax.servlet.http.HttpSession"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }

    /** Guaraníes sin decimales: 1500000 -> "1.500.000" */
    private static String _gs(java.math.BigDecimal v) {
        if (v == null) return "0";
        java.text.DecimalFormatSymbols sim = new java.text.DecimalFormatSymbols();
        sim.setGroupingSeparator('.');
        return new java.text.DecimalFormat("#,##0", sim).format(v.setScale(0, java.math.RoundingMode.HALF_UP));
    }

    /** Lee un entero opcional del formulario (vacío -> null). */
    private static Integer _int(String v) {
        return (v == null || v.trim().isEmpty()) ? null : Integer.valueOf(v.trim());
    }

    private String obtenerNombreGenerador(HttpSession sesion, Connection conexion) {
        try {
            Object idObj = sesion.getAttribute("idUsuario");
            if (idObj == null) return "-";
            try (PreparedStatement psGen = conexion.prepareStatement(
                    "SELECT p.nombre, p.apellido FROM public.usuarios u " +
                    "JOIN public.personas p ON u.id_persona = p.id_persona WHERE u.id_usuario = ?")) {
                psGen.setInt(1, (Integer) idObj);
                try (ResultSet rsGen = psGen.executeQuery()) {
                    return rsGen.next() ? rsGen.getString("nombre") + " " + rsGen.getString("apellido") : "-";
                }
            }
        } catch (Exception e) {
            return "-";
        }
    }
    private String obtenerRolGenerador(HttpSession sesion) {
        Object rol = sesion.getAttribute("nombreRol");
        return rol != null ? rol.toString() : "";
    }
%>
<%
    // ------------------------------------------------------------------
    // EQUIPOS PATRIMONIALES
    //  - Nunca se eliminan: pasan a Inactivo con un motivo.
    //      Descompuesto / Daño irreparable -> siguen en el inventario (vuelven al Depósito)
    //      Robo / Pérdida                  -> se descuentan del inventario y del patrimonio
    //  - En el Depósito el código patrimonial es opcional; en una sala es obligatorio.
    //  - Cada cambio de sala queda en historial_ubicacion_equipo (trigger en la base).
    //  - Acceso: Administrador y Encargado de depósito.
    //    Robo / Pérdida solo los registra el Administrador.
    // ------------------------------------------------------------------
    String accion = request.getParameter("accion");
    String pk = request.getParameter("id_equipo");
    String rolSesion = (String) session.getAttribute("nombreRol");
    boolean esAdminEq = "Administrador".equals(rolSesion);
    boolean esEncargadoEq = "Encargado de depósito".equals(rolSesion);

    try {
        if (!esAdminEq && !esEncargadoEq) {
            response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
            out.print("Error: acceso restringido al Administrador y al Encargado de depósito.");
            return;
        }

        // ============================================================
        // LISTAR (pestañas: activos | inactivos)
        // ============================================================
        if ("listar".equals(accion) && "referencial".equals(request.getParameter("vista"))) {
            // Referencial: solo los datos de cada equipo (sin estado, ubicación ni valores)
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT e.id_equipo, e.codigo_patrimonial, e.modelo, e.nro_serie, e.especificaciones, e.condicion_ingreso, m.nombre_marca, c.nombre_categoria " +
                    "FROM public.equipos e LEFT JOIN public.marcas m ON e.id_marca = m.id_marca LEFT JOIN public.categorias c ON e.id_categoria = c.id_categoria " +
                    "ORDER BY c.nombre_categoria, e.codigo_patrimonial NULLS LAST, e.id_equipo");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    int id = rs.getInt("id_equipo");
                    String cod = rs.getString("codigo_patrimonial");
                    out.print("<tr><td>" + id + "</td><td>" + (cod == null ? "<span class='text-muted'>Sin código</span>" : "<b class='text-primary text-uppercase'>" + h(cod) + "</b>") + "</td>"
                        + "<td>" + (rs.getString("nombre_categoria") == null ? "-" : h(rs.getString("nombre_categoria"))) + "</td>"
                        + "<td>" + (rs.getString("nombre_marca") == null ? "-" : h(rs.getString("nombre_marca"))) + "</td>"
                        + "<td>" + h(rs.getString("modelo")) + "</td>"
                        + "<td>" + (rs.getString("nro_serie") == null ? "-" : h(rs.getString("nro_serie"))) + "</td>"
                        + "<td class='small'>" + (rs.getString("especificaciones") == null ? "" : h(rs.getString("especificaciones"))) + "</td>"
                        + "<td>" + h(rs.getString("condicion_ingreso")) + "</td>"
                        + "<td class='text-center text-nowrap'><button class='btn btn-warning btn-sm' title='Modificar' aria-label='Modificar' onclick='editarEquipo(" + id + ")'><i class='fas fa-edit'></i></button> "
                        + "<button class='btn btn-info btn-sm' title='Ficha PDF' aria-label='Ficha PDF' onclick=\"window.open('../controladores/equiposControlador.jsp?accion=ReporteIndividual&id_equipo=" + id + "', '_blank')\"><i class='fas fa-file-pdf'></i></button></td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='9' class='text-center text-muted py-3'>No hay equipos registrados.</td></tr>");
        }

        else if ("listar".equals(accion)) {
            boolean verInactivos = "inactivos".equals(request.getParameter("vista"));
            boolean desdeInventario = "inventario".equals(request.getParameter("desde"));
            Integer filtroDepto = _int(request.getParameter("filtro_departamento"));   // -1 = Depósito
            StringBuilder sql = new StringBuilder(
                "SELECT e.*, m.nombre_marca, c.nombre_categoria, c.vida_util_anios, s.nombre_sala, s.es_deposito, " +
                "       d.nombre_departamento, mi.nombre_motivo, COALESCE(mi.descuenta, false) AS descuenta, " +
                "       ROUND(e.costo * GREATEST(0, 1 - ((CURRENT_DATE - e.fecha_ingreso) / 365.25) / NULLIF(c.vida_util_anios, 0))) AS valor_actual " +
                "FROM public.equipos e " +
                "LEFT JOIN public.marcas m ON e.id_marca = m.id_marca " +
                "LEFT JOIN public.categorias c ON e.id_categoria = c.id_categoria " +
                "LEFT JOIN public.salas s ON e.id_sala = s.id_sala " +
                "LEFT JOIN public.departamentos d ON s.id_departamento = d.id_departamento " +
                "LEFT JOIN public.motivos_inactivo mi ON e.id_motivo_inactivo = mi.id_motivo " +
                "WHERE e.estado = ? ");
            if (filtroDepto != null) sql.append(filtroDepto == -1 ? "AND s.es_deposito " : "AND s.id_departamento = ? ");
            sql.append("ORDER BY s.es_deposito DESC, d.nombre_departamento NULLS FIRST, s.nombre_sala, e.codigo_patrimonial NULLS FIRST, e.id_equipo DESC");

            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(sql.toString())) {
                ps.setString(1, verInactivos ? "Inactivo" : "Activo");
                if (filtroDepto != null && filtroDepto != -1) ps.setInt(2, filtroDepto);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        filas++;
                        int id = rs.getInt("id_equipo");
                        String cod = rs.getString("codigo_patrimonial");
                        String serie = rs.getString("nro_serie");
                        boolean enDeposito = rs.getBoolean("es_deposito");
                        boolean descuenta = rs.getBoolean("descuenta");
                        String ubicacion = enDeposito
                                ? "<span class='badge badge-warning'><i class='fas fa-warehouse' aria-hidden='true'></i> Depósito</span>"
                                : "<small class='text-muted d-block'>" + (rs.getString("nombre_departamento") == null ? "Sin departamento" : h(rs.getString("nombre_departamento"))) + "</small>" + h(rs.getString("nombre_sala"));
%>
                <tr>
                    <td><%= id %></td>
                    <td><%= cod == null ? "<span class='badge badge-light border'>Sin código</span>" : "<b class='text-primary text-uppercase'>" + h(cod) + "</b>" %></td>
                    <td>
                        <%= h(rs.getString("modelo")) %>
                        <% if (rs.getString("especificaciones") != null) { %>
                        <i class="fas fa-info-circle text-info" title="<%= h(rs.getString("especificaciones")) %>" aria-label="Especificaciones: <%= h(rs.getString("especificaciones")) %>"></i>
                        <% } %>
                    </td>
                    <td><%= serie == null ? "<span class='text-muted'>-</span>" : h(serie) %></td>
                    <td><%= rs.getString("nombre_marca") == null ? "-" : h(rs.getString("nombre_marca")) %></td>
                    <td><%= rs.getString("nombre_categoria") == null ? "-" : h(rs.getString("nombre_categoria")) %></td>
                    <td><%= ubicacion %></td>
                    <td><%= h(rs.getString("condicion_ingreso")) %></td>
                    <td class="text-right"><%= _gs(rs.getBigDecimal("costo")) %></td>
                    <td class="text-right"><%= (verInactivos && descuenta) ? "<span class='text-muted'>0</span>" : _gs(rs.getBigDecimal("valor_actual")) %></td>
<% if (verInactivos) { %>
                    <td>
                        <span class="badge <%= descuenta ? "badge-danger" : "badge-secondary" %>"><%= h(rs.getString("nombre_motivo")) %></span>
                        <small class="d-block text-muted"><%= _f(rs.getDate("fecha_inactivo")) %><%= descuenta ? " · descontado" : " · sigue en inventario" %></small>
                    </td>
<% } %>
                    <td class="text-center text-nowrap">
                        <% if (desdeInventario) { %>
                        <% } else if (!verInactivos) { %>
                        <button class="btn btn-warning btn-sm" title="Modificar / asignar sala" aria-label="Modificar" onclick="editarEquipo(<%= id %>)">
                            <i class="fas fa-edit" aria-hidden="true"></i>
                        </button>
                        <button class="btn btn-outline-danger btn-sm" title="Pasar a inactivo" aria-label="Pasar a inactivo" onclick="abrirInactivar(<%= id %>, '<%= hj((cod == null ? "Sin código" : cod) + " - " + rs.getString("modelo")) %>')">
                            <i class="fas fa-power-off" aria-hidden="true"></i>
                        </button>
                        <% } else if (!descuenta) { %>
                        <button class="btn btn-outline-success btn-sm" title="Reactivar (reparado)" aria-label="Reactivar" onclick="reactivar(<%= id %>)">
                            <i class="fas fa-undo" aria-hidden="true"></i>
                        </button>
                        <% } %>
                        <button class="btn btn-secondary btn-sm" title="Historial de ubicación" aria-label="Historial de ubicación" onclick="verHistorial(<%= id %>)">
                            <i class="fas fa-route" aria-hidden="true"></i>
                        </button>
                        <button class="btn btn-info btn-sm" title="Ficha PDF" aria-label="Ficha PDF" onclick="window.open('../controladores/equiposControlador.jsp?accion=ReporteIndividual&id_equipo=<%= id %>', '_blank')">
                            <i class="fas fa-file-pdf" aria-hidden="true"></i>
                        </button>
                    </td>
                </tr>
<%
                    }
                }
            }
            if (filas == 0) {
                out.print("<tr class='cta-empty-row'><td colspan='" + (verInactivos ? 12 : 11) + "' class='text-center text-muted py-3'>"
                        + (verInactivos ? "No hay equipos inactivos." : "No hay equipos activos para este filtro.") + "</td></tr>");
            }
        }

        // ============================================================
        // STOCK EN DEPÓSITO: equipos activos sin asignar, agrupados por modelo
        // ============================================================
        else if ("stockDeposito".equals(accion)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT COALESCE(c.nombre_categoria, '-') AS categoria, COALESCE(m.nombre_marca, '-') AS marca, e.modelo, " +
                    "       e.condicion_ingreso, count(*) AS cantidad, " +
                    "       count(*) FILTER (WHERE e.codigo_patrimonial IS NULL) AS sin_codigo " +
                    "FROM public.equipos e " +
                    "JOIN public.salas s ON s.id_sala = e.id_sala AND s.es_deposito " +
                    "LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria " +
                    "LEFT JOIN public.marcas m ON m.id_marca = e.id_marca " +
                    "WHERE e.estado = 'Activo' " +
                    "GROUP BY 1, 2, 3, 4 ORDER BY 1, 2, 3");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    out.print("<tr><td>" + h(rs.getString("categoria")) + "</td><td>" + h(rs.getString("marca")) + "</td><td>"
                            + h(rs.getString("modelo")) + "</td><td>" + h(rs.getString("condicion_ingreso")) + "</td>"
                            + "<td class='text-center'><b>" + rs.getInt("cantidad") + "</b></td>"
                            + "<td class='text-center'>" + rs.getInt("sin_codigo") + "</td></tr>");
                }
            }
            if (filas == 0) {
                out.print("<tr class='cta-empty-row'><td colspan='6' class='text-center text-muted py-3'>No hay equipos disponibles en el Depósito.</td></tr>");
            }
        }

        // ============================================================
        // OBTENER (para el formulario de edición) -> JSON
        // ============================================================
        else if ("obtener".equals(accion)) {
            response.setContentType("application/json;charset=UTF-8");
            try (PreparedStatement ps = conexion.prepareStatement("SELECT * FROM public.equipos WHERE id_equipo = ?")) {
                ps.setInt(1, Integer.parseInt(pk));
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) { out.print("{}"); return; }
                    org.json.JSONObject j = new org.json.JSONObject();
                    j.put("id_equipo", rs.getInt("id_equipo"));
                    j.put("codigo_patrimonial", rs.getString("codigo_patrimonial") == null ? "" : rs.getString("codigo_patrimonial"));
                    j.put("modelo", rs.getString("modelo"));
                    j.put("id_marca", rs.getObject("id_marca") == null ? "" : rs.getString("id_marca"));
                    j.put("id_categoria", rs.getObject("id_categoria") == null ? "" : rs.getString("id_categoria"));
                    j.put("id_sala", rs.getObject("id_sala") == null ? "" : rs.getString("id_sala"));
                    j.put("nro_serie", rs.getString("nro_serie") == null ? "" : rs.getString("nro_serie"));
                    j.put("garantia", rs.getDate("fecha_vencimiento_garantia") == null ? "" : rs.getDate("fecha_vencimiento_garantia").toString());
                    j.put("especificaciones", rs.getString("especificaciones") == null ? "" : rs.getString("especificaciones"));
                    j.put("condicion_ingreso", rs.getString("condicion_ingreso"));
                    j.put("costo", rs.getBigDecimal("costo").setScale(0, java.math.RoundingMode.HALF_UP).toPlainString());
                    j.put("fecha_ingreso", rs.getDate("fecha_ingreso").toString());
                    out.print(j.toString());
                }
            }
        }

        // ============================================================
        // COMBOS
        // ============================================================
        else if ("cargarCategorias".equals(accion)) {
            out.print("<option value=''>-- Seleccione Categoría --</option>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_categoria, nombre_categoria FROM public.categorias ORDER BY nombre_categoria").executeQuery()) {
                while (rs.next()) out.print("<option value='" + rs.getInt("id_categoria") + "'>" + h(rs.getString("nombre_categoria")) + "</option>");
            }
        }
        else if ("cargarMarcas".equals(accion)) {
            out.print("<option value=''>-- Seleccione Marca --</option>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_marca, nombre_marca FROM public.marcas ORDER BY nombre_marca").executeQuery()) {
                while (rs.next()) out.print("<option value='" + rs.getInt("id_marca") + "'>" + h(rs.getString("nombre_marca")) + "</option>");
            }
        }
        // Salas agrupadas por departamento; el Depósito primero
        else if ("cargarSalas".equals(accion)) {
            out.print("<option value=''>-- Seleccione la ubicación --</option>");
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT s.id_sala, s.nombre_sala, s.es_deposito, COALESCE(d.nombre_departamento, 'Sin departamento') AS depto " +
                    "FROM public.salas s LEFT JOIN public.departamentos d ON d.id_departamento = s.id_departamento " +
                    "ORDER BY s.es_deposito DESC, d.nombre_departamento NULLS LAST, s.nombre_sala").executeQuery()) {
                String grupoActual = null;
                while (rs.next()) {
                    boolean dep = rs.getBoolean("es_deposito");
                    String grupo = dep ? "Depósito" : rs.getString("depto");
                    if (!grupo.equals(grupoActual)) {
                        if (grupoActual != null) out.print("</optgroup>");
                        out.print("<optgroup label='" + h(grupo) + "'>");
                        grupoActual = grupo;
                    }
                    out.print("<option value='" + rs.getInt("id_sala") + "' data-deposito='" + dep + "'>" + h(rs.getString("nombre_sala")) + "</option>");
                }
                if (grupoActual != null) out.print("</optgroup>");
            }
        }
        else if ("cargarDepartamentos".equals(accion)) {
            out.print("<option value=''>Todas las ubicaciones</option><option value='-1'>Solo Depósito</option>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_departamento, nombre_departamento FROM public.departamentos ORDER BY nombre_departamento").executeQuery()) {
                while (rs.next()) out.print("<option value='" + rs.getInt("id_departamento") + "'>Dpto. " + h(rs.getString("nombre_departamento")) + "</option>");
            }
        }
        else if ("cargarMotivos".equals(accion)) {
            out.print("<option value=''>-- Seleccione el motivo --</option>");
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT id_motivo, nombre_motivo, descuenta FROM public.motivos_inactivo WHERE activo AND aplica_equipos ORDER BY descuenta, nombre_motivo").executeQuery()) {
                while (rs.next()) {
                    boolean desc = rs.getBoolean("descuenta");
                    // Robo / Pérdida: solo el Administrador
                    if (desc && !esAdminEq) continue;
                    out.print("<option value='" + rs.getInt("id_motivo") + "' data-descuenta='" + desc + "'>" + h(rs.getString("nombre_motivo"))
                            + (desc ? " (se descuenta del inventario)" : " (sigue en inventario)") + "</option>");
                }
            }
        }

        // ============================================================
        // GUARDAR (alta o modificación). No cambia el estado: eso va por inactivar/reactivar.
        // ============================================================
        else if ("guardar".equals(accion)) {
            // Los equipos ingresan únicamente por Recepción (mesa de entrada con confirmación).
            if (pk == null || pk.trim().isEmpty()) throw new Exception("Los equipos nuevos se registran desde Recepción de equipos e insumos.");
            String cod = request.getParameter("codigo_patrimonial");
            String mod = request.getParameter("modelo");
            Integer mar = _int(request.getParameter("id_marca"));
            Integer cat = _int(request.getParameter("id_categoria"));
            Integer sal = _int(request.getParameter("id_sala"));
            String ser = request.getParameter("nro_serie");
            String gar = request.getParameter("garantia");
            String esp = request.getParameter("especificaciones");
            String cond = request.getParameter("condicion_ingreso");
            String costoStr = request.getParameter("costo");
            String fIng = request.getParameter("fecha_ingreso");

            if (mod == null || mod.trim().isEmpty()) throw new Exception("Ingrese el modelo o nombre del equipo.");
            if (cat == null) throw new Exception("Seleccione la categoría.");
            if (sal == null) {
                // Desde el referencial no se cambia la ubicación (eso se hace en Asignación de equipos)
                try (PreparedStatement psSa = conexion.prepareStatement("SELECT id_sala FROM public.equipos WHERE id_equipo = ?")) {
                    psSa.setInt(1, Integer.parseInt(pk));
                    try (ResultSet rsSa = psSa.executeQuery()) { if (rsSa.next()) sal = rsSa.getInt(1); }
                }
                if (sal == null) throw new Exception("El equipo no existe.");
            }
            if (!"Nuevo".equals(cond) && !"Seminuevo".equals(cond) && !"Usado".equals(cond)) throw new Exception("Seleccione la condición de ingreso.");
            java.math.BigDecimal costo;
            try {
                costo = new java.math.BigDecimal((costoStr == null || costoStr.trim().isEmpty()) ? "0" : costoStr.trim().replace(".", "").replace(",", "."));
            } catch (NumberFormatException exCosto) { throw new Exception("El costo debe ser un número."); }
            if (costo.signum() < 0) throw new Exception("El costo no puede ser negativo.");

            boolean salaEsDeposito;
            try (PreparedStatement psS = conexion.prepareStatement("SELECT es_deposito FROM public.salas WHERE id_sala = ?")) {
                psS.setInt(1, sal);
                try (ResultSet rsS = psS.executeQuery()) {
                    if (!rsS.next()) throw new Exception("La ubicación elegida no existe.");
                    salaEsDeposito = rsS.getBoolean("es_deposito");
                }
            }
            if (!salaEsDeposito && (cod == null || cod.trim().isEmpty())) {
                throw new Exception("El equipo está en una sala: el código patrimonial es obligatorio.");
            }
            if (cod != null && !cod.trim().isEmpty()) {
                exigirUnico(conexion, "public.equipos", "codigo_patrimonial", "id_equipo", cod, pk, "Ya existe un equipo con ese código patrimonial.");
            }
            if (ser != null && !ser.trim().isEmpty()) {
                exigirUnico(conexion, "public.equipos", "nro_serie", "id_equipo", ser, pk, "Ya existe un equipo con ese número de serie.");
            }

            boolean esNuevo = (pk == null || pk.trim().isEmpty());
            // Costo, condición y fecha de ingreso vienen de la recepción: solo el Administrador los corrige.
            if (!esAdminEq) {
                try (PreparedStatement psOrig = conexion.prepareStatement(
                        "SELECT condicion_ingreso, costo, fecha_ingreso FROM public.equipos WHERE id_equipo = ?")) {
                    psOrig.setInt(1, Integer.parseInt(pk));
                    try (ResultSet rsOrig = psOrig.executeQuery()) {
                        if (rsOrig.next()) {
                            cond = rsOrig.getString("condicion_ingreso");
                            costo = rsOrig.getBigDecimal("costo");
                            fIng = rsOrig.getDate("fecha_ingreso").toString();
                        }
                    }
                }
            }
            String sql = esNuevo
                ? "INSERT INTO public.equipos (codigo_patrimonial, modelo, id_marca, id_categoria, id_sala, nro_serie, fecha_vencimiento_garantia, " +
                  "especificaciones, condicion_ingreso, costo, fecha_ingreso, estado) VALUES (?,?,?,?,?,?,?,?,?,?,COALESCE(?, CURRENT_DATE),'Activo')"
                : "UPDATE public.equipos SET codigo_patrimonial=?, modelo=?, id_marca=?, id_categoria=?, id_sala=?, nro_serie=?, fecha_vencimiento_garantia=?, " +
                  "especificaciones=?, condicion_ingreso=?, costo=?, fecha_ingreso=COALESCE(?, fecha_ingreso) WHERE id_equipo=?";
            try (PreparedStatement ps = conexion.prepareStatement(sql)) {
                ps.setString(1, (cod == null || cod.trim().isEmpty()) ? null : cod.trim());
                ps.setString(2, mod.trim());
                if (mar == null) ps.setNull(3, Types.INTEGER); else ps.setInt(3, mar);
                ps.setInt(4, cat);
                ps.setInt(5, sal);
                ps.setString(6, (ser == null || ser.trim().isEmpty()) ? null : ser.trim());
                ps.setDate(7, (gar != null && !gar.isEmpty()) ? Date.valueOf(gar) : null);
                ps.setString(8, (esp == null || esp.trim().isEmpty()) ? null : esp.trim());
                ps.setString(9, cond);
                ps.setBigDecimal(10, costo);
                ps.setDate(11, (fIng != null && !fIng.isEmpty()) ? Date.valueOf(fIng) : null);
                if (!esNuevo) ps.setInt(12, Integer.parseInt(pk));
                if (ps.executeUpdate() == 0) throw new Exception("El equipo no existe.");
            }
            out.print("success");
        }

        // ============================================================
        // PASAR A INACTIVO (reemplaza al "eliminar")
        // ============================================================
        else if ("inactivar".equals(accion)) {
            Integer idMotivo = _int(request.getParameter("id_motivo"));
            String obs = request.getParameter("observacion");
            String fecha = request.getParameter("fecha_inactivo");
            if (idMotivo == null) throw new Exception("Seleccione el motivo.");
            if (obs == null || obs.trim().length() < 5) throw new Exception("Escriba una observación (al menos 5 caracteres).");

            boolean descuenta;
            try (PreparedStatement psM = conexion.prepareStatement(
                    "SELECT descuenta FROM public.motivos_inactivo WHERE id_motivo = ? AND activo AND aplica_equipos")) {
                psM.setInt(1, idMotivo);
                try (ResultSet rsM = psM.executeQuery()) {
                    if (!rsM.next()) throw new Exception("Motivo no válido.");
                    descuenta = rsM.getBoolean("descuenta");
                }
            }
            if (descuenta && !esAdminEq) throw new Exception("Solo el Administrador puede registrar un robo o una pérdida.");

            // Descompuesto / Daño irreparable: el equipo vuelve físicamente al Depósito.
            // Robo / Pérdida: queda registrada la última sala donde estaba.
            String sql = "UPDATE public.equipos SET estado = 'Inactivo', id_motivo_inactivo = ?, observacion_inactivo = ?, " +
                         "fecha_inactivo = COALESCE(?, CURRENT_DATE)" +
                         (descuenta ? "" : ", id_sala = (SELECT id_sala FROM public.salas WHERE es_deposito)") +
                         " WHERE id_equipo = ? AND estado = 'Activo'";
            try (PreparedStatement ps = conexion.prepareStatement(sql)) {
                ps.setInt(1, idMotivo);
                ps.setString(2, obs.trim());
                ps.setDate(3, (fecha != null && !fecha.isEmpty()) ? Date.valueOf(fecha) : null);
                ps.setInt(4, Integer.parseInt(pk));
                if (ps.executeUpdate() == 0) throw new Exception("El equipo no existe o ya estaba inactivo.");
            }
            out.print("success");
        }

        // ============================================================
        // REACTIVAR (solo si el motivo no descuenta: un equipo reparado)
        // Queda en el Depósito, listo para asignarse a una sala.
        // ============================================================
        else if ("reactivar".equals(accion)) {
            try (PreparedStatement ps = conexion.prepareStatement(
                    "UPDATE public.equipos e SET estado = 'Activo' " +
                    "WHERE e.id_equipo = ? AND e.estado = 'Inactivo' " +
                    "AND NOT EXISTS (SELECT 1 FROM public.motivos_inactivo m WHERE m.id_motivo = e.id_motivo_inactivo AND m.descuenta)")) {
                ps.setInt(1, Integer.parseInt(pk));
                if (ps.executeUpdate() == 0) throw new Exception("Este equipo no se puede reactivar (fue dado de baja por robo o pérdida).");
            }
            out.print("success");
        }

        // ============================================================
        // HISTORIAL DE UBICACIÓN
        // ============================================================
        else if ("historial".equals(accion)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT h.fecha, so.nombre_sala AS origen, sd.nombre_sala AS destino, h.observacion, " +
                    "       COALESCE(p.nombre || ' ' || p.apellido, u.login, 'Sistema') AS usuario " +
                    "FROM public.historial_ubicacion_equipo h " +
                    "LEFT JOIN public.salas so ON so.id_sala = h.id_sala_origen " +
                    "LEFT JOIN public.salas sd ON sd.id_sala = h.id_sala_destino " +
                    "LEFT JOIN public.usuarios u ON u.id_usuario = h.id_usuario " +
                    "LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "WHERE h.id_equipo = ? ORDER BY h.fecha DESC, h.id_historial DESC")) {
                ps.setInt(1, Integer.parseInt(pk));
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        filas++;
                        out.print("<tr><td class='text-nowrap'>" + _fh(rs.getTimestamp("fecha")) + "</td><td>"
                                + (rs.getString("origen") == null ? "<span class='text-muted'>-</span>" : h(rs.getString("origen"))) + "</td><td>"
                                + h(rs.getString("destino")) + "</td><td>" + h(rs.getString("usuario")) + "</td><td>"
                                + (rs.getString("observacion") == null ? "" : h(rs.getString("observacion"))) + "</td></tr>");
                    }
                }
            }
            if (filas == 0) out.print("<tr><td colspan='5' class='text-center text-muted'>Sin movimientos registrados.</td></tr>");
        }

        // ============================================================
        // REPORTES PDF
        // ============================================================
        // Fase 7: patrimonio valorizado (con depreciación) por ubicación
        else if ("ReportePatrimonio".equals(accion)) {
            java.util.List<Integer> ids = new java.util.ArrayList<Integer>();
            String salaP = request.getParameter("id_sala");
            ids.add(salaP == null || salaP.trim().isEmpty() ? null : Integer.valueOf(salaP.trim()));
            byte[] pdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "reportePatrimonio", new String[]{}, "ID_SALA", ids, (Integer) session.getAttribute("idUsuario"));
            response.reset();
            response.setContentType("application/pdf");
            response.setContentLength(pdf.length);
            response.setHeader("Content-Disposition", "inline; filename=patrimonio_equipos.pdf");
            response.getOutputStream().write(pdf, 0, pdf.length);
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }
        else if ("ReporteGeneral".equals(accion) || "ReporteIndividual".equals(accion)) {
            boolean individual = "ReporteIndividual".equals(accion);
            net.sf.jasperreports.engine.JasperReport reporte = com.mycompany.pro.util.ReporteUtil.cargar(application,
                    individual ? "reporte_equipo_individual" : "reporte_equipos");
            Map<String, Object> parametros = new HashMap<String, Object>();
            if (individual) parametros.put("P_ID_EQUIPO", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));
            JasperPrint jasperPrint = JasperFillManager.fillReport(reporte, parametros, conexion);
            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=" + (individual ? "ficha_equipo_" + pk : "reporte_equipos") + ".pdf");
            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }
    } catch (Exception e) {
        out.print("Error: " + mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
