<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Salas</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalSala" onclick="completar('Nueva Sala', 'Guardar')">
                        <i class="fas fa-door-open"></i> Nueva Sala
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/salasControlador.jsp?tipo=ReporteGeneral', '_blank')">
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
                        <input type="text" class="form-control" id="buscarSalas" placeholder="Buscar por nombre, ubicacion..." oninput="filtrarTabla(this.value, 'tablaSalas')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Nombre de la Sala</th>
                            <th>Departamento</th>
                            <th>Ubicación (Piso)</th>
                            <th>Capacidad</th>
                            <th class="text-center">Equipos activos</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaSalas">
                        </tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalSala">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nueva Sala</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label for="txtDepartamento">Departamento</label>
                    <select class="form-control" id="txtDepartamento"></select>
                </div>
                <div class="form-group">
                    <label>Nombre de Sala</label>
                    <input type="text" class="form-control" id="txtNombre" placeholder="Ej: Laboratorio 1">
                </div>
                <div class="form-group">
                    <label>Ubicación / Piso</label>
                    <input type="text" class="form-control" id="txtUbicacion" placeholder="Ej: Primer Piso">
                </div>
                <div class="form-group">
                    <label>Capacidad (personas/equipos)</label>
                    <input type="number" class="form-control" id="txtCapacidad" min="1">
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-primary" id="btnAccion" onclick="ejecutarAccion()">Guardar</button>
            </div>
        </div>
    </div>
</div>

<script>
    $(document).ready(function() {
        listarSalas();
        $.post("../controladores/salasControlador.jsp", { tipo: "departamentos" }, function(data) { $("#txtDepartamento").html(data); });
    });

    function listarSalas() {
        $.post("../controladores/salasControlador.jsp", { tipo: "listar" }, function(data) {
            $("#tablaSalas").html(data);
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId").val(""); $("#txtNombre").val(""); $("#txtUbicacion").val(""); $("#txtCapacidad").val(""); $("#txtDepartamento").val("");
        }
    }

    function campos(id, nom, ubi, cap, depto) {
        $("#txtDepartamento").val(depto);
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#txtUbicacion").val(ubi);
        $("#txtCapacidad").val(cap);
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            ubicacion: $("#txtUbicacion").val(),
            capacidad: $("#txtCapacidad").val(),
            id_departamento: $("#txtDepartamento").val(),
            tipo: $("#btnAccion").text()
        };

        if (!data.id_departamento) { alert("Seleccione el departamento de la sala."); return; }
        if (!data.nombre || !data.capacidad) { alert("Complete el nombre y la capacidad."); return; }
        $.post("../controladores/salasControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalSala").modal("hide");
                listarSalas();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar esta sala?", function () {
            $.post("../controladores/salasControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") listarSalas();
                else alert(res.trim());
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>

<%@include file="../includes/footer.jsp" %>