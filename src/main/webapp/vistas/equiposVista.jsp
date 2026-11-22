<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-7"><h1>Equipos</h1></div>
                <div class="col-sm-5">
                    <button class="btn btn-outline-secondary float-right shadow" onclick="window.open('../controladores/equiposControlador.jsp?accion=ReporteGeneral', '_blank')">
                        <i class="fas fa-file-pdf" aria-hidden="true"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <div class="card card-primary card-outline shadow">
                <div class="card-header">
                    <div class="input-group input-group-sm" style="max-width: 360px;">
                        <input type="text" class="form-control" id="buscarEquipos" placeholder="Buscar por código, modelo, serie, marca..." aria-label="Buscar equipos" oninput="filtrarTabla(this.value, 'tablaEquipos')">
                        <div class="input-group-append"><span class="input-group-text bg-white"><i class="fas fa-search" aria-hidden="true"></i></span></div>
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-striped table-bordered table-sm m-0">
                            <thead class="bg-primary text-white">
                                <tr><th>ID</th><th>Cód. Patrimonial</th><th>Categoría</th><th>Marca</th><th>Modelo</th><th>Nro. Serie</th><th>Especificaciones</th><th>Condición</th><th class="text-center">Acciones</th></tr>
                            </thead>
                            <tbody id="tablaEquipos"></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </section>
</div>

<!-- MODAL: DATOS DEL EQUIPO -->
<div class="modal fade" id="modalEquipo">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h4 class="modal-title" id="tituloEquipo">Datos del Equipo</h4>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Cerrar">&times;</button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="id_equipo">
                <h6 class="text-primary border-bottom pb-1"><i class="fas fa-desktop" aria-hidden="true"></i> Identificación</h6>
                <div class="row">
                    <div class="col-md-4 form-group">
                        <label for="id_categoria">Categoría *</label>
                        <select id="id_categoria" class="form-control"></select>
                    </div>
                    <div class="col-md-4 form-group">
                        <label for="id_marca">Marca</label>
                        <select id="id_marca" class="form-control"></select>
                    </div>
                    <div class="col-md-4 form-group">
                        <label for="modelo">Modelo / Nombre *</label>
                        <input type="text" id="modelo" class="form-control" maxlength="100" placeholder="Ej: ThinkPad E14">
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-6 form-group">
                        <label for="nro_serie">Nro. de Serie</label>
                        <input type="text" id="nro_serie" class="form-control" maxlength="80" placeholder="S/N">
                    </div>
                    <div class="col-md-6 form-group">
                        <label for="garantia">Vencimiento de Garantía</label>
                        <input type="date" id="garantia" class="form-control">
                    </div>
                </div>
                <div class="form-group">
                    <label for="especificaciones">Especificaciones técnicas</label>
                    <textarea id="especificaciones" class="form-control" rows="2" placeholder="Ej: Intel i5 10ma gen, 8 GB RAM, SSD 256 GB, Windows 10"></textarea>
                </div>

                <h6 class="text-primary border-bottom pb-1 mt-2"><i class="fas fa-sign-in-alt" aria-hidden="true"></i> Ingreso</h6>
                <div class="row">
                    <div class="col-md-4 form-group">
                        <label for="condicion_ingreso">Condición de ingreso *</label>
                        <select id="condicion_ingreso" class="form-control">
                            <option value="Nuevo">Nuevo</option>
                            <option value="Seminuevo">Seminuevo</option>
                            <option value="Usado">Usado</option>
                        </select>
                    </div>
                    <div class="col-md-4 form-group">
                        <label for="costo">Costo (Gs.)</label>
                        <input type="number" id="costo" class="form-control" min="0" step="1" placeholder="0">
                    </div>
                    <div class="col-md-4 form-group">
                        <label for="fecha_ingreso">Fecha de ingreso</label>
                        <input type="date" id="fecha_ingreso" class="form-control">
                    </div>
                </div>

                <div class="form-group">
                    <label for="codigo_patrimonial">Código Patrimonial</label>
                    <input type="text" id="codigo_patrimonial" class="form-control" maxlength="50" placeholder="Ej: 01-2024-XXX" style="max-width: 320px;">
                </div>
            </div>
            <div class="modal-footer justify-content-between">
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-primary" onclick="guardarEquipo()">Guardar</button>
            </div>
        </div>
    </div>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    const CTRL_EQ = "../controladores/equiposControlador.jsp";
    const ES_ADMIN = <%= esAdmin %>;

    $(document).ready(function() {
        $.post(CTRL_EQ, { accion: "cargarCategorias" }, function(data) { $("#id_categoria").html(data); });
        $.post(CTRL_EQ, { accion: "cargarMarcas" }, function(data) { $("#id_marca").html(data); });
        // Costo, condición y fecha de ingreso vienen de la Recepción: solo el Administrador los corrige
        if (!ES_ADMIN) $("#condicion_ingreso, #costo, #fecha_ingreso").prop("disabled", true);
        listarEquipos();
    });

    function listarEquipos() {
        $.post(CTRL_EQ, { accion: "listar", vista: "referencial" }, function(data) {
            $("#tablaEquipos").html(data);
            filtrarTabla($("#buscarEquipos").val(), "tablaEquipos");
        });
    }

    function editarEquipo(id) {
        $.post(CTRL_EQ, { accion: "obtener", id_equipo: id }, function(e) {
            if (!e || !e.id_equipo) { alert("No se encontró el equipo."); return; }
            $("#tituloEquipo").text("Modificar equipo");
            $("#id_equipo").val(e.id_equipo);
            $("#codigo_patrimonial").val(e.codigo_patrimonial);
            $("#modelo").val(e.modelo);
            $("#id_marca").val(e.id_marca);
            $("#id_categoria").val(e.id_categoria);
            $("#nro_serie").val(e.nro_serie);
            $("#garantia").val(e.garantia);
            $("#especificaciones").val(e.especificaciones);
            $("#condicion_ingreso").val(e.condicion_ingreso);
            $("#costo").val(e.costo);
            $("#fecha_ingreso").val(e.fecha_ingreso);
            $("#modalEquipo").modal("show");
        }, "json");
    }

    function guardarEquipo() {
        let datos = {
            accion: "guardar",
            id_equipo: $("#id_equipo").val(),
            codigo_patrimonial: $("#codigo_patrimonial").val(),
            modelo: $("#modelo").val(),
            id_marca: $("#id_marca").val(),
            id_categoria: $("#id_categoria").val(),
            nro_serie: $("#nro_serie").val(),
            garantia: $("#garantia").val(),
            especificaciones: $("#especificaciones").val(),
            condicion_ingreso: $("#condicion_ingreso").val(),
            costo: $("#costo").val(),
            fecha_ingreso: $("#fecha_ingreso").val()
        };
        if (!datos.modelo || !datos.id_categoria) { alert("Complete la categoría y el modelo."); return; }
        $.post(CTRL_EQ, datos, function(res) {
            if (res.trim() === "success") { $("#modalEquipo").modal("hide"); listarEquipos(); }
            else alert(res.trim());
        });
    }
</script>
