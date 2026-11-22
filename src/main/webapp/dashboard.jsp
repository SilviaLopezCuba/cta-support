<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="includes/header.jsp" %>
<%@include file="config/conexion.jsp" %>
<%!
    // ---------- Utilidades de consulta ----------
    private static String _fl(java.util.Date d){if(d==null)return"-";String t=new java.text.SimpleDateFormat("EEEE, d 'de' MMMM 'de' yyyy HH:mm",new java.util.Locale("es","PY")).format(d);return Character.toUpperCase(t.charAt(0))+t.substring(1);}
    private static String _h(String t){if(t==null)return"";return t.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;");}
    private static String _n(int n){return String.format(new java.util.Locale("es","PY"),"%,d",n).replace(',', '.');}

    private void bind(java.sql.PreparedStatement ps,java.util.List<Object> p)throws java.sql.SQLException{for(int i=0;i<p.size();i++)ps.setObject(i+1,p.get(i));}

    private int contar(java.sql.Connection cn,String sql,java.util.List<Object> p){
        try(java.sql.PreparedStatement ps=cn.prepareStatement(sql)){bind(ps,p);try(java.sql.ResultSet rs=ps.executeQuery()){return rs.next()?rs.getInt(1):0;}}catch(Exception e){return 0;}
    }
    /** Devuelve pares (etiqueta, cantidad) de una consulta "SELECT etiqueta, COUNT(*)". */
    private java.util.List<Object[]> pares(java.sql.Connection cn,String sql,java.util.List<Object> p){
        java.util.List<Object[]> l=new java.util.ArrayList<>();
        try(java.sql.PreparedStatement ps=cn.prepareStatement(sql)){bind(ps,p);try(java.sql.ResultSet rs=ps.executeQuery()){while(rs.next())l.add(new Object[]{rs.getString(1)==null?"Sin dato":rs.getString(1),rs.getInt(2)});}}catch(Exception e){}
        return l;
    }
    /** Serie de 12 meses a partir de "SELECT mes, COUNT(*) ... GROUP BY 1". */
    private int[] meses(java.sql.Connection cn,String sql,java.util.List<Object> p){
        int[] m=new int[12];
        try(java.sql.PreparedStatement ps=cn.prepareStatement(sql)){bind(ps,p);try(java.sql.ResultSet rs=ps.executeQuery()){while(rs.next()){int i=rs.getInt(1)-1;if(i>=0&&i<12)m[i]=rs.getInt(2);}}}catch(Exception e){}
        return m;
    }
    private static int maximo(int[] v){int m=0;for(int x:v)m=Math.max(m,x);return m;}
    private static int maximo(java.util.List<Object[]> l){int m=0;for(Object[] o:l)m=Math.max(m,(Integer)o[1]);return m;}
    private static int suma(java.util.List<Object[]> l){int s=0;for(Object[] o:l)s+=(Integer)o[1];return s;}
    // ---------- Fase 7: utilidades del panel de inventario ----------
    private long sumaLong(java.sql.Connection cn,String sql){
        try(java.sql.PreparedStatement ps=cn.prepareStatement(sql);java.sql.ResultSet rs=ps.executeQuery()){return rs.next()?rs.getLong(1):0;}catch(Exception e){return 0;}
    }
    /** Pares (etiqueta, valor en Gs.) — valores que pueden superar un int. */
    private java.util.List<Object[]> paresLong(java.sql.Connection cn,String sql){
        java.util.List<Object[]> l=new java.util.ArrayList<>();
        try(java.sql.PreparedStatement ps=cn.prepareStatement(sql);java.sql.ResultSet rs=ps.executeQuery()){while(rs.next())l.add(new Object[]{rs.getString(1)==null?"Sin dato":rs.getString(1),rs.getLong(2)});}catch(Exception e){}
        return l;
    }
    private static String _gs(long n){return String.format(new java.util.Locale("es","PY"),"%,d",n).replace(',', '.');}
    /** Monto abreviado para los indicadores: 15,5 M / 1,2 mil M. */
    private static String _gsCorto(long n){
        if(Math.abs(n)>=1_000_000_000L)return String.format(new java.util.Locale("es","PY"),"%.1f mil M",n/1e9).replace('.', ',');
        if(Math.abs(n)>=1_000_000L)return String.format(new java.util.Locale("es","PY"),"%.1f M",n/1e6).replace('.', ',');
        return _gs(n);
    }

    // ---------- Gráficos SVG (sin librerías externas) ----------
    /** Curva suave que pasa por los puntos (Catmull-Rom convertida a Bézier). */
    private static String curva(double[] x,double[] y){
        StringBuilder s=new StringBuilder(String.format(java.util.Locale.US,"M%.1f,%.1f",x[0],y[0]));
        for(int i=0;i<x.length-1;i++){
            double x0=i>0?x[i-1]:x[i],y0=i>0?y[i-1]:y[i],x3=i+2<x.length?x[i+2]:x[i+1],y3=i+2<x.length?y[i+2]:y[i+1];
            double c1x=x[i]+(x[i+1]-x0)/6,c1y=y[i]+(y[i+1]-y0)/6,c2x=x[i+1]-(x3-x[i])/6,c2y=y[i+1]-(y3-y[i])/6;
            s.append(String.format(java.util.Locale.US," C%.1f,%.1f %.1f,%.1f %.1f,%.1f",c1x,c1y,c2x,c2y,x[i+1],y[i+1]));
        }
        return s.toString();
    }
    /** Minigráfico de tendencia para las tarjetas de indicadores. */
    private static String sparkline(int[] v,int n,String color){
        n=Math.max(2,n);int mx=1;for(int i=0;i<n;i++)mx=Math.max(mx,v[i]);double w=120,h=40;double[] x=new double[n],y=new double[n];
        for(int i=0;i<n;i++){x[i]=i*w/(n-1);y[i]=h-3-(v[i]*(h-8.0)/mx);}
        String d=curva(x,y);
        return "<svg class=\"spark\" viewBox=\"0 0 120 40\" aria-hidden=\"true\" preserveAspectRatio=\"none\"><path d=\""+d+" L120,40 L0,40 Z\" style=\"fill:"+color+"\" opacity=\".16\"/><path d=\""+d+"\" fill=\"none\" style=\"stroke:"+color+"\" stroke-width=\"2.4\" stroke-linecap=\"round\" vector-effect=\"non-scaling-stroke\"/></svg>";
    }
    /** Anillo con segmentos; los colores son id de degradados metálicos definidos en la página. */
    private static String anillo(int[] v,String[] grad,String centro,String sub){
        int t=0;for(int x:v)t+=x;double r=52,c=2*Math.PI*r,off=0;
        StringBuilder s=new StringBuilder("<svg class=\"anillo\" viewBox=\"0 0 140 140\" aria-hidden=\"true\"><circle class=\"anillo-base\" cx=\"70\" cy=\"70\" r=\"52\" fill=\"none\" stroke-width=\"20\"/>");
        if(t>0){for(int i=0;i<v.length;i++){if(v[i]==0)continue;double len=v[i]*c/t;double gap=v.length>1&&len>4?2.5:0;
            s.append(String.format(java.util.Locale.US,"<circle cx=\"70\" cy=\"70\" r=\"52\" fill=\"none\" stroke=\"url(#%s)\" stroke-width=\"20\" stroke-dasharray=\"%.2f %.2f\" stroke-dashoffset=\"%.2f\" transform=\"rotate(-90 70 70)\"/>",grad[i],len-gap,c-len+gap,-off));off+=len;}}
        s.append("<text x=\"70\" y=\"70\" class=\"anillo-n\">").append(centro).append("</text><text x=\"70\" y=\"90\" class=\"anillo-s\">").append(sub).append("</text></svg>");
        return s.toString();
    }
%>
<%
    // ---------- Sesión y rol ----------
    String rolD=(String)session.getAttribute("nombreRol");boolean isA="Administrador".equals(rolD),isT="Técnico".equals(rolD);
    Integer dIU=(Integer)session.getAttribute("idUsuario"),dIT=(Integer)session.getAttribute("idTecnico");
    int idU=dIU!=null?dIU:-1,idT=dIT!=null?dIT:-1;String cx=request.getContextPath()+"/";
    // Fase 7: el Administrador y el Encargado de depósito tienen además el panel de inventario
    boolean isE="Encargado de depósito".equals(rolD);
    String vistaP=request.getParameter("vista");
    boolean modoInv=(isA||isE)&&("inventario".equals(vistaP)||(vistaP==null&&isE));

    // ---------- Filtros (GET): año y prioridad ----------
    int anioAct=java.util.Calendar.getInstance().get(java.util.Calendar.YEAR);
    int anio=anioAct;try{anio=Integer.parseInt(request.getParameter("anio"));}catch(Exception e){}
    String[] PRIOS={"Critica","Alta","Media","Baja"};
    String prio=request.getParameter("prioridad");if(prio!=null&&!java.util.Arrays.asList(PRIOS).contains(prio))prio=null;

    // Condición común: año + prioridad + alcance del rol
    String w=" WHERE EXTRACT(YEAR FROM t.fecha_creacion)=?";
    java.util.List<Object> p=new java.util.ArrayList<>();p.add(anio);
    if(prio!=null){w+=" AND t.prioridad=?";p.add(prio);}
    if(isT){w+=" AND t.id_tecnico_asignado=?";p.add(idT);}
    else if(!isA){w+=" AND t.id_usuario_solicita=?";p.add(idU);}
    final String RES="('Resuelto','Cerrado')", CUR="('Asignado','En Proceso','Esperando Repuesto')";

    // Años disponibles para el filtro
    java.util.List<Integer> anios=new java.util.ArrayList<>();
    try(java.sql.PreparedStatement ps=conexion.prepareStatement("SELECT DISTINCT EXTRACT(YEAR FROM fecha_creacion)::int FROM ticket WHERE fecha_creacion IS NOT NULL ORDER BY 1 DESC");java.sql.ResultSet rs=ps.executeQuery()){while(rs.next())anios.add(rs.getInt(1));}catch(Exception e){}
    if(!anios.contains(anioAct))anios.add(0,anioAct);
    if(!anios.contains(anio))anios.add(anio);

    // ---------- Indicadores ----------
    String MES="SELECT EXTRACT(MONTH FROM t.fecha_creacion)::int, COUNT(*) FROM ticket t";
    int total=contar(conexion,"SELECT COUNT(*) FROM ticket t"+w,p);
    int resueltos=contar(conexion,"SELECT COUNT(*) FROM ticket t"+w+" AND t.estado IN "+RES,p);
    String estPend=isT?"Asignado":"Pendiente";
    int pendientes=contar(conexion,"SELECT COUNT(*) FROM ticket t"+w+" AND t.estado='"+estPend+"'",p);
    int enCurso=contar(conexion,"SELECT COUNT(*) FROM ticket t"+w+" AND t.estado IN "+CUR,p);
    int pctRes=total>0?(int)Math.round(resueltos*100.0/total):0;
    int[] mTot=meses(conexion,MES+w+" GROUP BY 1",p);
    int[] mRes=meses(conexion,MES+w+" AND t.estado IN "+RES+" GROUP BY 1",p);
    int[] mPen=meses(conexion,MES+w+" AND t.estado='"+estPend+"' GROUP BY 1",p);
    int[] mPct=new int[12];for(int i=0;i<12;i++)mPct[i]=mTot[i]>0?(int)Math.round(mRes[i]*100.0/mTot[i]):0;

    // ---------- Distribuciones ----------
    int[] vPrio=new int[4];
    for(Object[] o:pares(conexion,"SELECT t.prioridad, COUNT(*) FROM ticket t"+w+" GROUP BY 1",p)){int i=java.util.Arrays.asList(PRIOS).indexOf((String)o[0]);if(i>=0)vPrio[i]=(Integer)o[1];}
    java.util.List<Object[]> porCat=pares(conexion,"SELECT COALESCE(c.nombre_categoria,'Sin categoría'), COUNT(*) FROM ticket t LEFT JOIN equipos e ON t.id_equipo=e.id_equipo LEFT JOIN categorias c ON e.id_categoria=c.id_categoria"+w+" GROUP BY 1 ORDER BY 2 DESC LIMIT 5",p);
    java.util.List<Object[]> porEst=pares(conexion,"SELECT t.estado, COUNT(*) FROM ticket t"+w+" GROUP BY 1 ORDER BY 2 DESC",p);
    java.util.List<Object[]> porFalla=pares(conexion,"SELECT COALESCE(tf.nombre_tipo_falla,NULLIF(TRIM(t.tipo_falla),''),'Sin especificar'), COUNT(*) FROM ticket t LEFT JOIN tipos_falla tf ON tf.id_tipo_falla=t.id_tipo_falla"+w+" GROUP BY 1 ORDER BY 2 DESC LIMIT 5",p);
    java.util.List<Object[]> ranking;String tituloRanking;
    if(isA){
        tituloRanking="Técnicos con más tickets";
        ranking=pares(conexion,"SELECT pe.nombre||' '||pe.apellido, COUNT(*) FROM ticket t JOIN tecnicos tc ON t.id_tecnico_asignado=tc.id_tecnico JOIN usuarios u ON tc.id_usuario=u.id_usuario JOIN personas pe ON u.id_persona=pe.id_persona"+w+" GROUP BY 1 ORDER BY 2 DESC LIMIT 5",p);
    }else{
        tituloRanking="Tickets por sala";
        ranking=pares(conexion,"SELECT COALESCE(s.nombre_sala,'Sin sala'), COUNT(*) FROM ticket t LEFT JOIN salas s ON t.id_sala=s.id_sala"+w+" GROUP BY 1 ORDER BY 2 DESC LIMIT 5",p);
    }

    // Mantenimiento preventivo del año (administrador: todos; técnico: los suyos)
    int[] vMant=new int[3];
    if(isA||isT){
        String wm=" WHERE EXTRACT(YEAR FROM m.fecha_programada)=?";java.util.List<Object> pm=new java.util.ArrayList<>();pm.add(anio);
        if(isT){wm+=" AND (m.id_tecnico=? OR m.id_tecnico_ejecuta=?)";pm.add(idT);pm.add(idT);}
        for(Object[] o:pares(conexion,"SELECT m.estado, COUNT(*) FROM mantenimientos_preventivos m"+wm+" GROUP BY 1",pm)){
            String e=(String)o[0];int n=(Integer)o[1];
            if("Programado".equals(e))vMant[0]+=n;else if("En Proceso".equals(e))vMant[1]+=n;else if("Finalizado".equals(e))vMant[2]+=n;
        }
    }

    // ---------- Gráfico de líneas: creados vs. resueltos por mes ----------
    // Año en curso: las curvas llegan hasta el mes actual (los meses futuros no son "cero tickets").
    int nM=anio==anioAct?java.util.Calendar.getInstance().get(java.util.Calendar.MONTH)+1:(anio>anioAct?1:12);
    String[] MESES={"Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"};
    int lMax=Math.max(4,Math.max(maximo(mTot),maximo(mRes)));
    int paso=(int)Math.ceil(lMax/4.0);lMax=paso*4;
    double LX0=40,LX1=585,LY0=12,LY1=206;
    double[] lx=new double[12],lyT=new double[12],lyR=new double[12];
    for(int i=0;i<12;i++){lx[i]=LX0+i*(LX1-LX0)/11;lyT[i]=LY1-mTot[i]*(LY1-LY0)/lMax;lyR[i]=LY1-mRes[i]*(LY1-LY0)/lMax;}
    String dT=curva(java.util.Arrays.copyOf(lx,Math.max(2,nM)),java.util.Arrays.copyOf(lyT,Math.max(2,nM))),dR=curva(java.util.Arrays.copyOf(lx,Math.max(2,nM)),java.util.Arrays.copyOf(lyR,Math.max(2,nM)));double lxF=lx[Math.max(2,nM)-1];

    String tituloPanel=isA?"Panel de tickets":(isT?"Mis tickets":"Mis solicitudes");

    // ---------- Fase 7: panel de inventario ----------
    long valorPatr=0,costoPatr=0;int eqUso=0,eqDep=0,eqInac=0,bajoMin=0;
    java.util.List<Object[]> porUbic=null,valorUbic=null,bajoLista=null,masEntregado=null;java.util.List<Object[]> atender=new java.util.ArrayList<>();
    int[] mEnt=new int[12],mSal=new int[12];String dE="",dS="";double[] lyE=new double[12],lyS=new double[12];int pasoI=1;
    if(modoInv){
        tituloPanel="Panel de inventario";
        // Equipos que siguen en la institución: activos + inactivos que no se descuentan (descompuestos, daño irreparable)
        String EQ=" FROM equipos e JOIN salas s ON s.id_sala=e.id_sala LEFT JOIN departamentos d ON d.id_departamento=s.id_departamento LEFT JOIN categorias c ON c.id_categoria=e.id_categoria LEFT JOIN motivos_inactivo mi ON mi.id_motivo=e.id_motivo_inactivo WHERE (e.estado='Activo' OR NOT COALESCE(mi.descuenta,false))";
        String VAL="ROUND(e.costo*GREATEST(0,1-((CURRENT_DATE-e.fecha_ingreso)/365.25)/NULLIF(c.vida_util_anios,0)))";
        valorPatr=sumaLong(conexion,"SELECT COALESCE(SUM(COALESCE("+VAL+",e.costo)),0)::bigint"+EQ);
        costoPatr=sumaLong(conexion,"SELECT COALESCE(SUM(e.costo),0)::bigint"+EQ);
        eqUso=contar(conexion,"SELECT COUNT(*)"+EQ+" AND e.estado='Activo' AND NOT s.es_deposito",new java.util.ArrayList<Object>());
        eqDep=contar(conexion,"SELECT COUNT(*)"+EQ+" AND e.estado='Activo' AND s.es_deposito",new java.util.ArrayList<Object>());
        eqInac=contar(conexion,"SELECT COUNT(*)"+EQ+" AND e.estado='Inactivo'",new java.util.ArrayList<Object>());
        String UB="CASE WHEN s.es_deposito THEN 'Depósito' ELSE COALESCE(d.nombre_departamento,'Sin departamento') END";
        porUbic=pares(conexion,"SELECT "+UB+", COUNT(*)"+EQ+" GROUP BY 1 ORDER BY 2 DESC LIMIT 5",new java.util.ArrayList<Object>());
        valorUbic=paresLong(conexion,"SELECT "+UB+", SUM(COALESCE("+VAL+",e.costo))::bigint"+EQ+" GROUP BY 1 ORDER BY 2 DESC LIMIT 5");
        String ART="SELECT nombre, stock, stock_minimo FROM catalogo_repuestos UNION ALL SELECT nombre, stock, stock_minimo FROM catalogo_insumos";
        bajoMin=contar(conexion,"SELECT COUNT(*) FROM ("+ART+") a WHERE COALESCE(a.stock_minimo,0)>0 AND COALESCE(a.stock,0)<a.stock_minimo",new java.util.ArrayList<Object>());
        bajoLista=new java.util.ArrayList<>();
        try(java.sql.PreparedStatement ps=conexion.prepareStatement("SELECT a.nombre, COALESCE(a.stock,0), a.stock_minimo FROM ("+ART+") a WHERE COALESCE(a.stock_minimo,0)>0 AND COALESCE(a.stock,0)<a.stock_minimo ORDER BY COALESCE(a.stock,0)/a.stock_minimo, a.nombre LIMIT 5");java.sql.ResultSet rs=ps.executeQuery()){
            while(rs.next())bajoLista.add(new Object[]{rs.getString(1),rs.getBigDecimal(2).stripTrailingZeros().toPlainString(),rs.getBigDecimal(3).stripTrailingZeros().toPlainString(),(int)Math.round(rs.getDouble(2)*100/rs.getDouble(3))});
        }catch(Exception e){}
        java.util.List<Object> sinP=new java.util.ArrayList<Object>();
        atender.add(new Object[]{"Pedidos de material por entregar",contar(conexion,"SELECT COUNT(*) FROM solicitudes_material WHERE estado IN ('Pendiente','En espera')",sinP),"vistas/entregasVista.jsp"});
        atender.add(new Object[]{"Material sin usar ni devolver",contar(conexion,"SELECT COUNT(DISTINCT (tipo_orden,id_orden)) FROM v_material_orden WHERE saldo>0",sinP),"vistas/entregasVista.jsp"});
        atender.add(new Object[]{"Equipos en el Depósito sin asignar",contar(conexion,"SELECT COUNT(*) FROM equipos e JOIN salas s ON s.id_sala=e.id_sala WHERE s.es_deposito AND e.estado='Activo'",sinP),"vistas/movimientosEquiposVista.jsp?modo=asignacion"});
        atender.add(new Object[]{"Pedidos de reposición en curso",contar(conexion,"SELECT COUNT(*) FROM solicitudes_compra WHERE estado IN ('Enviada','Recibida parcial')",sinP),"vistas/controlStockVista.jsp"});
        atender.add(new Object[]{"Recepciones sin ingresar",contar(conexion,"SELECT COUNT(*) FROM recepciones WHERE estado<>'Confirmada'",sinP),"vistas/recepcionesVista.jsp"});
        atender.add(new Object[]{"Artículos bajo el mínimo",bajoMin,"vistas/inventarioVista.jsp"});
        java.util.List<Object> pa=new java.util.ArrayList<Object>();pa.add(anio);
        masEntregado=pares(conexion,"SELECT COALESCE(r.nombre,i.nombre), CEIL(SUM(d.cantidad_entregada))::int FROM solicitudes_material_detalle d JOIN solicitudes_material sm ON sm.id_solicitud=d.id_solicitud LEFT JOIN catalogo_repuestos r ON d.tipo_articulo='R' AND r.id_repuesto=d.id_articulo LEFT JOIN catalogo_insumos i ON d.tipo_articulo='I' AND i.id_insumo=d.id_articulo WHERE d.cantidad_entregada>0 AND EXTRACT(YEAR FROM sm.fecha_entrega)=? GROUP BY 1 ORDER BY 2 DESC LIMIT 5",pa);
        // Movimientos del kardex por mes (sin el saldo inicial): entradas vs. salidas
        String MK="SELECT EXTRACT(MONTH FROM fecha)::int, COUNT(*) FROM movimientos_stock WHERE saldo='disponible' AND tipo_movimiento<>'SALDO INICIAL' AND EXTRACT(YEAR FROM fecha)=?";
        mEnt=meses(conexion,MK+" AND cantidad>0 GROUP BY 1",pa);
        mSal=meses(conexion,MK+" AND cantidad<0 GROUP BY 1",pa);
    }
    String[] gPrio={"g-rojo","g-rojo-claro","g-azul","g-plata"};
    String[] cPrio={"m-rojo","m-rojo-claro","m-azul","m-plata"};
    String[] ePrio={"Crítica","Alta","Media","Baja"};
%>
<style>
    .tb-link { color: var(--tb-texto); text-decoration: underline; text-decoration-color: rgba(180, 193, 216, .5); text-underline-offset: 3px; }
    .tb-link:hover, .tb-link:focus { color: #fff; text-decoration-color: #fff; }
    .tb-atender th { text-align: left; }
    .tb-atender td { display: table-cell !important; }
    .tb-atender td.tb-hay { color: #ffb06b; }
</style>
<div class="content-wrapper tablero-wrap">
<svg width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false">
    <defs>
        <!-- Degradados metálicos tomados del logo: azul (A), rojo (C) y plata (T) -->
        <linearGradient id="g-azul" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b9d6ff"/><stop offset=".45" stop-color="#3f86e0"/><stop offset=".55" stop-color="#1e5bb5"/><stop offset="1" stop-color="#5c9cf0"/></linearGradient>
        <linearGradient id="g-rojo" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffb3bc"/><stop offset=".45" stop-color="#e0263f"/><stop offset=".55" stop-color="#a50f25"/><stop offset="1" stop-color="#f05a6d"/></linearGradient>
        <linearGradient id="g-rojo-claro" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffd9b0"/><stop offset=".45" stop-color="#f08a3c"/><stop offset=".55" stop-color="#c4621c"/><stop offset="1" stop-color="#ffb06b"/></linearGradient>
        <linearGradient id="g-plata" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".45" stop-color="#c3ccd8"/><stop offset=".55" stop-color="#8592a5"/><stop offset="1" stop-color="#e3e8ef"/></linearGradient>
        <linearGradient id="g-area-azul" x1="0" y1="0" x2="0" y2="1"><stop offset="0" style="stop-color:var(--c-serie1)" stop-opacity=".4"/><stop offset="1" style="stop-color:var(--c-serie1)" stop-opacity="0"/></linearGradient>
        <linearGradient id="g-area-plata" x1="0" y1="0" x2="0" y2="1"><stop offset="0" style="stop-color:var(--c-serie2)" stop-opacity=".28"/><stop offset="1" style="stop-color:var(--c-serie2)" stop-opacity="0"/></linearGradient>
    </defs>
</svg>

<section class="content">
<div class="tablero">

    <header class="tb-cab">
        <img src="<%= cx %>img/logo_mini.png" alt="" class="tb-cab-logo" width="180" height="47">
        <div class="tb-cab-tit">
            <h1><span class="tb-marca">CTA Support <span class="tb-sep" aria-hidden="true">|</span> </span><%= tituloPanel %> <%= anio %><%= !modoInv && prio != null ? " (prioridad " + ePrio[java.util.Arrays.asList(PRIOS).indexOf(prio)] + ")" : "" %></h1>
            <p>Actualizado: <%= _fl(new java.util.Date()) %></p>
        </div>
        <!-- Filtros: se aplican al cambiar la selección -->
        <form class="tb-filtros" method="get" action="<%= cx %>dashboard.jsp" aria-label="Filtros del panel">
            <% if (isA || isE) { %><input type="hidden" name="vista" value="<%= modoInv ? "inventario" : "tickets" %>"><% } %>
            <i class="fas fa-filter" aria-hidden="true"></i>
            <label for="fAnio">Año</label>
            <select id="fAnio" name="anio" class="form-control" onchange="this.form.submit()">
                <% for (Integer a : anios) { %><option value="<%= a %>"<%= a == anio ? " selected" : "" %>><%= a %></option><% } %>
            </select>
            <% if (!modoInv) { %>
            <label for="fPrio">Prioridad</label>
            <select id="fPrio" name="prioridad" class="form-control" onchange="this.form.submit()">
                <option value="">Todas</option>
                <% for (int i = 0; i < PRIOS.length; i++) { %><option value="<%= PRIOS[i] %>"<%= PRIOS[i].equals(prio) ? " selected" : "" %>><%= ePrio[i] %></option><% } %>
            </select>
            <% } %>
            <noscript><button type="submit" class="btn btn-primary">Aplicar</button></noscript>
            <% if (prio != null || anio != anioAct) { %><a href="<%= cx %>dashboard.jsp<%= (isA || isE) ? "?vista=" + (modoInv ? "inventario" : "tickets") : "" %>" class="btn btn-secondary btn-sm" title="Limpiar filtros" aria-label="Limpiar filtros"><i class="fas fa-undo" aria-hidden="true"></i></a><% } %>
        </form>
        <div class="tb-cab-acc">
            <% if (isA || isE) { %>
            <div class="btn-group" role="group" aria-label="Panel">
                <a href="<%= cx %>dashboard.jsp?vista=tickets&anio=<%= anio %>" class="btn <%= modoInv ? "btn-outline-light" : "btn-light" %>"<%= modoInv ? "" : " aria-current=\"page\"" %>><i class="fas fa-ticket-alt" aria-hidden="true"></i> Tickets</a>
                <a href="<%= cx %>dashboard.jsp?vista=inventario&anio=<%= anio %>" class="btn <%= modoInv ? "btn-light" : "btn-outline-light" %>"<%= modoInv ? " aria-current=\"page\"" : "" %>><i class="fas fa-boxes" aria-hidden="true"></i> Inventario</a>
            </div>
            <% } %>
            <% if (!isT && !isE && !modoInv) { %><a href="<%= cx %>vistas/ordenVista.jsp" class="btn btn-danger"><i class="fas fa-headset" aria-hidden="true"></i> Solicitar asistencia</a><% } %>
            <% if ((isA || isT) && !modoInv) { %><a href="<%= cx %>vistas/ordenUnificadaVista.jsp" class="btn btn-primary"><i class="fas fa-ticket-alt" aria-hidden="true"></i> <%= isA ? "Gestionar tickets" : "Ir a mis tickets" %></a><% } %>
        </div>
    </header>

    <% if (modoInv) {
        // Línea: entradas vs. salidas del kardex
        int lMaxI=Math.max(4,Math.max(maximo(mEnt),maximo(mSal)));pasoI=(int)Math.ceil(lMaxI/4.0);lMaxI=pasoI*4;
        for(int i=0;i<12;i++){lyE[i]=LY1-mEnt[i]*(LY1-LY0)/lMaxI;lyS[i]=LY1-mSal[i]*(LY1-LY0)/lMaxI;}
        dE=curva(java.util.Arrays.copyOf(lx,Math.max(2,nM)),java.util.Arrays.copyOf(lyE,Math.max(2,nM)));dS=curva(java.util.Arrays.copyOf(lx,Math.max(2,nM)),java.util.Arrays.copyOf(lyS,Math.max(2,nM)));
        int eqTot=eqUso+eqDep+eqInac;
    %>
    <div class="tb-grilla">
        <div class="tb-kpis">
            <article class="tb-card kpi">
                <div class="kpi-cab"><h2>Valor del patrimonio</h2><span class="kpi-ico m-verde"><i class="fas fa-coins" aria-hidden="true"></i></span></div>
                <p class="kpi-n" title="Gs. <%= _gs(valorPatr) %>">Gs. <%= _gsCorto(valorPatr) %></p>
                <div class="kpi-pie"><span class="kpi-nota">costo de ingreso Gs. <%= _gsCorto(costoPatr) %></span></div>
            </article>
            <article class="tb-card kpi">
                <div class="kpi-cab"><h2>Equipos en uso</h2><span class="kpi-ico m-azul"><i class="fas fa-desktop" aria-hidden="true"></i></span></div>
                <p class="kpi-n"><%= _n(eqUso) %></p>
                <div class="kpi-pie"><span class="kpi-nota">activos en las salas</span></div>
            </article>
            <article class="tb-card kpi">
                <div class="kpi-cab"><h2>En depósito</h2><span class="kpi-ico m-plata"><i class="fas fa-warehouse" aria-hidden="true"></i></span></div>
                <p class="kpi-n"><%= _n(eqDep) %></p>
                <div class="kpi-pie"><span class="kpi-nota"><%= _n(eqInac) %> inactivos (sin baja)</span></div>
            </article>
            <article class="tb-card kpi<%= bajoMin > 0 ? " kpi-alerta" : "" %>">
                <div class="kpi-cab"><h2>Bajo stock mínimo</h2><span class="kpi-ico m-rojo"><i class="fas fa-exclamation" aria-hidden="true"></i></span></div>
                <p class="kpi-n"><%= _n(bajoMin) %></p>
                <div class="kpi-pie"><span class="kpi-nota">repuestos e insumos</span></div>
            </article>
        </div>

        <section class="tb-card tb-prio" aria-labelledby="iEst">
            <h2 id="iEst">Equipos por estado</h2>
            <div class="anillo-fila"><div class="anillo-caja"><%= anillo(new int[]{eqUso, eqDep, eqInac}, new String[]{"g-azul", "g-plata", "g-rojo-claro"}, _n(eqTot), "equipos") %></div>
            <table class="tb-tabla">
                <caption class="sr-only">Equipos por estado</caption>
                <tr><th scope="row"><span class="punto m-azul"></span>En uso</th><td><%= _n(eqUso) %></td></tr>
                <tr><th scope="row"><span class="punto m-plata"></span>En depósito</th><td><%= _n(eqDep) %></td></tr>
                <tr><th scope="row"><span class="punto m-rojo-claro"></span>Inactivos</th><td><%= _n(eqInac) %></td></tr>
            </table></div>
        </section>

        <section class="tb-card" aria-labelledby="iUbic">
            <h2 id="iUbic">Valor por ubicación (Gs.)</h2>
            <% long mxV = 1; for (Object[] o : valorUbic) mxV = Math.max(mxV, (Long) o[1]); if (valorUbic.isEmpty()) { %><p class="tb-vacio">Sin equipos registrados.</p><% } %>
            <ul class="barras">
                <% for (Object[] o : valorUbic) { %>
                <li><span class="barra-et"><%= _h((String) o[0]) %></span><span class="barra-pista"><span class="barra m-verde" style="width:<%= Math.max(4, (int) ((Long) o[1] * 100 / mxV)) %>%"></span></span><span class="barra-n" title="Gs. <%= _gs((Long) o[1]) %>"><%= _gsCorto((Long) o[1]) %></span></li>
                <% } %>
            </ul>
        </section>

        <section class="tb-card" aria-labelledby="iAt">
            <h2 id="iAt">Por atender</h2>
            <table class="tb-tabla tb-atender">
                <caption class="sr-only">Trámites pendientes del depósito</caption>
                <% for (Object[] o : atender) { int n = (Integer) o[1]; %>
                <tr><th scope="row"><a href="<%= cx %><%= o[2] %>" class="tb-link"><%= o[0] %></a></th><td class="<%= n > 0 ? "tb-hay" : "" %>"><%= _n(n) %></td></tr>
                <% } %>
            </table>
        </section>

        <section class="tb-card" aria-labelledby="iBajo">
            <h2 id="iBajo">Reponer primero</h2>
            <% if (bajoLista.isEmpty()) { %><p class="tb-vacio">Ningún artículo está por debajo del mínimo.</p><% } %>
            <ol class="ranking">
                <% for (Object[] o : bajoLista) { %>
                <li><div class="ranking-fila"><span><%= _h((String) o[0]) %></span><b><%= o[1] %> / <%= o[2] %></b></div><span class="barra-pista delgada"><span class="barra m-rojo" style="width:<%= Math.max(4, (Integer) o[3]) %>%"></span></span></li>
                <% } %>
            </ol>
        </section>

        <section class="tb-card tb-linea" aria-labelledby="iLin">
            <div class="tb-linea-cab">
                <h2 id="iLin">Movimientos de stock por mes</h2>
                <ul class="leyenda"><li><span class="punto m-azul"></span>Entradas</li><li><span class="punto m-plata"></span>Salidas</li></ul>
            </div>
            <svg class="linea" viewBox="0 0 600 236" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Movimientos de entrada y salida de stock por mes en <%= anio %>">
                <% for (int k = 0; k <= 4; k++) { double gy = LY1 - k * (LY1 - LY0) / 4; %>
                <line x1="<%= LX0 %>" x2="<%= LX1 %>" y1="<%= gy %>" y2="<%= gy %>" class="linea-grilla"/>
                <text x="<%= LX0 - 12 %>" y="<%= gy + 5 %>" class="linea-eje" text-anchor="end"><%= k * pasoI %></text>
                <% } %>
                <path d="<%= dE %> L<%= lxF %>,<%= LY1 %> L<%= LX0 %>,<%= LY1 %> Z" fill="url(#g-area-azul)"/>
                <path d="<%= dS %> L<%= lxF %>,<%= LY1 %> L<%= LX0 %>,<%= LY1 %> Z" fill="url(#g-area-plata)"/>
                <path d="<%= dE %>" class="linea-serie serie1"/>
                <path d="<%= dS %>" class="linea-serie serie2" stroke-dasharray="7 5"/>
                <% for (int i = 0; i < 12; i++) { %>
                <% if (i < nM) { %>
                <circle cx="<%= lx[i] %>" cy="<%= lyE[i] %>" r="4.5" class="punto-serie1"><title><%= MESES[i] %>: <%= mEnt[i] %> entradas</title></circle>
                <circle cx="<%= lx[i] %>" cy="<%= lyS[i] %>" r="4.5" class="punto-serie2"><title><%= MESES[i] %>: <%= mSal[i] %> salidas</title></circle>
                <% } %>
                <text x="<%= lx[i] %>" y="230" class="linea-eje" text-anchor="middle"><%= MESES[i] %></text>
                <% } %>
            </svg>
        </section>

        <section class="tb-card" aria-labelledby="iMas">
            <h2 id="iMas">Material más entregado</h2>
            <% int mxM = Math.max(1, maximo(masEntregado)); if (masEntregado.isEmpty()) { %><p class="tb-vacio">Sin entregas en <%= anio %>.</p><% } %>
            <ul class="barras">
                <% for (Object[] o : masEntregado) { %>
                <li><span class="barra-et"><%= _h((String) o[0]) %></span><span class="barra-pista"><span class="barra m-azul" style="width:<%= Math.max(4, (Integer) o[1] * 100 / mxM) %>%"></span></span><span class="barra-n"><%= _n((Integer) o[1]) %></span></li>
                <% } %>
            </ul>
        </section>

        <section class="tb-card" aria-labelledby="iUb2">
            <h2 id="iUb2">Equipos por ubicación</h2>
            <% int mxU = Math.max(1, maximo(porUbic)); if (porUbic.isEmpty()) { %><p class="tb-vacio">Sin equipos registrados.</p><% } %>
            <ul class="barras">
                <% for (Object[] o : porUbic) { %>
                <li><span class="barra-et"><%= _h((String) o[0]) %></span><span class="barra-pista"><span class="barra m-plata" style="width:<%= Math.max(4, (Integer) o[1] * 100 / mxU) %>%"></span></span><span class="barra-n"><%= _n((Integer) o[1]) %></span></li>
                <% } %>
            </ul>
        </section>
    </div>
    <% } else { %>
    <div class="tb-grilla">

        <!-- Indicadores -->
        <div class="tb-kpis">
            <article class="tb-card kpi">
                <div class="kpi-cab"><h2>Tickets registrados</h2><span class="kpi-ico m-azul"><i class="fas fa-ticket-alt" aria-hidden="true"></i></span></div>
                <p class="kpi-n"><%= _n(total) %></p>
                <div class="kpi-pie"><span class="kpi-nota">en <%= anio %></span><%= sparkline(mTot, nM, "var(--c-serie1)") %></div>
            </article>
            <article class="tb-card kpi">
                <div class="kpi-cab"><h2>Resueltos</h2><span class="kpi-ico m-plata"><i class="fas fa-check-double" aria-hidden="true"></i></span></div>
                <p class="kpi-n"><%= _n(resueltos) %></p>
                <div class="kpi-pie"><span class="kpi-nota">resueltos o cerrados</span><%= sparkline(mRes, nM, "var(--c-serie2)") %></div>
            </article>
            <article class="tb-card kpi">
                <div class="kpi-cab"><h2>Tasa de resolución</h2><span class="kpi-ico m-verde"><i class="fas fa-percent" aria-hidden="true"></i></span></div>
                <p class="kpi-n"><%= pctRes %>%</p>
                <div class="kpi-pie"><span class="kpi-nota kpi-ok"><%= enCurso %> en curso</span><%= sparkline(mPct, nM, "var(--c-ok)") %></div>
            </article>
            <article class="tb-card kpi kpi-alerta">
                <div class="kpi-cab"><h2><%= isT ? "Sin empezar" : "Pendientes" %></h2><span class="kpi-ico m-rojo"><i class="fas fa-exclamation" aria-hidden="true"></i></span></div>
                <p class="kpi-n"><%= _n(pendientes) %></p>
                <div class="kpi-pie"><span class="kpi-nota"><%= isT ? "asignados a usted" : "sin técnico asignado" %></span><%= sparkline(mPen, nM, "var(--c-alerta)") %></div>
            </article>
        </div>

        <!-- Prioridad -->
        <section class="tb-card tb-prio" aria-labelledby="tPrio">
            <h2 id="tPrio">Tickets por prioridad</h2>
            <div class="anillo-fila"><div class="anillo-caja"><%= anillo(vPrio, gPrio, _n(total), "tickets") %></div>
            <table class="tb-tabla">
                <caption class="sr-only">Cantidad y porcentaje por prioridad</caption>
                <% for (int i = 0; i < 4; i++) { %>
                <tr><th scope="row"><span class="punto <%= cPrio[i] %>"></span><%= ePrio[i] %></th><td><%= _n(vPrio[i]) %></td><td><%= total > 0 ? Math.round(vPrio[i] * 1000.0 / total) / 10.0 : 0 %>%</td></tr>
                <% } %>
            </table></div>
        </section>

        <!-- Categoría -->
        <section class="tb-card" aria-labelledby="tCat">
            <h2 id="tCat">Tickets por categoría de equipo</h2>
            <% int mxC = Math.max(1, maximo(porCat)); if (porCat.isEmpty()) { %><p class="tb-vacio">Sin tickets para este filtro.</p><% } %>
            <ul class="barras">
                <% for (Object[] o : porCat) { %>
                <li><span class="barra-et"><%= _h((String) o[0]) %></span><span class="barra-pista"><span class="barra m-azul" style="width:<%= Math.max(4, (Integer) o[1] * 100 / mxC) %>%"></span></span><span class="barra-n"><%= _n((Integer) o[1]) %></span></li>
                <% } %>
            </ul>
        </section>

        <!-- Estado -->
        <section class="tb-card" aria-labelledby="tEst">
            <h2 id="tEst">Tickets por estado</h2>
            <% int mxE = Math.max(1, maximo(porEst)); if (porEst.isEmpty()) { %><p class="tb-vacio">Sin tickets para este filtro.</p><% } %>
            <ul class="barras">
                <% for (Object[] o : porEst) { String e = (String) o[0];
                   String cl = "Pendiente".equals(e) ? "m-rojo" : ("Resuelto".equals(e) || "Cerrado".equals(e) ? "m-plata" : ("Esperando Repuesto".equals(e) ? "m-rojo-claro" : "m-azul")); %>
                <li><span class="barra-et"><%= _h(e) %></span><span class="barra-pista"><span class="barra <%= cl %>" style="width:<%= Math.max(4, (Integer) o[1] * 100 / mxE) %>%"></span></span><span class="barra-n"><%= _n((Integer) o[1]) %></span></li>
                <% } %>
            </ul>
        </section>

        <!-- Ranking -->
        <section class="tb-card" aria-labelledby="tRank">
            <h2 id="tRank"><%= tituloRanking %></h2>
            <% int mxR = Math.max(1, maximo(ranking)); if (ranking.isEmpty()) { %><p class="tb-vacio">Sin datos para este filtro.</p><% } %>
            <ol class="ranking">
                <% for (Object[] o : ranking) { %>
                <li><div class="ranking-fila"><span><%= _h((String) o[0]) %></span><b><%= _n((Integer) o[1]) %></b></div><span class="barra-pista delgada"><span class="barra m-azul" style="width:<%= Math.max(4, (Integer) o[1] * 100 / mxR) %>%"></span></span></li>
                <% } %>
            </ol>
        </section>

        <!-- Mantenimiento o, para alumnos y maestros, fallas -->
        <% if (isA || isT) { int mTotal = vMant[0] + vMant[1] + vMant[2]; %>
        <section class="tb-card tb-prio" aria-labelledby="tMant">
            <h2 id="tMant">Mantenimiento preventivo</h2>
            <div class="anillo-fila"><div class="anillo-caja"><%= anillo(vMant, new String[]{"g-azul", "g-rojo-claro", "g-plata"}, _n(mTotal), "en " + anio) %></div>
            <table class="tb-tabla">
                <caption class="sr-only">Mantenimientos por estado</caption>
                <tr><th scope="row"><span class="punto m-azul"></span>Programados</th><td><%= vMant[0] %></td></tr>
                <tr><th scope="row"><span class="punto m-rojo-claro"></span>En curso</th><td><%= vMant[1] %></td></tr>
                <tr><th scope="row"><span class="punto m-plata"></span>Finalizados</th><td><%= vMant[2] %></td></tr>
            </table></div>
        </section>
        <% } else if (!isE) { %>
        <section class="tb-card tb-prio" aria-labelledby="tAyuda">
            <h2 id="tAyuda">¿Falla un equipo?</h2>
            <p class="tb-texto">Indique la sala, el equipo y la falla. Podrá seguir el ticket desde este panel.</p>
            <a href="<%= cx %>vistas/ordenVista.jsp" class="btn btn-danger btn-block">Solicitar asistencia</a>
        </section>
        <% } %>

        <!-- Línea temporal -->
        <section class="tb-card tb-linea" aria-labelledby="tLin">
            <div class="tb-linea-cab">
                <h2 id="tLin">Tickets por mes</h2>
                <ul class="leyenda"><li><span class="punto m-azul"></span>Registrados</li><li><span class="punto m-plata"></span>Resueltos</li></ul>
            </div>
            <svg class="linea" viewBox="0 0 600 236" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Tickets registrados y resueltos por mes en <%= anio %>">
                <% for (int k = 0; k <= 4; k++) { double gy = LY1 - k * (LY1 - LY0) / 4; %>
                <line x1="<%= LX0 %>" x2="<%= LX1 %>" y1="<%= gy %>" y2="<%= gy %>" class="linea-grilla"/>
                <text x="<%= LX0 - 12 %>" y="<%= gy + 5 %>" class="linea-eje" text-anchor="end"><%= k * paso %></text>
                <% } %>
                <path d="<%= dT %> L<%= lxF %>,<%= LY1 %> L<%= LX0 %>,<%= LY1 %> Z" fill="url(#g-area-azul)"/>
                <path d="<%= dR %> L<%= lxF %>,<%= LY1 %> L<%= LX0 %>,<%= LY1 %> Z" fill="url(#g-area-plata)"/>
                <path d="<%= dT %>" class="linea-serie serie1"/>
                <path d="<%= dR %>" class="linea-serie serie2" stroke-dasharray="7 5"/>
                <% for (int i = 0; i < 12; i++) { %>
                <% if (i < nM) { %>
                <circle cx="<%= lx[i] %>" cy="<%= lyT[i] %>" r="4.5" class="punto-serie1"><title><%= MESES[i] %>: <%= mTot[i] %> registrados</title></circle>
                <circle cx="<%= lx[i] %>" cy="<%= lyR[i] %>" r="4.5" class="punto-serie2"><title><%= MESES[i] %>: <%= mRes[i] %> resueltos</title></circle>
                <% } %>
                <text x="<%= lx[i] %>" y="230" class="linea-eje" text-anchor="middle"><%= MESES[i] %></text>
                <% } %>
            </svg>
        </section>

        <!-- Fallas frecuentes -->
        <section class="tb-card" aria-labelledby="tFal">
            <h2 id="tFal">Fallas más frecuentes</h2>
            <% int mxF = Math.max(1, maximo(porFalla)); int tF = Math.max(1, suma(porFalla)); if (porFalla.isEmpty()) { %><p class="tb-vacio">Sin datos para este filtro.</p><% } %>
            <ul class="barras barras-pct">
                <% for (Object[] o : porFalla) { %>
                <li><span class="barra-et"><%= _h((String) o[0]) %></span><span class="barra-pista"><span class="barra m-rojo" style="width:<%= Math.max(4, (Integer) o[1] * 100 / mxF) %>%"></span></span><span class="barra-n"><%= _n((Integer) o[1]) %></span></li>
                <% } %>
            </ul>
        </section>
    </div>
    <% } %>
</div>
</section>
</div>
<% if (conexion != null) { try { conexion.close(); } catch (Exception ex) {} } %>
<%@include file="includes/footer.jsp" %>
