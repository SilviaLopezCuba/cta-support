<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Repuestos</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalRepuesto" onclick="completar('Nuevo Repuesto', 'Guardar')">
                        <i class="fas fa-microchip"></i> Nuevo Repuesto
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/repuestosControlador.jsp?tipo=ReporteGeneral', '_blank')">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="card card-outline card-primary shadow">
            <div class="card-body">
                <div class="mb-3">
                    <div class="input-group input-group-sm" style="max-width: 320px;">
                        <input type="text" class="form-control" id="buscarRepuestos" placeholder="Buscar por nombre, marca, categoria..." oninput="filtrarTabla(this.value, 'tablaRepuestos')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th>ID</th>
                            <th>Nombre</th>
                            <th>Marca</th>
                            <th>Categoría</th>
                            <th>Especificaciones</th>
                            <th>Stock Mínimo</th>
                            <th class="text-center">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaRepuestos"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalRepuesto">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nuevo Repuesto</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="row">
                    <div class="col-md-12 form-group">
                        <label>Nombre del Repuesto</label>
                        <input type="text" class="form-control" id="txtNombre" placeholder="Ej: Pantalla LED 14.0">
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-6 form-group">
                        <label>Marca</label>
                        <select class="form-control" id="cmbMarca"></select>
                    </div>
                    <div class="col-md-6 form-group">
                        <label>Categoría</label>
                        <select class="form-control" id="cmbCategoria"></select>
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-6 form-group d-none">
                        <label>Stock Actual</label>
                        <input type="number" class="form-control" id="txtStock" placeholder="0" min="0" step="1" readonly tabindex="-1">
                    </div>
                    <div class="col-md-6 form-group">
                        <label>Stock Mínimo <small class="text-muted">(alerta de reposición)</small></label>
                        <input type="number" class="form-control" id="txtStockMinimo" placeholder="Ej: 2" min="0" step="1" value="0" onkeydown="return !/^[.,eE+-]$/.test(event.key)">
                    </div>
                </div>
                <div class="form-group">
                    <label>Especificación Técnica</label>
                    <input type="text" class="form-control" id="txtTecnica" placeholder="30 pines, Full HD, SSD 512GB">
                </div>
                <div class="form-group">
                    <label>Notas de Compatibilidad</label>
                    <textarea class="form-control" id="txtNotas" rows="2"></textarea>
                </div>
            </div>
            <div class="modal-footer justify-content-between">
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-primary" id="btnAccion" onclick="ejecutarAccion()">Guardar</button>
            </div>
        </div>
    </div>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    $(document).ready(function() {
        listarRepuestos();
        cargarCombos();
    });

    function cargarCombos() {
        $.post("../controladores/repuestosControlador.jsp", { tipo: "cargarMarcas" }, function(data) { $("#cmbMarca").html(data); });
        $.post("../controladores/repuestosControlador.jsp", { tipo: "cargarCategorias" }, function(data) { $("#cmbCategoria").html(data); });
    }

    function listarRepuestos() {
        $.post("../controladores/repuestosControlador.jsp", { tipo: "listar" }, function(data) {
            $("#tablaRepuestos").html(data);
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId").val(""); $("#txtNombre").val("");
            $("#txtTecnica").val(""); $("#txtNotas").val("");
            $("#txtStock").val("0"); $("#txtStockMinimo").val("0");
        }
    }

    function campos(id, nom, mar, cat, tec, not, stock, stockMin) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#cmbMarca").val(mar);
        $("#cmbCategoria").val(cat);
        $("#txtTecnica").val(tec);
        $("#txtNotas").val(not);
        $("#txtStock").val(stock);
        $("#txtStockMinimo").val(stockMin);
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            id_marca: $("#cmbMarca").val(),
            id_categoria: $("#cmbCategoria").val(),
            tecnica: $("#txtTecnica").val(),
            notas: $("#txtNotas").val(),
            stock: Math.round(parseFloat($("#txtStock").val()) || 0),
            stockMinimo: Math.round(parseFloat($("#txtStockMinimo").val()) || 0),
            tipo: $("#btnAccion").text()
        };

        $.post("../controladores/repuestosControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalRepuesto").modal("hide");
                listarRepuestos();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar este repuesto?", function () {
            $.post("../controladores/repuestosControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") listarRepuestos();
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>
