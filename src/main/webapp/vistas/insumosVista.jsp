<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Insumos</h1></div>
                <div class="col-sm-6 text-right">
                    <button class="btn btn-outline-secondary shadow mr-2" onclick="window.open('../controladores/insumosControlador.jsp?tipo=ReporteGeneral', '_blank')">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </button>
                    <button class="btn btn-primary shadow" data-toggle="modal" data-target="#modalInsumo" onclick="completar('Nuevo Insumo', 'Guardar')">
                        <i class="fas fa-flask"></i> Nuevo Insumo
                    </button>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="card card-outline card-primary shadow">
            <div class="card-body">
                <table class="table table-hover table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th>ID</th><th>Insumo</th><th>Marca</th><th>Stock Mínimo</th><th>Presentacion</th><th class="text-center">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaInsumos"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<!-- Modal -->
<div class="modal fade" id="modalInsumo">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nuevo Insumo</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label>Nombre del Insumo</label>
                    <input type="text" class="form-control" id="txtNombre" placeholder="Ej: Alcohol Isopropilico">
                </div>
                <div class="form-group">
                    <label>Marca</label>
                    <select id="cmbMarca" class="form-control"></select>
                </div>
                <div class="row">
                    <div class="col-6 form-group d-none">
                        <label>Stock Actual</label>
                        <input type="number" class="form-control" id="txtStock" placeholder="0" min="0" step="1" readonly tabindex="-1">
                        <small class="form-text text-muted" id="ayudaStock"></small>
                    </div>
                    <div class="col-6 form-group">
                        <label>Unidad</label>
                        <select id="cmbUnidad" class="form-control"></select>
                    </div>
                </div>
                <div class="form-group">
                    <label>Stock Mínimo <small class="text-muted">(alerta de reposición)</small></label>
                    <input type="number" class="form-control" id="txtStockMinimo" placeholder="Ej: 50" min="0" step="1" value="0">
                </div>
                <div class="form-group">
                    <label>Presentacion / Envase</label>
                    <input type="text" class="form-control" id="txtPresentacion" placeholder="Ej: Botella de plastico">
                </div>
            </div>
            <div class="modal-footer justify-content-between">
                <button type="button" class="btn btn-default" data-dismiss="modal">
                    <i class="fas fa-times"></i> Cancelar
                </button>
                <button type="button" class="btn btn-primary" id="btnAccion" onclick="ejecutarAccion()">
                    <i class="fas fa-save"></i> Guardar
                </button>
            </div>
        </div>
    </div>
</div>

<%@include file="../includes/footer.jsp" %>
<script>
    $(document).ready(function() {
        listarInsumos();
        cargarCombos();

        // La unidad de medida decide si el stock admite decimales o solo enteros
        $("#cmbUnidad").on("change", aplicarUnidad);
        $("#txtStock, #txtStockMinimo").on("keydown", function (e) {
            if (/^[eE+-]$/.test(e.key)) { e.preventDefault(); return; }
            if (!unidadAdmiteDecimal() && /^[.,]$/.test(e.key)) { e.preventDefault(); }
        });
    });

    function unidadAdmiteDecimal() {
        return String($("#cmbUnidad option:selected").attr("data-decimal")) !== "false";
    }

    function aplicarUnidad() {
        var dec = unidadAdmiteDecimal();
        $("#txtStock, #txtStockMinimo").attr("step", dec ? "0.01" : "1");
        $("#txtStock").attr("placeholder", dec ? "Ej: 2.5" : "Ej: 10");
        $("#txtStockMinimo").attr("placeholder", dec ? "Ej: 0.5" : "Ej: 2");
        $("#ayudaStock").text(dec ? "Admite decimales (ej: 2.5)" : "Solo numeros enteros");
        if (!dec) {
            $("#txtStock, #txtStockMinimo").each(function () {
                var v = $(this).val();
                if (v !== "") { $(this).val(Math.round(parseFloat(v) || 0)); }
            });
        }
    }

    function cargarCombos() {
        // Reutilizamos el controlador de marcas que ya funciona
        $.post("../controladores/repuestosControlador.jsp", { tipo: "cargarMarcas" }, function(data) { $("#cmbMarca").html(data); });
        $.post("../controladores/insumosControlador.jsp", { tipo: "cargarUnidades" }, function(data) { $("#cmbUnidad").html(data); aplicarUnidad(); });
    }

    function listarInsumos() {
        $.post("../controladores/insumosControlador.jsp", { tipo: "listar" }, function(data) { $("#tablaInsumos").html(data); });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId").val(""); $("#txtNombre").val("");
            $("#txtStock").val("0"); $("#txtStockMinimo").val("0"); $("#txtPresentacion").val("");
        }
        aplicarUnidad();
    }

    function campos(id, nom, mar, uni, stock, stockMin, pre) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#cmbMarca").val(mar);
        $("#cmbUnidad").val(uni);
        $("#txtStock").val(stock);
        $("#txtStockMinimo").val(stockMin);
        $("#txtPresentacion").val(pre);
        aplicarUnidad();
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            id_marca: $("#cmbMarca").val(),
            id_unidad: $("#cmbUnidad").val(),
            stock: $("#txtStock").val(),
            stockMinimo: $("#txtStockMinimo").val(),
            presentacion: $("#txtPresentacion").val(),
            tipo: $("#btnAccion").text()
        };
        $.post("../controladores/insumosControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalInsumo").modal("hide");
                listarInsumos();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Desea eliminar este insumo?", function () {
            $.post("../controladores/insumosControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") listarInsumos();
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>
