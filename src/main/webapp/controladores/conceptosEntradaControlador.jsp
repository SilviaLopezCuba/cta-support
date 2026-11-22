<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@include file="../config/conexion.jsp"%>
<%@page import="java.sql.*"%>
<%
    // Referencial: Conceptos de Entrada
    // Los registros no se eliminan: se activan o desactivan (quedan en el historial).
    // Solo el Administrador puede crear, modificar o cambiar el estado.
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String nombre = request.getParameter("nombre");
    boolean puedeEditar = "Administrador".equals((String) session.getAttribute("nombreRol"));

    try {
        if (!("listar".equals(tipo)) && !puedeEditar) {
            out.print("Error: solo el Administrador puede modificar este registro.");
        }

        // LISTAR
        else if ("listar".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT t.id_concepto, t.nombre_concepto, t.activo, t.es_sistema FROM public.conceptos_entrada t ORDER BY t.activo DESC, t.nombre_concepto");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                filas++;
                boolean activo = rs.getBoolean("activo");
                String sistemaBadge = rs.getBoolean("es_sistema") ? " <span class='badge badge-dark' title='Lo usa el sistema'>Sistema</span>" : "";
                boolean esSistema = rs.getBoolean("es_sistema");
%>
                <tr class="<%= activo ? "" : "text-muted" %>">
                    <td><%= rs.getInt("id_concepto") %></td>
                    <td><%= h(rs.getString("nombre_concepto")) %><%= sistemaBadge %></td>
                    <td class="text-center">
                        <span class="badge <%= activo ? "badge-success" : "badge-secondary" %>"><%= activo ? "Activo" : "Inactivo" %></span>
                    </td>
                    <td class="text-center text-nowrap">
                        <% if (!esSistema) { %>
                        <button class="btn btn-warning btn-sm" title="Modificar" aria-label="Modificar"
                                onclick="campos('<%= rs.getInt("id_concepto") %>', '<%= hj(rs.getString("nombre_concepto")) %>'); completar('Modificar Concepto', 'Modificar')">
                            <i class="fas fa-edit" aria-hidden="true"></i>
                        </button>
                        <button class="btn btn-sm <%= activo ? "btn-outline-secondary" : "btn-outline-success" %>"
                                title="<%= activo ? "Desactivar" : "Activar" %>" aria-label="<%= activo ? "Desactivar" : "Activar" %>"
                                onclick="cambiarEstado('<%= rs.getInt("id_concepto") %>', <%= activo %>)">
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
                out.print("<tr class='cta-empty-row'><td colspan='4' class='text-center text-muted py-3'>No hay registros cargados.</td></tr>");
            }
        }

        // GUARDAR / MODIFICAR
        else if ("Guardar".equals(tipo) || "Modificar".equals(tipo)) {
            boolean esNuevo = "Guardar".equals(tipo);
            if (nombre == null || nombre.trim().isEmpty()) throw new Exception("El nombre es obligatorio.");
            if (nombre.trim().length() > 100) throw new Exception("El nombre no puede superar los 100 caracteres.");
            if (!esNuevo) {
                try (PreparedStatement psSis = conexion.prepareStatement("SELECT es_sistema FROM public.conceptos_entrada WHERE id_concepto = ?")) {
                    psSis.setInt(1, Integer.parseInt(pk));
                    try (ResultSet rsSis = psSis.executeQuery()) {
                        if (rsSis.next() && rsSis.getBoolean("es_sistema")) throw new Exception("Este concepto lo usa el sistema y no se puede modificar.");
                    }
                }
            }
            exigirUnico(conexion, "public.conceptos_entrada", "nombre_concepto", "id_concepto", nombre, esNuevo ? null : pk, "Ya existe un registro con ese nombre.");
            String sql = esNuevo
                    ? "INSERT INTO public.conceptos_entrada (nombre_concepto) VALUES (?)"
                    : "UPDATE public.conceptos_entrada SET nombre_concepto = ? WHERE id_concepto = ?";
            try (PreparedStatement ps = conexion.prepareStatement(sql)) {
                    ps.setString(1, nombre.trim());
                    if (!esNuevo) ps.setInt(2, Integer.parseInt(pk));
                ps.executeUpdate();
            }
            out.print("success");
        }

        // ACTIVAR / DESACTIVAR (no se elimina)
        else if ("CambiarEstado".equals(tipo)) {
            try (PreparedStatement ps = conexion.prepareStatement(
                    "UPDATE public.conceptos_entrada SET activo = NOT activo WHERE id_concepto = ? AND NOT es_sistema")) {
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
