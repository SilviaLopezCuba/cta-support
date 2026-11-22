<%@page isELIgnored="true"%>
<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-7"><h1 class="font-weight-bold text-primary"><i class="fas fa-warehouse"></i> Inventario</h1></div>
                <div class="col-sm-5">
                    <button class="btn btn-outline-success float-right shadow" onclick="window.open('../controladores/equiposControlador.jsp?accion=ReportePatrimonio', '_blank')">
                        <i class="fas fa-coins" aria-hidden="true"></i> Patrimonio (PDF)
                    </button>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <ul class="nav nav-pills mb-3">
                <li class="nav-item"><a class="nav-link active" href="inventarioVista.jsp"><i class="fas fa-boxes"></i> Consulta</a></li>
                <li class="nav-item"><a class="nav-link" href="tomaInventarioVista.jsp"><i class="fas fa-sliders-h"></i> Ajustar stock</a></li>
            </ul>
            <div class="card card-primary card-outline card-outline-tabs shadow">
                <div class="card-header p-0 border-bottom-0">
                    <ul class="nav nav-tabs" role="tablist">
                        <li class="nav-item"><a class="nav-link active" data-toggle="pill" href="#tabResumen" role="tab" onclick="cargarResumen()"><i class="fas fa-chart-pie"></i> Resumen</a></li>
                        <li class="nav-item"><a class="nav-link" data-toggle="pill" href="#tabArticulos" role="tab" onclick="listarExistencias()"><i class="fas fa-boxes"></i> Repuestos e insumos</a></li>
                        <li class="nav-item"><a class="nav-link" data-toggle="pill" href="#tabFicha" role="tab"><i class="fas fa-list"></i> Ficha del artículo</a></li>
                        <li class="nav-item"><a class="nav-link" data-toggle="pill" href="#tabEquipos" role="tab" onclick="listarEquipos()"><i class="fas fa-desktop"></i> Equipos por ubicación</a></li>
                        <li class="nav-item"><a class="nav-link" data-toggle="pill" href="#tabInactivos" role="tab" onclick="listarInactivos()"><i class="fas fa-power-off"></i> Equipos inactivos</a></li>
                        <li class="nav-item"><a class="nav-link" data-toggle="pill" href="#tabRetirar" role="tab" onclick="listarPorRetirar()"><i class="fas fa-people-carry"></i> Por retirar de salas <span class="badge badge-danger" id="cantRetirar"></span></a></li>
                    </ul>
                </div>
                <div class="card-body">
                    <div class="tab-content">
                        <!-- RESUMEN -->
                        <div class="tab-pane fade show active" id="tabResumen" role="tabpanel">
                            <div class="row">
                                <div class="col-lg-3 col-6"><div class="small-box bg-success"><div class="inner"><h4 id="rValor">-</h4><p>Valor actual del patrimonio (Gs.)</p></div><div class="icon"><i class="fas fa-coins"></i></div></div></div>
                                <div class="col-lg-3 col-6"><div class="small-box bg-info"><div class="inner"><h4 id="rUso">-</h4><p>Equipos en uso en salas</p></div><div class="icon"><i class="fas fa-desktop"></i></div></div></div>
                                <div class="col-lg-3 col-6"><div class="small-box bg-secondary"><div class="inner"><h4 id="rDeposito">-</h4><p>Equipos en el Depósito</p></div><div class="icon"><i class="fas fa-warehouse"></i></div></div></div>
                                <div class="col-lg-3 col-6"><div class="small-box bg-dark"><div class="inner"><h4 id="rInactivos">-</h4><p>Equipos inactivos</p></div><div class="icon"><i class="fas fa-power-off"></i></div></div></div>
                                <div class="col-lg-3 col-6"><div class="small-box bg-danger"><div class="inner"><h4 id="rBajo">-</h4><p>Artículos bajo el mínimo</p></div><div class="icon"><i class="fas fa-exclamation-triangle"></i></div></div></div>
                                <div class="col-lg-3 col-6"><div class="small-box bg-primary"><div class="inner"><h4 id="rValorArt">-</h4><p>Valor de repuestos e insumos (Gs.)</p></div><div class="icon"><i class="fas fa-boxes"></i></div></div></div>
                                <div class="col-lg-3 col-6"><div class="small-box bg-warning"><div class="inner"><h4 id="rPedidos">-</h4><p>Pedidos de material por entregar</p></div><div class="icon"><i class="fas fa-hand-holding"></i></div></div></div>
                                <div class="col-lg-3 col-6"><div class="small-box bg-light border"><div class="inner"><h4 id="rReposiciones">-</h4><p>Pedidos de reposición en curso</p></div><div class="icon"><i class="fas fa-truck"></i></div></div></div>
                            </div>
                        </div>

                        <!-- REPUESTOS E INSUMOS -->
                        <div class="tab-pane fade" id="tabArticulos" role="tabpanel">
                            <div class="input-group input-group-sm mb-2" style="max-width: 320px;">
                                <input type="text" class="form-control" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaExistencias')">
                                <div class="input-group-append"><span class="input-group-text bg-white"><i class="fas fa-search"></i></span></div>
                            </div>
                            <div class="table-responsive">
                                <table class="table table-sm table-striped table-bordered m-0 text-sm">
                                    <thead class="bg-primary text-white"><tr><th>Tipo</th><th>Artículo</th><th class="text-right">Stock</th><th class="text-right">Mínimo</th><th class="text-right">Dañado</th><th class="text-right">Último costo</th><th class="text-right">Valor (Gs.)</th><th>Situación</th><th class="text-center">Acciones</th></tr></thead>
                                    <tbody id="tablaExistencias"></tbody>
                                </table>
                            </div>
                        </div>

                        <!-- FICHA DEL ARTÍCULO (cabecera - detalle) -->
                        <div class="tab-pane fade" id="tabFicha" role="tabpanel">
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="card card-info card-outline">
                                        <div class="card-header bg-white"><h3 class="card-title text-info font-weight-bold">Artículo</h3></div>
                                        <div class="card-body">
                                            <div class="form-group">
                                                <label for="fichaArticulo" class="text-secondary font-weight-bold">Repuesto o insumo</label>
                                                <select id="fichaArticulo" class="form-control" onchange="cargarFicha()"></select>
                                            </div>
                                            <div class="row">
                                                <div class="col-6 form-group"><label class="small font-weight-bold">Stock actual</label><input type="text" id="fStock" class="form-control bg-light font-weight-bold" readonly></div>
                                                <div class="col-6 form-group"><label class="small font-weight-bold">Stock mínimo</label><input type="text" id="fMinimo" class="form-control bg-light" readonly></div>
                                                <div class="col-6 form-group"><label class="small font-weight-bold">Stock dañado</label><input type="text" id="fDanado" class="form-control bg-light" readonly></div>
                                                <div class="col-6 form-group"><label class="small font-weight-bold">Último costo (Gs.)</label><input type="text" id="fCosto" class="form-control bg-light" readonly></div>
                                            </div>
                                            <div class="row">
                                                <div class="col-6 form-group mb-0"><label for="fDesde" class="small font-weight-bold">Desde</label><input type="date" id="fDesde" class="form-control form-control-sm" onchange="cargarMovimientos()"></div>
                                                <div class="col-6 form-group mb-0"><label for="fHasta" class="small font-weight-bold">Hasta</label><input type="date" id="fHasta" class="form-control form-control-sm" onchange="cargarMovimientos()"></div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-md-8">
                                    <div class="card card-secondary card-outline">
                                        <div class="card-header bg-white"><h3 class="card-title text-secondary font-weight-bold">Entradas y salidas</h3></div>
                                        <div class="card-body p-0">
                                            <div class="table-responsive" style="max-height: 480px;">
                                                <table class="table table-sm table-striped m-0 text-sm">
                                                    <thead class="bg-secondary text-white text-xs"><tr><th>Fecha</th><th>Artículo</th><th>Movimiento</th><th>Documento</th><th class="text-right">Cantidad</th><th class="text-right">Stock</th><th>Usuario</th></tr></thead>
                                                    <tbody id="tablaMovimientos"><tr><td colspan="7" class="text-center text-muted py-3">Seleccione un artículo.</td></tr></tbody>
                                                </table>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- EQUIPOS POR UBICACIÓN -->
                        <div class="tab-pane fade" id="tabEquipos" role="tabpanel">
                            <div class="d-flex flex-wrap mb-2" style="gap:.5rem;">
                                <select id="filtroUbicacion" class="form-control form-control-sm" style="max-width: 260px;" aria-label="Ubicación" onchange="listarEquipos()"></select>
                                <input type="text" class="form-control form-control-sm" style="max-width: 300px;" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaEquipos')">
                            </div>
                            <div class="table-responsive">
                                <table class="table table-sm table-striped table-bordered m-0 text-sm">
                                    <thead class="bg-info text-white"><tr><th>ID</th><th>Cód. Patrimonial</th><th>Modelo</th><th>Nro. Serie</th><th>Marca</th><th>Categoría</th><th>Ubicación</th><th>Condición</th><th class="text-right">Costo (Gs.)</th><th class="text-right">Valor actual (Gs.)</th><th class="text-center">Ver</th></tr></thead>
                                    <tbody id="tablaEquipos"></tbody>
                                </table>
                            </div>
                        </div>

                        <!-- POR RETIRAR DE SALAS -->
                        <div class="tab-pane fade" id="tabRetirar" role="tabpanel">
                            <div class="table-responsive">
                                <table class="table table-sm table-striped table-bordered m-0 text-sm">
                                    <thead class="bg-danger text-white"><tr><th>Equipo</th><th>Sala</th><th>Motivo</th><th>Fecha</th><th>Detalle</th><th class="text-center">Acción</th></tr></thead>
                                    <tbody id="tablaRetirar"></tbody>
                                </table>
                            </div>
                        </div>

                        <!-- EQUIPOS INACTIVOS -->
                        <div class="tab-pane fade" id="tabInactivos" role="tabpanel">
                            <div class="table-responsive">
                                <table class="table table-sm table-striped table-bordered m-0 text-sm">
                                    <thead class="bg-dark text-white"><tr><th>ID</th><th>Cód. Patrimonial</th><th>Modelo</th><th>Nro. Serie</th><th>Marca</th><th>Categoría</th><th>Ubicación</th><th>Condición</th><th class="text-right">Costo (Gs.)</th><th class="text-right">Valor actual (Gs.)</th><th>Motivo</th><th class="text-center">Ver</th></tr></thead>
                                    <tbody id="tablaInactivos"></tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalHistorial">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-secondary text-white">
                <h4 class="modal-title">Salas por las que pasó el equipo</h4>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Cerrar">&times;</button>
            </div>
            <div class="modal-body p-0">
                <table class="table table-sm table-striped m-0">
                    <thead><tr><th>Fecha</th><th>Desde</th><th>Hacia</th><th>Usuario</th><th>Observación</th></tr></thead>
                    <tbody id="tablaHistorial"></tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    const CTRL_INV = "../controladores/inventarioControlador.jsp";
    const CTRL_EQ = "../controladores/equiposControlador.jsp";
    const CTRL_K = "../controladores/kardexControlador.jsp";

    $(document).ready(function () {
        cargarResumen();
        listarPorRetirar();
        $.post(CTRL_EQ, { accion: "cargarDepartamentos" }, function (d) { $("#filtroUbicacion").html(d); });
        $.post(CTRL_K, { tipo: "articulos" }, function (d) {
            $("#fichaArticulo").html(d).find("option[value='']").text("-- Seleccione --");
        });
    });

    function cargarResumen() {
        $.post(CTRL_INV, { tipo: "resumen" }, function (r) {
            $("#rValor").text(r.valorPatrimonio); $("#rUso").text(r.eqUso); $("#rDeposito").text(r.eqDeposito); $("#rInactivos").text(r.eqInactivos);
            $("#rBajo").text(r.bajoMinimo); $("#rValorArt").text(r.valorArticulos); $("#rPedidos").text(r.pedidosMaterial); $("#rReposiciones").text(r.reposiciones);
        }, "json");
    }

    function listarExistencias() { $.post(CTRL_INV, { tipo: "existencias" }, function (d) { $("#tablaExistencias").html(d); }); }

    function verFicha(art) {
        $("a[href='#tabFicha']").tab("show");
        $("#fichaArticulo").val(art);
        cargarFicha();
    }

    function cargarFicha() {
        let art = $("#fichaArticulo").val();
        $("#fStock, #fMinimo, #fDanado, #fCosto").val("");
        if (!art) { $("#tablaMovimientos").html("<tr><td colspan='7' class='text-center text-muted py-3'>Seleccione un artículo.</td></tr>"); return; }
        $.post(CTRL_K, { tipo: "ficha", articulo: art }, function (f) {
            if (!f.ok) return;
            $("#fStock").val(f.stock + (f.unidad ? " " + f.unidad : "")).toggleClass("text-danger", f.bajo);
            $("#fMinimo").val(f.minimo); $("#fDanado").val(f.danado); $("#fCosto").val(f.costo);
        }, "json");
        cargarMovimientos();
    }

    function cargarMovimientos() {
        let art = $("#fichaArticulo").val();
        if (!art) return;
        $.post(CTRL_K, { tipo: "listar", articulo: art, desde: $("#fDesde").val(), hasta: $("#fHasta").val() }, function (d) { $("#tablaMovimientos").html(d); });
    }

    function listarEquipos() {
        $.post(CTRL_EQ, { accion: "listar", vista: "activos", desde: "inventario", filtro_departamento: $("#filtroUbicacion").val() }, function (d) { $("#tablaEquipos").html(d); });
    }
    function listarInactivos() {
        $.post(CTRL_EQ, { accion: "listar", vista: "inactivos", desde: "inventario" }, function (d) { $("#tablaInactivos").html(d); });
    }

    function listarPorRetirar() {
        $.post("../controladores/movimientosEquiposControlador.jsp", { tipo: "porRetirar" }, function (d) {
            $("#tablaRetirar").html(d);
            let n = $("#tablaRetirar tr").not(".cta-empty-row").length;
            $("#cantRetirar").text(n > 0 ? n : "");
        });
    }

    function recibirEnDeposito(id) {
        confirmar("¿Confirmás que el equipo ya está físicamente en el Depósito?", function () {
            $.post("../controladores/movimientosEquiposControlador.jsp", { tipo: "recibirEnDeposito", idEquipo: id }, function (res) {
                res = res.trim();
                if (res.indexOf("success") === 0) { avisar("success", "Equipo recibido en el Depósito."); listarPorRetirar(); cargarResumen(); }
                else alert(res);
            });
        }, { si: "Sí, ya está", title: "Recibido en depósito" });
    }

    function verHistorial(id) {
        $("#tablaHistorial").html("<tr><td colspan='5' class='text-center text-muted'>Cargando...</td></tr>");
        $("#modalHistorial").modal("show");
        $.post(CTRL_EQ, { accion: "historial", id_equipo: id }, function (d) { $("#tablaHistorial").html(d); });
    }
</script>
