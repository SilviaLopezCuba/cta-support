<%@page isELIgnored="true"%>
<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-8">
                    <h1 class="font-weight-bold text-primary"><i class="fas fa-hand-holding"></i> Material para Técnicos</h1>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <ul class="nav nav-pills mb-3" role="tablist">
                <li class="nav-item"><a class="nav-link active" data-toggle="pill" href="#tabEntrega" role="tab"><i class="fas fa-hand-holding"></i> Entrega <span class="badge badge-warning" id="cantPendientes"></span></a></li>
                <li class="nav-item"><a class="nav-link" data-toggle="pill" href="#tabDevolucion" role="tab" onclick="cargarOrdenesDevolucion(); listarHistorialDev();"><i class="fas fa-undo"></i> Devolución</a></li>
            </ul>

            <div class="tab-content">
                <!-- ======================= ENTREGA ======================= -->
                <div class="tab-pane fade show active" id="tabEntrega" role="tabpanel">
                    <div class="row">
                        <div class="col-md-4">
                            <div class="card card-info card-outline shadow">
                                <div class="card-header bg-white">
                                    <h3 class="card-title text-info font-weight-bold"><i class="fas fa-file-alt"></i> Datos del Pedido</h3>
                                </div>
                                <div class="card-body">
                                    <div class="form-group">
                                        <label for="selPedido" class="text-secondary font-weight-bold">Pedido pendiente</label>
                                        <select id="selPedido" class="form-control" onchange="cargarPedido()"></select>
                                    </div>
                                    <div class="form-group">
                                        <label for="pedFecha" class="text-secondary font-weight-bold">Fecha del pedido</label>
                                        <input type="text" id="pedFecha" class="form-control bg-light" readonly>
                                    </div>
                                    <div class="form-group">
                                        <label for="pedOrden" class="text-secondary font-weight-bold">Orden</label>
                                        <input type="text" id="pedOrden" class="form-control bg-light" readonly>
                                    </div>
                                    <div class="form-group">
                                        <label for="pedTecnico" class="text-secondary font-weight-bold">Técnico</label>
                                        <input type="text" id="pedTecnico" class="form-control bg-light" readonly>
                                    </div>
                                    <div class="form-group">
                                        <label for="pedObs" class="text-secondary font-weight-bold">Observación del técnico</label>
                                        <input type="text" id="pedObs" class="form-control bg-light" readonly>
                                    </div>
                                    <div class="form-group mb-0">
                                        <label for="pedComentario" class="text-secondary font-weight-bold">Comentario de la entrega</label>
                                        <input type="text" id="pedComentario" class="form-control" maxlength="255" placeholder="Obligatorio si entregás menos de lo pedido">
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-8">
                            <div class="card card-secondary card-outline shadow">
                                <div class="card-header bg-white">
                                    <h3 class="card-title text-secondary font-weight-bold"><i class="fas fa-boxes"></i> Artículos del Pedido</h3>
                                </div>
                                <div class="card-body">
                                    <table class="table table-bordered table-sm m-0 text-sm">
                                        <thead class="bg-secondary text-white text-xs">
                                            <tr><th>Artículo</th><th width="100px" class="text-right">Pedido</th><th width="110px" class="text-right">En depósito</th><th width="140px">A entregar</th></tr>
                                        </thead>
                                        <tbody id="detalleEntrega">
                                            <tr><td colspan="4" class="text-center text-muted py-3">Seleccione un pedido.</td></tr>
                                        </tbody>
                                    </table>
                                </div>
                                <div class="card-footer bg-white border-top">
                                    <button type="button" class="btn btn-outline-danger" id="btnSinStock" onclick="dejarEnEspera()" disabled title="No se rechaza: queda esperando la próxima entrada y el técnico lo ve"><i class="fas fa-hourglass-half"></i> Sin stock: dejar en espera</button>
                                    <button type="button" class="btn btn-outline-secondary" id="btnRechazar" onclick="rechazar()" disabled><i class="fas fa-ban"></i> Rechazar (otro motivo)</button>
                                    <button type="button" class="btn btn-success float-right font-weight-bold shadow" id="btnEntregar" onclick="registrarEntrega()" disabled><i class="fas fa-check-circle"></i> REGISTRAR ENTREGA</button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="card card-success card-outline shadow mt-4">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-success font-weight-bold"><i class="fas fa-history"></i> Historial de Entregas</h3>
                            <div class="card-tools">
                                <input type="text" class="form-control form-control-sm" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaHistorial')" style="width:220px;">
                            </div>
                        </div>
                        <div class="card-body p-0">
                            <div class="table-responsive">
                                <table class="table table-hover table-striped m-0 text-sm">
                                    <thead class="bg-light"><tr><th>N°</th><th>Orden</th><th>Técnico</th><th>Entregó</th><th>Estado</th><th class="text-center">Imprimir</th></tr></thead>
                                    <tbody id="tablaHistorial"></tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- ======================= DEVOLUCIÓN ======================= -->
                <div class="tab-pane fade" id="tabDevolucion" role="tabpanel">
                    <div class="row">
                        <div class="col-md-4">
                            <div class="card card-info card-outline shadow">
                                <div class="card-header bg-white">
                                    <h3 class="card-title text-info font-weight-bold"><i class="fas fa-file-alt"></i> Datos de la Devolución</h3>
                                </div>
                                <div class="card-body">
                                    <div class="form-group">
                                        <label for="selOrdenDev" class="text-secondary font-weight-bold">Orden</label>
                                        <select id="selOrdenDev" class="form-control" onchange="cargarOrdenDev()"></select>
                                    </div>
                                    <div class="form-group">
                                        <label for="devTecnico" class="text-secondary font-weight-bold">Técnico que devuelve</label>
                                        <input type="text" id="devTecnico" class="form-control bg-light" readonly>
                                    </div>
                                    <div class="form-group mb-0">
                                        <label for="devObs" class="text-secondary font-weight-bold">Observación</label>
                                        <input type="text" id="devObs" class="form-control" maxlength="255" placeholder="Opcional">
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-8">
                            <div class="card card-secondary card-outline shadow">
                                <div class="card-header bg-white">
                                    <h3 class="card-title text-secondary font-weight-bold"><i class="fas fa-boxes"></i> Artículos a Devolver</h3>
                                </div>
                                <div class="card-body">
                                    <table class="table table-bordered table-sm m-0 text-sm">
                                        <thead class="bg-secondary text-white text-xs">
                                            <tr><th>Artículo</th><th width="120px" class="text-right">Tiene el técnico</th><th width="130px">A devolver</th><th width="130px">Estado</th></tr>
                                        </thead>
                                        <tbody id="detalleDevolucion">
                                            <tr><td colspan="4" class="text-center text-muted py-3">Seleccione una orden.</td></tr>
                                        </tbody>
                                    </table>
                                </div>
                                <div class="card-footer bg-white border-top">
                                    <button type="button" class="btn btn-success float-right font-weight-bold shadow" id="btnDevolver" onclick="registrarDevolucion()" disabled><i class="fas fa-check-circle"></i> REGISTRAR DEVOLUCIÓN</button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="card card-success card-outline shadow mt-4">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-success font-weight-bold"><i class="fas fa-history"></i> Historial de Devoluciones</h3>
                            <div class="card-tools">
                                <input type="text" class="form-control form-control-sm" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaHistorialDev')" style="width:220px;">
                            </div>
                        </div>
                        <div class="card-body p-0">
                            <div class="table-responsive">
                                <table class="table table-hover table-striped m-0 text-sm">
                                    <thead class="bg-light"><tr><th>N°</th><th>Fecha</th><th>Orden</th><th>Técnico</th><th>Artículos</th><th>Recibió</th></tr></thead>
                                    <tbody id="tablaHistorialDev"></tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    const CTRL_MAT = "../controladores/materialesControlador.jsp";
    let devItems = [];

    $(document).ready(function () {
        cargarPedidos();
        listarHistorial();
    });

    function esc(t) { return $("<div>").text(t == null ? "" : String(t)).html(); }

    // ---------------- ENTREGA ----------------
    function cargarPedidos() {
        $.post(CTRL_MAT, { tipo: "comboPendientes" }, function (d) {
            $("#selPedido").html(d);
            let n = $("#selPedido option").length - 1;
            $("#cantPendientes").text(n > 0 ? n : "");
            cargarPedido();
        });
    }

    function cargarPedido() {
        let op = $("#selPedido option:selected"), id = $("#selPedido").val();
        $("#pedFecha").val(id ? op.data("fecha") : "");
        $("#pedOrden").val(id ? op.data("orden") : "");
        $("#pedTecnico").val(id ? op.data("tecnico") : "");
        $("#pedObs").val(id ? op.data("obs") : "");
        $("#btnEntregar, #btnRechazar, #btnSinStock").prop("disabled", !id);
        // Un pedido que ya está en espera no se vuelve a "dejar en espera"
        if (id && op.data("estado") === "espera") $("#btnSinStock").prop("disabled", true);
        $("#pedComentario").val("");
        if (!id) { $("#detalleEntrega").html("<tr><td colspan='4' class='text-center text-muted py-3'>Seleccione un pedido.</td></tr>"); return; }
        $.post(CTRL_MAT, { tipo: "detalleSolicitud", id_solicitud: id }, function (r) {
            let h = "";
            r.lineas.forEach(function (l) {
                h += "<tr" + (l.falta ? " class='table-warning' title='No hay stock suficiente'" : "") + "><td>" + esc(l.nombre) + (l.falta ? " <span class='badge badge-warning'>Stock insuficiente</span>" : "") + "</td><td class='text-right'>" + esc(l.solicitada) + "</td><td class='text-right'>" + esc(l.stock) + "</td>"
                   + "<td><input type='number' min='0' step='any' class='form-control form-control-sm cant-entrega' data-id='" + l.id_detalle + "' value='"
                   + String(l.sugerida).replace(",", ".") + "' aria-label='Cantidad a entregar de " + esc(l.nombre) + "'></td></tr>";
            });
            $("#detalleEntrega").html(h);
        }, "json");
    }

    function listarHistorial() { $.post(CTRL_MAT, { tipo: "historial" }, function (d) { $("#tablaHistorial").html(d); }); }

    function registrarEntrega() {
        let id = $("#selPedido").val();
        if (!id) return;
        let cantidades = {};
        $(".cant-entrega").each(function () { cantidades[$(this).data("id")] = $(this).val() || "0"; });
        $("#btnEntregar").prop("disabled", true);
        $.post(CTRL_MAT, { tipo: "entregar", id_solicitud: id, cantidades: JSON.stringify(cantidades), comentario: $("#pedComentario").val() }, function (res) {
            res = res.trim();
            if (res === "success") {
                avisar("success", "Entrega registrada.");
                if (window.ctaAvisos) ctaAvisos();
                cargarPedidos();
                listarHistorial();
            } else { $("#btnEntregar").prop("disabled", false); alert(res); }
        }).fail(function () { $("#btnEntregar").prop("disabled", false); });
    }

    function dejarEnEspera() {
        let id = $("#selPedido").val();
        if (!id) return;
        confirmar("El pedido queda en espera hasta que entre stock. El técnico lo verá como \"En espera de stock\" (si indicó que no puede seguir sin el material, el ticket pasa a Esperando Repuesto). Cuando registres una entrada, el pedido va a aparecer arriba como YA HAY STOCK.", function () {
            $.post(CTRL_MAT, { tipo: "enEspera", id_solicitud: id, comentario: $("#pedComentario").val().trim() }, function (res) {
                if (res.trim() === "success") { avisar("success", "Pedido en espera de stock."); cargarPedidos(); listarHistorial(); if (window.ctaAvisos) ctaAvisos(); } else alert(res.trim());
            });
        }, { si: "Sí, dejar en espera", title: "Sin stock" });
    }

    function rechazar() {
        let id = $("#selPedido").val();
        if (!id) return;
        Swal.fire({
            title: "Rechazar pedido", input: "textarea", inputLabel: "Motivo",
            inputPlaceholder: "Ej.: sin stock, se pidió reposición.", showCancelButton: true,
            confirmButtonText: "Rechazar", cancelButtonText: "Cancelar",
            inputValidator: function (v) { return (!v || v.trim().length < 5) ? "Escriba al menos 5 caracteres" : null; }
        }).then(function (r) {
            if (!r.isConfirmed) return;
            $.post(CTRL_MAT, { tipo: "rechazar", id_solicitud: id, motivo: r.value }, function (res) {
                if (res.trim() === "success") { cargarPedidos(); listarHistorial(); } else alert(res.trim());
            });
        });
    }

    // ---------------- DEVOLUCIÓN ----------------
    function cargarOrdenesDevolucion() {
        $.post(CTRL_MAT, { tipo: "comboOrdenesConMaterial" }, function (d) { $("#selOrdenDev").html(d); cargarOrdenDev(); });
    }

    function cargarOrdenDev() {
        let v = $("#selOrdenDev").val();
        $("#devTecnico").val(v ? $("#selOrdenDev option:selected").data("tecnico") : "");
        $("#btnDevolver").prop("disabled", !v);
        devItems = [];
        if (!v) { $("#detalleDevolucion").html("<tr><td colspan='4' class='text-center text-muted py-3'>Seleccione una orden.</td></tr>"); return; }
        let p = v.split("-");
        $.post(CTRL_MAT, { tipo: "saldo", tipo_orden: p[0], id_orden: p[1] }, function (r) {
            if (!r.ok) { alert(r.error); return; }
            devItems = r.items.filter(function (it) { return it.saldo_num > 0; });
            let h = "";
            devItems.forEach(function (it, i) {
                h += "<tr><td>" + esc(it.nombre) + "</td><td class='text-right'>" + esc(it.saldo) + "</td>"
                   + "<td><input type='number' min='0' step='any' class='form-control form-control-sm dev-cant' data-i='" + i + "' value='" + String(it.saldo).replace(",", ".") + "' aria-label='Cantidad a devolver de " + esc(it.nombre) + "'></td>"
                   + "<td><select class='form-control form-control-sm dev-cond' data-i='" + i + "' aria-label='Estado'><option>Bueno</option><option>Dañado</option></select></td></tr>";
            });
            $("#detalleDevolucion").html(h || "<tr><td colspan='4' class='text-center text-muted py-3'>El técnico no tiene material de esta orden.</td></tr>");
        }, "json");
    }

    function listarHistorialDev() { $.post(CTRL_MAT, { tipo: "historialDevoluciones" }, function (d) { $("#tablaHistorialDev").html(d); }); }

    function registrarDevolucion() {
        let v = $("#selOrdenDev").val();
        if (!v) return;
        let p = v.split("-");
        let items = [];
        $(".dev-cant").each(function () {
            let i = $(this).data("i");
            items.push({ articulo: devItems[i].articulo, cantidad: $(this).val() || "0", condicion: $(".dev-cond[data-i='" + i + "']").val() });
        });
        $("#btnDevolver").prop("disabled", true);
        $.post(CTRL_MAT, { tipo: "registrarDevolucion", datos: JSON.stringify({ tipo_orden: p[0], id_orden: p[1], observacion: $("#devObs").val(), items: items }) }, function (res) {
            res = res.trim();
            if (res.indexOf("success") === 0) {
                avisar("success", "Devolución registrada.");
                $("#devObs").val("");
                cargarOrdenesDevolucion();
                listarHistorialDev();
            } else { $("#btnDevolver").prop("disabled", false); alert(res); }
        }).fail(function () { $("#btnDevolver").prop("disabled", false); });
    }

    // Devoluciones antiguas que quedaron pendientes
    function recibirDevolucion(id, numero) {
        confirmar("¿Recibir la devolución " + numero + "?", function () {
            $.post(CTRL_MAT, { tipo: "recibirDevolucion", id_devolucion: id }, function (res) {
                if (res.trim() === "success") { listarHistorialDev(); cargarOrdenesDevolucion(); avisar("success", "Devolución recibida."); }
                else alert(res.trim());
            });
        }, { si: "Sí, recibir", title: "Recibir devolución" });
    }
</script>
