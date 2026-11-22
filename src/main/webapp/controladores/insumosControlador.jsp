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
<%!
    // Unidades que se cuentan en numeros enteros. Cualquier otra (Litros, Onzas, ...) admite decimales.
    private static final java.util.Set<String> UNIDADES_ENTERAS = new java.util.HashSet<String>(
            java.util.Arrays.asList("unidades", "unidad", "spray", "mililitros", "gramos"));

    private boolean unidadAdmiteDecimal(String nombreUnidad) {
        String n = nombreUnidad == null ? "" : nombreUnidad.trim().toLowerCase();
        return !UNIDADES_ENTERAS.contains(n);
    }

    private boolean unidadDecimalPorId(Connection c, int idUnidad) throws SQLException {
        PreparedStatement p = c.prepareStatement("SELECT nombre_unidad FROM unidades_medida WHERE id_unidad = ?");
        try {
            p.setInt(1, idUnidad);
            ResultSet r = p.executeQuery();
            try { return r.next() && unidadAdmiteDecimal(r.getString(1)); } finally { r.close(); }
        } finally { p.close(); }
    }

    // Texto de la cantidad: entero si la unidad no admite decimales; si admite, hasta 2 decimales sin ceros sobrantes.
    private String cantidadTexto(double v, boolean decimal) {
        if (!decimal) return String.valueOf(Math.round(v));
        return new java.math.BigDecimal(v).setScale(2, java.math.RoundingMode.HALF_UP).stripTrailingZeros().toPlainString();
    }

    private double ajustarCantidad(double v, boolean decimal) {
        return decimal ? Math.round(v * 100) / 100.0 : Math.round(v);
    }
%>
<%
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String nombre = request.getParameter("nombre");
    String id_marca = request.getParameter("id_marca");
    String id_unidad = request.getParameter("id_unidad");
    String stock = request.getParameter("stock");
    String stockMinimo = request.getParameter("stockMinimo");
    String presentacion = request.getParameter("presentacion");

    try {
        if ("listar".equals(tipo)) {
            String sql = "SELECT i.*, m.nombre_marca, u.nombre_unidad " +
                         "FROM catalogo_insumos i " +
                         "JOIN marcas m ON i.id_marca = m.id_marca " +
                         "JOIN unidades_medida u ON i.id_unidad = u.id_unidad " +
                         "ORDER BY i.id_insumo ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                double stockActual = rs.getDouble("stock");
                double stockMin = rs.getDouble("stock_minimo");
                boolean decUni = unidadAdmiteDecimal(rs.getString("nombre_unidad"));
                String badgeStock = stockActual <= stockMin ? "badge-danger" : "badge-success";
%>
                <tr>
                    <td><%= rs.getInt("id_insumo") %></td>
                    <td><%= h(rs.getString("nombre")) %></td>
                    <td><span class="badge badge-secondary"><%= h(rs.getString("nombre_marca")) %></span></td>
                    <td><%= cantidadTexto(stockMin, decUni) %> <%= h(rs.getString("nombre_unidad")) %></td>
                    <td><%= h(rs.getString("presentacion")) %></td>
                    <td class="text-center">
                        <button class="btn btn-info btn-sm" data-toggle="modal" data-target="#modalInsumo" 
                                onclick="campos('<%= rs.getInt("id_insumo") %>', '<%= hj(rs.getString("nombre")) %>', '<%= rs.getInt("id_marca") %>', '<%= rs.getInt("id_unidad") %>', '<%= cantidadTexto(stockActual, decUni) %>', '<%= cantidadTexto(stockMin, decUni) %>', '<%= hj(rs.getString("presentacion")) %>'); completar('Modificar Insumo', 'Modificar')">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="eliminar('<%= rs.getInt("id_insumo") %>')">
                            <i class="fas fa-trash"></i>
                        </button>
                        <button class="btn btn-info btn-sm" onclick="window.open('../controladores/insumosControlador.jsp?tipo=ReporteIndividual&pk=<%= rs.getInt("id_insumo") %>', '_blank')">
                            <i class="fas fa-file-pdf"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        }
        else if ("cargarUnidades".equals(tipo)) {
            ResultSet rs = conexion.prepareStatement("SELECT * FROM unidades_medida ORDER BY nombre_unidad").executeQuery();
            while(rs.next()){
                out.print("<option value='"+rs.getInt("id_unidad")+"' data-decimal='"+unidadAdmiteDecimal(h(rs.getString("nombre_unidad")))+"'>"+h(rs.getString("nombre_unidad"))+"</option>");
            }
        }
        else if ("Guardar".equals(tipo)) {
            exigirUnico(conexion, "catalogo_insumos", "nombre", "id_insumo", nombre, null, "Ya existe un insumo con ese nombre.");
            boolean decUnidad = unidadDecimalPorId(conexion, Integer.parseInt(id_unidad));
            PreparedStatement ps = conexion.prepareStatement("INSERT INTO catalogo_insumos (nombre, id_marca, id_unidad, stock, stock_minimo, presentacion) VALUES (?, ?, ?, ?, ?, ?)");
            ps.setString(1, nombre);
            ps.setInt(2, Integer.parseInt(id_marca));
            ps.setInt(3, Integer.parseInt(id_unidad));
            // El stock arranca en 0: solo cambia por Recepción, Entregas o Ajustes (queda en el kardex)
            ps.setDouble(4, 0);
            ps.setDouble(5, stockMinimo == null || stockMinimo.trim().isEmpty() ? 0 : ajustarCantidad(Double.parseDouble(stockMinimo), decUnidad));
            ps.setString(6, presentacion);
            ps.executeUpdate();
            out.print("success");
        }
        else if ("Modificar".equals(tipo)) {
            exigirUnico(conexion, "catalogo_insumos", "nombre", "id_insumo", nombre, pk, "Ya existe un insumo con ese nombre.");
            boolean decUnidad = unidadDecimalPorId(conexion, Integer.parseInt(id_unidad));
            PreparedStatement ps = conexion.prepareStatement("UPDATE catalogo_insumos SET nombre=?, id_marca=?, id_unidad=?, stock_minimo=?, presentacion=? WHERE id_insumo=?");
            ps.setString(1, nombre);
            ps.setInt(2, Integer.parseInt(id_marca));
            ps.setInt(3, Integer.parseInt(id_unidad));
            // El stock no se edita desde acá (ver Kardex)
            ps.setDouble(4, stockMinimo == null || stockMinimo.trim().isEmpty() ? 0 : ajustarCantidad(Double.parseDouble(stockMinimo), decUnidad));
            ps.setString(5, presentacion);
            ps.setInt(6, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        else if ("Borrar".equals(tipo)) {
            // Un artículo con movimientos en el kardex no se elimina (se perdería la trazabilidad)
            try (PreparedStatement psMov = conexion.prepareStatement(
                    "SELECT 1 FROM public.movimientos_stock WHERE tipo_articulo = 'I' AND id_articulo = ? LIMIT 1")) {
                psMov.setInt(1, Integer.parseInt(pk));
                try (ResultSet rsMov = psMov.executeQuery()) {
                    if (rsMov.next()) throw new Exception("Este artículo tiene movimientos de stock registrados y no se puede eliminar.");
                }
            }
            PreparedStatement ps = conexion.prepareStatement("DELETE FROM catalogo_insumos WHERE id_insumo = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // REPORTE GENERAL (PDF)
        else if ("ReporteGeneral".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_insumos");

            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=reporte_insumos.pdf");

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
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_insumo_individual");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_ID_INSUMO", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=ficha_insumo_" + pk + ".pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }
    } catch (Exception e) { out.print("Error: " + mensajeError(e)); } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
