<%@page import="java.sql.*"%>
<%@include file="../config/conexion.jsp"%>
<%@page import="com.mycompany.pro.util.PasswordUtil"%>
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
    String pass = request.getParameter("pass");
    String id_rol = request.getParameter("id_rol");
    String id_persona = request.getParameter("id_persona");

    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        // 1. LISTAR
        if ("listar".equals(tipo)) {
            String sql = "SELECT u.id_usuario, p.nombre, p.apellido, p.documento, r.nombre_rol, u.id_rol, u.id_persona " +
                         "FROM usuarios u " +
                         "JOIN personas p ON u.id_persona = p.id_persona " +
                         "JOIN roles r ON u.id_rol = r.id_rol " +
                         "ORDER BY u.id_usuario DESC";
            
            ps = conexion.prepareStatement(sql);
            rs = ps.executeQuery();
            while (rs.next()) {
%>
                <tr>
                    <td><%= rs.getInt("id_usuario") %></td>
                    <td><%= h(rs.getString("nombre")) %> <%= h(rs.getString("apellido")) %></td>
                    <td><b class="text-primary"><%= h(rs.getString("documento")) %></b></td>
                    <td><span class="badge badge-info"><%= h(rs.getString("nombre_rol")) %></span></td>
                    <td class="text-center">
                        <button class="btn btn-warning btn-sm" 
                                onclick="campos('<%= rs.getInt("id_usuario") %>', '<%= rs.getInt("id_persona") %>', '', '<%= rs.getInt("id_rol") %>'); completar('Modificar Cuenta', 'Modificar')">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="eliminar('<%= rs.getInt("id_usuario") %>')">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                        <button class="btn btn-info btn-sm" onclick="window.open('../controladores/usuariosControlador.jsp?tipo=ReporteIndividual&pk=<%= rs.getInt("id_usuario") %>', '_blank')">
                            <i class="fas fa-file-pdf"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        }

        // 2. CARGAR COMBO PERSONAS
        else if ("cargarCombo".equals(tipo)) {
            String sql = "SELECT id_persona, nombre, apellido, documento FROM personas ORDER BY nombre ASC";
            ps = conexion.prepareStatement(sql);
            rs = ps.executeQuery();
            out.print("<option value='' data-cedula=''>-- Seleccione una Persona --</option>");
            while(rs.next()) {
                out.print("<option value='" + rs.getInt("id_persona") + "' " +
                          "data-cedula='" + h(rs.getString("documento")) + "'>" + 
                          h(rs.getString("nombre")) + " " + h(rs.getString("apellido")) + "</option>");
            }
        }

        // 3. CARGAR COMBO ROLES
        else if ("cargarRoles".equals(tipo)) {
            String sql = "SELECT id_rol, nombre_rol FROM roles ORDER BY nombre_rol ASC";
            ps = conexion.prepareStatement(sql);
            rs = ps.executeQuery();
            while(rs.next()) {
                out.print("<option value='" + rs.getInt("id_rol") + "'>" + h(rs.getString("nombre_rol")) + "</option>");
            }
        }

        // 4. GUARDAR
        else if ("Guardar".equals(tipo)) {
            exigirUnico(conexion, "usuarios", "id_persona", "id_usuario", id_persona, null, "Esa persona ya tiene un usuario.");
            // Convertir contraseña a hash seguro (BCrypt)
            String passHash = PasswordUtil.hashPassword(pass);

            // Usar documento de la persona como login
            String sqlLogin = "SELECT documento FROM personas WHERE id_persona=?";
            PreparedStatement psDoc = conexion.prepareStatement(sqlLogin);
            psDoc.setInt(1, Integer.parseInt(id_persona));
            ResultSet rsDoc = psDoc.executeQuery();
            String login = "";
            if (rsDoc.next()) {
                login = rsDoc.getString("documento");
            }
            rsDoc.close();
            psDoc.close();

            ps = conexion.prepareStatement("INSERT INTO usuarios (login, password, id_rol, id_persona) VALUES (?, ?, ?, ?)");
            ps.setString(1, login);
            ps.setString(2, passHash);
            ps.setInt(3, Integer.parseInt(id_rol));
            ps.setInt(4, Integer.parseInt(id_persona));
            ps.executeUpdate();
            out.print("success");
        }

        // 5. MODIFICAR
        else if ("Modificar".equals(tipo)) {
            exigirUnico(conexion, "usuarios", "id_persona", "id_usuario", id_persona, pk, "Esa persona ya tiene un usuario.");
            // Convertir contraseña a hash seguro (BCrypt)
            String passHash = PasswordUtil.hashPassword(pass);

            // Obtener documento de la persona para actualizar login
            String sqlLogin = "SELECT documento FROM personas WHERE id_persona=?";
            PreparedStatement psDoc = conexion.prepareStatement(sqlLogin);
            psDoc.setInt(1, Integer.parseInt(id_persona));
            ResultSet rsDoc = psDoc.executeQuery();
            String login = "";
            if (rsDoc.next()) {
                login = rsDoc.getString("documento");
            }
            rsDoc.close();
            psDoc.close();

            ps = conexion.prepareStatement("UPDATE usuarios SET login=?, password=?, id_rol=?, id_persona=? WHERE id_usuario=?");
            ps.setString(1, login);
            ps.setString(2, passHash);
            ps.setInt(3, Integer.parseInt(id_rol));
            ps.setInt(4, Integer.parseInt(id_persona));
            ps.setInt(5, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }

        // 6. BORRAR
        else if ("Borrar".equals(tipo)) {
            ps = conexion.prepareStatement("DELETE FROM usuarios WHERE id_usuario = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // 7. REPORTE GENERAL (PDF)
        else if ("ReporteGeneral".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_usuarios");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=reporte_usuarios.pdf");

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
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_usuario_individual");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_ID_USUARIO", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=ficha_usuario_" + pk + ".pdf");

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
        if (rs != null) try { rs.close(); } catch (SQLException e) { }
        if (ps != null) try { ps.close(); } catch (SQLException e) { }
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
