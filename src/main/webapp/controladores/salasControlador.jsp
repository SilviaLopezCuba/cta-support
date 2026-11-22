<%@include file="../config/conexion.jsp"%>
<%@page import="java.sql.*"%>
<%@page import="net.sf.jasperreports.engine.JasperFillManager"%>
<%@page import="net.sf.jasperreports.engine.JasperPrint"%>
<%@page import="net.sf.jasperreports.engine.export.JRPdfExporter"%>
<%@page import="net.sf.jasperreports.export.SimpleExporterInput"%>
<%@page import="net.sf.jasperreports.export.SimpleOutputStreamExporterOutput"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="java.io.InputStream"%>
<%@page import="javax.servlet.http.HttpSession"%>
<%!
    // Busca nombre y apellido de la persona dueña del usuario logueado (sesión)
    private String obtenerNombreGenerador(HttpSession sesion, Connection conexion) {
        try {
            Object idObj = sesion.getAttribute("idUsuario");
            if (idObj == null) {
                return "-";
            }
            int idUsuario = (Integer) idObj;
            PreparedStatement psGen = conexion.prepareStatement(
                "SELECT p.nombre, p.apellido FROM public.usuarios u " +
                "JOIN public.personas p ON u.id_persona = p.id_persona " +
                "WHERE u.id_usuario = ?");
            psGen.setInt(1, idUsuario);
            ResultSet rsGen = psGen.executeQuery();
            String nombreCompleto = "-";
            if (rsGen.next()) {
                nombreCompleto = rsGen.getString("nombre") + " " + rsGen.getString("apellido");
            }
            rsGen.close();
            psGen.close();
            return nombreCompleto;
        } catch (Exception e) {
            return "-";
        }
    }

    // El rol ya viene guardado en la sesión desde el login, no hace falta ir a la base
    private String obtenerRolGenerador(HttpSession sesion) {
        Object rol = sesion.getAttribute("nombreRol");
        return rol != null ? rol.toString() : "";
    }
%>
<%
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String nombre = request.getParameter("nombre");
    String ubicacion = request.getParameter("ubicacion");
    String capacidad = request.getParameter("capacidad");
    String idDepartamento = request.getParameter("id_departamento");
    boolean puedeEditarSalas = "Administrador".equals((String) session.getAttribute("nombreRol"));

    try {
        // LISTAR
        if ("listar".equals(tipo)) {
            PreparedStatement ps = conexion.prepareStatement(
                "SELECT s.*, d.nombre_departamento, " +
                "(SELECT count(*) FROM public.equipos e WHERE e.id_sala = s.id_sala AND e.estado = 'Activo') AS equipos_activos " +
                "FROM public.salas s LEFT JOIN public.departamentos d ON d.id_departamento = s.id_departamento " +
                "ORDER BY s.es_deposito DESC, d.nombre_departamento NULLS LAST, s.nombre_sala");
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                boolean esDeposito = rs.getBoolean("es_deposito");
                String depto = rs.getString("nombre_departamento");
%>
                <tr class="<%= esDeposito ? "table-warning" : "" %>">
                    <td><%= rs.getInt("id_sala") %></td>
                    <td>
                        <% if (esDeposito) { %><i class="fas fa-warehouse text-warning" aria-hidden="true"></i> <% } %>
                        <%= h(rs.getString("nombre_sala")) %>
                    </td>
                    <td>
                        <% if (esDeposito) { %><span class="badge badge-dark">General (sin departamento)</span>
                        <% } else if (depto == null) { %><span class="badge badge-danger">Sin asignar</span>
                        <% } else { %><%= h(depto) %><% } %>
                    </td>
                    <td><%= h(rs.getString("ubicacion_piso")) %></td>
                    <td><%= esDeposito ? "-" : String.valueOf(rs.getInt("capacidad")) %></td>
                    <td class="text-center"><%= rs.getInt("equipos_activos") %></td>
                    <td class="text-nowrap">
                        <% if (esDeposito) { %>
                        <span class="text-muted small">Ubicación fija del sistema</span>
                        <% } else { %>
                        <button class="btn btn-warning btn-sm" data-toggle="modal" data-target="#modalSala" title="Modificar" aria-label="Modificar"
                                onclick="campos('<%= rs.getInt("id_sala") %>', '<%= hj(rs.getString("nombre_sala")) %>', '<%= hj(rs.getString("ubicacion_piso")) %>', '<%= rs.getInt("capacidad") %>', '<%= rs.getObject("id_departamento") == null ? "" : rs.getInt("id_departamento") %>'); completar('Modificar Sala', 'Modificar')">
                            <i class="fas fa-edit" aria-hidden="true"></i>
                        </button>
                        <button class="btn btn-danger btn-sm" title="Eliminar" aria-label="Eliminar" onclick="eliminar('<%= rs.getInt("id_sala") %>')">
                            <i class="fas fa-trash" aria-hidden="true"></i>
                        </button>
                        <% } %>
                        <button class="btn btn-info btn-sm" title="Ficha PDF" aria-label="Ficha PDF" onclick="window.open('../controladores/salasControlador.jsp?tipo=ReporteIndividual&pk=<%= rs.getInt("id_sala") %>', '_blank')">
                            <i class="fas fa-file-pdf" aria-hidden="true"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        }
        // COMBO DE DEPARTAMENTOS ACTIVOS
        else if ("departamentos".equals(tipo)) {
            out.print("<option value=''>-- Seleccione el departamento --</option>");
            PreparedStatement ps = conexion.prepareStatement(
                "SELECT id_departamento, nombre_departamento, activo FROM public.departamentos ORDER BY nombre_departamento");
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                // Los inactivos se listan deshabilitados para que una sala vieja siga mostrando el suyo
                out.print("<option value='" + rs.getInt("id_departamento") + "'" + (rs.getBoolean("activo") ? "" : " disabled") + ">"
                        + h(rs.getString("nombre_departamento")) + (rs.getBoolean("activo") ? "" : " (inactivo)") + "</option>");
            }
        }
        // Solo el Administrador crea, modifica o elimina salas
        else if (("Guardar".equals(tipo) || "Modificar".equals(tipo) || "Borrar".equals(tipo)) && !puedeEditarSalas) {
            out.print("Error: solo el Administrador puede modificar las salas.");
        }
        // GUARDAR
        else if ("Guardar".equals(tipo)) {
            if (idDepartamento == null || idDepartamento.trim().isEmpty()) throw new Exception("Seleccione el departamento de la sala.");
            exigirUnico(conexion, "salas", "nombre_sala", "id_sala", nombre, null, "Ya existe una sala con ese nombre.");
            PreparedStatement ps = conexion.prepareStatement("INSERT INTO salas (nombre_sala, ubicacion_piso, capacidad, id_departamento, es_deposito) VALUES (?, ?, ?, ?, false)");
            ps.setString(1, nombre);
            ps.setString(2, ubicacion);
            ps.setInt(3, Integer.parseInt(capacidad));
            ps.setInt(4, Integer.parseInt(idDepartamento.trim()));
            ps.executeUpdate();
            out.print("success");
        }

        // MODIFICAR
        else if ("Modificar".equals(tipo)) {
            if (idDepartamento == null || idDepartamento.trim().isEmpty()) throw new Exception("Seleccione el departamento de la sala.");
            exigirUnico(conexion, "salas", "nombre_sala", "id_sala", nombre, pk, "Ya existe una sala con ese nombre.");
            // El Depósito no se modifica desde acá (es una ubicación fija del sistema)
            PreparedStatement ps = conexion.prepareStatement("UPDATE salas SET nombre_sala=?, ubicacion_piso=?, capacidad=?, id_departamento=? WHERE id_sala=? AND NOT es_deposito");
            ps.setString(1, nombre);
            ps.setString(2, ubicacion);
            ps.setInt(3, Integer.parseInt(capacidad));
            ps.setInt(4, Integer.parseInt(idDepartamento.trim()));
            ps.setInt(5, Integer.parseInt(pk));
            if (ps.executeUpdate() == 0) throw new Exception("El Depósito no se puede modificar.");
            out.print("success");
        }

        // BORRAR
        else if ("Borrar".equals(tipo)) {
            PreparedStatement ps = conexion.prepareStatement("DELETE FROM salas WHERE id_sala = ? AND NOT es_deposito");
            ps.setInt(1, Integer.parseInt(pk));
            if (ps.executeUpdate() == 0) throw new Exception("El Depósito no se puede eliminar.");
            out.print("success");
        }

        // REPORTE GENERAL (PDF)
        else if ("ReporteGeneral".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_salas");

            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=reporte_salas.pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }

        // REPORTE INDIVIDUAL (PDF)
        else if ("ReporteIndividual".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_sala_individual");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_ID_SALA", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=ficha_sala_" + pk + ".pdf");

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