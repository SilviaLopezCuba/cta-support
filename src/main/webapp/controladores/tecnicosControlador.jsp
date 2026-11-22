<%@page import="java.sql.*"%>
<%@include file="../config/conexion.jsp"%>
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
    String id_usuario = request.getParameter("id_usuario");
    String id_especialidad = request.getParameter("id_especialidad"); // Cambiado a ID
    String disponibilidad = request.getParameter("disponibilidad");

    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        // 1. LISTAR TÉCNICOS CON JOIN A ESPECIALIDADES
        if ("listar".equals(tipo)) {
            String sql = "SELECT t.id_tecnico, p.nombre, p.apellido, e.nombre_especialidad, " +
                         "t.estado_disponibilidad, t.id_usuario, t.id_especialidad " +
                         "FROM tecnicos t " +
                         "JOIN usuarios u ON t.id_usuario = u.id_usuario " +
                         "JOIN personas p ON u.id_persona = p.id_persona " +
                         "JOIN especialidades e ON t.id_especialidad = e.id_especialidad " +
                         "ORDER BY t.id_tecnico DESC";
            
            ps = conexion.prepareStatement(sql);
            rs = ps.executeQuery();
            while (rs.next()) {
                String estado = rs.getBoolean("estado_disponibilidad") ? "Disponible" : "Ocupado";
                String color = rs.getBoolean("estado_disponibilidad") ? "success" : "danger";
%>
                <tr>
                    <td><%= rs.getInt("id_tecnico") %></td>
                    <td><%= rs.getString("nombre") %> <%= rs.getString("apellido") %></td>
                    <td><%= rs.getString("nombre_especialidad") %></td>
                    <td><span class="badge badge-<%= color %>"><%= estado %></span></td>
                    <td class="text-center">
                        <button class="btn btn-warning btn-sm" 
                                onclick="campos('<%= rs.getInt("id_tecnico") %>', '<%= rs.getInt("id_usuario") %>', '<%= rs.getInt("id_especialidad") %>', '<%= rs.getBoolean("estado_disponibilidad") %>'); completar('Modificar Técnico', 'Modificar')">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="eliminar('<%= rs.getInt("id_tecnico") %>')">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                        <button class="btn btn-info btn-sm" onclick="window.open('../controladores/tecnicosControlador.jsp?tipo=ReporteIndividual&pk=<%= rs.getInt("id_tecnico") %>', '_blank')">
                            <i class="fas fa-file-pdf"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        }

        // 2. CARGAR COMBO DE USUARIOS
        else if ("cargarUsuarios".equals(tipo)) {
            // Solo usuarios cuyo rol es Tecnico (T_cnico cubre "Tecnico" y "Técnico")
            String sql = "SELECT u.id_usuario, p.nombre, p.apellido FROM usuarios u " +
                         "JOIN personas p ON u.id_persona = p.id_persona " +
                         "JOIN roles r ON u.id_rol = r.id_rol " +
                         "WHERE r.nombre_rol ILIKE 'T_cnico' ORDER BY p.nombre ASC";
            ps = conexion.prepareStatement(sql);
            rs = ps.executeQuery();
            out.print("<option value=''>-- Seleccione Usuario --</option>");
            while(rs.next()) {
                out.print("<option value='" + rs.getInt("id_usuario") + "'>" + rs.getString("nombre") + " " + rs.getString("apellido") + "</option>");
            }
        }

        // 3. NUEVO: CARGAR COMBO DE ESPECIALIDADES (Lo que pediste)
        else if ("cargarEspecialidades".equals(tipo)) {
            String sql = "SELECT id_especialidad, nombre_especialidad FROM especialidades ORDER BY nombre_especialidad ASC";
            ps = conexion.prepareStatement(sql);
            rs = ps.executeQuery();
            out.print("<option value=''>-- Seleccione Especialidad --</option>");
            while(rs.next()) {
                out.print("<option value='" + rs.getInt("id_especialidad") + "'>" + rs.getString("nombre_especialidad") + "</option>");
            }
        }

        // 4. GUARDAR
        else if ("Guardar".equals(tipo)) {
            ps = conexion.prepareStatement("SELECT 1 FROM usuarios u JOIN roles r ON u.id_rol = r.id_rol " +
                                           "WHERE u.id_usuario = ? AND r.nombre_rol ILIKE 'T_cnico'");
            ps.setInt(1, Integer.parseInt(id_usuario));
            rs = ps.executeQuery();
            boolean esRolTecnico = rs.next();
            rs.close(); ps.close();
            if (!esRolTecnico) {
                out.print("Error: el usuario seleccionado no tiene el rol Técnico");
            } else {
            ps = conexion.prepareStatement("INSERT INTO tecnicos (id_usuario, id_especialidad, estado_disponibilidad) VALUES (?, ?, ?)");
            ps.setInt(1, Integer.parseInt(id_usuario));
            ps.setInt(2, Integer.parseInt(id_especialidad));
            ps.setBoolean(3, Boolean.parseBoolean(disponibilidad));
            ps.executeUpdate();
            out.print("success");
            }
        }

        // 5. MODIFICAR
        else if ("Modificar".equals(tipo)) {
            ps = conexion.prepareStatement("SELECT 1 FROM usuarios u JOIN roles r ON u.id_rol = r.id_rol " +
                                           "WHERE u.id_usuario = ? AND r.nombre_rol ILIKE 'T_cnico'");
            ps.setInt(1, Integer.parseInt(id_usuario));
            rs = ps.executeQuery();
            boolean esRolTecnico = rs.next();
            rs.close(); ps.close();
            if (!esRolTecnico) {
                out.print("Error: el usuario seleccionado no tiene el rol Técnico");
            } else {
            ps = conexion.prepareStatement("UPDATE tecnicos SET id_usuario=?, id_especialidad=?, estado_disponibilidad=? WHERE id_tecnico=?");
            ps.setInt(1, Integer.parseInt(id_usuario));
            ps.setInt(2, Integer.parseInt(id_especialidad));
            ps.setBoolean(3, Boolean.parseBoolean(disponibilidad));
            ps.setInt(4, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
            }
        }

        // 6. BORRAR
        else if ("Borrar".equals(tipo)) {
            ps = conexion.prepareStatement("DELETE FROM tecnicos WHERE id_tecnico = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // 7. REPORTE GENERAL (PDF)
        else if ("ReporteGeneral".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_tecnicos");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=reporte_tecnicos.pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }
        // 8. REPORTE INDIVIDUAL (PDF)
        else if ("ReporteIndividual".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_tecnico_individual");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_ID_TECNICO", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=ficha_tecnico_" + pk + ".pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }

    } catch (Exception e) {
        out.print("Error: " + e.getMessage());
    } finally {
        if (rs != null) try { rs.close(); } catch (SQLException e) { }
        if (ps != null) try { ps.close(); } catch (SQLException e) { }
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>