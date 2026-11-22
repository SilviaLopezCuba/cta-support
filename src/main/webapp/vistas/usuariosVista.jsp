<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Usuarios</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalUsuario" onclick="completar('Nueva Cuenta de Acceso', 'Guardar')">
                        <i class="fas fa-user-plus"></i> Nuevo Usuario
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/usuariosControlador.jsp?tipo=ReporteGeneral', '_blank')">
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
                            <input type="text" class="form-control" id="buscarUsuarios" placeholder="Buscar por nombre, login, rol..." oninput="filtrarTabla(this.value, 'tablaUsuarios')">
                            <div class="input-group-append">
                                <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                            </div>
                        </div>
                    </div>
                    <table class="table table-striped table-bordered m-0">
                        <thead class="bg-primary text-white">
                            <tr>
                                <th>ID</th>
                                <th>Nombre y Apellido</th>
                                <th>Login (Cédula)</th>
                                <th>Rol</th>
                                <th class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="tablaUsuarios"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalUsuario">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Datos de Acceso</h4>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label>Persona</label>
                    <select id="cmbPersona" class="form-control" onchange="mostrarUsuarioSugerido()"></select>
                </div>
                
                <div class="form-group">
                    <label>Usuario sugerido (cédula)</label>
                    <input type="text" id="txtSugerido" class="form-control" readonly 
                           style="background-color: var(--cta-surface-alt); font-weight: bold; color: var(--cta-navy);">
                </div>

                <div class="form-group">
                    <label>Contraseña</label>
                    <input type="password" id="txtPass" class="form-control" placeholder="Ingrese contraseña">
                </div>

                <div class="form-group">
                    <label>Rol de Usuario</label>
                    <select id="cmbRol" class="form-control"></select>
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
        listarUsuarios();
        cargarCombos();
    });

    function listarUsuarios() {
        $.post("../controladores/usuariosControlador.jsp", { tipo: "listar" }, function(data) {
            $("#tablaUsuarios").html(data);
        });
    }

    function cargarCombos() {
        $.post("../controladores/usuariosControlador.jsp", { tipo: "cargarCombo" }, function(data) { $("#cmbPersona").html(data); });
        $.post("../controladores/usuariosControlador.jsp", { tipo: "cargarRoles" }, function(data) { $("#cmbRol").html(data); });
    }

    function mostrarUsuarioSugerido() {
        let cedula = $("#cmbPersona").find(':selected').data('cedula');
        $("#txtSugerido").val(cedula ? cedula : "");
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId").val("");
            $("#txtPass").val("");
            $("#cmbPersona").val("");
            $("#txtSugerido").val("");
        }
    }

    function campos(id, persona, pass, rol) {
        $("#txtId").val(id);
        $("#cmbPersona").val(persona);
        $("#txtPass").val(pass);
        $("#cmbRol").val(rol);
        mostrarUsuarioSugerido();
        $("#modalUsuario").modal("show");
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            tipo: $("#btnAccion").text(),
            pass: $("#txtPass").val(),
            id_rol: $("#cmbRol").val(),
            id_persona: $("#cmbPersona").val()
        };

        $.post("../controladores/usuariosControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalUsuario").modal("hide");
                listarUsuarios();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar este acceso?", function () {
            $.post("../controladores/usuariosControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") {
                    listarUsuarios();
                } else { alert("Error: " + res); }
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }
</script>