<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Unidades de Medida</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-outline-secondary float-right shadow mr-2" id="btnReporte">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </button>
                    <button class="btn btn-primary float-right shadow" id="btnNueva" data-toggle="modal" data-target="#modalUnidad">
                        <i class="fas fa-ruler-combined"></i> Nueva Unidad
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
                        <input type="text" class="form-control" id="buscarUnidades" placeholder="Buscar por nombre..."
                               aria-label="Buscar unidad de medida" oninput="filtrarTabla(this.value, 'tablaUnidades')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th style="width: 100px;">ID</th>
                            <th>Unidad de Medida</th>
                            <th class="text-center" style="width: 150px;">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaUnidades"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalUnidad">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nueva Unidad</h4>
                <button type="button" class="close" data-dismiss="modal" aria-label="Cerrar">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label for="txtNombre">Nombre de la Unidad</label>
                    <input type="text" class="form-control" id="txtNombre" maxlength="50" placeholder="Ej. Unidad, Metro, Caja...">
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
    var CTRL = "../controladores/unidadesMedidaControlador.jsp";

    $(document).ready(function () {
        listarUnidades();

        $("#btnNueva").on("click", function () {
            $("#tituloModal").text("Nueva Unidad");
            $("#btnAccion").text("Guardar");
            $("#txtId").val("");
            $("#txtNombre").val("");
        });

        // Los botones se crean al listar, por eso se usa delegación de eventos
        $("#tablaUnidades").on("click", ".btn-editar", function () {
            $("#tituloModal").text("Modificar Unidad");
            $("#btnAccion").text("Modificar");
            $("#txtId").val($(this).data("id"));
            $("#txtNombre").val($(this).data("nombre"));
        });

        $("#btnReporte").on("click", function () {
            window.open(CTRL + "?tipo=ReporteGeneral", "_blank");
        });

        $("#tablaUnidades").on("click", ".btn-pdf", function () {
            window.open(CTRL + "?tipo=ReporteIndividual&pk=" + $(this).data("id"), "_blank");
        });

        $("#tablaUnidades").on("click", ".btn-eliminar", function () {
            eliminar($(this).data("id"));
        });
    });

    function listarUnidades() {
        $.post(CTRL, {tipo: "listar"}, function (data) {
            $("#tablaUnidades").html(data);
        });
    }

    function ejecutarAccion() {
        var datos = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            tipo: $("#btnAccion").text()
        };

        if (datos.nombre.trim() === "") {
            avisar("warning", "El nombre de la unidad es obligatorio");
            return;
        }

        $.post(CTRL, datos, function (res) {
            if (res.trim() === "success") {
                $("#modalUnidad").modal("hide");
                listarUnidades();
                avisar("success", "Unidad guardada correctamente");
            } else {
                avisar("error", res.replace(/^error:\s*/, ""));
            }
        });
    }

    function eliminar(id) {
        confirmar("¿Seguro que desea eliminar esta unidad de medida?", function () {
            $.post(CTRL, {pk: id, tipo: "Borrar"}, function (res) {
                if (res.trim() === "success") {
                    listarUnidades();
                    avisar("success", "Unidad eliminada");
                } else {
                    avisar("error", res.replace(/^error:\s*/, ""));
                }
            });
        }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>
