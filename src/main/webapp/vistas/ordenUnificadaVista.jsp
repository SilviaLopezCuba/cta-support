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
                    <h1 class="font-weight-bold text-primary"><i class="fas fa-tools"></i> Módulo Técnico - Mesa de Ayuda</h1>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">

            <% if (esAdminSesion) { %>
            <!-- Panel de Supervisión (SOLO Administrador): todos los casos activos, en tiempo real -->
            <div class="card card-danger card-outline shadow mb-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-danger font-weight-bold">
                        <i class="fas fa-user-shield"></i> Panel de Supervisión (Administrador)
                        <small class="text-muted">Todos los casos activos y su técnico asignado &mdash; se actualiza solo cada 15s</small>
                    </h3>
                    <div class="card-tools">
                        <button type="button" class="btn btn-tool" onclick="listarActivosAdmin()" title="Actualizar ahora">
                            <i class="fas fa-sync-alt"></i>
                        </button>
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Ticket</th>
                                    <th>Estado</th>
                                    <th>Prioridad</th>
                                    <th>Ubicación / Equipo</th>
                                    <th>Fecha</th>
                                    <th>Técnico Asignado</th>
                                    <th width="170px" class="text-center">Tomar / Atender</th>
                                    <th width="200px" class="text-center">Reasignar</th>
                                </tr>
                            </thead>
                            <tbody id="tablaActivosAdmin">
                                <tr><td colspan="8" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
            <% } %>

            <!-- Bandeja 1: Tickets Pendientes -->
            <div class="card card-warning card-outline shadow mb-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-warning font-weight-bold">
                        <i class="fas fa-bell"></i> 1. Tickets Pendientes <small class="text-muted">(sin técnico o esperando repuesto)</small>
                    </h3>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Ticket</th>
                                    <th>Prioridad</th>
                                    <th>Ubicación</th>
                                    <th>Equipo</th>
                                    <th>Fecha</th>
                                    <th>Tipo de Falla</th>
                                    <th>Estado / Técnico</th>
                                    <th width="<%= esAdminSesion ? "230px" : "140px" %>" class="text-center">Acción</th>
                                </tr>
                            </thead>
                            <tbody id="tablaTicketsPendientes">
                                <tr><td colspan="8" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- Bandeja 2: Mis Tickets en Curso -->
            <div class="card card-primary card-outline shadow mb-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-primary font-weight-bold">
                        <i class="fas fa-user-clock"></i> 2. Mis Tickets en Curso <small class="text-muted">(Asignado / En Proceso / Esperando Repuesto)</small>
                    </h3>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Ticket</th>
                                    <th>Prioridad</th>
                                    <th>Estado</th>
                                    <th>Ubicación / Equipo</th>
                                    <th>Material</th>
                                    <th>Fecha de seguimiento</th>
                                    <th width="160px" class="text-center">Acción</th>
                                </tr>
                            </thead>
                            <tbody id="tablaTicketsEnCurso">
                                <tr><td colspan="7" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <div class="row">
                <!-- Columna izquierda: Gestión del Ticket -->
                <div class="col-md-5">
                    <div class="card card-info card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold">
                                <i class="fas fa-user-check"></i> 3. Gestión del Ticket
                            </h3>
                        </div>
                        <div class="card-body">
                            <form id="formProcesar">
                                <input type="hidden" id="id_ticket_procesar">
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">Ticket Seleccionado</label>
                                    <input type="text" id="txt_ticket" class="form-control bg-light font-weight-bold text-primary" readonly placeholder="Use 'Continuar / Cerrar' en Mis Tickets en Curso">
                                </div>
                                <div class="form-group" id="grupoAdjuntos" style="display:none;">
                                    <span class="d-block text-secondary font-weight-bold mb-1">Archivos del ticket</span>
                                    <div id="adjuntos_ticket"></div>
                                </div>
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">Prioridad</label>
                                    <select id="prioridad_ticket" class="form-control font-weight-bold">
                                        <option value="Baja">BAJA</option>
                                        <option value="Media" selected>MEDIA</option>
                                        <option value="Alta">ALTA</option>
                                        <option value="Critica">CRÍTICA</option>
                                    </select>
                                </div>
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">Diagnóstico</label>
                                    <textarea id="diagnostico" class="form-control" rows="2" placeholder="Descripción de la falla encontrada..."></textarea>
                                </div>
                                <div class="form-group">
                                    <span class="d-block text-secondary font-weight-bold mb-1">Servicios realizados <small class="text-muted font-weight-normal">(obligatorio para resolver o cerrar)</small></span>
                                    <div id="serviciosCierre" class="border rounded p-2 bg-light small" style="max-height: 170px; overflow-y: auto;">
                                        <span class="text-muted">Abra un ticket para marcar los servicios.</span>
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">Observación Final / Solución</label>
                                    <textarea id="comentario_final" class="form-control" rows="3" placeholder="Detalles de la reparación..."></textarea>
                                </div>
                                <div class="form-group">
                                    <span class="d-block text-secondary font-weight-bold mb-1">Evidencia del trabajo <span class="font-weight-normal">(opcional)</span></span>
                                    <div id="adjuntosCierre"></div>
                                </div>
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">Estado Final</label>
                                    <select id="estado_final" class="form-control font-weight-bold text-success" onchange="toggleFechaSeguimiento()">
                                        <option value="En Proceso">EN PROCESO (queda pendiente)</option>
                                        <option value="Esperando Repuesto">ESPERANDO REPUESTO (queda pendiente)</option>
                                        <option value="Resuelto">RESUELTO (Trabajo Concluido)</option>
                                        <option value="Cerrado">CERRADO (Ticket Finalizado)</option>
                                    </select>
                                </div>
                                <div class="form-group border border-danger rounded p-2" id="grupoNoReparable" style="display:none;">
                                    <div class="custom-control custom-checkbox">
                                        <input type="checkbox" class="custom-control-input" id="chkNoReparable" onchange="$('#motivoNoReparable').toggle(this.checked)">
                                        <label class="custom-control-label text-danger font-weight-bold" for="chkNoReparable">El equipo no tiene arreglo (pasa a inactivo)</label>
                                    </div>
                                    <select id="motivoNoReparable" class="form-control form-control-sm mt-2" style="display:none;" aria-label="Motivo"></select>
                                </div>
                                <div class="form-group" id="grupoFechaSeguimiento">
                                    <label class="text-secondary font-weight-bold">
                                        Fecha de seguimiento <span class="text-danger">*</span>
                                        <small class="text-muted d-block font-weight-normal">Obligatoria mientras el ticket quede pendiente: indica cuándo se debe retomar.</small>
                                    </label>
                                    <input type="date" id="fecha_seguimiento" class="form-control">
                                </div>
                            </form>
                        </div>
                    </div>
                </div>

                <!-- Columna derecha: Pedido de material y Repuestos e Insumos -->
                <div class="col-md-7">
                    <div id="panelPedidoMaterial" class="mb-3"></div>
                    <div class="card card-secondary card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-secondary font-weight-bold">
                                <i class="fas fa-boxes"></i> 4. Repuestos e Insumos Utilizados
                            </h3>
                        </div>
                        <div class="card-body">
                            <div class="row bg-light p-3 mb-3 rounded border">
                                <div class="col-md-8 form-group">
                                    <label class="small font-weight-bold">Seleccionar Artículo</label>
                                    <select id="id_material" class="form-control" onchange="autocompletarPrecioMaterial()"></select>
                                </div>
                                <div class="col-md-4 form-group">
                                    <label class="small font-weight-bold">Cantidad</label>
                                    <input type="number" id="cantidad_material" class="form-control" value="1" min="1" step="1">
                                </div>
                                <input type="hidden" id="precio_material" value="0">
                                <div class="col-md-12 align-self-end form-group">
                                    <button class="btn btn-info btn-block font-weight-bold" type="button" onclick="agregarAlDetalleJS()">
                                        <i class="fas fa-plus"></i> Agregar Material
                                    </button>
                                </div>
                            </div>

                            <table class="table table-bordered table-sm m-0 text-sm">
                                <thead class="bg-secondary text-white text-xs">
                                    <tr>
                                        <th>Categoría</th>
                                        <th>Descripción</th>
                                        <th width="90px" class="text-right">Cantidad</th>
                                        <th width="60px" class="text-center">Quitar</th>
                                    </tr>
                                </thead>
                                <tbody id="tbodyDetalleJS">
                                    <tr><td colspan="4" class="text-center text-muted py-3">Ningún material asignado.</td></tr>
                                </tbody>
                            </table>
                        </div>
                        <div class="card-footer bg-white border-top">
                            <button type="button" class="btn btn-success float-right font-weight-bold shadow" onclick="procesarYDescontarOrden()">
                                <i class="fas fa-check-circle"></i> GUARDAR / PROCESAR TICKET
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Bandeja 5: Historial de Tickets Solucionados -->
            <div class="card card-success card-outline shadow mt-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-success font-weight-bold">
                        <i class="fas fa-check-double"></i> 5. Historial de Tickets Solucionados <small class="text-muted">(Resuelto / Cerrado - últimos 50)</small>
                    </h3>
                    <div class="card-tools">
                        <button type="button" class="btn btn-tool" onclick="listarTicketsResueltos()"><i class="fas fa-sync-alt"></i></button>
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Ticket</th>
                                    <th>Estado</th>
                                    <th>Prioridad</th>
                                    <th>Equipo</th>
                                    <th>Técnico</th>
                                    <th>Fecha de cierre</th>
                                    <th class="text-right">Tiempo de resolución</th>
                                    <th class="text-center">Comprobante</th>
                                </tr>
                            </thead>
                            <tbody id="tablaTicketsResueltos">
                                <tr><td colspan="8" class="text-center text-muted py-3">Cargando...</td></tr>
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
<script src="../dist/js/cta-adjuntos.js"></script>

<%-- IMPORTANTE: NO volver a cargar jQuery aquí. footer.jsp ya carga jQuery + Bootstrap + AdminLTE;
     un segundo jQuery reemplaza a "$" y descarta los plugins de Bootstrap. --%>

<script>
    let arrayDetalle = [];
    const esAdminSesion = <%= esAdminSesion %>;

    // Formatea un número como Guaraníes paraguayos: sin decimales
    // (el Gs. no usa centavos en la práctica) y con separador de miles
    // "." propio de la configuración regional es-PY, ej: Gs. 150.000
    function formatGs(valor) {
        let n = Number(valor);
        if (isNaN(n)) n = 0;
        return "Gs. " + Math.round(n).toLocaleString("es-PY");
    }

    console.log("jQuery cargado correctamente");

    $(document).ready(function () {
        console.log("document ready ejecutado");
        listarTicketsPendientes();
        listarTicketsEnCurso();
        listarTicketsResueltos();
        cargarCombosTecnicosMateriales();
        toggleFechaSeguimiento();

        if (esAdminSesion) {
            listarActivosAdmin();
            // Panel de supervisión "en tiempo real": refresco periódico por
            // polling (sin necesidad de WebSockets) cada 15 segundos.
            setInterval(listarActivosAdmin, 15000);
        }
    });

    function listarActivosAdmin() {
        CTA.skeleton.show("#tablaActivosAdmin");
        if (!esAdminSesion) return;
        $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "listarActivosAdmin" }, function (html) {
            $("#tablaActivosAdmin").html(html);
        }).fail(function(xhr, status, error) {
            console.error("Error en listarActivosAdmin:", status, error);
            $("#tablaActivosAdmin").html('<tr><td colspan="7" class="text-center text-danger py-3">Error: ' + error + '</td></tr>');
        });
    }

    function estadoEsPendiente(estado) {
        return estado === 'En Proceso' || estado === 'Esperando Repuesto';
    }

    function toggleFechaSeguimiento() {
        let estado = $("#estado_final").val();
        $("#grupoNoReparable").toggle(!estadoEsPendiente(estado));
        if (estadoEsPendiente(estado)) { $("#chkNoReparable").prop("checked", false); $("#motivoNoReparable").hide(); }
        if (estadoEsPendiente(estado)) {
            $("#grupoFechaSeguimiento").show();
        } else {
            $("#grupoFechaSeguimiento").hide();
            $("#fecha_seguimiento").val("");
        }
    }

    function listarTicketsPendientes() {
        CTA.skeleton.show("#tablaTicketsPendientes");
        console.log("listarTicketsPendientes llamada");
        $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "listarPendientes" }, function (html) {
            console.log("Respuesta listarPendientes recibida");
            $("#tablaTicketsPendientes").html(html);
        }).fail(function(xhr, status, error) {
            console.error("Error en listarPendientes:", status, error);
            $("#tablaTicketsPendientes").html('<tr><td colspan="8" class="text-center text-danger py-3">Error: ' + error + '</td></tr>');
        });
    }

    function listarTicketsEnCurso() {
        CTA.skeleton.show("#tablaTicketsEnCurso");
        console.log("listarTicketsEnCurso llamada");
        $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "listarEnCurso" }, function (html) {
            console.log("Respuesta listarEnCurso recibida");
            $("#tablaTicketsEnCurso").html(html);
        }).fail(function(xhr, status, error) {
            console.error("Error en listarEnCurso:", status, error);
            $("#tablaTicketsEnCurso").html('<tr><td colspan="7" class="text-center text-danger py-3">Error: ' + error + '</td></tr>');
        });
    }

    function listarTicketsResueltos() {
        CTA.skeleton.show("#tablaTicketsResueltos");
        console.log("listarTicketsResueltos llamada");
        $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "listarResueltos" }, function (html) {
            console.log("Respuesta listarResueltos recibida");
            $("#tablaTicketsResueltos").html(html);
        }).fail(function(xhr, status, error) {
            console.error("Error en listarResueltos:", status, error);
            $("#tablaTicketsResueltos").html('<tr><td colspan="8" class="text-center text-danger py-3">Error: ' + error + '</td></tr>');
        });
    }

    function refrescarBandejas() {
        listarTicketsPendientes();
        listarTicketsEnCurso();
        listarTicketsResueltos();
        if (esAdminSesion) {
            listarActivosAdmin();
        }
    }

    // Carga combos de técnicos (panel admin) y materiales (con precio de referencia).
    // Se llama al iniciar la página Y cada vez que se abre un ticket para
    // gestionar (ver cargarTicketEnFormulario), para que el combo de
    // artículos siempre refleje el stock actual y nunca quede vacío por una
    // carga inicial que no llegó a tiempo.
    function cargarCombosTecnicosMateriales() {
        console.log("cargarCombosTecnicosMateriales llamada");
        $("#id_material").html('<option value="">Cargando articulos...</option>');
        $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "cargarCombosTecnicoYMat", idTicket: $("#id_ticket_procesar").val() }, function (data) {
            console.log("Respuesta combos recibida");
            let parts = data.split("|||");
            if (parts.length === 2) {
                $("#id_material").html(parts[1]);
            } else {
                console.error("Formato de respuesta inválido en combos:", data);
                $("#id_material").html('<option value="">Error al cargar materiales</option>');
            }
        }).fail(function(xhr, status, error) {
            console.error("Error en cargarCombos:", status, error);
            $("#id_material").html('<option value="">Error al cargar materiales</option>');
        });
    }

    // Autocompleta el precio unitario con el último precio de compra registrado
    // para el artículo seleccionado (queda editable por si hace falta corregirlo).
    function autocompletarPrecioMaterial() {
        let opcionSeleccionada = $("#id_material option:selected");
        let precio = parseFloat(opcionSeleccionada.attr("data-precio"));
        // El campo es numérico y editable, así que se deja el valor "pelado"
        // (redondeado, sin decimales); el formato "Gs. 000.000" se aplica
        // solo donde el precio ya se muestra como texto (tabla y comprobante).
        $("#precio_material").val(isNaN(precio) ? "0" : Math.round(precio));
    }

    // Materiales de un ticket (Administrador): consultar, modificar cantidad/precio y quitar.
    // El servidor valida el rol y ajusta el stock en una transacción.
    var ticketMatActual = { id: null, numero: "" };

    function escHtml(t) {
        return String(t == null ? "" : t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    function verMaterialesTicket(idTicket, numero) {
        ticketMatActual = { id: idTicket, numero: numero };
        $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "listarMaterialesTicket", idTicket: idTicket }, function (lista) {
            var filas = "";
            for (var i = 0; i < lista.length; i++) {
                var m = lista[i];
                filas += "<tr><td>" + escHtml(m.categoria) + "</td><td>" + escHtml(m.descripcion) + "</td>" +
                    "<td class='text-right'>" + escHtml(m.cantidad) + "</td><td class='text-right'>" + escHtml(m.precio) + "</td>" +
                    "<td class='text-center'><button type='button' class='btn btn-warning btn-sm mr-1 btn-mat-edit' data-id='" + m.id +
                    "' data-cant='" + escHtml(m.cantidad) + "' data-precio='" + escHtml(m.precio) + "'><i class='fas fa-edit'></i></button>" +
                    "<button type='button' class='btn btn-danger btn-sm btn-mat-del' data-id='" + m.id + "'><i class='fas fa-trash'></i></button></td></tr>";
            }
            if (filas === "") { filas = "<tr><td colspan='5' class='text-center text-muted'>El ticket no tiene materiales registrados.</td></tr>"; }
            Swal.fire({
                title: "Materiales del ticket " + numero,
                width: 700,
                html: "<div class='table-responsive'><table class='table table-sm text-left'><thead><tr><th>Tipo</th><th>Artículo</th>" +
                      "<th class='text-right'>Cantidad</th><th class='text-right'>Precio unit.</th><th></th></tr></thead><tbody>" + filas + "</tbody></table></div>",
                confirmButtonText: "Cerrar"
            });
        }, "json").fail(function (xhr, status, error) {
            Swal.fire("Error de comunicación", String(error), "error");
        });
    }

    function postMaterialTicket(datos) {
        $.post("../controladores/ordenUnificadaControlador.jsp", datos, function (resp) {
            if (resp.trim() === "success") {
                verMaterialesTicket(ticketMatActual.id, ticketMatActual.numero);
            } else {
                Swal.fire("No se pudo completar", resp.replace("error: ", ""), "error");
            }
        }).fail(function (xhr, status, error) {
            Swal.fire("Error de comunicación", String(error), "error");
        });
    }

    $(document).on("click", ".btn-mat-edit", function () {
        var id = $(this).data("id"), cant = $(this).attr("data-cant"), precio = $(this).attr("data-precio");
        Swal.fire({
            title: "Modificar material",
            html: "<label for='swCant'>Cantidad</label><input id='swCant' type='number' class='swal2-input' min='0.01' step='any' value='" + escHtml(cant) + "'>" +
                  "<label for='swPrecio'>Precio unitario</label><input id='swPrecio' type='number' class='swal2-input' min='0' step='any' value='" + escHtml(precio) + "'>",
            showCancelButton: true,
            confirmButtonText: "Guardar",
            cancelButtonText: "Volver",
            preConfirm: function () {
                var c = parseFloat(document.getElementById("swCant").value), p = parseFloat(document.getElementById("swPrecio").value);
                if (isNaN(c) || c <= 0 || isNaN(p) || p < 0) { Swal.showValidationMessage("Indique una cantidad mayor a cero y un precio válido"); return false; }
                return { cantidad: c, precio: p };
            }
        }).then(function (r) {
            if (r.isConfirmed) {
                postMaterialTicket({ tipo: "modificarMaterialTicket", idMaterial: id, cantidad: r.value.cantidad, precio: r.value.precio });
            } else {
                verMaterialesTicket(ticketMatActual.id, ticketMatActual.numero);
            }
        });
    });

    $(document).on("click", ".btn-mat-del", function () {
        var id = $(this).data("id");
        Swal.fire({
            title: "¿Quitar este material?",
            text: "La cantidad volverá al stock.",
            showCancelButton: true,
            confirmButtonText: "Quitar",
            cancelButtonText: "Volver"
        }).then(function (r) {
            if (r.isConfirmed) {
                postMaterialTicket({ tipo: "quitarMaterialTicket", idMaterial: id });
            } else {
                verMaterialesTicket(ticketMatActual.id, ticketMatActual.numero);
            }
        });
    });

    // Anulacion de ticket (Administrador). El servidor vuelve a validar el rol.
    function anularTicket(idTicket, numeroTicket) {
        Swal.fire({
            title: "Anular ticket " + numeroTicket,
            input: "textarea",
            inputLabel: "Motivo de la anulación (obligatorio)",
            inputAttributes: { "aria-label": "Motivo de la anulación" },
            showCancelButton: true,
            confirmButtonText: "Anular ticket",
            cancelButtonText: "Volver",
            inputValidator: function (v) { return (!v || v.trim().length < 5) ? "Escriba un motivo de al menos 5 caracteres" : null; }
        }).then(function (r) {
            if (!r.isConfirmed) { return; }
            $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "anularTicket", idTicket: idTicket, motivo: r.value }, function (resp) {
                if (resp.trim() === "success") {
                    Swal.fire("Ticket anulado", "El ticket quedó en estado Cancelado.", "success");
                    refrescarBandejas();
                } else {
                    Swal.fire("No se pudo anular", resp.replace("error: ", ""), "error");
                }
            }).fail(function (xhr, status, error) {
                Swal.fire("Error de comunicación", String(error), "error");
            });
        });
    }

    // Asignación/reasignación manual de técnico (solo disponible para el rol Administrador;
    // el botón únicamente se renderiza para ese rol, y el servidor vuelve a validarlo).
    function asignarTecnicoManual(idTicket, idTecnico) {
        if (!idTecnico) {
            alert("Seleccione un técnico para asignar.");
            return;
        }
        $.post("../controladores/ordenUnificadaControlador.jsp", {
            tipo: "asignarTecnicoManual",
            idTicket: idTicket,
            idTecnico: idTecnico
        }, function (resp) {
            let r = resp.trim();
            if (r.indexOf("success") === 0) {
                if (r !== "success") {
                    // "success: atención, el técnico está marcado como no disponible"
                    alert(r.replace("success: ", ""));
                } else {
                    avisar("success", "Técnico asignado correctamente.");
                }
                refrescarBandejas();
            } else {
            alert("No se pudo asignar el técnico: " + r);
            }
        }).fail(function(xhr, status, error) {
            console.error("Error en asignarTecnicoManual:", status, error);
            alert("Error de comunicación con el servidor: " + error);
        });
    }

    // Archivos del ticket (fotos de la solicitud y evidencias anteriores), con miniatura
    function mostrarAdjuntos(idTicket) {
        $("#grupoAdjuntos").hide();
        if (!idTicket) { $("#adjuntos_ticket").empty(); return; }
        CtaAdjuntos.mostrar("#adjuntos_ticket", idTicket).then(function(cantidad) {
            $("#grupoAdjuntos").toggle(cantidad > 0);
        });
    }

    // Fotos o informes que el técnico adjunta al procesar el ticket
    var selectorCierre;
    $(function() { CtaMateriales.montar("#panelPedidoMaterial", "T", cargarCombosTecnicosMateriales); });
    $(function() { $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "motivosNoReparable" }, function (d) { $("#motivoNoReparable").html(d); }); });
    $(function() { selectorCierre = CtaAdjuntos.selector("#adjuntosCierre", { max: 4, texto: "Agregar fotos del trabajo o un informe PDF" }); });

    function cargarTicketEnFormulario(idTicket, despues) {
        console.log("cargarTicketEnFormulario: " + idTicket);
        $.ajax({
            url: "../controladores/ordenUnificadaControlador.jsp",
            method: "POST",
            data: { tipo: "obtenerTicket", idTicket: idTicket },
            dataType: "json"
        })
        .done(function(data) {
            if (!data.ok) {
                alert("No se pudo cargar el ticket: " + data.error);
                return;
            }

            $("#id_ticket_procesar").val(data.idTicket);
            CtaMateriales.cargar(data.idTicket);
            $("#txt_ticket").val("Ticket " + data.numeroTicket + " - " + data.equipo + " (" + data.sala + ") [" + data.estado + "]");
            mostrarAdjuntos(data.idTicket);
            $("#prioridad_ticket").val(data.prioridad || "Media");
            $("#diagnostico").val(data.diagnostico || "");
            $("#comentario_final").val(data.comentario || "");

            let estadoSugerido = estadoEsPendiente(data.estado) ? data.estado : "En Proceso";
            $("#estado_final").val(estadoSugerido);
            toggleFechaSeguimiento();
            if (data.fechaSeguimiento) {
                $("#fecha_seguimiento").val(data.fechaSeguimiento);
            }

            arrayDetalle = [];
            dibujarTabla();
            // Recarga el combo de artículos con el stock más reciente justo
            // al abrir el ticket para trabajar (antes se cargaba una sola
            // vez al entrar a la página y podía quedar vacío u obsoleto).
            cargarCombosTecnicosMateriales();
            $.post("../controladores/ordenUnificadaControlador.jsp", { tipo: "cargarServicios", idTicket: data.idTicket }, function (html) {
                $("#serviciosCierre").html(html);
            });
            $("#diagnostico").focus();
            // Ticket asignado que nadie revisó: primero la revisión, si no, no se trabaja
            if (data.revisado === false) {
                primeraRevision(data.idTicket, "revisar", data.numeroTicket, function (sigue) { seguirSegunRevision(data.idTicket, sigue); });
                $("#diagnostico").blur();
                return;
            }
            if (typeof despues === "function") despues();
        })
        .fail(function(xhr, status, error) {
            console.error("Error en cargarTicket:", status, error);
            alert("Error al cargar el ticket: " + error);
        });
    }

    // Autoasignación de ticket por el técnico logueado. Complementa a
    // asignarTecnicoManual (que usa el Administrador): un ticket "Pendiente"
    // puede ser tomado directamente por cualquier técnico disponible.
    // PRIMERA REVISIÓN (obligatoria): diagnóstico + urgencia + cómo sigue.
    //  modo "tomar": se pide antes de tomar el ticket (si se cancela, no se toma).
    //  modo "revisar": ticket ya asignado que nadie revisó.
    function primeraRevision(idTicket, modo, numero, alTerminar) {
        let hoy = new Date(); hoy.setMinutes(hoy.getMinutes() - hoy.getTimezoneOffset());
        let manana = new Date(hoy.getTime() + 86400000).toISOString().substring(0, 10);
        let html =
            "<div class='text-left'>" +
            "<label class='font-weight-bold small mb-1' for='rv_diag'>Diagnóstico inicial <span class='text-danger'>*</span></label>" +
            "<textarea id='rv_diag' class='form-control mb-3' rows='3' maxlength='500' placeholder='Qué encontraste al revisar el equipo'></textarea>" +
            "<label class='font-weight-bold small mb-1' for='rv_prio'>Urgencia <span class='text-danger'>*</span></label>" +
            "<select id='rv_prio' class='form-control mb-3'><option value=''>-- Elegir --</option><option value='Baja'>Baja</option><option value='Media'>Media</option>" +
            "<option value='Alta'>Alta</option><option value='Critica'>Crítica</option></select>" +
            "<span class='font-weight-bold small d-block mb-1'>¿Cómo sigue? <span class='text-danger'>*</span></span>" +
            "<div class='custom-control custom-radio'><input type='radio' class='custom-control-input' name='rv_sigue' id='rv_s1' value='proceso'><label class='custom-control-label' for='rv_s1'>🔧 Lo reparo ahora</label></div>" +
            "<div class='custom-control custom-radio'><input type='radio' class='custom-control-input' name='rv_sigue' id='rv_s2' value='repuesto'><label class='custom-control-label' for='rv_s2'>📦 Necesito repuesto</label></div>" +
            "<div class='custom-control custom-radio mb-3'><input type='radio' class='custom-control-input' name='rv_sigue' id='rv_s3' value='resuelto'><label class='custom-control-label' for='rv_s3'>✅ Ya está resuelto</label></div>" +
            "<div id='rv_grupo_fecha'><label class='font-weight-bold small mb-1' for='rv_fecha'>Fecha de seguimiento <span class='text-danger'>*</span></label>" +
            "<input type='date' id='rv_fecha' class='form-control' value='" + manana + "' min='" + hoy.toISOString().substring(0, 10) + "'></div>" +
            "</div>";
        Swal.fire({
            title: "Primera revisión" + (numero ? " · " + numero : ""),
            html: html, width: 560, showCancelButton: true, allowOutsideClick: false,
            confirmButtonText: modo === "tomar" ? "Tomar ticket" : "Guardar revisión", cancelButtonText: "Cancelar",
            didOpen: function () {
                $("input[name=rv_sigue]").on("change", function () { $("#rv_grupo_fecha").toggle(this.value !== "resuelto"); });
                $("#rv_diag").focus();
            },
            preConfirm: function () {
                let d = { rev_diagnostico: $.trim($("#rv_diag").val()), rev_prioridad: $("#rv_prio").val(),
                          rev_sigue: $("input[name=rv_sigue]:checked").val() || "", rev_fecha: $("#rv_fecha").val() };
                if (d.rev_diagnostico.length < 10) { Swal.showValidationMessage("Escribí el diagnóstico (al menos 10 caracteres)."); return false; }
                if (!d.rev_prioridad) { Swal.showValidationMessage("Elegí la urgencia."); return false; }
                if (!d.rev_sigue) { Swal.showValidationMessage("Elegí cómo sigue el ticket."); return false; }
                if (d.rev_sigue !== "resuelto" && !d.rev_fecha) { Swal.showValidationMessage("Indicá la fecha de seguimiento."); return false; }
                d.tipo = modo === "tomar" ? "tomarTicket" : "primeraRevision";
                d.idTicket = idTicket;
                return $.post("../controladores/ordenUnificadaControlador.jsp", d).then(function (resp) {
                    let r = $.trim(resp);
                    if (r !== "success") { Swal.showValidationMessage(r.replace(/^error:\s*/, "")); return false; }
                    return d.rev_sigue;
                }, function () { Swal.showValidationMessage("Error de comunicación con el servidor."); return false; });
            }
        }).then(function (res) {
            if (res.isConfirmed && alTerminar) alTerminar(res.value);
            else if (!res.isConfirmed && modo === "revisar") limpiarFormularioProceso();   // sin revisión no se trabaja
        });
    }

    // Después de la revisión: abre el ticket y deja listo el paso que eligió
    function seguirSegunRevision(idTicket, sigue) {
        refrescarBandejas();
        if (window.ctaAvisos) ctaAvisos();
        cargarTicketEnFormulario(idTicket, function () {
            if (sigue === "resuelto") { $("#estado_final").val("Resuelto"); toggleFechaSeguimiento(); $("#comentario_final").focus(); }
            if (sigue === "repuesto") {
                $("html, body").animate({ scrollTop: $("#panelPedidoMaterial").offset().top - 70 }, 300);
                avisar("info", "Agregá los repuestos que necesitás y enviá el pedido al depósito.");
            }
        });
    }

    // Tomar un ticket: primero la revisión; recién al guardarla queda tomado.
    function tomarTicket(idTicket, botonElemento) {
        let numero = botonElemento ? $(botonElemento).closest("tr").find("td:first").text().trim() : "";
        primeraRevision(idTicket, "tomar", numero, function (sigue) { seguirSegunRevision(idTicket, sigue); });
    }

    function continuarTicket(idTicket, numeroTicket) {
        console.log("continuarTicket: " + idTicket);
        cargarTicketEnFormulario(idTicket);
    }

    function agregarAlDetalleJS() {
        let selectMat = $("#id_material option:selected");
        let valMat = $("#id_material").val();
        if (!valMat) {
            alert("Seleccione un artículo válido.");
            return;
        }

        let textoCant = String($("#cantidad_material").val()).trim();
        let cant = Number(textoCant);
        if (!/^\d+$/.test(textoCant) || cant <= 0) {
            alert("Ingrese una cantidad válida (número entero mayor a cero).");
            return;
        }

        let precio = parseFloat($("#precio_material").val());
        if (isNaN(precio) || precio < 0) precio = 0;

        let splitted = valMat.split("-");
        let nombreArticulo = selectMat.text().trim();
        let stock = parseFloat(selectMat.data("stock"));

        // Si el artículo ya está en la lista se suma la cantidad en la misma fila
        let existente = arrayDetalle.find(function (it) { return it.tipo === splitted[0] && String(it.id) === String(splitted[1]); });
        let total = cant + (existente ? existente.cantidad : 0);
        if (!isNaN(stock) && total > stock) {
            alert("Solo tiene " + stock + " en su poder para este ticket y está intentando usar " + total + ". Pida más material al depósito.");
            return;
        }

        if (existente) {
            existente.cantidad = total;
        } else {
            arrayDetalle.push({
                tipo: splitted[0],
                id: splitted[1],
                nombre: nombreArticulo,
                cantidad: cant,
                precio: precio
            });
        }

        $("#cantidad_material").val("1");
        $("#precio_material").val("0");
        $("#id_material").val("");
        dibujarTabla();
    }

    // Redibuja la tabla de materiales creando los nodos por DOM (no por HTML plano)
    // para garantizar que el contenido siempre se vea, sin importar los caracteres
    // que tenga el nombre del artículo, y que el botón "Quitar" siempre funcione.
    // Nota: el precio se sigue enviando internamente (precio_material, oculto) para
    // no perder el costeo interno del stock, pero ya no se muestra en pantalla.
    function dibujarTabla() {
        let tbody = $("#tbodyDetalleJS");
        tbody.empty();

        if (arrayDetalle.length === 0) {
            tbody.html('<tr><td colspan="4" class="text-center text-muted py-3">Ningún material asignado.</td></tr>');
            return;
        }

        arrayDetalle.forEach((item, index) => {
            let esRepuesto = item.tipo === 'R';

            let $badge = $("<span>").addClass(esRepuesto ? "badge badge-primary" : "badge badge-info")
                                     .text(esRepuesto ? "Repuesto" : "Insumo");

            let $btnQuitar = $("<button>").addClass("btn btn-danger btn-xs").attr("type", "button")
                                           .attr("data-index", index).html('<i class="fas fa-times"></i>')
                                           .on("click", function () {
                                               let i = parseInt($(this).attr("data-index"));
                                               arrayDetalle.splice(i, 1);
                                               dibujarTabla();
                                           });

            let $fila = $("<tr>");
            $fila.append($("<td>").append($badge));
            $fila.append($("<td>").text(item.nombre || "(sin nombre)"));
            $fila.append($("<td>").addClass("text-right font-weight-bold").text(item.cantidad));
            $fila.append($("<td>").addClass("text-center").append($btnQuitar));

            tbody.append($fila);
        });
    }

    function procesarYDescontarOrden() {
        let idTicket = $("#id_ticket_procesar").val();
        let prioridad = $("#prioridad_ticket").val();
        let diagnostico = $("#diagnostico").val().trim();
        let comentario = $("#comentario_final").val().trim();
        let estado = $("#estado_final").val();
        let fechaSeguimiento = $("#fecha_seguimiento").val();

        if (!idTicket) {
            alert("Debe seleccionar un ticket usando 'Tomar Ticket' o 'Continuar / Cerrar'.");
            return;
        }
        if (!diagnostico) {
            alert("Debe ingresar un diagnóstico.");
            return;
        }
        if (!comentario && !estadoEsPendiente(estado)) {
            alert("Debe ingresar la observación final / solución para resolver o cerrar el ticket.");
            return;
        }
        let servicios = $(".chk-servicio:checked").map(function () { return this.value; }).get();
        if (!estadoEsPendiente(estado) && servicios.length === 0) {
            alert("Marque al menos un servicio realizado para resolver o cerrar el ticket.");
            return;
        }
        let servicioOtro = ($("#servicioOtroTexto").val() || "").trim();
        if ($(".chk-otros").is(":checked") && servicioOtro.length < 5) {
            alert("Marcó \"Otros\": describa qué se hizo.");
            $("#servicioOtroTexto").removeClass("d-none").focus();
            return;
        }
        var continuarCierre = function () {
        if (estadoEsPendiente(estado) && !fechaSeguimiento) {
            alert("Debe indicar una fecha de seguimiento para dejar el ticket en estado '" + estado + "'.");
            return;
        }

        let params = {
            tipo: "procesarCierre",
            idTicket: idTicket,
            diagnostico: diagnostico,
            comentario: comentario,
            estado: estado,
            prioridad: prioridad,
            fechaSeguimiento: fechaSeguimiento,
            servicios: servicios.join(","),
            servicioOtro: servicioOtro,
            noReparable: !estadoEsPendiente(estado) && $("#chkNoReparable").is(":checked"),
            motivoNoReparable: $("#motivoNoReparable").val(),
            det_count: arrayDetalle.length
        };
        arrayDetalle.forEach((item, i) => {
            params["det_tipo_" + i] = item.tipo;
            params["det_id_" + i] = item.id;
            params["det_cantidad_" + i] = item.cantidad;
            params["det_precio_" + i] = item.precio;
        });

        $.post("../controladores/ordenUnificadaControlador.jsp", params, function (res) {
            if (res.trim().indexOf("success") === 0) {
                let bajaNum = res.trim().split("|")[1];
                let mensaje = estadoEsPendiente(estado)
                        ? "Ticket guardado. Queda '" + estado + "' con seguimiento para el " + fechaSeguimiento + "."
                        : "Ticket procesado correctamente." + (bajaNum ? " El equipo pasó a inactivo (" + bajaNum + ") y el Encargado de depósito lo va a retirar de la sala." : "");
                let evidencias = selectorCierre ? selectorCierre.archivos() : [];
                if (evidencias.length) {
                    selectorCierre.estado("Subiendo evidencias...");
                    CtaAdjuntos.subir(idTicket, "cierre", evidencias).then(function (r) {
                        let extra = r.subidos ? " Se adjunt" + (r.subidos === 1 ? "ó 1 archivo." : "aron " + r.subidos + " archivos.") : "";
                        if (r.errores.length) extra += " No se pudieron adjuntar: " + r.errores.join(" ");
                        alert(mensaje + extra);
                        limpiarFormularioProceso();
                    });
                } else {
                    alert(mensaje);
                    limpiarFormularioProceso();
                }
            } else {
                alert("Error: " + res);
            }
        }).fail(function(xhr, status, error) {
            console.error("Error en procesarCierre:", status, error);
            alert("Error de comunicación con el servidor: " + error);
        });
            };

        continuarCierre();
    }

    function limpiarFormularioProceso() {
                $("#id_ticket_procesar").val("");
                CtaMateriales.limpiar();
                $("#txt_ticket").val("");
                $("#diagnostico").val("");
                $("#comentario_final").val("");
                $("#prioridad_ticket").val("Media");
                $("#estado_final").val("En Proceso");
                $("#chkNoReparable").prop("checked", false); $("#motivoNoReparable").hide();
                toggleFechaSeguimiento();
                arrayDetalle = [];
                dibujarTabla();
                cargarCombosTecnicosMateriales();
                refrescarBandejas();
                mostrarAdjuntos(null);
                if (selectorCierre) selectorCierre.limpiar();
                $("#serviciosCierre").html("<span class='text-muted'>Abra un ticket para marcar los servicios.</span>");
    }

    // Comprobante formal en PDF (JasperReports, con membrete)
    function imprimirTicket(idTicket) {
        window.open("../controladores/ordenUnificadaControlador.jsp?tipo=comprobantePdf&idTicket=" + idTicket, "_blank");
    }
</script>