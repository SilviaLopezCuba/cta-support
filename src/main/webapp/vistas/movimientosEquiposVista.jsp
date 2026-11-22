<%@page isELIgnored="true"%>
<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <h1 class="font-weight-bold text-primary"><i class="fas fa-exchange-alt"></i> Movimientos de Equipos</h1>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <div class="row">
                <div class="col-md-4">
                    <div class="card card-info card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold"><i class="fas fa-file-alt"></i> Datos del Movimiento</h3>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label for="movTipo" class="text-secondary font-weight-bold">Movimiento</label>
                                <select id="movTipo" class="form-control" onchange="cambiarMovimiento()">
                                    <option value="ASIGNACION">Asignar del Depósito a una sala</option>
                                    <option value="RETIRO">Devolver de una sala al Depósito</option>
                                    <option value="BAJA">Dar de baja (pasar a inactivo)</option>
                                    <option value="REACTIVACION">Reactivar equipos reparados</option>
                                </select>
                            </div>
                            <div class="form-group" id="grupoSala">
                                <label for="movSala" class="text-secondary font-weight-bold" id="lblSala">Sala</label>
                                <select id="movSala" class="form-control" onchange="cargarEquipos()"></select>
                            </div>
                            <div class="form-group" id="grupoMotivo">
                                <label for="movMotivo" class="text-secondary font-weight-bold">Motivo</label>
                                <select id="movMotivo" class="form-control"></select>
                            </div>
                            <div class="form-group">
                                <label for="movFecha" class="text-secondary font-weight-bold">Fecha</label>
                                <input type="date" id="movFecha" class="form-control">
                            </div>
                            <div class="form-group mb-0">
                                <label for="movObs" class="text-secondary font-weight-bold">Observación</label>
                                <input type="text" id="movObs" class="form-control" maxlength="255">
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-8">
                    <div class="card card-secondary card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-secondary font-weight-bold"><i class="fas fa-desktop"></i> Equipos</h3>
                        </div>
                        <div class="card-body">
                            <div class="row bg-light p-3 mb-3 rounded border">
                                <div class="col-md-8 form-group">
                                    <label for="selEquipo" class="small font-weight-bold">Equipo</label>
                                    <select id="selEquipo" class="form-control"></select>
                                </div>
                                <div class="col-md-4 form-group" id="grupoCodigo">
                                    <label for="txtCodigo" class="small font-weight-bold">Código patrimonial</label>
                                    <input type="text" id="txtCodigo" class="form-control" maxlength="50">
                                </div>
                                <div class="col-md-12">
                                    <button type="button" class="btn btn-info btn-block font-weight-bold" onclick="agregarEquipo()"><i class="fas fa-plus"></i> Agregar</button>
                                </div>
                            </div>
                            <table class="table table-bordered table-sm m-0 text-sm">
                                <thead class="bg-secondary text-white text-xs">
                                    <tr><th>Equipo</th><th id="thExtra">Código patrimonial</th><th width="60px" class="text-center">Quitar</th></tr>
                                </thead>
                                <tbody id="tbodyEquipos"><tr><td colspan="3" class="text-center text-muted py-3">Ningún equipo agregado.</td></tr></tbody>
                            </table>
                        </div>
                        <div class="card-footer bg-white border-top">
                            <button type="button" id="btnRegistrar" class="btn btn-success float-right font-weight-bold shadow" onclick="registrar()"><i class="fas fa-check-circle"></i> REGISTRAR</button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card card-success card-outline shadow mt-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-success font-weight-bold"><i class="fas fa-history"></i> Historial</h3>
                    <div class="card-tools">
                        <input type="text" class="form-control form-control-sm" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaHistorial')" style="width:220px;">
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light"><tr><th>N°</th><th>Fecha</th><th>Movimiento</th><th>Destino / Motivo</th><th>Equipos</th><th>Registró</th><th>Observación</th></tr></thead>
                            <tbody id="tablaHistorial"></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    const CTRL_ME = "../controladores/movimientosEquiposControlador.jsp";
    let disponibles = [], elegidos = [];

    $(document).ready(function () {
        let d = new Date();
        $("#movFecha").val(new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().substring(0, 10));
        $.post(CTRL_ME, { tipo: "combos" }, function (c) {
            $("#movSala").html(c.salas);
            $("#movMotivo").html(c.motivos);
            cambiarMovimiento();
        }, "json");
        listar();
    });

    function esc(t) { return $("<div>").text(t == null ? "" : String(t)).html(); }
    function mov() { return $("#movTipo").val(); }

    function cambiarMovimiento() {
        let m = mov();
        $("#grupoSala").toggle(m !== "REACTIVACION");
        $("#lblSala").text(m === "ASIGNACION" ? "Sala de destino" : (m === "RETIRO" ? "Sala de donde se retiran" : "Sala (opcional, para filtrar)"));
        $("#movSala option:first").text(m === "BAJA" ? "-- Todas las salas y el Depósito --" : "-- Seleccione la sala --");
        $("#grupoMotivo").toggle(m === "BAJA");
        $("#grupoCodigo").toggle(m === "ASIGNACION");
        $("#thExtra").text(m === "ASIGNACION" ? "Código patrimonial" : "Ubicación actual");
        $("#movObs").attr("placeholder", m === "BAJA" ? "Qué pasó (obligatorio). Si fue robo, N° de denuncia" : "Opcional");
        elegidos = [];
        dibujar();
        cargarEquipos();
    }

    function cargarEquipos() {
        let m = mov(), sala = $("#movSala").val();
        if (m === "RETIRO" && !sala) { disponibles = []; llenarCombo(); return; }
        $.post(CTRL_ME, { tipo: "equipos", movimiento: m, idSala: m === "ASIGNACION" ? "" : sala }, function (arr) {
            disponibles = arr;
            llenarCombo();
        }, "json");
    }

    function llenarCombo() {
        let h = "<option value=''>" + (disponibles.length ? "-- Seleccione un equipo --" : "-- No hay equipos para este movimiento --") + "</option>";
        disponibles.forEach(function (e) {
            if (elegidos.some(function (x) { return x.id === e.id; })) return;
            h += "<option value='" + e.id + "'>" + esc(e.descripcion) + (mov() === "BAJA" ? " — " + esc(e.ubicacion) : "") + (e.motivo ? " — " + esc(e.motivo) : "") + "</option>";
        });
        $("#selEquipo").html(h);
        $("#txtCodigo").val("");
    }

    function agregarEquipo() {
        let id = parseInt($("#selEquipo").val(), 10);
        if (!id) { alert("Seleccione un equipo."); return; }
        let e = disponibles.find(function (x) { return x.id === id; });
        let cod = $("#txtCodigo").val().trim();
        if (mov() === "ASIGNACION" && !cod) { alert("Cargá el código patrimonial del equipo."); $("#txtCodigo").focus(); return; }
        if (mov() === "ASIGNACION" && elegidos.some(function (x) { return x.codigo.toLowerCase() === cod.toLowerCase(); })) { alert("Ese código ya está en la lista."); return; }
        elegidos.push({ id: id, descripcion: e.descripcion, codigo: cod, ubicacion: e.ubicacion });
        dibujar();
        llenarCombo();
    }

    function quitar(i) { elegidos.splice(i, 1); dibujar(); llenarCombo(); }

    function dibujar() {
        if (!elegidos.length) { $("#tbodyEquipos").html("<tr><td colspan='3' class='text-center text-muted py-3'>Ningún equipo agregado.</td></tr>"); return; }
        let h = "";
        elegidos.forEach(function (e, i) {
            h += "<tr><td>" + esc(e.descripcion) + "</td><td>" + esc(mov() === "ASIGNACION" ? e.codigo : e.ubicacion) + "</td>"
               + "<td class='text-center'><button type='button' class='btn btn-outline-danger btn-xs' aria-label='Quitar' onclick='quitar(" + i + ")'><i class='fas fa-times'></i></button></td></tr>";
        });
        $("#tbodyEquipos").html(h);
    }

    function listar() { $.post(CTRL_ME, { tipo: "listar" }, function (d) { $("#tablaHistorial").html(d); }); }

    function registrar() {
        let m = mov();
        if (m === "ASIGNACION" && !$("#movSala").val()) { alert("Elija la sala de destino."); return; }
        if (m === "BAJA" && !$("#movMotivo").val()) { alert("Elija el motivo de la baja."); return; }
        if (m === "BAJA" && $("#movObs").val().trim().length < 5) { alert("Escribí qué pasó en la observación."); return; }
        if (!elegidos.length) { alert("Agregue al menos un equipo."); return; }
        let datos = { movimiento: m, idSalaDestino: $("#movSala").val(), idMotivo: $("#movMotivo").val(), fecha: $("#movFecha").val(), observacion: $("#movObs").val(),
                      equipos: elegidos.map(function (e) { return { id: e.id, codigo: e.codigo }; }) };
        let texto = m === "BAJA" ? "¿Dar de baja " + elegidos.length + " equipo(s) por \"" + $("#movMotivo option:selected").text() + "\"?"
                  : "¿Registrar el movimiento de " + elegidos.length + " equipo(s)?";
        confirmar(texto, function () {
            $("#btnRegistrar").prop("disabled", true);
            $.post(CTRL_ME, { tipo: "registrar", datos: JSON.stringify(datos) }, function (res) {
                $("#btnRegistrar").prop("disabled", false);
                res = res.trim();
                if (res.indexOf("success") === 0) {
                    avisar("success", "Movimiento " + res.split("|")[1] + " registrado.");
                    $("#movObs").val("");
                    elegidos = [];
                    dibujar();
                    cargarEquipos();
                    listar();
                } else alert(res);
            }).fail(function () { $("#btnRegistrar").prop("disabled", false); });
        }, { si: "Sí, registrar", title: "Confirmar", peligro: m === "BAJA" });
    }
</script>
