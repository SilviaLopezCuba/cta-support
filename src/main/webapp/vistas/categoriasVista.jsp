<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Categorías</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalCategoria" onclick="completar('Nueva Categoría', 'Guardar')">
                        <i class="fas fa-tags"></i> Nueva Categoría
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/categoriasControlador.jsp?tipo=ReporteGeneral', '_blank')">
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
                        <input type="text" class="form-control" id="buscarCategorias" placeholder="Buscar por nombre de categoría..." oninput="filtrarTabla(this.value, 'tablaCategorias')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th style="width: 100px;">ID</th>
                            <th>Nombre de la Categoría</th>
                            <th class="text-center" style="width: 140px;">Vida útil</th>
                            <th class="text-center" style="width: 150px;">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaCategorias"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalCategoria">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nueva Categoría</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label>Nombre de Categoría</label>
                    <input type="text" class="form-control" id="txtNombre" placeholder="Ej. Laptops, Impresoras...">
                </div>
                <div class="form-group">
                    <label for="txtVidaUtil">Vida útil (años)</label>
                    <input type="number" class="form-control" id="txtVidaUtil" min="1" max="50" value="5">
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
        listarCategorias();
    });

    function listarCategorias() {
        $.post("../controladores/categoriasControlador.jsp", { tipo: "listar" }, function(data) {
            $("#tablaCategorias").html(data);
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId").val(""); 
            $("#txtNombre").val("");
            $("#txtVidaUtil").val("5");
        }
    }

    function campos(id, nom, vida) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#txtVidaUtil").val(vida);
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            vida_util: $("#txtVidaUtil").val(),
            tipo: $("#btnAccion").text()
        };

        if(data.nombre.trim() === "") {
            alert("El nombre es obligatorio");
            return;
        }

        $.post("../controladores/categoriasControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalCategoria").modal("hide");
                listarCategorias();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar esta categoría?", function () {
            $.post("../controladores/categoriasControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") listarCategorias();
                else alert("No se puede eliminar: " + res);
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>