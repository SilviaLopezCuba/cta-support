<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1>Gestión de Donantes</h1></div>
                <div class="col-sm-6">
                    <button class="btn btn-primary float-right shadow" data-toggle="modal" data-target="#modalDonante" onclick="completar('Nuevo Donante', 'Guardar')">
                        <i class="fas fa-hand-holding-heart"></i> Nuevo Donante
                    </button>
                    <button class="btn btn-outline-secondary float-right shadow mr-2" onclick="window.open('../controladores/donantesControlador.jsp?tipo=ReporteGeneral', '_blank')">
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
                        <input type="text" class="form-control" id="buscarDonantes" placeholder="Buscar por nombre, documento, email..." oninput="filtrarTabla(this.value, 'tablaDonantes')">
                        <div class="input-group-append">
                            <span class="input-group-text bg-white"><i class="fas fa-search"></i></span>
                        </div>
                    </div>
                </div>
                <table id="tablaPrincipal" class="table table-bordered table-striped">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Nombre /Institucion</th>
                            <th>CI / RUC</th>
                            <th>Teléfono</th>
                            <th>Email</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tablaDonantes">
                        </tbody>
                </table>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalDonante">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloModal">Nuevo Donante</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="txtId">
                <div class="form-group"><label>Nombre / Institucion</label><input type="text" class="form-control" id="txtNombre"></div>
                <div class="form-group"><label>CI / RUC <small class="text-muted">(opcional)</small></label><input type="text" class="form-control" id="txtDocumento"></div>
                <div class="form-group"><label>Teléfono</label><input type="text" class="form-control" id="txtTelefono"></div>
                <div class="form-group"><label>Email</label><input type="email" class="form-control" id="txtEmail"></div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-primary" id="btnAccion" onclick="ejecutarAccion()">Guardar</button>
            </div>
        </div>
    </div>
</div>

<script>
    // 1. FUNCIONES GLOBALES
    function completar(titulo, boton) {
        $("#tituloModal").text(titulo);
        $("#btnAccion").text(boton);
        if(boton === 'Guardar') {
            $("#txtId, #txtNombre, #txtDocumento, #txtTelefono, #txtEmail").val("");
        }
    }

    function campos(id, nom, doc, tel, mail) {
        $("#txtId").val(id);
        $("#txtNombre").val(nom);
        $("#txtDocumento").val(doc);
        $("#txtTelefono").val(tel);
        $("#txtEmail").val(mail);
    }

    function listarDonantes() {
        $.post("../controladores/donantesControlador.jsp", { tipo: "listar" }, function(data) {
            if ($.fn.DataTable.isDataTable('#tablaPrincipal')) {
                $('#tablaPrincipal').DataTable().destroy();
            }
            $("#tablaDonantes").html(data);

            // Inicialización de DataTable con botones
            var table = $("#tablaPrincipal").DataTable({
                "responsive": true, 
                "lengthChange": false, 
                "autoWidth": false,
                "language": { "url": "<%=request.getContextPath()%>/plugins/datatables/i18n/es-ES.json" },
                "buttons": [
                    { extend: 'copy', text: 'Copiar' },
                    { extend: 'csv', text: 'CSV' },
                    { extend: 'excel', text: 'Excel', title: 'Reporte de Donantes' },
                    { extend: 'pdf', text: 'PDF', title: 'Reporte de Donantes' },
                    { extend: 'print', text: 'Imprimir' },
                    { extend: 'colvis', text: 'Columnas' }
                ]
            });

            // Mueve los botones al contenedor visual de la tabla
            table.buttons().container().appendTo('#tablaPrincipal_wrapper .col-md-6:eq(0)');
        });
    }

    function ejecutarAccion() {
        const data = {
            pk: $("#txtId").val(),
            nombre: $("#txtNombre").val(),
            documento: $("#txtDocumento").val(),
            telefono: $("#txtTelefono").val(),
            email: $("#txtEmail").val(),
            tipo: $("#btnAccion").text()
        };
        $.post("../controladores/donantesControlador.jsp", data, function(res) {
            if(res.trim() === "success") {
                $("#modalDonante").modal("hide");
                listarDonantes();
            } else { alert("Error: " + res); }
        });
    }

    function eliminar(id) {
    confirmar("¿Seguro que desea eliminar este donante?", function () {
            $.post("../controladores/donantesControlador.jsp", { pk: id, tipo: "Borrar" }, function(res) {
                if(res.trim() === "success") listarDonantes();
            });
    }, {peligro: true, si: "Sí, eliminar", title: "¿Eliminar registro?"});
    }

    // 2. INICIO
    $(document).ready(function() {
        listarDonantes();
    });
</script>

<%@include file="../includes/footer.jsp" %>