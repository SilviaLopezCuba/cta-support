<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>
<%
    // Único punto de verdad para saber si el usuario logueado es Administrador:
    // el atributo de sesión seteado en login.jsp a partir del rol real en BD.
    boolean esAdminSesion = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
%>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6">
                    <h1 class="font-weight-bold text-primary"><i class="fas fa-broom"></i> Mantenimiento Preventivo</h1>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">

<% if (esAdminSesion) { %>
            <!-- Panel 0: Programar Nuevo Mantenimiento (solo Administrador) -->
            <div class="card card-dark card-outline shadow mb-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-dark font-weight-bold">
                        <i class="fas fa-calendar-plus"></i> 0. Programar Nuevo Mantenimiento
                    </h3>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-4 form-group">
                            <label class="small font-weight-bold">Técnico Asignado</label>
                            <select id="prog_id_tecnico" class="form-control"></select>
                        </div>
                        <div class="col-md-4 form-group">
                            <label class="small font-weight-bold">Sala / Aula</label>
                            <select id="prog_id_sala" class="form-control" onchange="cargarEquiposDeSala()"></select>
                        </div>
                        <div class="col-md-4 form-group">
                            <label class="small font-weight-bold">Fecha Programada</label>
                            <input type="date" id="prog_fecha" class="form-control">
                        </div>
                    </div>
                    <div class="form-group">
                        <label class="small font-weight-bold">Equipos a revisar <span class="font-weight-normal text-muted">(uno o varios; en el Depósito también los inactivos para reparar)</span></label>
                        <div id="prog_equipos" class="border rounded p-2 bg-light" style="max-height:180px; overflow-y:auto;">
                            <span class="text-muted small">Seleccione una sala para ver sus equipos.</span>
                        </div>
                    </div>
                    <div class="form-group">
                        <label class="small font-weight-bold">Observaciones</label>
                        <textarea id="prog_observaciones" class="form-control" rows="2" placeholder="Notas generales del mantenimiento a programar..."></textarea>
                    </div>
                    <button type="button" class="btn btn-dark font-weight-bold shadow-sm" onclick="programarMantenimiento()">
                        <i class="fas fa-save"></i> Programar Mantenimiento
                    </button>
                </div>
            </div>
<% } %>

            <!-- Calendario de mantenimientos (Fase 5) -->
            <div class="card card-primary card-outline shadow mb-4">
                <div class="card-header bg-white d-flex align-items-center">
                    <h3 class="card-title text-primary font-weight-bold mr-auto">
                        <i class="fas fa-calendar-alt" aria-hidden="true"></i> Calendario de mantenimientos
                    </h3>
                    <button type="button" class="btn btn-outline-secondary btn-sm mr-1" onclick="moverMes(-1)" aria-label="Mes anterior"><i class="fas fa-chevron-left" aria-hidden="true"></i></button>
                    <span class="font-weight-bold mx-2" id="calTitulo" style="min-width: 140px; text-align: center;"></span>
                    <button type="button" class="btn btn-outline-secondary btn-sm ml-1" onclick="moverMes(1)" aria-label="Mes siguiente"><i class="fas fa-chevron-right" aria-hidden="true"></i></button>
                </div>
                <div class="card-body p-2">
                    <div class="table-responsive">
                        <table class="table table-bordered table-sm m-0 text-xs" style="table-layout: fixed;">
                            <thead class="bg-light text-center"><tr><th>Lun</th><th>Mar</th><th>Mié</th><th>Jue</th><th>Vie</th><th>Sáb</th><th>Dom</th></tr></thead>
                            <tbody id="calCuerpo"></tbody>
                        </table>
                    </div>
                    <p class="small text-muted mb-0 mt-1"><span class="badge badge-warning">Programado</span> <span class="badge badge-info">En Proceso</span> <span class="badge badge-success">Finalizado</span></p>
                </div>
            </div>

            <!-- Bandeja 1: Programados -->
            <div class="card card-warning card-outline shadow mb-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-warning font-weight-bold">
                        <i class="fas fa-bell"></i>
                        <% if (esAdminSesion) { %>1. Mantenimientos Programados <small class="text-muted">(sin tomar)</small>
                        <% } else { %>1. Mis Mantenimientos Asignados <small class="text-muted">(sin tomar)</small><% } %>
                    </h3>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Mantenimiento</th>
                                    <th>Fecha Programada</th>
                                    <th>Sala</th>
                                    <th>Técnico</th>
                                    <th class="text-center">Equipos</th>
                                    <th width="<%= esAdminSesion ? "230px" : "140px" %>" class="text-center">Acción</th>
                                </tr>
                            </thead>
                            <tbody id="tablaProgramados">
                                <tr><td colspan="6" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- Bandeja 2: Mis mantenimientos en curso -->
            <div class="card card-primary card-outline shadow mb-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-primary font-weight-bold">
                        <i class="fas fa-user-clock"></i> <%= esAdminSesion ? "2. Mantenimientos en Curso (todos los técnicos)" : "2. Mis Mantenimientos en Curso" %>
                    </h3>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Mantenimiento</th>
                                    <th>Sala</th>
                                    <th>Fecha Programada</th>
<% if (esAdminSesion) { %>
                                    <th>Técnico</th>
<% } %>
                                    <th class="text-center">Progreso</th>
                                    <th>Material</th>
                                    <th width="<%= esAdminSesion ? "260px" : "140px" %>" class="text-center">Acción</th>
                                </tr>
                            </thead>
                            <tbody id="tablaEnCurso">
                                <tr><td colspan="<%= esAdminSesion ? 7 : 6 %>" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- Panel 3: Gestión del mantenimiento seleccionado (cabecera - detalle) -->
            <input type="hidden" id="id_mantenimiento_actual">
            <div class="row">
                <div class="col-md-4">
                    <div class="card card-info card-outline shadow mb-4">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold"><i class="fas fa-clipboard-check"></i> 3. Datos del Mantenimiento</h3>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label for="txt_mantenimiento" class="text-secondary font-weight-bold">N° Mantenimiento</label>
                                <input type="text" id="txt_mantenimiento" class="form-control bg-light font-weight-bold text-primary" readonly placeholder="Use 'Tomar' o 'Continuar' arriba">
                            </div>
                            <div class="form-group">
                                <label for="txt_mant_sala" class="text-secondary font-weight-bold">Sala</label>
                                <input type="text" id="txt_mant_sala" class="form-control bg-light" readonly>
                            </div>
                            <div class="form-group">
                                <label for="txt_mant_fecha" class="text-secondary font-weight-bold">Fecha programada</label>
                                <input type="text" id="txt_mant_fecha" class="form-control bg-light" readonly>
                            </div>
                            <div class="form-group">
                                <label for="txt_mant_tecnico" class="text-secondary font-weight-bold">Técnico</label>
                                <input type="text" id="txt_mant_tecnico" class="form-control bg-light" readonly>
                            </div>
                            <div class="form-group">
                                <label for="txt_mant_obs" class="text-secondary font-weight-bold">Observación general</label>
                                <textarea id="txt_mant_obs" class="form-control bg-light" rows="2" readonly></textarea>
                            </div>
                            <div class="form-group mb-0">
                                <label for="txt_mant_obs_ini" class="text-secondary font-weight-bold">Observación inicial <span class="text-danger">*</span>
                                    <small class="d-block text-muted font-weight-normal">Cómo encontraste la sala y los equipos. Obligatoria para pedir material.</small></label>
                                <textarea id="txt_mant_obs_ini" class="form-control" rows="3" maxlength="500" placeholder="Ej.: 2 equipos no encienden, el resto funciona."></textarea>
                                <button type="button" class="btn btn-info btn-sm btn-block mt-2" onclick="guardarObservacionInicial()"><i class="fas fa-save"></i> Guardar observación inicial</button>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-8">
                    <div class="card card-secondary card-outline shadow mb-4">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-secondary font-weight-bold"><i class="fas fa-desktop"></i> Equipos Revisados</h3>
                            <div class="card-tools">
                                <button type="button" class="btn btn-outline-success btn-sm" onclick="marcarTodosOk()"><i class="fas fa-check-double"></i> Marcar todos OK</button>
                            </div>
                        </div>
                        <div class="card-body p-0">
                            <div class="table-responsive">
                                <table class="table table-bordered table-sm m-0 text-sm">
                                    <thead class="bg-secondary text-white text-xs">
                                        <tr><th>Equipo</th><th width="190px">Resultado</th><th>Observación</th></tr>
                                    </thead>
                                    <tbody id="listaEquiposGestion">
                                        <tr><td colspan="3" class="text-center text-muted py-3">Ningún mantenimiento seleccionado.</td></tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        <div class="card-footer bg-white border-top">
                            <button type="button" class="btn btn-success float-right font-weight-bold shadow" onclick="finalizarMantenimiento()">
                                <i class="fas fa-check-circle"></i> FINALIZAR MANTENIMIENTO
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Material del mantenimiento (para todo el mantenimiento, no por equipo) -->
            <div class="row">
                <div class="col-md-6">
                    <div id="panelPedidoMaterial" class="mb-4"></div>
                </div>
                <div class="col-md-6">
                    <div class="card card-info card-outline shadow mb-4">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold"><i class="fas fa-boxes"></i> Material Usado</h3>
                        </div>
                        <div class="card-body">
                            <div class="row bg-light p-3 mb-3 rounded border">
                                <div class="col-md-8 form-group">
                                    <label for="mg_sel" class="small font-weight-bold">Artículo recibido</label>
                                    <select id="mg_sel" class="form-control"><option value="">-- Abra un mantenimiento --</option></select>
                                </div>
                                <div class="col-md-4 form-group">
                                    <label for="mg_cant" class="small font-weight-bold">Cantidad</label>
                                    <input type="number" id="mg_cant" class="form-control" value="1" min="0" step="any">
                                </div>
                                <div class="col-md-12">
                                    <button type="button" class="btn btn-info btn-block font-weight-bold" onclick="agregarMaterialGlobal()"><i class="fas fa-plus"></i> Agregar</button>
                                </div>
                            </div>
                            <table class="table table-bordered table-sm m-0 text-sm">
                                <thead class="bg-secondary text-white text-xs">
                                    <tr><th>Tipo</th><th>Artículo</th><th width="90px" class="text-right">Cantidad</th><th width="80px" class="text-center">Acción</th></tr>
                                </thead>
                                <tbody id="tablaMaterialUsado">
                                    <tr><td colspan="4" class="text-center text-muted py-2">Sin material usado.</td></tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Bandeja 4: Historial de mantenimientos finalizados -->
            <div class="card card-success card-outline shadow mt-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-success font-weight-bold">
                        <i class="fas fa-check-double"></i> 4. Historial de Mantenimientos Finalizados <small class="text-muted">(últimos 50<%= esAdminSesion ? "" : ", solo los suyos" %>)</small>
                    </h3>
                    <div class="card-tools">
                        <button type="button" class="btn btn-tool" onclick="listarFinalizados()"><i class="fas fa-sync-alt"></i></button>
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Mantenimiento</th>
                                    <th>Sala</th>
                                    <th>Técnico</th>
                                    <th>Fecha de cierre</th>
                                    <th class="text-center">Comprobante</th>
                                </tr>
                            </thead>
                            <tbody id="tablaFinalizados">
                                <tr><td colspan="5" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>
<script src="<%=request.getContextPath()%>/dist/js/cta-materiales.js"></script>

<%-- IMPORTANTE: NO volver a cargar jQuery aquí. footer.jsp ya carga jQuery + Bootstrap + AdminLTE;
     un segundo jQuery reemplaza a "$" y descarta los plugins de Bootstrap (collapse, modal, etc.). --%>

<script>
// VARIABLES GLOBALES
const esAdminSesion = <%= esAdminSesion %>;

console.log("===== VISTA MANTENIMIENTO CARGADA =====");

$(document).ready(function() {
    console.log("document ready ejecutado");
    if (esAdminSesion) cargarCombosProgramar();
    listarProgramados();
    listarEnCurso();
    listarFinalizados();
});

// FUNCIONES DE COMBOS

// ===== Calendario (Fase 5) =====
var calMes = new Date(); calMes.setDate(1);
function moverMes(delta) { calMes.setMonth(calMes.getMonth() + delta); dibujarCalendario(); }
function dibujarCalendario() {
    var y = calMes.getFullYear(), m = calMes.getMonth();
    var mesTxt = y + "-" + String(m + 1).padStart(2, "0");
    var nombres = ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"];
    $("#calTitulo").text(nombres[m] + " " + y);
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "calendario", mes: mesTxt }, function (r) {
        var porDia = {};
        (r.items || []).forEach(function (it) { (porDia[it.fecha] = porDia[it.fecha] || []).push(it); });
        var primero = new Date(y, m, 1), dias = new Date(y, m + 1, 0).getDate();
        var inicio = (primero.getDay() + 6) % 7;   // lunes = 0
        var hoy = hoyISO(), html = "<tr>", celda = 0;
        for (var k = 0; k < inicio; k++, celda++) html += "<td class='bg-light'></td>";
        for (var d = 1; d <= dias; d++, celda++) {
            if (celda > 0 && celda % 7 === 0) html += "</tr><tr>";
            var f = mesTxt + "-" + String(d).padStart(2, "0");
            var finde = (celda % 7) >= 5;
            html += "<td style='height:64px; vertical-align:top;' class='" + (f === hoy ? "border border-primary" : "") + (finde ? " bg-light" : "") + "'>"
                 + "<div class='font-weight-bold'>" + d + "</div>";
            (porDia[f] || []).forEach(function (it) {
                var b = it.estado === "Finalizado" ? "badge-success" : (it.estado === "En Proceso" ? "badge-info" : "badge-warning");
                html += "<span class='badge " + b + " d-block text-truncate mb-1' title='" + esc(it.numero + " · " + it.sala + " · " + it.tecnico + " · " + it.equipos + " equipo(s)") + "'>"
                     + esc(it.numero) + " · " + esc(it.sala) + "</span>";
            });
            html += "</td>";
        }
        while (celda % 7 !== 0) { html += "<td class='bg-light'></td>"; celda++; }
        $("#calCuerpo").html(html + "</tr>");
    }, "json");
}
$(function () { dibujarCalendario(); });
$(function () { CtaMateriales.montar("#panelPedidoMaterial", "M", function () { var id = $("#id_mantenimiento_actual").val(); if (id) cargarMantenimientoEnGestion(id); }); });

function cargarCombosProgramar() {
    console.log("cargarCombosProgramar llamada");
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "cargarCombosProgramar" })
    .done(function(data) {
        console.log("Respuesta combosProgramar recibida");
        var parts = data.split("|||");
        if (parts.length === 2) {
            $("#prog_id_tecnico").html(parts[0]);
            $("#prog_id_sala").html(parts[1]);
        } else {
            console.error("Formato de respuesta inválido:", data);
        }
    })
    .fail(function(xhr, status, error) {
        console.error("Error en cargarCombosProgramar:", status, error);
        alert("Error al cargar combos: " + error);
    });
}

function cargarEquiposDeSala() {
    var idSala = $("#prog_id_sala").val();
    console.log("cargarEquiposDeSala llamada, idSala:", idSala);
    if (!idSala) {
        $("#prog_equipos").html("<span class='text-muted small'>Seleccione una sala para ver sus equipos.</span>");
        return;
    }
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "cargarEquiposPorSala", idSala: idSala })
    .done(function(html) {
        console.log("Respuesta equiposPorSala recibida");
        $("#prog_equipos").html(html);
    })
    .fail(function(xhr, status, error) {
        console.error("Error en cargarEquiposDeSala:", status, error);
        $("#prog_equipos").html("<span class='text-danger small'>Error al cargar equipos: " + error + "</span>");
    });
}

// PROGRAMAR MANTENIMIENTO - CORREGIDO

// Fecha de hoy en formato yyyy-mm-dd (hora local), para validar y para el atributo min
function hoyISO() {
    var d = new Date();
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
}
$(function () { $("#prog_fecha").attr("min", hoyISO()); });

function programarMantenimiento() {
    var idTecnico = $("#prog_id_tecnico").val();
    var idSala = $("#prog_id_sala").val();
    var fecha = $("#prog_fecha").val();
    var observaciones = $("#prog_observaciones").val().trim();
    var equipos = $(".chk-equipo:checked:not(:disabled)").map(function() { return $(this).val(); }).get();

    console.log("===== DATOS A ENVIAR =====");
    console.log("idTecnico:", idTecnico);
    console.log("idSala:", idSala);
    console.log("fecha:", fecha);
    console.log("observaciones:", observaciones);
    console.log("equipos seleccionados:", equipos);

    if (!idTecnico || idTecnico === "") {
        alert("Seleccione un técnico.");
        return;
    }
    if (!idSala || idSala === "") {
        alert("Seleccione una sala.");
        return;
    }
    if (!fecha) {
        alert("Seleccione una fecha programada.");
        return;
    }
    if (fecha < hoyISO()) {
        alert("La fecha programada no puede ser anterior a hoy.");
        return;
    }
    if (equipos.length === 0) {
        alert("Seleccione al menos un equipo para el mantenimiento.");
        return;
    }

    var params = {
        tipo: "programarMantenimiento",
        idTecnico: idTecnico,
        idSala: idSala,
        fechaProgramada: fecha,
        observaciones: observaciones,
        eq_count: equipos.length
    };
    equipos.forEach(function(id, i) {
        params["eq_id_" + i] = id;
    });

    console.log("PARAMS FINALES:", params);

    $.ajax({
        url: "../controladores/mantenimientoUnificadoControlador.jsp",
        method: "POST",
        data: params,
        dataType: "text"
    })
    .done(function(res) {
        console.log("=== RESPUESTA DEL SERVIDOR ===");
        console.log("Respuesta completa: '" + res + "'");
        console.log("Trim: '" + res.trim() + "'");
        console.log("==============================");
        
        if (res.trim() === "success") {
      alert(" Mantenimiento programado correctamente.");
            $("#prog_id_tecnico").val("");
            $("#prog_id_sala").val("");
            $("#prog_fecha").val("");
            $("#prog_observaciones").val("");
            $("#prog_equipos").html("<span class='text-muted small'>Seleccione una sala para ver sus equipos.</span>");
            listarProgramados();
            listarEnCurso();
            dibujarCalendario();
        } else {
      alert(" Error: " + res);
        }
    })
    .fail(function(xhr, status, error) {
        console.error("=== ERROR AJAX ===");
        console.error("Status:", status);
        console.error("Error:", error);
        console.error("Respuesta del servidor:", xhr.responseText);
        console.error("==================");
    alert(" Error de comunicación con el servidor: " + error);
    });
}

// BANDEJAS

function listarProgramados() {
    console.log("listarProgramados llamada");
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "listarProgramados" })
    .done(function(html) {
        console.log("Respuesta listarProgramados recibida");
        $("#tablaProgramados").html(html);
    })
    .fail(function(xhr, status, error) {
        console.error("Error en listarProgramados:", status, error);
        $("#tablaProgramados").html('<tr><td colspan="6" class="text-center text-danger py-3">Error: ' + error + '</td></tr>');
    });
}

function listarEnCurso() {
    console.log("listarEnCurso llamada");
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "listarEnCurso" })
    .done(function(html) {
        console.log("Respuesta listarEnCurso recibida");
        $("#tablaEnCurso").html(html);
    })
    .fail(function(xhr, status, error) {
        console.error("Error en listarEnCurso:", status, error);
        $("#tablaEnCurso").html('<tr><td colspan="' + (esAdminSesion ? 7 : 6) + '" class="text-center text-danger py-3">Error: ' + error + '</td></tr>');
    });
}

function listarFinalizados() {
    console.log("listarFinalizados llamada");
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "listarFinalizados" })
    .done(function(html) {
        console.log("Respuesta listarFinalizados recibida");
        $("#tablaFinalizados").html(html);
    })
    .fail(function(xhr, status, error) {
        console.error("Error en listarFinalizados:", status, error);
        $("#tablaFinalizados").html('<tr><td colspan="5" class="text-center text-danger py-3">Error: ' + error + '</td></tr>');
    });
}

function refrescarBandejas() {
    listarProgramados();
    listarEnCurso();
    listarFinalizados();
}

// TOMAR / CONTINUAR MANTENIMIENTO

// Anulación de mantenimiento (Administrador). El servidor vuelve a validar el rol.
function anularMantenimiento(idMantenimiento, numero) {
    Swal.fire({
        title: "Anular mantenimiento " + numero,
        text: "Los materiales ya consumidos volverán al stock.",
        input: "textarea",
        inputLabel: "Motivo de la anulación (obligatorio)",
        inputAttributes: { "aria-label": "Motivo de la anulación" },
        showCancelButton: true,
        confirmButtonText: "Anular mantenimiento",
        cancelButtonText: "Volver",
        inputValidator: function (v) { return (!v || v.trim().length < 5) ? "Escriba un motivo de al menos 5 caracteres" : null; }
    }).then(function (r) {
        if (!r.isConfirmed) { return; }
        $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "anularMantenimiento", idMantenimiento: idMantenimiento, motivo: r.value }, function (resp) {
            if (resp.trim() === "success") {
                Swal.fire("Mantenimiento anulado", "Quedó en estado Cancelado.", "success");
                listarProgramados();
                listarEnCurso();
            } else {
                Swal.fire("No se pudo anular", resp.replace("error: ", ""), "error");
            }
        }).fail(function (xhr, status, error) {
            Swal.fire("Error de comunicación", String(error), "error");
        });
    });
}

function tomarMantenimiento(idMantenimiento, botonElemento) {
    console.log("tomarMantenimiento:", idMantenimiento);
    if (botonElemento) botonElemento.disabled = true;
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "tomarMantenimiento", idMantenimiento: idMantenimiento })
    .done(function(resp) {
        console.log("Respuesta tomarMantenimiento:", resp);
        if (resp.trim() === "success") {
            refrescarBandejas();
            cargarMantenimientoEnGestion(idMantenimiento);
        } else {
            alert("No se pudo tomar el mantenimiento: " + resp);
        }
        if (botonElemento) botonElemento.disabled = false;
    })
    .fail(function(xhr, status, error) {
        console.error("Error en tomarMantenimiento:", status, error);
        alert("Error de comunicación con el servidor: " + error);
        if (botonElemento) botonElemento.disabled = false;
    });
}

// Administrador: tomar un mantenimiento que ya está en curso con otro técnico (se conserva el avance)
function tomarMantenimientoEnCurso(idMantenimiento, botonElemento) {
    var tecnico = $(botonElemento).data("tecnico");
    // Si ya figura a tu nombre no hace falta confirmar: se abre para trabajarlo
    if (String($(botonElemento).data("mio")) === "1") { tomarMantenimiento(idMantenimiento, botonElemento); return; }
    confirmar("Este mantenimiento lo está haciendo " + (tecnico || "otro técnico") + ". ¿Lo tomás vos? Se conserva todo lo que ya se avanzó.", function () {
        tomarMantenimiento(idMantenimiento, botonElemento);
    }, { si: "Sí, tomarlo", title: "Tomar mantenimiento" });
}

function continuarMantenimiento(idMantenimiento) {
    console.log("continuarMantenimiento:", idMantenimiento);
    cargarMantenimientoEnGestion(idMantenimiento);
}

// Asignar / reasignar técnico (SOLO Administrador). El botón solo se dibuja para
// ese rol y el servidor vuelve a validarlo. En "Programado" cambia el técnico
// asignado (él deberá tomarlo); en "En curso" traspasa el mantenimiento.
function asignarMantenimiento(idMantenimiento, idTecnico) {
    if (!idTecnico) {
    alert("Seleccione un técnico para asignar.");
        return;
    }
  confirmar("¿Confirma asignar este mantenimiento al técnico seleccionado?", function () {
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", {
        tipo: "asignarMantenimiento",
        idMantenimiento: idMantenimiento,
        idTecnico: idTecnico
    })
    .done(function(resp) {
        console.log("Respuesta asignarMantenimiento:", resp);
        if (resp.trim() === "success") {
            // Si justo se estaba gestionando ese mantenimiento, se limpia el panel 3
            if (String($("#id_mantenimiento_actual").val()) === String(idMantenimiento)) {
                limpiarGestion();
            }
            refrescarBandejas();
        } else {
            alert("No se pudo asignar el mantenimiento: " + resp);
        }
    })
    .fail(function(xhr, status, error) {
        console.error("Error en asignarMantenimiento:", status, error);
        alert("Error de comunicación con el servidor: " + error);
    });

    });
}

function guardarObservacionInicial() {
    var id = $("#id_mantenimiento_actual").val();
    if (!id) { alert("Abra un mantenimiento."); return; }
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "guardarObservacionInicial", idMantenimiento: id, observacion: $("#txt_mant_obs_ini").val() }, function (r) {
        r = $.trim(r);
        if (r === "success") {
            $("#txt_mant_obs_ini").removeClass("is-invalid");
            if (typeof avisar === "function") avisar("success", "Observación guardada. Ya podés pedir material.");
            CtaMateriales.cargar(id);
        } else alert(r.replace(/^error:\s*/, ""));
    });
}

function limpiarGestion() {
    $("#id_mantenimiento_actual").val("");
    CtaMateriales.limpiar();
    $("#txt_mantenimiento, #txt_mant_sala, #txt_mant_fecha, #txt_mant_tecnico, #txt_mant_obs, #txt_mant_obs_ini").val("");
    $("#listaEquiposGestion").html("<tr><td colspan='3' class='text-center text-muted py-3'>Ningún mantenimiento seleccionado.</td></tr>");
    $("#tablaMaterialUsado").html("<tr><td colspan='4' class='text-center text-muted py-2'>Sin material usado.</td></tr>");
    $("#mg_sel").html("<option value=''>-- Abra un mantenimiento --</option>");
}

// Evita inyección de HTML desde datos de la BD (observaciones, descripciones, etc.)
function esc(s) {
    return $("<div>").text(s == null ? "" : String(s)).html();
}

// GESTIÓN DEL MANTENIMIENTO

function cargarMantenimientoEnGestion(idMantenimiento) {
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "obtenerMantenimiento", idMantenimiento: idMantenimiento })
    .done(function(resp) {
        var data = (typeof resp === "string") ? JSON.parse(resp) : resp;
        if (!data.ok) {
            alert("No se pudo cargar el mantenimiento: " + data.error);
            limpiarGestion();
            return;
        }
        $("#id_mantenimiento_actual").val(data.idMantenimiento);
        CtaMateriales.cargar(data.idMantenimiento);
        window.mantEsDeposito = !!data.esDeposito;
        $("#txt_mantenimiento").val(data.numeroMantenimiento + " [" + data.estado + "]");
        $("#txt_mant_sala").val(data.sala);
        $("#txt_mant_fecha").val(data.fechaProgramada);
        $("#txt_mant_tecnico").val(data.tecnico);
        $("#txt_mant_obs").val(data.observaciones);
        $("#txt_mant_obs_ini").val(data.observacionInicial || "");
        if (!data.observacionInicial) setTimeout(function () { $("#txt_mant_obs_ini").addClass("is-invalid").focus(); }, 300);
        else $("#txt_mant_obs_ini").removeClass("is-invalid");
        dibujarEquiposGestion(data.equipos);
        dibujarMaterialUsado(data.materiales || []);
        cargarComboMaterialUsado();
    })
    .fail(function(xhr, status, error) {
        alert("Error al cargar el mantenimiento: " + error);
    });
}

function dibujarEquiposGestion(equipos) {
    if (!equipos || equipos.length === 0) {
        $("#listaEquiposGestion").html("<tr><td colspan='3' class='text-center text-muted py-3'>Este mantenimiento no tiene equipos.</td></tr>");
        return;
    }
    var opciones = window.mantEsDeposito ? ["Reparado", "Sin reparación"] : ["OK", "Requirió repuesto", "Derivado a ticket", "No reparable"];
    var html = "";
    equipos.forEach(function (eq) {
        var id = eq.idDetalle;
        var sel = '<select class="form-control form-control-sm" id="res_' + id + '" aria-label="Resultado de ' + esc(eq.equipo) + '" onchange="elegirResultado(' + id + ')"' + (eq.ticketDerivado ? ' disabled' : '') + '>' +
                  '<option value="">-- Pendiente --</option>';
        opciones.forEach(function (o) { sel += '<option' + (eq.resultado === o ? ' selected' : '') + '>' + o + '</option>'; });
        sel += '</select>';
        html += "<tr" + (eq.resultado ? "" : " class='table-light'") + "><td>" + esc(eq.equipo)
              + (eq.ticketDerivado ? " <span class='badge badge-danger'>Ticket " + esc(eq.ticketDerivado) + "</span>" : "") + "</td>"
              + "<td>" + sel + "</td>"
              + "<td><input type='text' class='form-control form-control-sm' id='obs_" + id + "' maxlength='500' value='" + esc(eq.observacion || "") + "' placeholder='Opcional' aria-label='Observación' onblur='guardarObservacion(" + id + ")'></td></tr>";
    });
    $("#listaEquiposGestion").html(html);
}

function marcarTodosOk() {
    var id = $("#id_mantenimiento_actual").val();
    if (!id) { alert("Abra un mantenimiento primero."); return; }
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "marcarTodosOk", idMantenimiento: id }, function (resp) {
        resp = resp.trim();
        if (resp.indexOf("success") === 0) cargarMantenimientoEnGestion(id);
        else alert(resp.replace("error: ", ""));
    });
}

function guardarObservacion(idDetalle) {
    if ($("#res_" + idDetalle).val()) marcarEquipo(idDetalle);
}

// MATERIAL USADO (todo el mantenimiento)
function dibujarMaterialUsado(materiales) {
    if (!materiales.length) { $("#tablaMaterialUsado").html("<tr><td colspan='4' class='text-center text-muted py-2'>Sin material usado.</td></tr>"); return; }
    var h = "";
    materiales.forEach(function (m) {
        h += "<tr><td>" + (m.categoria === "Repuesto" ? "<span class='badge badge-primary'>Repuesto</span>" : "<span class='badge badge-info'>Insumo</span>") + "</td><td>" + esc(m.descripcion)
           + "</td><td class='text-right'>" + esc(m.cantidad) + "</td><td class='text-center text-nowrap'>"
           + "<button type='button' class='btn btn-warning btn-xs mr-1' title='Modificar cantidad' aria-label='Modificar cantidad' onclick='modificarMaterial(" + m.id + ", " + m.cantidad + ")'><i class='fas fa-edit'></i></button>"
           + "<button type='button' class='btn btn-danger btn-xs' title='Quitar' aria-label='Quitar' onclick='quitarMaterial(" + m.id + ")'><i class='fas fa-times'></i></button></td></tr>";
    });
    $("#tablaMaterialUsado").html(h);
}

function cargarComboMaterialUsado() {
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "cargarComboMateriales", idMantenimiento: $("#id_mantenimiento_actual").val() }, function (d) { $("#mg_sel").html(d); });
}

function agregarMaterialGlobal() {
    var id = $("#id_mantenimiento_actual").val(), v = $("#mg_sel").val(), cant = parseFloat(String($("#mg_cant").val()).replace(",", "."));
    if (!id) { alert("Abra un mantenimiento primero."); return; }
    if (!v) { alert("Seleccione un artículo que haya recibido del depósito."); return; }
    if (!(cant > 0)) { alert("Ingrese una cantidad mayor a cero."); return; }
    var p = v.split("-");
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "agregarMaterial", idMantenimiento: id, tipoItem: p[0], itemId: p[1], cantidad: cant }, function (resp) {
        if (resp.trim() === "success") { $("#mg_cant").val(1); cargarMantenimientoEnGestion(id); }
        else alert(resp.replace("error: ", ""));
    });
}

// Elegir el resultado marca el equipo como revisado
function elegirResultado(idDetalle) {
    var r = $("#res_" + idDetalle).val();
    if (r === "Derivado a ticket" && ($("#obs_" + idDetalle).val() || "").trim().length < 10) {
        alert("Para derivar a un ticket, primero describa la falla en la observación del equipo (al menos 10 caracteres).");
        $("#res_" + idDetalle).val("");
        $("#obs_" + idDetalle).focus();
        return;
    }
    marcarEquipo(idDetalle);
}

function marcarEquipo(idDetalle) {
    var resultado = $("#res_" + idDetalle).val();
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", {
        tipo: "marcarEquipo",
        idDetalle: idDetalle,
        realizado: !!resultado,
        observacion: $("#obs_" + idDetalle).val(),
        resultado: resultado
    })
    .done(function(resp) {
        resp = resp.trim();
        if (resp === "success|ticket") {
            if (typeof avisar === "function") avisar("info", "Se creó un ticket correctivo para el equipo.");
            cargarMantenimientoEnGestion($("#id_mantenimiento_actual").val());
        } else if (resp !== "success") {
            alert("No se pudo actualizar el equipo: " + resp.replace("error: ", ""));
            cargarMantenimientoEnGestion($("#id_mantenimiento_actual").val());
        } else {
            $("#res_" + idDetalle).closest("tr").toggleClass("table-light", !resultado);
        }
    })
    .fail(function(xhr, status, error) {
        alert("Error al actualizar el equipo: " + error);
    });
}

function modificarMaterial(idMaterial, cantidadActual) {
    Swal.fire({
        title: "Modificar cantidad",
        input: "number",
        inputValue: cantidadActual,
        inputAttributes: { min: 0.01, step: "any", "aria-label": "Nueva cantidad" },
        showCancelButton: true,
        confirmButtonText: "Guardar",
        cancelButtonText: "Volver",
        inputValidator: function (v) { return (!v || parseFloat(v) <= 0) ? "Indique una cantidad mayor a cero" : null; }
    }).then(function (r) {
        if (!r.isConfirmed) { return; }
        $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "modificarMaterial", idMaterial: idMaterial, cantidad: r.value }, function (resp) {
            if (resp.trim() === "success") {
                cargarMantenimientoEnGestion($("#id_mantenimiento_actual").val());
            } else {
                Swal.fire("No se pudo modificar", resp.replace("error: ", ""), "error");
            }
        }).fail(function (xhr, status, error) {
            Swal.fire("Error de comunicación", String(error), "error");
        });
    });
}

function quitarMaterial(idMaterial) {
  confirmar("¿Quitar este material del mantenimiento?", function () {
    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "quitarMaterial", idMaterial: idMaterial })
    .done(function(resp) {
        if (resp.trim() === "success") {
            cargarMantenimientoEnGestion($("#id_mantenimiento_actual").val());
        } else {
            alert("No se pudo quitar el material: " + resp);
        }
    })
    .fail(function(xhr, status, error) {
        console.error("Error en quitarMaterial:", status, error);
        alert("Error de comunicación con el servidor: " + error);
    });

    });
}

// FINALIZAR MANTENIMIENTO

function finalizarMantenimiento() {
    var idMantenimiento = $("#id_mantenimiento_actual").val();
    console.log("finalizarMantenimiento:", idMantenimiento);
    if (!idMantenimiento) {
        alert("Seleccione un mantenimiento usando 'Tomar' o 'Continuar' arriba.");
        return;
    }
    var sinRevisar = $("select[id^='res_']").filter(function () { return !$(this).val(); }).length;
    if (sinRevisar > 0) {
        alert("Falta el resultado de " + sinRevisar + " equipo(s). Elegilo en la tabla o usá \"Marcar todos OK\".");
        return;
    }
  confirmar("¿Confirma que desea finalizar este mantenimiento?", function () {

    $.post("../controladores/mantenimientoUnificadoControlador.jsp", { tipo: "finalizarMantenimiento", idMantenimiento: idMantenimiento })
    .done(function(res) {
        console.log("Respuesta finalizarMantenimiento:", res);
        if (res.trim() === "success") {
            alert("Mantenimiento finalizado correctamente.");
            limpiarGestion();
            refrescarBandejas();
        } else {
            alert(res.replace("error: ", ""));
        }
    })
    .fail(function(xhr, status, error) {
        console.error("Error en finalizarMantenimiento:", status, error);
        alert("Error de comunicación con el servidor: " + error);
    });

    });
}

// IMPRIMIR COMPROBANTE

function imprimirMantenimiento(idMantenimiento) {
    window.open("../controladores/mantenimientoUnificadoControlador.jsp?tipo=comprobantePdf&idMantenimiento=" + idMantenimiento, "_blank");
}
</script>