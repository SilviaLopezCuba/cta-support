<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Catálogo de Servicios</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalReferencial" onclick="completar('Nuevo Servicio', 'Guardar')">
                        <i class="fas fa-tools" aria-hidden="true"></i> Nuevo Servicio
                    </button>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="card card-outline card-primary shadow">
            <div class="card-body">
                <p class="text-muted mb-3"><i class="fas fa-info-circle" aria-hidden="true"></i> Trabajos que el técnico puede registrar al cerrar una orden o un mantenimiento.</p>
                <div class="mb-3">
                    <div class="input-group input-group-sm" style="max-width: 320px;">
                        <input type="text" class="form-control" id="buscarReferencial" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaReferencial')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search" aria-hidden="true"></i></span>
                        </div>
                    </div>
                </div>
                <table class="table table-bordered table-striped">
                    <thead class="bg-primary text-white">
                        <tr>
                            <th style="width: 80px;">ID</th>
                            <th>Nombre</th>
                            <th>Descripción</th>
                            <th class="text-center" style="width: 110px;">Estado</th>
                            <th class="text-center" style="width: 130px;">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaReferencial"></tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalReferencial">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nuevo Servicio</h4>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Cerrar">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group">
                    <label for="txtNombre">Nombre</label>
                    <input type="text" class="form-control" id="txtNombre" maxlength="100" placeholder="Ej. Limpieza interna, Formateo...">
                </div>
                <div class="form-group">
                    <label for="txtDescripcion">Descripción <span class="text-muted">(opcional)</span></label>
                    <textarea class="form-control" id="txtDescripcion" rows="2" maxlength="255"></textarea>
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
    const CTRL = "../controladores/serviciosCatalogoControlador.jsp";

    $(document).ready(function() {
        listar();
    });

    function listar() {
        $.post(CTRL, { tipo: "listar" }, function(data) {
            $("#tablaReferencial").html(data);
            filtrarTabla($("#buscarReferencial").val(), "tablaReferencial");
        });
    }

    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if (boton === "Guardar") {
            $("#txtId").val("");
            $("#txtNombre").val("");
            $("#txtDescripcion").val("");
        }
        $("#modalReferencial").modal("show");
    }

    function campos(id, nom, desc) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#txtDescripcion").val(desc);
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            descripcion: $("#txtDescripcion").val(),
            tipo: $("#btnAccion").text()
        };
        if (!data.nombre || data.nombre.trim() === "") {
            alert("El nombre es obligatorio.");
            return;
        }
        $.post(CTRL, data, function(res) {
            if (res.trim() === "success") {
                $("#modalReferencial").modal("hide");
                listar();
            } else {
                alert(res.trim());
            }
        });
    }

    function cambiarEstado(id, activo) {
        confirmar(activo ? "¿Desactivar este registro? Dejará de aparecer en los formularios, pero no se borra."
                         : "¿Volver a activar este registro?", function () {
            $.post(CTRL, { pk: id, tipo: "CambiarEstado" }, function(res) {
                if (res.trim() === "success") listar();
                else alert(res.trim());
            });
        }, { si: activo ? "Sí, desactivar" : "Sí, activar", title: activo ? "¿Desactivar?" : "¿Activar?" });
    }
</script>
