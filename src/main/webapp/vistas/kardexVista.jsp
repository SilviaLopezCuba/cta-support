<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <h1>Movimientos de Stock</h1>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <div class="card card-outline card-primary shadow">
                <div class="card-header">
                    <div class="form-row align-items-end">
                        <div class="col-md-4 mb-2">
                            <label for="fArticulo" class="small mb-0">Artículo</label>
                            <select id="fArticulo" class="form-control form-control-sm"></select>
                        </div>
                        <div class="col-md-2 mb-2">
                            <label for="fMovimiento" class="small mb-0">Movimiento</label>
                            <select id="fMovimiento" class="form-control form-control-sm">
                                <option value="">Todos</option>
                                <option>SALDO INICIAL</option>
                                <option>ENTRADA</option>
                                <option>ENTREGA</option>
                                <option>DEVOLUCION</option>
                                <option>AJUSTE</option>
                                <option>DAÑO</option>
                                <option>SALIDA</option>
                            </select>
                        </div>
                        <div class="col-md-2 mb-2">
                            <label for="fDesde" class="small mb-0">Desde</label>
                            <input type="date" id="fDesde" class="form-control form-control-sm">
                        </div>
                        <div class="col-md-2 mb-2">
                            <label for="fHasta" class="small mb-0">Hasta</label>
                            <input type="date" id="fHasta" class="form-control form-control-sm">
                        </div>
                        <div class="col-md-2 mb-2">
                            <button class="btn btn-primary btn-sm btn-block" onclick="listar()"><i class="fas fa-filter" aria-hidden="true"></i> Filtrar</button>
                        </div>
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-striped table-bordered table-sm m-0">
                            <thead class="bg-primary text-white">
                                <tr>
                                    <th>Fecha</th>
                                    <th>Artículo</th>
                                    <th>Movimiento</th>
                                    <th>Referencia</th>
                                    <th class="text-right">Cantidad</th>
                                    <th class="text-right">Stock</th>
                                    <th>Usuario</th>
                                    <th>Observación</th>
                                </tr>
                            </thead>
                            <tbody id="tablaKardex"></tbody>
                        </table>
                    </div>
                    
                </div>
            </div>
        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    const CTRL_K = "../controladores/kardexControlador.jsp";
    $(document).ready(function () {
        $.post(CTRL_K, { tipo: "articulos" }, function (d) { $("#fArticulo").html(d); });
        listar();
    });
    function listar() {
        $("#tablaKardex").html("<tr><td colspan='8' class='text-center text-muted'>Cargando...</td></tr>");
        $.post(CTRL_K, {
            tipo: "listar", articulo: $("#fArticulo").val(), movimiento: $("#fMovimiento").val(),
            desde: $("#fDesde").val(), hasta: $("#fHasta").val()
        }, function (d) { $("#tablaKardex").html(d); });
    }
</script>
