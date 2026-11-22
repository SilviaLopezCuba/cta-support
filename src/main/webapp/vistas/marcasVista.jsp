<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Marcas</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalMarca" onclick="completar('Nueva Marca', 'Guardar')">
                        <i class="fas fa-copyright"></i> Nueva Marca
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/marcasControlador.jsp?tipo=ReporteGeneral', '_blank')">
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
                        <input type="text" class="form-control" id="buscarMarcas" placeholder="Buscar por nombre de marca..." oninput="filtrarTabla(this.value, 'tablaMarcas')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th style="width: 100px;">ID</th>
                            <th>Nombre de la Marca</th>
                            <th class="text-center" style="width: 150px;">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaMarcas"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalMarca">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nueva Marca</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label>Nombre de la Marca</label>
                    <input type="text" class="form-control" id="txtNombre" placeholder="Ej. HP, Dell, Lenovo...">
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
        listarMarcas();
    });

    function listarMarcas() {
        $.post("../controladores/marcasControlador.jsp", { tipo: "listar" }, function(data) {
            $("#tablaMarcas").html(data);
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId").val(""); 
            $("#txtNombre").val("");
        }
    }

    function campos(id, nom) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            tipo: $("#btnAccion").text()
        };

        if(data.nombre.trim() === "") {
            alert("El nombre de la marca es obligatorio");
            return;
        }

        $.post("../controladores/marcasControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalMarca").modal("hide");
                listarMarcas();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar esta marca?", function () {
            $.post("../controladores/marcasControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") listarMarcas();
                else alert("No se puede eliminar: " + res);
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>