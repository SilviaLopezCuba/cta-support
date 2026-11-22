<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Roles</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalRol" onclick="completar('Nuevo Rol', 'Guardar')">
                        <i class="fas fa-user-tag"></i> Nuevo Rol
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/rolesControlador.jsp?tipo=ReporteGeneral', '_blank')">
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
                        <input type="text" class="form-control" id="buscarRoles" placeholder="Buscar por nombre del rol..." oninput="filtrarTabla(this.value, 'tablaRoles')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th style="width: 10%">ID</th>
                            <th>Nombre del Rol</th>
                            <th style="width: 15%" class="text-center">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaRoles"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalRol">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nuevo Rol</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label>Nombre del Rol</label>
                    <input type="text" class="form-control" id="txtNombre" placeholder="Ej: Administrador">
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
    $(document).ready(function () {
        listarRoles();
    });

    function listarRoles() {
        $.post("../controladores/rolesControlador.jsp", {tipo: "listar"}, function (data) {
            $("#tablaRoles").html(data);
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if (boton === 'Guardar') {
            $("#txtId").val("");
            $("#txtNombre").val("");
        }
    }

    function campos(id, nom) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#modalRol").modal("show");
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            tipo: $("#btnAccion").text()
        };

        $.post("../controladores/rolesControlador.jsp", data, function (res) {
            if (res.trim() === "success") {
                $("#modalRol").modal("hide");
                listarRoles();
            } else {
                alert("Error: " + res);
            }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar este rol?", function () {
            $.post("../controladores/rolesControlador.jsp", {pk: id, tipo: "Borrar"}, function (res) {
                if (res.trim() === "success") {
                    listarRoles();
                } else {
                    alert("Error: " + res);
                }
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>