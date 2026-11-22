<%@page isELIgnored="true"%>
<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <h1 class="font-weight-bold text-primary"><i class="fas fa-warehouse"></i> Inventario</h1>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <ul class="nav nav-pills mb-3">
                <li class="nav-item"><a class="nav-link" href="inventarioVista.jsp"><i class="fas fa-boxes"></i> Consulta</a></li>
                <li class="nav-item"><a class="nav-link active" href="tomaInventarioVista.jsp"><i class="fas fa-sliders-h"></i> Ajustar stock</a></li>
            </ul>
            <div class="row">
                <div class="col-md-4">
                    <div class="card card-info card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold"><i class="fas fa-file-alt"></i> Datos del Ajuste</h3>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label for="fechaAjuste" class="text-secondary font-weight-bold">Fecha</label>
                                <input type="text" id="fechaAjuste" class="form-control bg-light" readonly>
                            </div>
                            <div class="form-group mb-0">
                                <label for="motivoAjuste" class="text-secondary font-weight-bold">Motivo</label>
                                <input type="text" id="motivoAjuste" class="form-control" maxlength="255" placeholder="Ej.: conteo de fin de mes, se encontró roto">
                            </div>
                        </div>
                    </div>
                </div>

                <div class="col-md-8">
                    <div class="card card-secondary card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-secondary font-weight-bold"><i class="fas fa-boxes"></i> Artículos a Corregir</h3>
                        </div>
                        <div class="card-body">
                            <div class="row bg-light p-3 mb-3 rounded border">
                                <div class="col-md-6 form-group">
                                    <label for="selArticulo" class="small font-weight-bold">Artículo</label>
                                    <select id="selArticulo" class="form-control" onchange="mostrarSistema()"></select>
                                </div>
                                <div class="col-md-3 form-group">
                                    <label for="txtSistema" class="small font-weight-bold">Según el sistema</label>
                                    <input type="text" id="txtSistema" class="form-control bg-light" readonly>
                                </div>
                                <div class="col-md-3 form-group">
                                    <label for="txtReal" class="small font-weight-bold">Cantidad real</label>
                                    <input type="number" id="txtReal" class="form-control" min="0" step="any">
                                </div>
                                <div class="col-md-12">
                                    <button type="button" class="btn btn-info btn-block font-weight-bold" onclick="agregarLinea()"><i class="fas fa-plus"></i> Agregar</button>
                                </div>
                            </div>
                            <table class="table table-bordered table-sm m-0 text-sm">
                                <thead class="bg-secondary text-white text-xs">
                                    <tr><th>Artículo</th><th width="110px" class="text-right">Según sistema</th><th width="110px" class="text-right">Cantidad real</th><th width="100px" class="text-right">Diferencia</th><th width="60px" class="text-center">Quitar</th></tr>
                                </thead>
                                <tbody id="tbodyAjuste"><tr><td colspan="5" class="text-center text-muted py-3">Ningún artículo agregado.</td></tr></tbody>
                            </table>
                        </div>
                        <div class="card-footer bg-white border-top">
                            <button type="button" id="btnRegistrar" class="btn btn-success float-right font-weight-bold shadow" onclick="registrarAjuste()">
                                <i class="fas fa-check-circle"></i> REGISTRAR AJUSTE
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card card-success card-outline shadow mt-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-success font-weight-bold"><i class="fas fa-history"></i> Historial de Ajustes</h3>
                    <div class="card-tools">
                        <input type="text" class="form-control form-control-sm" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaAjustes')" style="width:220px;">
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light"><tr><th>N°</th><th>Fecha</th><th class="text-center">Resultado</th><th>Registró</th><th>Motivo</th><th class="text-center">Imprimir</th></tr></thead>
                            <tbody id="tablaAjustes"></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    const CTRL_TI = "../controladores/tomaInventarioControlador.jsp";
    let articulos = [], lineas = [];

    $(document).ready(function () {
        $("#fechaAjuste").val(new Date().toLocaleDateString("es-PY"));
        cargarArticulos();
        listar();
    });

    function esc(t) { return $("<div>").text(t == null ? "" : String(t)).html(); }
    function num(v) { v = (v || "").toString().replace(",", "."); let n = parseFloat(v); return isNaN(n) ? null : n; }
    function fmt(n) { return (Math.round(n * 100) / 100).toString().replace(".", ","); }

    function cargarArticulos() {
        $.post(CTRL_TI, { tipo: "planilla", tipoToma: "ARTICULOS" }, function (r) {
            articulos = r.filas;
            let h = "<option value=''>-- Seleccione --</option><optgroup label='Repuestos'>", grupo = "R";
            articulos.forEach(function (a, i) {
                if (a.tipo !== grupo) { h += "</optgroup><optgroup label='Insumos'>"; grupo = a.tipo; }
                h += "<option value='" + i + "'>" + esc(a.nombre) + "</option>";
            });
            $("#selArticulo").html(h + "</optgroup>");
            // Viene desde Inventario con un artículo elegido
            let pre = new URLSearchParams(location.search).get("art");
            if (pre && !lineas.length) {
                let idx = articulos.findIndex(function (a) { return a.tipo + "-" + a.id === pre; });
                if (idx >= 0) { $("#selArticulo").val(idx); mostrarSistema(); $("#txtReal").focus(); return; }
            }
            mostrarSistema();
        }, "json");
    }

    function mostrarSistema() {
        let i = $("#selArticulo").val();
        $("#txtSistema").val(i === "" ? "" : articulos[i].sistema);
        $("#txtReal").val("");
    }

    function agregarLinea() {
        let i = $("#selArticulo").val(), real = num($("#txtReal").val());
        if (i === "") { alert("Seleccione un artículo."); return; }
        if (real === null || real < 0) { alert("Cargue la cantidad real (0 o más)."); return; }
        let a = articulos[i];
        lineas = lineas.filter(function (l) { return !(l.tipo === a.tipo && l.id === a.id); });
        lineas.push({ tipo: a.tipo, id: a.id, nombre: a.nombre, sistema: num(a.sistema), real: real });
        $("#selArticulo").val(""); mostrarSistema();
        dibujar();
    }

    function quitar(i) { lineas.splice(i, 1); dibujar(); }

    function dibujar() {
        if (!lineas.length) { $("#tbodyAjuste").html("<tr><td colspan='5' class='text-center text-muted py-3'>Ningún artículo agregado.</td></tr>"); return; }
        let h = "";
        lineas.forEach(function (l, i) {
            let d = l.real - l.sistema;
            h += "<tr class='" + (d < 0 ? "table-danger" : (d > 0 ? "table-info" : "")) + "'><td>" + esc(l.nombre) + "</td><td class='text-right'>" + fmt(l.sistema) + "</td><td class='text-right'>" + fmt(l.real)
               + "</td><td class='text-right font-weight-bold'>" + (d > 0 ? "+" : "") + fmt(d) + "</td><td class='text-center'><button type='button' class='btn btn-outline-danger btn-xs' aria-label='Quitar' onclick='quitar(" + i + ")'><i class='fas fa-times'></i></button></td></tr>";
        });
        $("#tbodyAjuste").html(h);
    }

    function listar() { $.post(CTRL_TI, { tipo: "listar" }, function (d) { $("#tablaAjustes").html(d); }); }

    function registrarAjuste() {
        let motivo = $("#motivoAjuste").val().trim();
        if (motivo.length < 5) { alert("Escribí el motivo del ajuste."); $("#motivoAjuste").focus(); return; }
        if (!lineas.length) { alert("Agregá al menos un artículo con su cantidad real."); return; }
        let datos = { tipoToma: "ARTICULOS", observacion: motivo, articulos: lineas.map(function (l) { return { tipo: l.tipo, id: l.id, contada: l.real }; }) };
        confirmar("¿Registrar el ajuste? El stock de los artículos quedará en la cantidad real.", function () {
            $("#btnRegistrar").prop("disabled", true);
            $.post(CTRL_TI, { tipo: "registrar", datos: JSON.stringify(datos) }, function (res) {
                $("#btnRegistrar").prop("disabled", false);
                res = res.trim();
                if (res.indexOf("success") === 0) {
                    avisar("success", "Ajuste registrado.");
                    lineas = []; dibujar(); $("#motivoAjuste").val("");
                    cargarArticulos(); listar();
                } else alert(res);
            }).fail(function () { $("#btnRegistrar").prop("disabled", false); });
        }, { si: "Sí, registrar", title: "Registrar ajuste" });
    }
</script>
