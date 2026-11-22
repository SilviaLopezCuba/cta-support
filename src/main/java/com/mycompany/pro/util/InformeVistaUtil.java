package com.mycompany.pro.util;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Utilidad compartida por los 4 informes (Solicitudes, Ordenes correctivas,
 * Compras y Mantenimiento):
 *
 *  - pantalla(...)  -> fragmento HTML con filtros aplicados, totales, resumen y
 *                      tabla (con "Imprimir" por fila y por seleccion), que la
 *                      vista carga por AJAX apenas se entra.
 *  - listarIds(...) -> ids de TODO lo filtrado, para el "Imprimir detallado".
 *
 * Las consultas usan EXACTAMENTE el mismo FROM/WHERE (incluidos los filtros y
 * las restricciones por rol) que el .jrxml, asi pantalla, PDF y detallado
 * siempre muestran el mismo conjunto de registros.
 */
public class InformeVistaUtil {

    public static final int MAX_FILAS_PANTALLA = 500;

    //  DEFINICION DE UN INFORME
    public static class Informe {

        String titulo;
        String columnas;
        String[] titulosColumnas;
        String origen;
        String orden = "1";
        String idExpr;
        final List<String[]> metricas = new ArrayList<String[]>();
        final List<String[]> grupos = new ArrayList<String[]>();
        final List<String[]> filtros = new ArrayList<String[]>();

        public Informe(String titulo) {
            this.titulo = titulo;
        }

        /** Lista SELECT de la tabla en pantalla y los titulos de cada columna (mismo orden). */
        public Informe columnas(String select, String... titulos) {
            this.columnas = select;
            this.titulosColumnas = titulos;
            return this;
        }

        /** Parte de la consulta desde FROM: debe filtrar por rango de fechas con dos parametros (desde y hasta). */
        public Informe origen(String fromWhere) {
            this.origen = fromWhere;
            return this;
        }

        public Informe orden(String orden) {
            this.orden = orden;
            return this;
        }

        /** Expresion SQL del id del registro (ej. "t.id_ticket"): habilita "Imprimir" por fila y por seleccion. */
        public Informe idRegistro(String expresionSql) {
            this.idExpr = expresionSql;
            return this;
        }

        /** tipo: N = entero, M = monto, D = decimal (1 decimal). color: info, success, warning, danger, primary, secondary. */
        public Informe metrica(String titulo, String agregadoSql, String tipo, String icono, String color) {
            metricas.add(new String[]{titulo, agregadoSql, tipo, icono, color});
            return this;
        }

        /** Resumen agrupado: cantidad por expresion y, opcionalmente, suma de un monto (sumaSql puede ser null). */
        public Informe grupo(String titulo, String expresionSql, String sumaSql) {
            grupos.add(new String[]{titulo, expresionSql, sumaSql});
            return this;
        }

        public Informe filtro(String etiqueta, String valor) {
            if (valor != null && !valor.trim().isEmpty()) {
                filtros.add(new String[]{etiqueta, valor});
            }
            return this;
        }
    }

    //  API PUBLICA
    /** Fragmento HTML (AdminLTE 3) para la pantalla principal. */
    public static String pantalla(Connection cn, Informe inf, String desde, String hasta) throws SQLException {
        java.sql.Date d = java.sql.Date.valueOf(desde.trim());
        java.sql.Date h = java.sql.Date.valueOf(hasta.trim());
        Fmt f = new Fmt();

        long total = contar(cn, inf, d, h);
        StringBuilder sb = new StringBuilder(8192);

        // Filtros aplicados
        sb.append("<div class='card card-outline card-secondary'>")
          .append("<div class='card-header py-2'><h3 class='card-title'><i class='fas fa-filter mr-1'></i> Filtros aplicados</h3></div>")
          .append("<div class='card-body py-2'>");
        sb.append(chip("Periodo", f.fecha(d) + " al " + f.fecha(h)));
        for (String[] fl : inf.filtros) {
            sb.append(chip(fl[0], fl[1]));
        }
        sb.append("</div></div>");

        // Tabla
        String sql = "SELECT " + (inf.idExpr != null ? inf.idExpr + " AS registro_id, " : "") + inf.columnas + " " + inf.origen + " ORDER BY " + inf.orden
                + " LIMIT " + (MAX_FILAS_PANTALLA + 1);
        PreparedStatement ps = cn.prepareStatement(sql);
        try {
            ps.setDate(1, d);
            ps.setDate(2, h);
            ResultSet rs = ps.executeQuery();
            ResultSetMetaData md = rs.getMetaData();
            int n = md.getColumnCount();
            int off = inf.idExpr != null ? 1 : 0;   // la 1a columna es el id (no se muestra)

            sb.append("<div class='card card-outline card-primary'>")
              .append("<div class='card-header py-2'><h3 class='card-title'><i class='fas fa-table mr-1'></i> Registros ")
              .append("<span class='badge badge-primary'>").append(f.entero(total)).append("</span></h3>");
            if (off == 1) {
                sb.append("<div class='card-tools'><button type='button' class='btn btn-sm btn-outline-primary' onclick='imprimirSeleccionados()'>")
                  .append("<i class='fas fa-print'></i> Imprimir seleccionados</button></div>");
            }
            sb.append("</div>")
              .append("<div class='card-body table-responsive p-0' style='max-height:480px'>")
              .append("<table class='table table-sm table-striped table-hover table-head-fixed text-nowrap'><thead><tr>");
            if (off == 1) {
                sb.append("<th style='width:80px'><input type='checkbox' title='Seleccionar todos' onclick='marcarTodos(this)'> Imprimir</th>");
            }
            for (int i = off; i < n; i++) {
                String t = (inf.titulosColumnas != null && i - off < inf.titulosColumnas.length) ? inf.titulosColumnas[i - off] : humanizar(md.getColumnLabel(i + 1));
                sb.append("<th>").append(esc(t)).append("</th>");
            }
            sb.append("</tr></thead><tbody>");
            int filas = 0;
            while (rs.next() && filas < MAX_FILAS_PANTALLA) {
                filas++;
                sb.append("<tr>");
                if (off == 1) {
                    long idFila = rs.getLong(1);
                    sb.append("<td class='text-nowrap'><input type='checkbox' class='chk-registro' value='").append(idFila).append("'> ")
                      .append("<button type='button' class='btn btn-xs btn-outline-primary ml-1' title='Imprimir comprobante detallado' onclick='imprimirRegistro(")
                      .append(idFila).append(")'><i class='fas fa-print'></i></button></td>");
                }
                for (int i = 1 + off; i <= n; i++) {
                    Object v = rs.getObject(i);
                    String col = md.getColumnLabel(i);
                    String texto = f.valor(v, col);
                    if (v instanceof Number && !(col.toLowerCase(Locale.ROOT).startsWith("id"))) {
                        sb.append("<td class='text-right'>").append(esc(texto)).append("</td>");
                    } else if (v instanceof String && esBadge(col)) {
                        sb.append("<td>").append(badge((String) v)).append("</td>");
                    } else {
                        sb.append("<td>").append(esc(texto)).append("</td>");
                    }
                }
                sb.append("</tr>");
            }
            if (filas == 0) {
                sb.append("<tr><td colspan='").append(Math.max(1, n)).append("' class='text-center text-muted py-4'>")
                  .append("No hay registros para los filtros aplicados.</td></tr>");
            }
            sb.append("</tbody></table></div>");
            if (total > MAX_FILAS_PANTALLA) {
                sb.append("<div class='card-footer py-2'><small class='text-warning'><i class='fas fa-exclamation-triangle'></i> ")
                  .append("Se muestran los primeros ").append(MAX_FILAS_PANTALLA).append(" de ").append(f.entero(total))
                  .append(" registros. El informe PDF y el detallado incluyen todos.</small></div>");
            }
            sb.append("</div>");
            rs.close();
        } finally {
            ps.close();
        }
        return sb.toString();
    }

    /** Ids de TODO lo filtrado (mismo FROM/WHERE y orden que la pantalla y el PDF). */
    public static java.util.List<Integer> listarIds(Connection cn, Informe inf, String desde, String hasta) throws SQLException {
        java.sql.Date d = java.sql.Date.valueOf(desde.trim());
        java.sql.Date h = java.sql.Date.valueOf(hasta.trim());
        PreparedStatement ps = cn.prepareStatement("SELECT " + inf.idExpr + " " + inf.origen + " ORDER BY " + inf.orden);
        try {
            ps.setDate(1, d);
            ps.setDate(2, h);
            ResultSet rs = ps.executeQuery();
            List<Integer> ids = new ArrayList<Integer>();
            while (rs.next()) {
                ids.add(rs.getInt(1));
            }
            rs.close();
            return ids;
        } finally {
            ps.close();
        }
    }

    /** Ids separados por coma ("3,5,9") -> lista de enteros validos (ignora lo que no sea numero). */
    public static List<Integer> parsearIds(String csv) {
        List<Integer> ids = new ArrayList<Integer>();
        if (csv == null) {
            return ids;
        }
        for (String p : csv.split(",")) {
            Integer n = aEntero(p);
            if (n != null && !ids.contains(n)) {
                ids.add(n);
            }
        }
        return ids;
    }

    /** Ejecuta un SELECT que devuelve ids en la 1a columna (sin parametros). */
    public static List<Integer> consultarIds(Connection cn, String sql) throws SQLException {
        PreparedStatement ps = cn.prepareStatement(sql);
        try {
            ResultSet rs = ps.executeQuery();
            List<Integer> ids = new ArrayList<Integer>();
            while (rs.next()) {
                ids.add(rs.getInt(1));
            }
            rs.close();
            return ids;
        } finally {
            ps.close();
        }
    }

    /** Alerta HTML de error (para el fragmento de pantalla). */
    public static String errorHtml(Exception ex) {
        return "<div class='alert alert-danger'><i class='fas fa-exclamation-circle'></i> "
                + "No se pudieron cargar los datos: " + esc(ex.getMessage()) + "</div>";
    }

    /** Devuelve un texto obtenido con un SELECT de una sola columna y un parametro entero (o null). */
    public static String etiqueta(Connection cn, String sql, String idTexto) {
        Integer id = aEntero(idTexto);
        if (id == null) {
            return null;
        }
        try {
            PreparedStatement ps = cn.prepareStatement(sql);
            try {
                ps.setInt(1, id);
                ResultSet rs = ps.executeQuery();
                String r = rs.next() ? rs.getString(1) : null;
                rs.close();
                return r;
            } finally {
                ps.close();
            }
        } catch (SQLException e) {
            return null;
        }
    }

    public static Integer aEntero(String s) {
        if (s == null) {
            return null;
        }
        try {
            return Integer.valueOf(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    //  CALCULOS
    private static long contar(Connection cn, Informe inf, java.sql.Date d, java.sql.Date h) throws SQLException {
        PreparedStatement ps = cn.prepareStatement("SELECT COUNT(*) " + inf.origen);
        try {
            ps.setDate(1, d);
            ps.setDate(2, h);
            ResultSet rs = ps.executeQuery();
            long n = rs.next() ? rs.getLong(1) : 0;
            rs.close();
            return n;
        } finally {
            ps.close();
        }
    }

    //  FORMATO
    private static class Fmt {

        private final SimpleDateFormat fFecha = new SimpleDateFormat("dd/MM/yyyy");
        private final SimpleDateFormat fFechaHora = new SimpleDateFormat("dd/MM/yyyy HH:mm");
        private final SimpleDateFormat fHora = new SimpleDateFormat("HH:mm");
        private final DecimalFormat fEntero;
        private final DecimalFormat fDecimal;
        private final DecimalFormat fUnDecimal;

        Fmt() {
            DecimalFormatSymbols s = new DecimalFormatSymbols(new Locale("es", "PY"));
            s.setGroupingSeparator('.');
            s.setDecimalSeparator(',');
            fEntero = new DecimalFormat("#,##0", s);
            fDecimal = new DecimalFormat("#,##0.##", s);
            fUnDecimal = new DecimalFormat("#,##0.0", s);
        }

        String fecha(java.util.Date d) {
            return fFecha.format(d);
        }

        String fechaHora(java.util.Date d) {
            return fFechaHora.format(d);
        }

        String entero(long n) {
            return fEntero.format(n);
        }

        String metrica(Object v, String tipo) {
            if (v == null) {
                return "0";
            }
            if (!(v instanceof Number)) {
                return String.valueOf(v);
            }
            if ("N".equals(tipo)) {
                return fEntero.format(((Number) v).longValue());
            }
            if ("D".equals(tipo)) {
                return fUnDecimal.format(v);
            }
            return fDecimal.format(v);
        }

        String valor(Object v, String col) {
            if (v == null) {
                return "\u2014";
            }
            if (v instanceof Boolean) {
                return ((Boolean) v) ? "Si" : "No";
            }
            if (v instanceof java.sql.Timestamp) {
                return fFechaHora.format((java.util.Date) v);
            }
            if (v instanceof java.sql.Date) {
                return fFecha.format((java.util.Date) v);
            }
            if (v instanceof java.sql.Time) {
                return fHora.format((java.util.Date) v);
            }
            if (v instanceof BigDecimal || v instanceof Double || v instanceof Float) {
                return fDecimal.format(v);
            }
            if (v instanceof Number) {
                if (col != null && col.toLowerCase(Locale.ROOT).startsWith("id")) {
                    return String.valueOf(v);
                }
                return fEntero.format(((Number) v).longValue());
            }
            if (v instanceof byte[]) {
                return "[archivo de " + ((byte[]) v).length + " bytes]";
            }
            String s = String.valueOf(v).trim();
            return s.isEmpty() ? "\u2014" : s;
        }
    }

    //  UTILES DE TEXTO / HTML
    private static final Map<String, String> ACENTOS = new HashMap<String, String>();

    static {
        String[][] pares = {
            {"numero", "N\u00famero"}, {"codigo", "C\u00f3digo"}, {"descripcion", "Descripci\u00f3n"},
            {"diagnostico", "Diagn\u00f3stico"}, {"tecnico", "T\u00e9cnico"}, {"tecnicos", "T\u00e9cnicos"},
            {"resolucion", "Resoluci\u00f3n"}, {"creacion", "Creaci\u00f3n"}, {"ubicacion", "Ubicaci\u00f3n"},
            {"observacion", "Observaci\u00f3n"}, {"observaciones", "Observaciones"}, {"revision", "Revisi\u00f3n"},
            {"accion", "Acci\u00f3n"}, {"telefono", "Tel\u00e9fono"}, {"direccion", "Direcci\u00f3n"},
            {"razon", "Raz\u00f3n"}, {"modificacion", "Modificaci\u00f3n"}, {"actualizacion", "Actualizaci\u00f3n"},
            {"informacion", "Informaci\u00f3n"}, {"solucion", "Soluci\u00f3n"}, {"asignacion", "Asignaci\u00f3n"},
            {"ejecucion", "Ejecuci\u00f3n"}, {"categoria", "Categor\u00eda"}, {"garantia", "Garant\u00eda"},
            {"contrasena", "Contrase\u00f1a"}, {"a\u00f1o", "A\u00f1o"}, {"id", "ID"}, {"nro", "N\u00b0"},
            {"ticket", "Ticket"}, {"minutos", "Minutos"}
        };
        for (String[] p : pares) {
            ACENTOS.put(p[0], p[1]);
        }
    }

    /** "numero_ticket" -> "N\u00famero ticket". */
    static String humanizar(String nombre) {
        if (nombre == null) {
            return "";
        }
        String[] partes = nombre.trim().split("_+");
        StringBuilder sb = new StringBuilder();
        for (String parte : partes) {
            String p = parte.toLowerCase(Locale.ROOT);
            if (p.isEmpty()) {
                continue;
            }
            String w = ACENTOS.containsKey(p) ? ACENTOS.get(p) : p;
            boolean siglas = "ID".equals(w) || w.endsWith("\u00b0");
            if (sb.length() == 0) {
                w = Character.toUpperCase(w.charAt(0)) + w.substring(1);
            } else {
                sb.append(' ');
                if (!siglas) {
                    w = w.toLowerCase(Locale.ROOT);
                }
            }
            sb.append(w);
        }
        return sb.toString();
    }

    private static boolean esBadge(String col) {
        String c = col.toLowerCase(Locale.ROOT);
        return c.equals("estado") || c.equals("prioridad");
    }

    private static String badge(String valor) {
        String clase = "secondary";
        String v = valor == null ? "" : valor.trim().toLowerCase(Locale.ROOT);
        if (v.equals("pendiente") || v.equals("alta") || v.equals("esperando repuesto") || v.equals("recibida parcial")) {
            clase = "warning";
        } else if (v.equals("asignado") || v.equals("media") || v.equals("programado")) {
            clase = "info";
        } else if (v.equals("en proceso")) {
            clase = "primary";
        } else if (v.equals("resuelto") || v.equals("finalizado") || v.equals("baja")) {
            clase = "success";
        } else if (v.equals("critica") || v.equals("cr\u00edtica")) {
            clase = "danger";
        } else if (v.equals("cerrado")) {
            clase = "dark";
        }
        return "<span class='badge badge-" + clase + "'>" + esc(valor) + "</span>";
    }

    private static String chip(String etiqueta, String valor) {
        return "<span class='chip badge badge-info mr-1' style='font-size:90%'><b>" + esc(etiqueta) + ":</b> " + esc(valor) + "</span> ";
    }

    private static String q(String identificador) {
        return "\"" + identificador.replace("\"", "\"\"") + "\"";
    }

    public static String esc(String s) {
        if (s == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&': sb.append("&amp;"); break;
                case '<': sb.append("&lt;"); break;
                case '>': sb.append("&gt;"); break;
                case '"': sb.append("&quot;"); break;
                case '\'': sb.append("&#39;"); break;
                default: sb.append(c);
            }
        }
        return sb.toString();
    }
}
