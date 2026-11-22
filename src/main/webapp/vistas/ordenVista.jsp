<%@page contentType="text/html" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Solicitar asistencia técnica | CTA SUPPORT</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/png" href="../img/favicon.png">
    <link rel="stylesheet" href="../plugins/fontawesome-free/css/all.min.css">
    <link rel="stylesheet" href="../dist/css/adminlte.min.css">
    <link rel="stylesheet" href="../dist/css/cta-tokens.css">
    <link rel="stylesheet" href="../dist/css/cta-skeleton.css">
    <script src="../plugins/jquery/jquery.min.js"></script>
    <script src="../dist/js/cta-ui.js"></script>
    <style>
        /* Mismo color de marca que el resto del sistema (variables en dist/css/cta-tokens.css) */
        .navbar-primary, .bg-primary, .btn-primary, .badge-primary {
            background-color: var(--cta-navy) !important;
            border-color: var(--cta-navy) !important;
        }
        .btn-primary:hover, .btn-primary:focus { background-color: var(--cta-steel) !important; border-color: var(--cta-steel) !important; }
        .card.card-outline.card-primary { border-top-color: var(--cta-navy) !important; }
        .table thead.bg-primary th { color: #fff; }
        .content-wrapper { background-color: var(--cta-page-bg); padding-top: 30px; }
        .main-footer { margin-left: 0 !important; text-align: center; }
    </style>
    <link rel="stylesheet" href="<%=request.getContextPath()%>/dist/css/cta-presentacion.css">
    <script>(function(){var t=null;try{t=localStorage.getItem("cta-tema");}catch(e){}document.documentElement.setAttribute("data-tema",t==="claro"?"claro":"oscuro");})();</script>
</head>
<body class="hold-transition layout-top-nav">
<div class="wrapper">

    <nav class="main-header navbar navbar-expand-md navbar-dark navbar-primary">
        <div class="container-fluid">
            <a href="../dashboard.jsp" class="btn btn-outline-light btn-sm mr-3 font-weight-bold" title="Volver al inicio">
                <i class="fas fa-arrow-left"></i> Atrás
            </a>
            <span class="navbar-brand font-weight-bold text-white">
                <i class="fas fa-headset"></i> Solicitar asistencia técnica
            </span>
        </div>
    </nav>

    <div class="content-wrapper">
        <section class="content">
            <h1 class="sr-only">Solicitar asistencia técnica</h1>
            <div class="container-fluid" style="max-width: 1200px; margin: 0 auto;">
                <div class="row">

                    <div class="col-md-6">
                        <div class="card card-primary card-outline shadow">
                            <div class="card-header bg-white">
                                <h2 class="card-title font-weight-bold">
                                    <i class="fas fa-edit"></i> Nueva solicitud
                                </h2>
                            </div>
                            <div class="card-body">
                                <form id="formSolicitud" onsubmit="return false;">
                                    <div class="form-group">
                                        <label for="id_depto_ticket" class="font-weight-bold">Departamento</label>
                                        <select id="id_depto_ticket" class="form-control" style="width: 100%;" required></select>
                                    </div>
                                    <div class="form-group">
                                        <label for="id_sala_ticket" class="font-weight-bold">Aula o sala</label>
                                        <select id="id_sala_ticket" class="form-control" style="width: 100%;" required></select>
                                    </div>
                                    <div class="form-group">
                                        <label for="id_equipo_ticket" class="font-weight-bold">Equipo con falla</label>
                                        <select id="id_equipo_ticket" class="form-control" style="width: 100%;" required></select>
                                    </div>
                                    <div class="form-group">
                                        <label for="tipo_falla" class="font-weight-bold">Tipo de falla</label>
                                        <select id="tipo_falla" class="form-control" required disabled>
                                            <option value="">-- Primero seleccione el equipo --</option>
                                        </select>
                                    </div>
                                    <div class="form-group">
                                        <label for="descripcion" class="font-weight-bold">Descripción del problema</label>
                                        <textarea id="descripcion" class="form-control" rows="4" placeholder="Cuéntenos qué ocurre, desde cuándo y cualquier detalle que ayude al técnico" required></textarea>
                                    </div>
                                    <div class="form-group mb-0">
                                        <span class="d-block font-weight-bold mb-2">Fotos o documentos <span class="font-weight-normal text-muted">(opcional)</span></span>
                                        <div id="adjuntosSolicitud"></div>
                                    </div>
                                </form>
                            </div>
                            <div class="card-footer bg-white text-right">
                                <button type="button" id="btnEnviar" class="btn btn-primary font-weight-bold shadow-sm" onclick="guardarTicketAlumno()">
                                    <i class="fas fa-paper-plane"></i> Enviar solicitud
                                </button>
                            </div>
                        </div>
                    </div>

                    <div class="col-md-6">
                        <div class="card card-primary card-outline shadow">
                            <div class="card-header bg-white">
                                <h2 class="card-title font-weight-bold">
                                    <i class="fas fa-history"></i> Mis solicitudes
                                </h2>
                            </div>
                            <div class="card-body p-0">
                                <div class="table-responsive">
                                    <table class="table table-striped table-hover m-0 text-sm">
                                        <thead class="bg-primary text-white">
                                            <tr>
                                                <th>N.º de ticket</th>
                                                <th>Equipo</th>
                                                <th>Fecha de solicitud</th>
                                                <th>Estado</th>
                                                <th>Prioridad</th>
                                                <th>Técnico</th>
                                                <th class="text-center">Comprobante</th>
                                            </tr>
                                        </thead>
                                        <tbody id="tablaMisTickets">
                                            <tr><td colspan="7" class="text-center text-muted py-4">Cargando sus solicitudes...</td></tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>

                </div>
            </div>
        </section>
    </div>

    <footer class="main-footer text-center" style="margin-left: 0px !important;">
        <strong>&copy; 2026 CTA SUPPORT.</strong> Gestión de tickets de soporte técnico.
    </footer>
</div>

<script src="../plugins/bootstrap/js/bootstrap.bundle.min.js"></script>
<script src="../dist/js/adminlte.min.js"></script>
<script src="../plugins/sweetalert2/sweetalert2.all.min.js"></script>
<script src="../dist/js/avisos.js"></script>
<script src="../dist/js/cta-adjuntos.js"></script>

<script>
    $(document).ready(function() {
        cargarSalasYEquipos();
        listarMisTickets();
    });

    var todosLosEquipos = $();
    var todasLasSalas = $();

    // Departamento -> Sala
    function filtrarSalasPorDepto() {
        var depto = $("#id_depto_ticket").val();
        var $sa = $("#id_sala_ticket");
        $sa.find("option").not(":first").remove();
        if (!depto) {
            $sa.find("option:first").text("-- Primero seleccione el departamento --");
            $sa.prop("disabled", true).val("");
        } else {
            var delDepto = todasLasSalas.filter(function () { return String($(this).data("depto")) === String(depto); }).clone();
            $sa.append(delDepto);
            $sa.find("option:first").text(delDepto.length ? "-- Seleccione la Sala / Aula --" : "-- Este departamento no tiene salas --");
            $sa.prop("disabled", delDepto.length === 0).val("");
        }
        filtrarEquiposPorSala();
    }
    $(document).on("change", "#id_depto_ticket", filtrarSalasPorDepto);

    // Equipo -> tipos de falla de su categoría (más las generales)
    function cargarTiposFalla() {
        var $tf = $("#tipo_falla");
        var categoria = $("#id_equipo_ticket option:selected").data("categoria");
        if (!$("#id_equipo_ticket").val()) {
            $tf.html("<option value=''>-- Primero seleccione el equipo --</option>").prop("disabled", true);
            return;
        }
        $.post("../controladores/tiposFallaControlador.jsp", { tipo: "combo", id_categoria: categoria || "" }, function (html) {
            $tf.html(html).prop("disabled", false);
        });
    }
    $(document).on("change", "#id_equipo_ticket", cargarTiposFalla);

    function filtrarEquiposPorSala() {
        var sala = $("#id_sala_ticket").val();
        var $eq = $("#id_equipo_ticket");
        $eq.find("option").not(":first").remove();
        if (!sala) {
            $eq.find("option:first").text("-- Primero seleccione la sala --");
            $eq.prop("disabled", true).val("");
            cargarTiposFalla();
            return;
        }
        var deLaSala = todosLosEquipos.filter(function () { return String($(this).data("sala")) === String(sala); }).clone();
        $eq.append(deLaSala);
        $eq.find("option:first").text(deLaSala.length ? "-- Seleccione el Equipo en Falla --" : "-- Esta sala no tiene equipos registrados --");
        $eq.prop("disabled", deLaSala.length === 0).val("");
        cargarTiposFalla();
    }

    $(document).on("change", "#id_sala_ticket", filtrarEquiposPorSala);

    function cargarSalasYEquipos() {
        $.post("../controladores/ordenControlador.jsp", { tipo: "cargarSalasYEquipos" })
        .done(function(data) {
            var deptos = data.substring(data.indexOf("<DEPTOS>") + 8, data.indexOf("</DEPTOS>"));
            var salas = data.substring(data.indexOf("<SALAS>") + 7, data.indexOf("</SALAS>"));
            $("#id_depto_ticket").html(deptos);
            var equipos = data.substring(data.indexOf("<EQUIPOS>") + 9, data.indexOf("</EQUIPOS>"));
            $("#id_sala_ticket").html(salas);
            $("#id_equipo_ticket").html(equipos);
            // Se guardan todas las opciones y se muestran solo las de la sala elegida
            todosLosEquipos = $("#id_equipo_ticket option").not(":first").clone();
            todasLasSalas = $("#id_sala_ticket option").not(":first").clone();
            filtrarSalasPorDepto();
        })
        .fail(function(xhr) {
            avisar("danger", "No se pudieron cargar las salas y equipos (error " + xhr.status + ").");
        });
    }

    function listarMisTickets() {
        $.post("../controladores/ordenControlador.jsp", { tipo: "listarTicketsAlumno" })
        .done(function(html) {
            $("#tablaMisTickets").html(html);
        })
        .fail(function(xhr) {
            $("#tablaMisTickets").html("<tr><td colspan='7' class='text-center text-danger py-3'>No se pudieron cargar sus solicitudes (error " + xhr.status + ").</td></tr>");
        });
    }

    // Selector de fotos / PDF que se envían junto con la solicitud
    var selectorAdjuntos;
    $(function() { selectorAdjuntos = CtaAdjuntos.selector("#adjuntosSolicitud", { max: 4, texto: "Agregar fotos de la falla o un PDF" }); });

    function guardarTicketAlumno() {
        var eq = $("#id_equipo_ticket").val();
        var sala = $("#id_sala_ticket").val();
        var tipoFalla = $("#tipo_falla").val();
        var desc = $("#descripcion").val().trim();

        if (!eq || !sala || !tipoFalla || !desc) {
            avisar("warning", "Complete todos los campos para enviar la solicitud.");
            return;
        }
        if (desc.length < 10) {
            avisar("warning", "Describa el problema con un poco más de detalle (al menos 10 caracteres).");
            return;
        }

        var $btn = $("#btnEnviar").prop("disabled", true);
        var textoBoton = $btn.html();

        $.post("../controladores/ordenControlador.jsp", {
            tipo: "guardarTicket",
            id_equipo: eq,
            id_sala: sala,
            id_tipo_falla: tipoFalla,
            descripcion: desc
        })
        .done(function(res) {
            res = (res || "").trim();
            if (res.indexOf("success") !== 0) {
                avisar("danger", "No se pudo registrar la solicitud: " + res);
                $btn.prop("disabled", false);
                return;
            }
            var idTicket = res.split(":")[1];
            var archivos = selectorAdjuntos.archivos();
            var terminar = function(resultado) {
                var msg = "Su solicitud de asistencia fue registrada con éxito. Un técnico acudirá pronto. Puede imprimir el comprobante desde \"Mis solicitudes\".";
                if (resultado && resultado.subidos) {
                    msg += " Se adjunt" + (resultado.subidos === 1 ? "ó 1 archivo." : "aron " + resultado.subidos + " archivos.");
                }
                if (resultado && resultado.errores.length) {
                    avisar("warning", msg + " Algunos archivos no se pudieron adjuntar: " + resultado.errores.join(" "));
                } else {
                    avisar("success", msg);
                }
                $("#descripcion").val("");
                $("#id_depto_ticket").prop("selectedIndex", 0);
                filtrarSalasPorDepto();
                selectorAdjuntos.limpiar();
                $btn.prop("disabled", false).html(textoBoton);
                listarMisTickets();
            };
            if (!archivos.length || !idTicket) { terminar(null); return; }
            CtaAdjuntos.subir(idTicket, "solicitud", archivos, function(n, total) {
                $btn.html('<i class="fas fa-spinner fa-spin" aria-hidden="true"></i> Subiendo archivo ' + n + ' de ' + total + '...');
            }).then(terminar);
        })
        .fail(function(xhr) {
            avisar("danger", "Error del servidor (" + xhr.status + "). Vuelva a intentarlo o inicie sesión de nuevo.");
            $btn.prop("disabled", false);
        });
    }
</script>
</body>
</html>
