<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@include file="../config/conexion.jsp"%>
<%@page import="java.sql.*"%>
<%
    // Referencial: Tipos de Falla
    // Los registros no se eliminan: se activan o desactivan (quedan en el historial).
    // Solo el Administrador puede crear, modificar o cambiar el estado.
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String nombre = request.getParameter("nombre");
    String idCategoria = request.getParameter("id_categoria");
    boolean puedeEditar = "Administrador".equals((String) session.getAttribute("nombreRol"));

    try {
        if (!("listar".equals(tipo) || "combo".equals(tipo) || "categorias".equals(tipo)) && !puedeEditar) {
            out.print("Error: solo el Administrador puede modificar este registro.");
        }

        // LISTAR
        else if ("listar".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT t.id_tipo_falla, t.nombre_tipo_falla, t.activo, t.id_categoria, COALESCE(c.nombre_categoria, 'Todas') AS nombre_categoria, (SELECT count(*) FROM public.ticket tk WHERE tk.id_tipo_falla = t.id_tipo_falla) AS cantidad_uso FROM public.tipos_falla t LEFT JOIN public.categorias c ON c.id_categoria = t.id_categoria ORDER BY t.activo DESC, c.nombre_categoria NULLS FIRST, t.nombre_tipo_falla");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                filas++;
                boolean activo = rs.getBoolean("activo");
                String sistemaBadge = "";
                boolean esSistema = false;
%>
                <tr class="<%= activo ? "" : "text-muted" %>">
                    <td><%= rs.getInt("id_tipo_falla") %></td>
                    <td><%= h(rs.getString("nombre_tipo_falla")) %><%= sistemaBadge %></td>
                    <td><%= rs.getObject("id_categoria") == null ? "<span class='badge badge-secondary'>Todas</span>" : h(rs.getString("nombre_categoria")) %></td>
                    <td class="text-center"><%= rs.getInt("cantidad_uso") %></td>
                    <td class="text-center">
                        <span class="badge <%= activo ? "badge-success" : "badge-secondary" %>"><%= activo ? "Activo" : "Inactivo" %></span>
                    </td>
                    <td class="text-center text-nowrap">
                        <% if (!esSistema) { %>
                        <button class="btn btn-warning btn-sm" title="Modificar" aria-label="Modificar"
                                onclick="campos('<%= rs.getInt("id_tipo_falla") %>', '<%= hj(rs.getString("nombre_tipo_falla")) %>', '<%= rs.getObject("id_categoria") == null ? "" : rs.getInt("id_categoria") %>'); completar('Modificar Tipo de Falla', 'Modificar')">
                            <i class="fas fa-edit" aria-hidden="true"></i>
                        </button>
                        <button class="btn btn-sm <%= activo ? "btn-outline-secondary" : "btn-outline-success" %>"
                                title="<%= activo ? "Desactivar" : "Activar" %>" aria-label="<%= activo ? "Desactivar" : "Activar" %>"
                                onclick="cambiarEstado('<%= rs.getInt("id_tipo_falla") %>', <%= activo %>)">
                            <i class="fas <%= activo ? "fa-toggle-on" : "fa-toggle-off" %>" aria-hidden="true"></i>
                        </button>
                        <% } else { %>
                        <span class="text-muted small">Fijo</span>
                        <% } %>
                    </td>
                </tr>
<%
                }
            }
            if (filas == 0) {
                out.print("<tr class='cta-empty-row'><td colspan='6' class='text-center text-muted py-3'>No hay registros cargados.</td></tr>");
            }
        }

        // COMBO (para el formulario de tickets): fallas activas de la categoría del equipo + las generales
        else if ("combo".equals(tipo)) {
            out.print("<option value=''>-- Seleccione el tipo de falla --</option>");
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT id_tipo_falla, nombre_tipo_falla FROM public.tipos_falla WHERE activo AND (id_categoria IS NULL OR id_categoria = ?) " +
                    "ORDER BY (lower(nombre_tipo_falla) = 'otro'), id_categoria NULLS LAST, nombre_tipo_falla")) {
                String idCatCombo = request.getParameter("id_categoria");
                if (idCatCombo == null || idCatCombo.trim().isEmpty()) ps.setNull(1, Types.INTEGER); else ps.setInt(1, Integer.parseInt(idCatCombo.trim()));
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        out.print("<option value='" + rs.getInt("id_tipo_falla") + "'>" + h(rs.getString("nombre_tipo_falla")) + "</option>");
                    }
                }
            }
        }
        // Categorías para el combo del formulario
        else if ("categorias".equals(tipo)) {
            out.print("<option value=''>Todas las categorías (falla general)</option>");
            try (PreparedStatement ps = conexion.prepareStatement("SELECT id_categoria, nombre_categoria FROM public.categorias ORDER BY nombre_categoria");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    out.print("<option value='" + rs.getInt("id_categoria") + "'>" + h(rs.getString("nombre_categoria")) + "</option>");
                }
            }
        }
        // GUARDAR / MODIFICAR
        else if ("Guardar".equals(tipo) || "Modificar".equals(tipo)) {
            boolean esNuevo = "Guardar".equals(tipo);
            if (nombre == null || nombre.trim().isEmpty()) throw new Exception("El nombre es obligatorio.");
            if (nombre.trim().length() > 100) throw new Exception("El nombre no puede superar los 100 caracteres.");
            Integer idCat = (idCategoria == null || idCategoria.trim().isEmpty()) ? null : Integer.valueOf(idCategoria.trim());
            String sqlDup = "SELECT 1 FROM public.tipos_falla WHERE lower(trim(nombre_tipo_falla)) = lower(trim(?)) AND COALESCE(id_categoria, 0) = COALESCE(?, 0)"
                    + (esNuevo ? "" : " AND id_tipo_falla <> ?");
            try (PreparedStatement psDup = conexion.prepareStatement(sqlDup)) {
                psDup.setString(1, nombre);
                if (idCat == null) psDup.setNull(2, Types.INTEGER); else psDup.setInt(2, idCat);
                if (!esNuevo) psDup.setInt(3, Integer.parseInt(pk));
                try (ResultSet rsDup = psDup.executeQuery()) {
                    if (rsDup.next()) throw new Exception("Ya existe ese tipo de falla para la categoría elegida.");
                }
            }
            String sql = esNuevo
                    ? "INSERT INTO public.tipos_falla (nombre_tipo_falla, id_categoria) VALUES (?, ?)"
                    : "UPDATE public.tipos_falla SET nombre_tipo_falla = ?, id_categoria = ? WHERE id_tipo_falla = ?";
            try (PreparedStatement ps = conexion.prepareStatement(sql)) {
                    ps.setString(1, nombre.trim());
                    if (idCat == null) ps.setNull(2, Types.INTEGER); else ps.setInt(2, idCat);
                    if (!esNuevo) ps.setInt(3, Integer.parseInt(pk));
                ps.executeUpdate();
            }
            out.print("success");
        }

        // ACTIVAR / DESACTIVAR (no se elimina)
        else if ("CambiarEstado".equals(tipo)) {
            try (PreparedStatement ps = conexion.prepareStatement(
                    "UPDATE public.tipos_falla SET activo = NOT activo WHERE id_tipo_falla = ?")) {
                ps.setInt(1, Integer.parseInt(pk));
                if (ps.executeUpdate() == 0) throw new Exception("No se puede cambiar el estado de este registro.");
            }
            out.print("success");
        }
    } catch (Exception e) {
        out.print("Error: " + mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
