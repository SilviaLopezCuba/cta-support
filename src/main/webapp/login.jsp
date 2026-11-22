<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="com.mycompany.pro.util.PasswordUtil"%>
<%@ include file="config/conexion.jsp" %>
<%
        if (request.getParameter("btnLogin") != null) {
            String user = request.getParameter("usuario");
            request.setAttribute("loginUsuario", user == null ? "" : user.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;"));
            String password = request.getParameter("pswrd");

            HttpSession sesion = request.getSession();

            try {
                String sqlLogin = "SELECT u.id_usuario, u.id_rol, u.login, u.password, r.nombre_rol, p.nombre, p.apellido " +
                        "FROM public.usuarios u " +
                        "LEFT JOIN public.roles r ON u.id_rol = r.id_rol " +
                        "LEFT JOIN public.personas p ON u.id_persona = p.id_persona " +
                        "WHERE u.login = ?";
                PreparedStatement psLogin = conexion.prepareStatement(sqlLogin);
                psLogin.setString(1, user);
                ResultSet rs = psLogin.executeQuery();

                boolean credencialesOk = false;

                if (rs.next()) {
                    String storedHash = rs.getString("password");

                    if (PasswordUtil.isBcrypt(storedHash)) {
                        credencialesOk = PasswordUtil.checkBcrypt(password, storedHash);
                    } else if (PasswordUtil.isLegacyMd5(storedHash)) {
                        credencialesOk = PasswordUtil.md5Legacy(password).equals(storedHash);
                        if (credencialesOk) {
                            // Migración progresiva: recalculamos con BCrypt y actualizamos.
                            String nuevoHash = PasswordUtil.hashPassword(password);
                            PreparedStatement psUpd = conexion.prepareStatement(
                                "UPDATE public.usuarios SET password = ? WHERE id_usuario = ?");
                            psUpd.setString(1, nuevoHash);
                            psUpd.setInt(2, rs.getInt("id_usuario"));
                            psUpd.executeUpdate();
                            psUpd.close();
                        }
                    }
                }

                if (credencialesOk) {
                    int idUsuario = rs.getInt("id_usuario");
                    int idRol = rs.getInt("id_rol");
                    String nombreRol = rs.getString("nombre_rol");
                    boolean esAdmin = "Administrador".equalsIgnoreCase(nombreRol);

                    String nombrePersona = rs.getString("nombre");
                    String apellidoPersona = rs.getString("apellido");
                    String nombreCompleto = ((nombrePersona != null ? nombrePersona : "") + " " +
                            (apellidoPersona != null ? apellidoPersona : "")).trim();
                    if (nombreCompleto.isEmpty()) {
                        nombreCompleto = rs.getString("login");
                    }

                    sesion.setAttribute("logueado", "1");
                    sesion.setAttribute("user", rs.getString("login"));
                    sesion.setAttribute("nombreCompleto", nombreCompleto);
                    sesion.setAttribute("idUsuario", idUsuario);
                    sesion.setAttribute("idRol", idRol);
                    sesion.setAttribute("nombreRol", nombreRol);
                    sesion.setAttribute("esAdmin", esAdmin);

                    String sqlTec = "SELECT id_tecnico FROM public.tecnicos WHERE id_usuario = ?";
                    PreparedStatement psTec = conexion.prepareStatement(sqlTec);
                    psTec.setInt(1, idUsuario);
                    ResultSet rsTec = psTec.executeQuery();
                    if (rsTec.next()) {
                        sesion.setAttribute("idTecnico", rsTec.getInt("id_tecnico"));
                    } else if (esAdmin) {
                        // El Administrador puede tomar y resolver tickets como un tecnico: se le crea una fila
                        // en tecnicos (disponibilidad en false para que NO entre en la asignacion automatica
                        // ni aparezca en el combo "Asignar").
                        Integer idTecAdmin = null;
                        try {
                            PreparedStatement psNuevoTec = conexion.prepareStatement(
                                "INSERT INTO public.tecnicos (id_usuario, estado_disponibilidad) VALUES (?, false) RETURNING id_tecnico");
                            psNuevoTec.setInt(1, idUsuario);
                            ResultSet rsNuevoTec = psNuevoTec.executeQuery();
                            if (rsNuevoTec.next()) {
                                idTecAdmin = rsNuevoTec.getInt(1);
                            }
                            rsNuevoTec.close();
                            psNuevoTec.close();
                        } catch (Exception exTecAdmin) {
                            idTecAdmin = null;
                        }
                        sesion.setAttribute("idTecnico", idTecAdmin);
                    } else {
                        sesion.setAttribute("idTecnico", null);
                    }
                    rsTec.close();
                    psTec.close();

                    rs.close();
                    psLogin.close();

                    response.sendRedirect("dashboard.jsp");
                    return;
                } else {
                    request.setAttribute("loginMsg", "Usuario o contraseña incorrectos");
                }
                rs.close();
                psLogin.close();
            } catch (Exception e) {
                request.setAttribute("loginMsg", "No se pudo iniciar sesión. Intente nuevamente.");
            }
        }
%>
<!DOCTYPE html>
<html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Iniciar sesión | CTA Support</title>
        <link rel="icon" type="image/png" href="img/favicon.png">
        <link rel="stylesheet" href="plugins/fontawesome-free/css/all.min.css">
        <link rel="stylesheet" href="dist/css/cta-tokens.css">
        <link rel="stylesheet" href="dist/css/cta-skeleton.css">
        <style>
            /* Los valores salen de dist/css/cta-tokens.css; aqui solo hay alias locales. */
            :root {
                --navy: var(--cta-navy);
                --navy-deep: #0f1a33;
                --steel: #274c7c;
                --ink: #0d1424;
                --muted: var(--cta-text-muted);
                --line: #8793a3;          /* borde de campos: 3.2:1 contra blanco (WCAG 1.4.11) */
                --placeholder: #6b7585;   /* 4.7:1 (antes #98a1b0 = 2.6:1) */
            }
            .sr-only {
                position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
                overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
            }
            * { box-sizing: border-box; }
            html, body { height: 100%; margin: 0; }
            body {
                font-family: "Segoe UI", system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif;
                color: var(--ink);
                background: #fff;
            }
            .login-layout {
                display: grid;
                grid-template-columns: 52fr 48fr;
                min-height: 100vh;
            }

            /* Panel oscuro */
            .brand-panel {
                position: relative;
                overflow: hidden;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                padding: 48px 40px;
                color: #fff;
                background:
                    radial-gradient(circle at 50% 22%, rgba(61, 140, 150, 0.16), transparent 42%),
                    linear-gradient(160deg, var(--navy-deep) 0%, #17294d 52%, #274c7c 100%);
            }
            .brand-panel::before,
            .brand-panel::after {
                content: "";
                position: absolute;
                left: 50%;
                top: 45%;
                border-radius: 50%;
                border: 1px solid rgba(255, 255, 255, 0.07);
                transform: translate(-50%, -50%);
                pointer-events: none;
            }
            .brand-panel::before { width: 1100px; height: 1100px; }
            .brand-panel::after  { width: 1500px; height: 1500px; border-color: rgba(255, 255, 255, 0.04); }

            .logo-card {
                position: relative;
                z-index: 1;
                width: min(368px, 100%);
                padding: 8px 22px 6px;
                background: #fff;
                border-radius: 18px;
                box-shadow: 0 18px 44px rgba(0, 0, 0, 0.32);
            }
            .logo-card img { display: block; width: 100%; height: auto; }

            .brand-copy {
                position: relative;
                z-index: 1;
                max-width: 360px;
                margin-top: 38px;
                text-align: center;
            }
            .brand-copy .brand-title {
                display: block;
                margin: 0 0 10px;
                font-size: 1.65rem;
                line-height: 1.22;
                font-weight: 700;
                letter-spacing: 0.1px;
            }
            .brand-copy p {
                margin: 0;
                font-size: 0.98rem;
                line-height: 1.5;
                color: rgba(255, 255, 255, 0.78);
            }

            /* Panel del formulario */
            .form-panel {
                display: flex;
                flex-direction: column;
                justify-content: space-between;
                padding: 0 40px 28px;
            }
            .form-wrap {
                width: 100%;
                max-width: 400px;
                margin: auto;
                padding-top: 60px;
            }
            .form-wrap h1 {
                margin: 0 0 8px;
                font-size: 2.1rem;
                line-height: 1.1;
                font-weight: 800;
                letter-spacing: -0.2px;
            }
            .form-wrap .lead {
                margin: 0 0 28px;
                font-size: 0.97rem;
                color: var(--muted);
            }
            .field { margin-bottom: 18px; }
            .field label {
                display: block;
                margin-bottom: 8px;
                font-size: 0.88rem;
                font-weight: 700;
            }
            .control { position: relative; }
            .control input {
                width: 100%;
                height: 48px;
                padding: 0 16px;
                font: inherit;
                font-size: 0.97rem;
                color: var(--ink);
                background: #fff;
                border: 1px solid var(--line);
                border-radius: var(--cta-radius);
                transition: border-color var(--cta-motion), box-shadow var(--cta-motion);
            }
            .control input::placeholder { color: var(--placeholder); }
            .control input:focus-visible {
                border-color: var(--cta-focus);
                outline: 3px solid var(--cta-focus);
                outline-offset: 2px;
            }
            .control input[aria-invalid="true"] { border-color: var(--cta-burgundy); border-width: 2px; }
            .control.has-toggle input { padding-right: 46px; }
            .toggle-pass {
                position: absolute;
                top: 0;
                right: 0;
                width: 46px;
                height: 48px;
                display: flex;
                align-items: center;
                justify-content: center;
                border: 0;
                background: transparent;
                color: var(--cta-text-muted);
                cursor: pointer;
                font-size: 0.9rem;
            }
            .toggle-pass:hover { color: var(--navy); }
            .toggle-pass:focus-visible { color: var(--navy); outline: 3px solid var(--cta-focus); outline-offset: -3px; border-radius: var(--cta-radius); }

            .btn-acceder {
                width: 100%;
                height: 50px;
                margin-top: 8px;
                font: inherit;
                font-size: 0.98rem;
                font-weight: 700;
                letter-spacing: 0.2px;
                color: #fff;
                background: var(--navy);
                border: 0;
                border-radius: var(--cta-radius);
                box-shadow: 0 8px 18px rgba(26, 43, 76, 0.28);
                cursor: pointer;
                transition: background .15s, transform .05s;
            }
            .btn-acceder:hover { background: #223a66; }
            .btn-acceder:active { transform: translateY(1px); }
            .btn-acceder:focus-visible { outline: 3px solid var(--cta-focus); outline-offset: 3px; }
            /* Estado "verificando": skeleton sobre el boton. No se usa disabled porque un boton
               deshabilitado no envia su name (btnLogin) y el servidor no procesaria el ingreso. */
            .btn-acceder.is-loading {
                cursor: progress;
                background: linear-gradient(90deg, var(--navy) 0%, #34508a 50%, var(--navy) 100%);
                background-size: 200% 100%;
                animation: cta-pulse 1.4s ease-in-out infinite;
            }
            .form-error {
                margin: 18px 0 0;
                padding: 10px 14px;
                font-size: 0.9rem;
                color: var(--cta-burgundy);
                background: #fbf3f4;
                border-left: 4px solid var(--cta-burgundy);
                border-radius: var(--cta-radius-sm);
            }
            /* Logo: mientras carga se reserva su espacio y se muestra el skeleton */
            .logo-card.is-loading { background: var(--cta-skel-base); animation: cta-pulse 1.4s ease-in-out infinite; }
            .logo-card.is-loading img { visibility: hidden; }

            .help {
                margin: 24px 0 0;
                font-size: 0.86rem;
                line-height: 1.5;
                color: var(--muted);
            }
            .legal {
                font-size: 0.8rem;
                color: var(--cta-text-muted);
            }
            .legal-wrap { width: 100%; max-width: 400px; margin: 0 auto; }

            /* Responsive */
            @media (max-width: 860px) {
                .login-layout { grid-template-columns: 1fr; }
                .brand-panel { padding: 20px 24px; }
                .brand-panel::before, .brand-panel::after { display: none; }
                .logo-card { width: min(200px, 70%); }
                .brand-copy { display: none; }
                .form-wrap { padding-top: 28px; margin: 0 auto; }
                .form-wrap h1 { font-size: 1.7rem; }
                .form-wrap .lead { margin-bottom: 20px; }
                .form-panel { padding: 0 24px 24px; }
            }
        </style>
    </head>
    <body>
        <main class="login-layout" id="contenido-principal">
            <section class="brand-panel">
                <div class="logo-card is-loading" id="logoCard">
                    <img src="img/logo_ctasupport.png" alt="CTA Support" width="1024" height="513" id="logoImg">
                </div>
                <div class="brand-copy">
                    <p class="brand-title">Soporte técnico<br>para aulas y equipos</p>
                    <p>Solicitudes, mantenimiento e inventario en un solo lugar.</p>
                </div>
            </section>

            <section class="form-panel">
                <div class="form-wrap">
                    <h1>Iniciar sesión</h1>
                    <p class="lead">Ingrese sus datos para acceder al sistema.</p>

                    <form action="login.jsp" method="post" autocomplete="on" id="formLogin">
                        <div class="field">
                            <label for="usuario">Usuario (cédula)</label>
                            <div class="control">
                                <input type="text" id="usuario" name="usuario" placeholder="Su número de cédula"
                                       autocomplete="username" inputmode="numeric" required aria-required="true" value="<%= request.getAttribute("loginUsuario") != null ? request.getAttribute("loginUsuario") : "" %>" autofocus<%= request.getAttribute("loginMsg") != null ? " aria-invalid=\"true\" aria-describedby=\"loginError\"" : "" %>>
                            </div>
                        </div>
                        <div class="field">
                            <label for="pswrd">Contraseña</label>
                            <div class="control has-toggle">
                                <input type="password" id="pswrd" name="pswrd" placeholder="Su contraseña"
                                       autocomplete="current-password" required aria-required="true"<%= request.getAttribute("loginMsg") != null ? " aria-invalid=\"true\" aria-describedby=\"loginError\"" : "" %>>
                                <button type="button" class="toggle-pass" id="togglePass"
                                        aria-label="Mostrar contraseña" aria-controls="pswrd" aria-pressed="false">
                                    <i class="fas fa-eye" id="togglePassIcon" aria-hidden="true"></i>
                                </button>
                            </div>
                        </div>
                        <button type="submit" name="btnLogin" class="btn-acceder" id="btnAcceder">Acceder</button>
                        <div class="sr-only" id="loginStatus" role="status" aria-live="polite"></div>
                    </form>

                    <p class="help">¿No puede ingresar? Pida al administrador que revise su usuario.</p>

                    <% if (request.getAttribute("loginMsg") != null) { %>
                    <p class="form-error" id="loginError"><i class="fas fa-exclamation-circle" aria-hidden="true"></i> <%= request.getAttribute("loginMsg") %></p>
                    <% } %>
                </div>
                <div class="legal-wrap">
                    <div class="legal">&copy; 2025-2026 CTA SUPPORT</div>
                </div>
            </section>
        </main>

        <script>
            (function () {
                var btn = document.getElementById('togglePass');
                var inp = document.getElementById('pswrd');
                var ico = document.getElementById('togglePassIcon');
                btn.addEventListener('click', function () {
                    var ver = inp.type === 'password';
                    inp.type = ver ? 'text' : 'password';
                    ico.className = ver ? 'fas fa-eye-slash' : 'fas fa-eye';
                    btn.setAttribute('aria-pressed', ver ? 'true' : 'false');
                    btn.setAttribute('aria-label', ver ? 'Ocultar contraseña' : 'Mostrar contraseña');
                });

                if (document.getElementById('usuario').value && document.getElementById('loginError')) { inp.focus(); }

                // Skeleton del logo
                var card = document.getElementById('logoCard');
                var img = document.getElementById('logoImg');
                function logoListo() { card.classList.remove('is-loading'); }
                if (img.complete) { logoListo(); } else { img.addEventListener('load', logoListo); img.addEventListener('error', logoListo); }

                // Estado "verificando" al enviar (evita doble envio y avisa a lectores de pantalla)
                var form = document.getElementById('formLogin');
                var enviar = document.getElementById('btnAcceder');
                var estado = document.getElementById('loginStatus');
                var enviando = false;
                form.addEventListener('submit', function (e) {
                    if (enviando) { e.preventDefault(); return; }
                    enviando = true;
                    enviar.classList.add('is-loading');
                    enviar.setAttribute('aria-busy', 'true');
                    enviar.textContent = 'Verificando...';
                    estado.textContent = 'Verificando sus datos';
                });
                // Al volver con el boton "atras" el navegador restaura la pagina: se reinicia el estado
                window.addEventListener('pageshow', function () {
                    enviando = false;
                    enviar.classList.remove('is-loading');
                    enviar.removeAttribute('aria-busy');
                    enviar.textContent = 'Acceder';
                    estado.textContent = '';
                });
            })();
        </script>
    </body>
</html>
