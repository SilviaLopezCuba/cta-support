<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Personas</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalPersona" onclick="completar('Nueva Persona', 'Guardar')">
                        <i class="fas fa-user-plus"></i> Nueva Persona
                    </button>
                    <div class="col-sm-6">
                        <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/personasControlador.jsp?tipo=ReporteGeneral', '_blank')">
                            <i class="fas fa-file-pdf"></i> Reporte General
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="card card-outline card-primary shadow">
            <div class="card-body">
                <div class="mb-3">
                    <div class="input-group input-group-sm" style="max-width: 320px;">
                        <input type="text" class="form-control" id="buscarPersonas" placeholder="Buscar por nombre, apellido, documento..." oninput="filtrarTabla(this.value, 'tablaPersonas')">
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
                            <th>Apellido</th>
                            <th>Documento</th>
                            <th>Correo</th>
                            <th>Teléfono</th>
                            <th class="text-center">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaPersonas"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalPersona">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nueva Persona</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="row">
                    <div class="col-md-6 form-group">
                        <label>Nombre</label>
                        <input type="text" class="form-control" id="txtNombre">
                    </div>
                    <div class="col-md-6 form-group">
                        <label>Apellido</label>
                        <input type="text" class="form-control" id="txtApellido">
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-6 form-group">
                        <label>Documento (CI)</label>
                        <input type="text" class="form-control" id="txtDocumento">
                    </div>
                    <div class="col-md-6 form-group">
                        <label>Teléfono</label>
                        <input type="text" class="form-control" id="txtTelefono">
                    </div>
                </div>
                <div class="form-group">
                    <label>Correo Electronico</label>
                    <input type="email" class="form-control" id="txtCorreo">
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
        listarPersonas();
    });

    function listarPersonas() {
        $.post("../controladores/personasControlador.jsp", {tipo: "listar"}, function (data) {
            $("#tablaPersonas").html(data);
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if (boton === 'Guardar') {
            $("#txtId").val("");
            $("#txtNombre").val("");
            $("#txtApellido").val("");
            $("#txtDocumento").val("");
            $("#txtCorreo").val("");
            $("#txtTelefono").val("");
        }
    }

    function campos(id, nom, ape, doc, cor, tel) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#txtApellido").val(ape);
        $("#txtDocumento").val(doc);
        $("#txtCorreo").val(cor);
        $("#txtTelefono").val(tel);
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            apellido: $("#txtApellido").val(),
            documento: $("#txtDocumento").val(),
            correo: $("#txtCorreo").val(),
            telefono: $("#txtTelefono").val(),
            tipo: $("#btnAccion").text()
        };

        $.post("../controladores/personasControlador.jsp", data, function (res) {
            if (res.trim() === "success") {
                $("#modalPersona").modal("hide");
                listarPersonas();
            } else {
                alert("Error: " + res);
            }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar a esta persona?", function () {
            $.post("../controladores/personasControlador.jsp", {pk: id, tipo: "Borrar"}, function (res) {
                if (res.trim() === "success")
                    listarPersonas();
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }


</script>