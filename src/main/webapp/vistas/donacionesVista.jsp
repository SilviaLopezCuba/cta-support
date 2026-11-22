<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6">
                    <h1 class="font-weight-bold text-primary"><i class="fas fa-hand-holding-heart"></i> Donaciones Recibidas</h1>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">

            <div class="row">
                <!-- Columna izquierda: Datos de la donación -->
                <div class="col-md-5">
                    <div class="card card-info card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold">
                                <i class="fas fa-file-alt"></i> Datos de la Donación
                            </h3>
                        </div>
                        <div class="card-body">
                            <form id="formDonacion">
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">Donante</label>
                                    <select id="id_donante" class="form-control"></select>
                                </div>
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">N° de Comprobante</label>
                                    <input type="text" id="nro_comprobante" class="form-control" placeholder="Opcional (si lo deja vacío, se genera automáticamente)">
                                </div>
                                <div class="form-group">
                                    <label class="text-secondary font-weight-bold">Fecha de Donación</label>
                                    <input type="date" id="fecha_donacion" class="form-control">
                                </div>
                            </form>
                        </div>
                    </div>
                </div>

                <!-- Columna derecha: Repuestos e Insumos recibidos -->
                <div class="col-md-7">
                    <div class="card card-secondary card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-secondary font-weight-bold">
                                <i class="fas fa-boxes"></i> Artículos Recibidos
                            </h3>
                        </div>
                        <div class="card-body">
                            <div class="row bg-light p-3 mb-3 rounded border">
                                <div class="col-md-8 form-group">
                                    <label class="small font-weight-bold">Seleccionar Artículo</label>
                                    <select id="id_material" class="form-control"></select>
                                </div>
                                <div class="col-md-4 form-group">
                                    <label class="small font-weight-bold">Cantidad</label>
                                    <input type="number" id="cantidad_material" class="form-control" value="1" min="1" step="1">
                                </div>
                                <div class="col-md-12 align-self-end form-group">
                                    <button class="btn btn-info btn-block font-weight-bold" type="button" onclick="agregarAlDetalleJS()">
                                        <i class="fas fa-plus"></i> Agregar Artículo
                                    </button>
                                </div>
                            </div>

                            <table class="table table-bordered table-sm m-0 text-sm">
                                <thead class="bg-secondary text-white text-xs">
                                    <tr>
                                        <th>Categoría</th>
                                        <th>Descripción</th>
                                        <th width="100px" class="text-right">Cantidad</th>
                                        <th width="60px" class="text-center">Quitar</th>
                                    </tr>
                                </thead>
                                <tbody id="tbodyDetalleJS">
                                    <tr><td colspan="4" class="text-center text-muted py-3">Ningún artículo agregado.</td></tr>
                                </tbody>
                            </table>
                        </div>
                        <div class="card-footer bg-white border-top d-flex justify-content-between align-items-center">
                            <span class="font-weight-bold">Unidades: <span id="totalUnidades">0</span></span>
                            <button type="button" class="btn btn-success font-weight-bold shadow" onclick="registrarDonacionJS()">
                                <i class="fas fa-check-circle"></i> REGISTRAR DONACIÓN
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Historial de donaciones -->
            <div class="card card-success card-outline shadow mt-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-success font-weight-bold">
                        <i class="fas fa-history"></i> Historial de Donaciones <small class="text-muted">(últimas 50)</small>
                    </h3>
                    <div class="card-tools">
                        <button type="button" class="btn btn-tool" onclick="listarDonaciones()"><i class="fas fa-sync-alt"></i></button>
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>ID</th>
                                    <th>N° Comprobante</th>
                                    <th>Donante</th>
                                    <th>Fecha</th>
                                    <th class="text-center">Artículos</th>
                                    <th class="text-right">Unidades recibidas</th>
                                    <th class="text-center">Estado</th>
                                    <th class="text-center">Acciones</th>
                                </tr>
                            </thead>
                            <tbody id="tablaDonaciones">
                                <tr><td colspan="8" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    let arrayDetalleDonacion = [];

    $(document).ready(function () {
        cargarCombosDonacion();
        listarDonaciones();
    });

    function cargarCombosDonacion() {
        $.post("../controladores/donacionesControlador.jsp", { tipo: "cargarCombosDonacion" }, function (data) {
            let parts = data.split("|||");
            if (parts.length === 2) {
                $("#id_donante").html(parts[0]);
                $("#id_material").html(parts[1]);
            }
        });
    }

    function listarDonaciones() {
        $.post("../controladores/donacionesControlador.jsp", { tipo: "listarDonaciones" }, function (html) {
            $("#tablaDonaciones").html(html);
        });
    }

    // Gestión del detalle de la donación
    function agregarAlDetalleJS() {
        let selectMat = $("#id_material option:selected");
        let valMat = $("#id_material").val();
        if (!valMat) {
            avisar("Seleccione un artículo válido.");
            return;
        }

        let cant = parseFloat($("#cantidad_material").val());
        if (isNaN(cant) || cant <= 0 || !Number.isInteger(cant)) {
            avisar("Ingrese una cantidad entera mayor a cero.");
            return;
        }

        let partes = valMat.split("-");
        let tipo = partes[0];       // R o I
        let id = partes[1];
        let categoria = tipo === "R" ? "Repuesto" : "Insumo";
        let descripcion = selectMat.text();

        arrayDetalleDonacion.push({
            tipo: tipo,
            id: id,
            categoria: categoria,
            descripcion: descripcion,
            cantidad: cant
        });

        dibujarTablaDonacion();
        $("#cantidad_material").val(1);
    }

    function quitarDelDetalleDonacion(index) {
        arrayDetalleDonacion.splice(index, 1);
        dibujarTablaDonacion();
    }

    function dibujarTablaDonacion() {
        let tbody = $("#tbodyDetalleJS");
        tbody.empty();

        if (arrayDetalleDonacion.length === 0) {
            tbody.append("<tr><td colspan='4' class='text-center text-muted py-3'>Ningún artículo agregado.</td></tr>");
            $("#totalUnidades").text("0");
            return;
        }

        let unidades = 0;
        arrayDetalleDonacion.forEach(function (item, index) {
            unidades += item.cantidad;
            tbody.append(
                "<tr>" +
                "<td>" + item.categoria + "</td>" +
                "<td>" + item.descripcion + "</td>" +
                "<td class='text-right'>" + item.cantidad + "</td>" +
                "<td class='text-center'><button class='btn btn-danger btn-sm' onclick='quitarDelDetalleDonacion(" + index + ")'><i class='fas fa-times'></i></button></td>" +
                "</tr>"
            );
        });
        $("#totalUnidades").text(unidades);
    }

    // Registrar la donación
    function registrarDonacionJS() {
        let idDonante = $("#id_donante").val();
        let fechaDonacion = $("#fecha_donacion").val();
        let nroComprobante = $("#nro_comprobante").val().trim();

        if (!idDonante) {
            avisar("Seleccione un donante.");
            return;
        }
        if (!fechaDonacion) {
            avisar("Seleccione la fecha de la donación.");
            return;
        }
        if (arrayDetalleDonacion.length === 0) {
            avisar("Agregue al menos un artículo a la donación.");
            return;
        }

        let datos = {
            tipo: "registrarDonacion",
            idDonante: idDonante,
            nroComprobante: nroComprobante,
            fechaDonacion: fechaDonacion,
            det_count: arrayDetalleDonacion.length
        };

        arrayDetalleDonacion.forEach(function (item, index) {
            datos["det_tipo_" + index] = item.tipo;
            datos["det_id_" + index] = item.id;
            datos["det_cantidad_" + index] = item.cantidad;
        });

        $.post("../controladores/donacionesControlador.jsp", datos, function (resp) {
            let texto = (typeof resp === "string") ? resp.trim() : JSON.stringify(resp);
            if (texto.indexOf("success") === 0) {
                let partes = texto.split("|");
                let numeroGenerado = partes.length > 1 ? partes[1] : "";
                avisar("Donación registrada correctamente (N° " + numeroGenerado + "). El stock fue actualizado.");
                arrayDetalleDonacion = [];
                dibujarTablaDonacion();
                $("#nro_comprobante").val("");
                $("#fecha_donacion").val("");
                $("#id_donante").val("");
                cargarCombosDonacion();
                listarDonaciones();
            } else {
                avisar("No se pudo registrar la donación: " + texto);
            }
        }).fail(function () {
            avisar("Error de comunicación con el servidor.");
        });
    }

    // Imprimir comprobante de donación (PDF formal con membrete)
    function imprimirDonacion(idDonacion) {
        window.open("../controladores/donacionesControlador.jsp?tipo=comprobantePdf&idDonacion=" + idDonacion, "_blank");
    }

    // Anulación de donación (Administrador). El servidor vuelve a validar el rol
    function anularDonacion(idDonacion, nroComprobante) {
        Swal.fire({
            title: "Anular donación " + nroComprobante,
            text: "Se revertirá el stock que esta donación sumó.",
            input: "textarea",
            inputLabel: "Motivo de la anulación (obligatorio)",
            inputAttributes: { "aria-label": "Motivo de la anulación" },
            showCancelButton: true,
            confirmButtonText: "Anular donación",
            cancelButtonText: "Volver",
            inputValidator: function (v) { return (!v || v.trim().length < 5) ? "Escriba un motivo de al menos 5 caracteres" : null; }
        }).then(function (r) {
            if (!r.isConfirmed) { return; }
            $.post("../controladores/donacionesControlador.jsp", { tipo: "anularDonacion", idDonacion: idDonacion, motivo: r.value }, function (resp) {
                if (resp.trim() === "success") {
                    Swal.fire("Donación anulada", "El stock fue revertido.", "success");
                    listarDonaciones();
                } else {
                    Swal.fire("No se pudo anular", resp.replace("error: ", ""), "error");
                }
            }).fail(function (xhr, status, error) {
                Swal.fire("Error de comunicación", String(error), "error");
            });
        });
    }
</script>
