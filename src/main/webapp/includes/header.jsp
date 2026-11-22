<%@page pageEncoding="UTF-8"%>
<%@ include file="../config/seguridad.jsp" %> 
<%
    // Variables de rol para mostrar/ocultar secciones del menú.
    // "nombreRol" ya se guarda en sesión en login.jsp.
    String nombreRolSesion = (String) session.getAttribute("nombreRol");
    boolean esAdmin = "Administrador".equals(nombreRolSesion);
    boolean esTecnico = "Técnico".equals(nombreRolSesion);
    boolean esAlumnoOMaestro = "Alumno".equals(nombreRolSesion) || "Maestro".equals(nombreRolSesion);
    boolean esEncargado = "Encargado de depósito".equals(nombreRolSesion);
    // Control de acceso por vista: si el rol no tiene la pantalla en su menú,
    // se lo devuelve al inicio en lugar de mostrarle la vista vacía.
    {
        String rutaVista = request.getServletPath();
        if (rutaVista != null && rutaVista.startsWith("/vistas/") && !esAdmin) {
            java.util.Set<String> permitidas = new java.util.HashSet<String>();
            if (esTecnico) {
                permitidas.add("/vistas/ordenUnificadaVista.jsp");
                permitidas.add("/vistas/mantenimientoUnificadoVista.jsp");
                permitidas.add("/vistas/informeSolicitudesVista.jsp");
                permitidas.add("/vistas/informeOrdenesVista.jsp");
                permitidas.add("/vistas/informeMantenimientoVista.jsp");
                permitidas.add("/vistas/informeMaterialVista.jsp");
            } else if (esAlumnoOMaestro) {
                permitidas.add("/vistas/ordenVista.jsp");
            } else if (esEncargado) {
                permitidas.add("/vistas/inventarioVista.jsp");
                permitidas.add("/vistas/recepcionesVista.jsp");
                permitidas.add("/vistas/movimientosEquiposVista.jsp");
                permitidas.add("/vistas/entregasVista.jsp");
                permitidas.add("/vistas/controlStockVista.jsp");
                permitidas.add("/vistas/tomaInventarioVista.jsp");
                permitidas.add("/vistas/informeEntradasVista.jsp");
                permitidas.add("/vistas/informeMaterialVista.jsp");
                permitidas.add("/vistas/informeExistenciasVista.jsp");
                permitidas.add("/vistas/informeMovimientosEquiposVista.jsp");
                permitidas.add("/vistas/informeInventarioVista.jsp");
                // El Encargado de depósito no solicita asistencia correctiva
            }
            if (!permitidas.contains(rutaVista)) {
                response.sendRedirect(request.getContextPath() + "/dashboard.jsp?acceso=denegado");
                return;
            }
        }
    }
    String nombreCompletoSesion = (String) session.getAttribute("nombreCompleto");
    String usuarioSesion = nombreCompletoSesion != null ? nombreCompletoSesion : (String) session.getAttribute("user");
%>
<!DOCTYPE html>
<html lang="es">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>CTA SUPPORT</title>
        <link rel="icon" type="image/png" href="<%=request.getContextPath()%>/img/favicon.png">

        <link rel="stylesheet" href="<%=request.getContextPath()%>/plugins/fontawesome-free/css/all.min.css">
        <link rel="stylesheet" href="<%=request.getContextPath()%>/dist/css/adminlte.min.css">
        <link rel="stylesheet" href="<%=request.getContextPath()%>/dist/css/cta-tokens.css">
        <link rel="stylesheet" href="<%=request.getContextPath()%>/dist/css/cta-skeleton.css">
        <script>document.documentElement.classList.add("cta-loading");</script>
        <!-- Modo claro / oscuro: se aplica antes de pintar para evitar parpadeo. Preferencia guardada en este navegador. -->
        <script>(function(){var t=null;try{t=localStorage.getItem("cta-tema");}catch(e){}document.documentElement.setAttribute("data-tema",t==="claro"?"claro":"oscuro");})();</script>
        <script src="<%=request.getContextPath()%>/plugins/jquery/jquery.min.js"></script>
        <script src="<%=request.getContextPath()%>/dist/js/cta-ui.js"></script>

        <style>
            .main-sidebar {
                background-color: #0f172a !important;
            }
            .nav-sidebar .nav-link i {
                color: #06b6d4 !important;
            }
            .brand-text, .nav-sidebar .nav-link p {
                color: #f8fafc !important;
            }
            .nav-link:hover {
                background-color: rgba(6, 182, 212, 0.1) !important;
            }
            /* Colores personalizados para iconos de registros */
            .text-orange {
                color: #fd7e14 !important;
            }
            .text-teal {
                color: #20c997 !important;
            }
            .text-indigo {
                color: #6610f2 !important;
            }

            /* Usuario logueado en la barra superior */
            .navbar-user {
                display: flex;
                align-items: center;
                gap: 0.6rem;
                padding: 0 0.5rem;
            }
            .navbar-user .navbar-user-avatar {
                width: 32px;
                height: 32px;
                border-radius: 50%;
                background: #0f172a;
                color: #06b6d4;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 0.9rem;
            }
            .navbar-user .navbar-user-info {
                line-height: 1.15;
                max-width: 11rem;
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
            }
            @media (max-width: 575.98px) {
                .navbar-user .navbar-user-info { display: none; }
            }
            .navbar-user .navbar-user-name {
                font-weight: 600;
                color: #1a2b4c;
                font-size: 0.88rem;
            }
            .navbar-user .navbar-user-role {
                color: var(--cta-text-muted);
                font-size: 0.74rem;
            }

            /* Paleta corporativa aplicada a las clases de Bootstrap/AdminLTE (bg-*, btn-*, card-*, badge-*, text-*). Variables en dist/css/cta-tokens.css */
            /* Variables (--cta-*): ver dist/css/cta-tokens.css */

            .card {
                border-radius: 8px;
            }

            /* primary -> navy */
            .bg-primary, .btn-primary, .badge-primary {
                background-color: var(--cta-navy) !important;
                border-color: var(--cta-navy) !important;
            }
            .text-primary { color: var(--cta-navy) !important; }
            .card.card-outline.card-primary { border-top-color: var(--cta-navy) !important; }
            .btn-outline-primary { color: var(--cta-navy) !important; border-color: var(--cta-navy) !important; }
            .btn-primary:hover, .btn-primary:focus { background-color: var(--cta-steel) !important; border-color: var(--cta-steel) !important; }

            /* secondary -> gris pizarra */
            .bg-secondary, .btn-secondary, .badge-secondary {
                background-color: var(--cta-slate) !important;
                border-color: var(--cta-slate) !important;
            }
            .text-secondary { color: var(--cta-slate) !important; }
            .card.card-outline.card-secondary { border-top-color: var(--cta-slate) !important; }
            .btn-outline-secondary {
                color: var(--cta-navy) !important;
                border-color: var(--cta-border) !important;
            }
            .btn-outline-secondary:hover {
                background-color: var(--cta-navy) !important;
                border-color: var(--cta-navy) !important;
                color: #fff !important;
            }

            /* info -> azul acero */
            .bg-info, .btn-info, .badge-info {
                background-color: var(--cta-steel) !important;
                border-color: var(--cta-steel) !important;
            }
            .text-info { color: var(--cta-steel) !important; }
            .card.card-outline.card-info { border-top-color: var(--cta-steel) !important; }
            .btn-info:hover, .btn-info:focus { background-color: var(--cta-navy) !important; border-color: var(--cta-navy) !important; }

            /* success -> verde azulado sobrio */
            .bg-success, .btn-success, .badge-success {
                background-color: var(--cta-teal-ok) !important;
                border-color: var(--cta-teal-ok) !important;
            }
            .text-success { color: var(--cta-teal-ok) !important; }
            .card.card-outline.card-success { border-top-color: var(--cta-teal-ok) !important; }
            .btn-success:hover, .btn-success:focus { background-color: var(--cta-deep-teal) !important; border-color: var(--cta-deep-teal) !important; }

            /* warning -> dorado apagado, con texto blanco por contraste */
            .bg-warning, .btn-warning, .badge-warning {
                background-color: var(--cta-gold) !important;
                border-color: var(--cta-gold) !important;
                color: #fff !important;
            }
            .text-warning { color: var(--cta-gold) !important; }
            .card.card-outline.card-warning { border-top-color: var(--cta-gold) !important; }
            .btn-warning:hover, .btn-warning:focus { background-color: #6f5730 !important; border-color: #6f5730 !important; color: #fff !important; }

            /* danger -> burdeos apagado */
            .bg-danger, .btn-danger, .badge-danger {
                background-color: var(--cta-burgundy) !important;
                border-color: var(--cta-burgundy) !important;
            }
            .text-danger { color: var(--cta-burgundy) !important; }
            .card.card-outline.card-danger { border-top-color: var(--cta-burgundy) !important; }
            .btn-danger:hover, .btn-danger:focus { background-color: #5c2c35 !important; border-color: #5c2c35 !important; }

            /* teal (AdminLTE) -> verde azulado profundo, usado en Categorías */
            .bg-teal, .btn-teal, .badge-teal {
                background-color: var(--cta-deep-teal) !important;
                border-color: var(--cta-deep-teal) !important;
            }
            .card.card-outline.card-teal { border-top-color: var(--cta-deep-teal) !important; }

            /* thead de tablas: mismo tono navy sin importar qué bg-* traía la vista */
            .table thead.bg-success,
            .table thead.bg-info,
            .table thead.bg-primary,
            .table thead.bg-danger,
            .table thead.bg-teal,
            .table thead.bg-secondary {
                background-color: var(--cta-navy) !important;
                color: #fff !important;
            }
        </style>
        <!-- Botones metálicos, menú contraído y panel de inicio. Va después de los estilos de arriba para tener prioridad. -->
        <link rel="stylesheet" href="<%=request.getContextPath()%>/dist/css/cta-presentacion.css">
    </head>
    <body class="hold-transition sidebar-mini layout-fixed">
        <div class="wrapper">

            <nav class="main-header navbar navbar-expand navbar-white navbar-light">
                <ul class="navbar-nav">
                    <li class="nav-item">
                        <a class="nav-link" data-widget="pushmenu" href="#" role="button" aria-label="Mostrar u ocultar el menú lateral"><i class="fas fa-bars" aria-hidden="true"></i></a>
                    </li>
                    <li class="nav-item d-none d-sm-inline-block">
                        <a href="<%=request.getContextPath()%>/dashboard.jsp" class="nav-link">Inicio</a>
                    </li>
                </ul>

                <ul class="navbar-nav ml-auto">
<%                  if (esAdmin || esTecnico || esEncargado) { %>
                    <!-- Avisos de material: el técnico ve lo que puede ir a retirar; el depósito, lo que tiene por entregar -->
                    <li class="nav-item dropdown d-none" id="ctaAvisos"
                        data-ctx="<%=request.getContextPath()%>" data-deposito="<%= (esAdmin || esEncargado) ? "1" : "0" %>">
                        <a class="nav-link" data-toggle="dropdown" href="#" role="button" aria-label="Avisos de material">
                            <i class="far fa-bell" aria-hidden="true"></i>
                            <span class="badge badge-danger navbar-badge" id="ctaAvisosNum"></span>
                        </a>
                        <div class="dropdown-menu dropdown-menu-lg dropdown-menu-right" id="ctaAvisosMenu"></div>
                    </li>
<%                  } %>
                    <li class="nav-item">
                        <button type="button" class="btn-tema" id="btnTema" aria-pressed="false" title="Cambiar a modo claro">
                            <i class="fas fa-sun" aria-hidden="true"></i><span class="btn-tema-txt">Modo claro</span>
                        </button>
                    </li>
                    <li class="nav-item">
                        <div class="navbar-user">
                            <span class="navbar-user-avatar"><i class="fas fa-user"></i></span>
                            <span class="navbar-user-info">
                                <span class="navbar-user-name d-block"><%= usuarioSesion != null ? usuarioSesion : "" %></span>
                                <span class="navbar-user-role d-block"><%= nombreRolSesion != null ? nombreRolSesion : "" %></span>
                            </span>
                        </div>
                    </li>
                    <li class="nav-item">
                        <a href="<%=request.getContextPath()%>/logout.jsp" class="nav-link" title="Cerrar sesión" aria-label="Cerrar sesión">
                            <i class="fas fa-sign-out-alt" aria-hidden="true"></i><span class="d-none d-sm-inline"> Cerrar sesión</span>
                        </a>
                    </li>
                </ul>
            </nav>

            <script>
                (function () {
                    var raiz = document.documentElement, btn = document.getElementById("btnTema");
                    function pintar() {
                        var oscuro = raiz.getAttribute("data-tema") === "oscuro";
                        btn.setAttribute("aria-pressed", oscuro ? "true" : "false");
                        btn.title = oscuro ? "Cambiar a modo claro" : "Cambiar a modo oscuro";
                        btn.querySelector("i").className = oscuro ? "fas fa-sun" : "fas fa-moon";
                        btn.querySelector(".btn-tema-txt").textContent = oscuro ? "Modo claro" : "Modo oscuro";
                    }
                    btn.addEventListener("click", function () {
                        var nuevo = raiz.getAttribute("data-tema") === "oscuro" ? "claro" : "oscuro";
                        raiz.setAttribute("data-tema", nuevo);
                        try { localStorage.setItem("cta-tema", nuevo); } catch (e) {}
                        pintar();
                    });
                    pintar();
                })();
            </script>

            <aside class="main-sidebar elevation-4">
                <a href="<%=request.getContextPath()%>/dashboard.jsp" class="brand-link">
                    <span class="cta-brand-logo">
                        <img class="logo-completo" src="<%=request.getContextPath()%>/img/logo_sidebar.png" alt="CTA Support" width="400" height="189">
                        <img class="logo-mini" src="<%=request.getContextPath()%>/img/logo_mini.png" alt="" width="180" height="47">
                    </span>
                    <span class="sr-only">CTA SUPPORT - Inicio</span>
                </a>

                <div class="sidebar">
                    <nav class="mt-2">
                        <ul class="nav nav-pills nav-sidebar flex-column" data-widget="treeview" role="menu" data-accordion="false">
                           <% if (esAdmin) { %>

                            <li class="nav-item">
                                <a href="#" class="nav-link">
                                    <i class="nav-icon fas fa-shield-alt"></i>
                                    <p>REFERENCIALES <i class="right fas fa-angle-left"></i></p>
                                </a>
                                <ul class="nav nav-treeview">
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/personasVista.jsp" class="nav-link">
                                            <i class="fas fa-id-card nav-icon"></i>
                                            <p>Personas</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/rolesVista.jsp" class="nav-link">
                                            <i class="fas fa-user-tag nav-icon"></i>
                                            <p>Roles</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/usuariosVista.jsp" class="nav-link">
                                            <i class="fas fa-user-shield nav-icon"></i>
                                            <p>Usuarios</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/marcasVista.jsp" class="nav-link">
                                            <i class="fas fa-copyright nav-icon"></i>
                                            <p>Marcas</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/categoriasVista.jsp" class="nav-link">
                                            <i class="fas fa-tags nav-icon"></i>
                                            <p>Categorías</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/especialidadesVista.jsp" class="nav-link">
                                            <i class="fas fa-graduation-cap nav-icon"></i>
                                            <p>Especialidades</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/unidadesMedidaVista.jsp" class="nav-link">
                                            <i class="fas fa-ruler nav-icon"></i>
                                            <p>Unidades de Medida</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/tecnicosVista.jsp" class="nav-link">
                                            <i class="fas fa-user-cog nav-icon"></i>
                                            <p>Técnicos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/departamentosVista.jsp" class="nav-link">
                                            <i class="fas fa-building nav-icon"></i>
                                            <p>Departamentos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/salasVista.jsp" class="nav-link">
                                            <i class="fas fa-door-open nav-icon"></i>
                                            <p>Salas</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/equiposVista.jsp" class="nav-link">
                                            <i class="fas fa-laptop nav-icon"></i>
                                            <p>Equipos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/repuestosVista.jsp" class="nav-link">
                                            <i class="fas fa-cogs nav-icon"></i>
                                            <p>Repuestos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/insumosVista.jsp" class="nav-link">
                                            <i class="fas fa-box-open nav-icon"></i>
                                            <p>Insumos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/donantesVista.jsp" class="nav-link">
                                            <i class="fas fa-hand-holding-heart nav-icon"></i>
                                            <p>Donantes</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/tiposFallaVista.jsp" class="nav-link">
                                            <i class="fas fa-bug nav-icon"></i>
                                            <p>Tipos de Falla</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/serviciosCatalogoVista.jsp" class="nav-link">
                                            <i class="fas fa-tools nav-icon"></i>
                                            <p>Catálogo de Servicios</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/conceptosEntradaVista.jsp" class="nav-link">
                                            <i class="fas fa-sign-in-alt nav-icon"></i>
                                            <p>Conceptos de Entrada</p>
                                        </a>
                                    </li>



                                </ul>

                            </li>
                            <% } %>









                            <% if (esAdmin || esEncargado) { %>
                            <li class="nav-item">
                                <a href="#" class="nav-link">
                                    <i class="nav-icon fas fa-warehouse"></i>
                                    <p>INVENTARIO <i class="right fas fa-angle-left"></i></p>
                                </a>
                                <ul class="nav nav-treeview">
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/inventarioVista.jsp" class="nav-link">
                                            <i class="fas fa-boxes nav-icon"></i>
                                            <p>Inventario</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/recepcionesVista.jsp" class="nav-link">
                                            <i class="fas fa-truck-loading nav-icon"></i>
                                            <p>Entradas</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/entregasVista.jsp" class="nav-link">
                                            <i class="fas fa-hand-holding nav-icon"></i>
                                            <p>Material para técnicos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/movimientosEquiposVista.jsp" class="nav-link">
                                            <i class="fas fa-exchange-alt nav-icon"></i>
                                            <p>Movimientos de equipos</p>
                                        </a>
                                    </li>
                                </ul>
                            </li>
                            <% } %>

                            <% if (!esEncargado) { %>
                            <li class="nav-item">
                                <a href="#" class="nav-link">
                                    <i class="nav-icon fas fa-file-invoice"></i>
                                    <p>PROCESOS <i class="right fas fa-angle-left"></i></p>
                                </a>
                                <ul class="nav nav-treeview">
                                  <% if (!esTecnico) { %>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/ordenVista.jsp" class="nav-link">
                                            <i class="fas fa-headset nav-icon"></i>
                                            <p>Solicitar asistencia</p>
                                        </a>
                                    </li>
                                  <% } %>
                                  <% if (!esAlumnoOMaestro && !esEncargado) { %>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/ordenUnificadaVista.jsp" class="nav-link">
                                            <i class="fas fa-wrench nav-icon"></i>
                                            <p>Órdenes de trabajo correctivas</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/mantenimientoUnificadoVista.jsp" class="nav-link">
                                            <i class="fas fa-calendar-check nav-icon"></i>
                                            <p>Mantenimiento preventivo</p>
                                        </a>
                                    </li>
                                    <% } %>
                                </ul>
                            </li>
                            <% } %>

                            <% if (!esAlumnoOMaestro) { %>
                            <li class="nav-item">
                                <a href="#" class="nav-link">
                                    <i class="nav-icon fas fa-chart-bar"></i>
                                    <p>INFORMES <i class="right fas fa-angle-left"></i></p>
                                </a>
                                <ul class="nav nav-treeview">
                                  <% if (!esEncargado) { %>
                                    <li class="nav-header" style="font-size:.7rem;">MESA DE AYUDA</li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeSolicitudesVista.jsp" class="nav-link">
                                            <i class="fas fa-file-alt nav-icon"></i>
                                            <p>Solicitudes de asistencia</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeOrdenesVista.jsp" class="nav-link">
                                            <i class="fas fa-file-invoice nav-icon"></i>
                                            <p>Órdenes correctivas</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeMantenimientoVista.jsp" class="nav-link">
                                            <i class="fas fa-calendar-check nav-icon"></i>
                                            <p>Mantenimiento preventivo</p>
                                        </a>
                                    </li>
                                  <% } %>
                                    <li class="nav-header" style="font-size:.7rem;">INVENTARIO</li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeMaterialVista.jsp" class="nav-link">
                                            <i class="fas fa-toolbox nav-icon"></i>
                                            <p>Material para técnicos</p>
                                        </a>
                                    </li>
                                  <% if (esAdmin || esEncargado) { %>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeEntradasVista.jsp" class="nav-link">
                                            <i class="fas fa-truck-loading nav-icon"></i>
                                            <p>Entradas</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeExistenciasVista.jsp" class="nav-link">
                                            <i class="fas fa-warehouse nav-icon"></i>
                                            <p>Existencias y movimientos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeMovimientosEquiposVista.jsp" class="nav-link">
                                            <i class="fas fa-desktop nav-icon"></i>
                                            <p>Movimientos de equipos</p>
                                        </a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="<%=request.getContextPath()%>/vistas/informeInventarioVista.jsp" class="nav-link">
                                            <i class="fas fa-clipboard-list nav-icon"></i>
                                            <p>Pedidos de reposición</p>
                                        </a>
                                    </li>
                                  <% } %>
                                </ul>
                            </li>
                            <% } %>

                        </ul>
                    </nav>
                </div>
            </aside>
