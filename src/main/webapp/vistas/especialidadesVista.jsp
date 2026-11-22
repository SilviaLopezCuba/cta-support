<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Especialidades</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalEspecialidad" onclick="completar('Nueva Especialidad', 'Guardar')">
                        <i class="fas fa-graduation-cap"></i> Nueva Especialidad
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/especialidadesControlador.jsp?tipo=ReporteGeneral', '_blank')">
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
                        <input type="text" class="form-control" id="buscarEspecialidades" placeholder="Buscar por nombre de especialidad..." oninput="filtrarTabla(this.value, 'tablaEspecialidades')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th style="width: 100px;">ID</th>
                            <th>Nombre de la Especialidad</th>
                            <th class="text-center" style="width: 150px;">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaEspecialidades"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalEspecialidad">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nueva Especialidad</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label>Nombre de la Especialidad</label>
                    <input type="text" class="form-control" id="txtNombre" placeholder="Ej. Redes, Soporte Técnico, Desarrollo...">
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
        listarEspecialidades();
    });

    function listarEspecialidades() {
        $.post("../controladores/especialidadesControlador.jsp", { tipo: "listar" }, function(data) {
            $("#tablaEspecialidades").html(data);
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
            alert("El nombre de la especialidad es obligatorio");
            return;
        }

        $.post("../controladores/especialidadesControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalEspecialidad").modal("hide");
                listarEspecialidades();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar esta especialidad?", function () {
            $.post("../controladores/especialidadesControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") listarEspecialidades();
                else alert("No se puede eliminar: " + res);
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>