<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Técnicos</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalTecnico" onclick="completar('Registrar Técnico', 'Guardar')">
                        <i class="fas fa-plus"></i> Nuevo Técnico
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/tecnicosControlador.jsp?tipo=ReporteGeneral', '_blank')">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <div class="card card-outline card-primary shadow">
                <div class="card-body p-0">
                    <div class="p-3 pb-0">
                        <div class="input-group input-group-sm" style="max-width: 320px;">
                            <input type="text" class="form-control" id="buscarTecnicos" placeholder="Buscar por nombre, especialidad..." oninput="filtrarTabla(this.value, 'tablaTecnicos')">
                            <div class="input-group-append">
                                <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                            </div>
                        </div>
                    </div>
                    <table class="table table-striped table-bordered m-0">
                        <thead class="bg-primary text-white">
                            <tr>
                                <th>ID</th>
                                <th>Técnico (Usuario)</th>
                                <th>Especialidad</th>
                                <th>Estado</th>
                                <th class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="tablaTecnicos"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalTecnico">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Registrar Técnico</h4>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                
                <div class="form-group">
                    <label>Seleccionar Usuario Técnico</label>
                    <select id="cmbUsuario" class="form-control"></select>
                </div>
                
                <div class="form-group">
                    <label>Especialidad</label>
                    <select id="cmbEspecialidad" class="form-control"></select>
                </div>

                <div class="form-group">
                    <label>Disponibilidad</label>
                    <select id="cmbEstado" class="form-control">
                        <option value="true">Disponible</option>
                        <option value="false">Ocupado</option>
                    </select>
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
        listarTecnicos();
        cargarComboUsuarios();
        cargarComboEspecialidades(); // Nueva llamada
    });

    function listarTecnicos() {
        $.post("../controladores/tecnicosControlador.jsp", { tipo: "listar" }, function(data) {
            $("#tablaTecnicos").html(data);
        });
    }

    function cargarComboUsuarios() {
        $.post("../controladores/tecnicosControlador.jsp", { tipo: "cargarUsuarios" }, function(data) {
            $("#cmbUsuario").html(data);
        });
    }

    // NUEVA FUNCIÓN
    function cargarComboEspecialidades() {
        $.post("../controladores/tecnicosControlador.jsp", { tipo: "cargarEspecialidades" }, function(data) {
            $("#cmbEspecialidad").html(data);
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId").val("");
            $("#cmbEspecialidad").val("");
            $("#cmbUsuario").val("");
        }
    }

    function campos(id, usuario, especialidad, estado) {
        $("#txtId").val(id);
        $("#cmbUsuario").val(usuario);
        $("#cmbEspecialidad").val(especialidad); // Asigna el ID de especialidad
        $("#cmbEstado").val(estado);
        $("#modalTecnico").modal("show");
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            tipo: $("#btnAccion").text(),
            id_usuario: $("#cmbUsuario").val(),
            id_especialidad: $("#cmbEspecialidad").val(), // Cambiado a ID
            disponibilidad: $("#cmbEstado").val()
        };

        if(!data.id_usuario || !data.id_especialidad) {
            alert("Complete los campos obligatorios");
            return;
        }

        $.post("../controladores/tecnicosControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalTecnico").modal("hide");
                listarTecnicos();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Desea eliminar este registro de técnico?", function () {
            $.post("../controladores/tecnicosControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") {
                    listarTecnicos();
                } else { alert("Error: " + res); }
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>