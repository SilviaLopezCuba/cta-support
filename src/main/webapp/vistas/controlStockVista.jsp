<%@page pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>
<%
    // Acceso restringido: solo el rol Administrador puede ver Control de Inventario.
    if (!esAdmin) {
        response.sendRedirect(request.getContextPath() + "/vistas/mantenimientoUnificadoVista.jsp");
        return;
    }
%>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-12"><h1 class="font-weight-bold text-primary"><i class="fas fa-truck-loading"></i> Entradas</h1></div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <ul class="nav nav-pills mb-3">
                <li class="nav-item"><a class="nav-link" href="recepcionesVista.jsp"><i class="fas fa-dolly"></i> Recibir</a></li>
                <li class="nav-item"><a class="nav-link active" href="controlStockVista.jsp"><i class="fas fa-truck"></i> Pedir reposición</a></li>
            </ul>
            <div class="row">
                <div class="col-md-4">
                    <div class="card card-info card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold"><i class="fas fa-file-alt"></i> Datos del Pedido</h3>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label for="selInstitucion" class="text-secondary font-weight-bold">Institución a la que se pide</label>
                                <select class="form-control" id="selInstitucion"></select>
                            </div>
                            <div class="form-group mb-0">
                                <label for="txtObservaciones" class="text-secondary font-weight-bold">Observaciones</label>
                                <textarea class="form-control" id="txtObservaciones" rows="3" placeholder="Opcional"></textarea>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-8">
                    <div class="card card-secondary card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-secondary font-weight-bold"><i class="fas fa-boxes"></i> Artículos a Pedir</h3>
                            <div class="card-tools d-flex align-items-center" style="gap:.75rem;">
                                <div class="custom-control custom-switch">
                                    <input type="checkbox" class="custom-control-input" id="chkSoloFaltantes" onchange="aplicarFiltroFaltantes()">
                                    <label class="custom-control-label small" for="chkSoloFaltantes">Solo bajo el mínimo</label>
                                </div>
                                <input type="text" class="form-control form-control-sm" id="buscarStock" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaStock')" style="width:180px;">
                            </div>
                        </div>
                        <div class="card-body p-0">
                            <div class="table-responsive" style="max-height: 420px;">
                                <table class="table table-bordered table-sm m-0 text-sm tabla-pedido">
                                    <thead class="bg-secondary text-white text-xs">
                                        <tr>
                                            <th class="text-center" style="width:40px;"><input type="checkbox" id="chkMarcarTodos" onchange="marcarTodosItems(this.checked)" title="Marcar/desmarcar todos" aria-label="Marcar todos"></th>
                                            <th>Tipo</th>
                                            <th>Nombre</th>
                                            <th>Marca</th>
                                            <th class="text-right">Stock</th>
                                            <th class="text-right">Mínimo</th>
                                            <th class="text-center">Estado</th>
                                            <th class="text-center">Cantidad a pedir</th>
                                            <th class="d-none">Ajuste</th>
                                        </tr>
                                    </thead>
                                    <tbody id="tablaStock">
                                        <tr><td colspan="9" class="text-center text-muted py-3">Cargando...</td></tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        <div class="card-footer bg-white border-top">
                            <span id="lblSeleccionados" class="text-muted d-inline-block mt-2">0 artículos seleccionados</span>
                            <button type="button" class="btn btn-success float-right font-weight-bold shadow" onclick="generarSolicitud()">
                                <i class="fas fa-check-circle"></i> GENERAR PEDIDO
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card card-success card-outline shadow mt-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-success font-weight-bold"><i class="fas fa-history"></i> Historial de Pedidos</h3>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N° Pedido</th>
                                    <th>Fecha</th>
                                    <th>Solicitado por</th>
                                    <th class="text-center">Artículos</th>
                                    <th class="text-center">Estado</th>
                                    <th class="text-center">Acciones</th>
                                </tr>
                            </thead>
                            <tbody id="tablaHistorial">
                                <tr><td colspan="6" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </section>
</div>
<style>.tabla-pedido td:last-child { display: none; }</style>

<!-- Modal ajuste de inventario -->
<div class="modal fade" id="modalAjuste" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header bg-danger">
                <h5 class="modal-title text-white"><i class="fas fa-exclamation-triangle mr-1"></i> Ajustar Inventario</h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Cerrar"><span>&times;</span></button>
            </div>
            <div class="modal-body">
                <p><b id="ajusteItemNombre"></b></p>
                <div class="form-group" id="grupoStockActual" style="display:none;">
                    <label>Stock actual</label>
                    <input type="text" class="form-control" id="ajusteStockActual" readonly>
                </div>
                <div class="form-group" id="grupoStockNuevo" style="display:none;">
                    <label for="ajusteStockNuevo">Nuevo stock (después del ajuste)</label>
                    <input type="number" class="form-control" id="ajusteStockNuevo" min="0" step="1">
                </div>
                <div class="form-group">
                    <label for="ajusteMotivo">Motivo</label>
                    <select class="form-control" id="ajusteMotivo">
                        <option value="Robo">Robo</option>
                        <option value="Pérdida">Pérdida</option>
                        <option value="Rotura">Rotura / daño irreparable</option>
                        <option value="Corrección de conteo">Corrección de conteo</option>
                        <option value="Otro">Otro</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="ajusteObservaciones">Observaciones</label>
                    <textarea class="form-control" id="ajusteObservaciones" rows="2" placeholder="Detalle lo ocurrido (opcional)"></textarea>
                </div>
                <div class="alert alert-warning py-2 mb-0" id="ajusteAvisoEquipo" style="display:none;">
                    <i class="fas fa-info-circle"></i> El equipo quedará marcado como de baja y no aparecerá disponible para nuevas asistencias.
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-danger" onclick="confirmarAjuste()">Confirmar ajuste</button>
            </div>
        </div>
    </div>
</div>

<!-- Modal recepcion de solicitud -->
<div class="modal fade" id="modalRecepcion" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-success">
                <h5 class="modal-title text-white"><i class="fas fa-truck-loading mr-1"></i> Recibir Solicitud <span id="recepcionNumero"></span></h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Cerrar"><span>&times;</span></button>
            </div>
            <div class="modal-body">
                <div class="form-group">
                    <label for="recNroComprobante">N° de comprobante de lo recibido *</label>
                    <input type="text" class="form-control" id="recNroComprobante" maxlength="50" placeholder="Remisión, nota o factura" style="max-width: 320px;">
                </div>
                <div class="table-responsive">
                    <table class="table table-sm table-bordered">
                        <thead class="bg-light">
                            <tr>
                                <th>Tipo</th>
                                <th>Artículo</th>
                                <th class="text-center">Solicitado</th>
                                <th class="text-center">Ya recibido</th>
                                <th class="text-center">Recibir ahora</th>
                                <th class="text-center">Costo unit. (Gs.)</th>
                            </tr>
                        </thead>
                        <tbody id="tablaRecepcion">
                            <tr><td colspan="6" class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-success" onclick="confirmarRecepcion()">
                    <i class="fas fa-check"></i> Registrar recepción
                </button>
            </div>
        </div>
    </div>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    var CTRL = '<%=request.getContextPath()%>/controladores/controlStockControlador.jsp';
    var ES_ADMIN_STOCK = <%= esAdmin %>;

    // Fase 6: institución destino del pedido; marcar el pedido como enviado
    $(function () {
        $.post(CTRL, { tipo: 'cargarInstituciones' }, function (d) { $('#selInstitucion').html(d); });
        // Los ajustes de inventario son solo del Administrador
        if (!ES_ADMIN_STOCK) {
            $('#tab-ajustes-link').closest('li').hide();
            $(document).ajaxComplete(function () { $('button[onclick^="abrirAjuste"]').hide(); });
        }
    });
    function marcarEnviada(id, numero) {
        confirmar('¿Marcar el pedido ' + numero + ' como enviado a la institución? Imprimí el PDF para enviarlo.', function () {
            $.post(CTRL, { tipo: 'marcarEnviada', idSolicitud: id }, function (r) {
                if (r.trim() === 'success') listarHistorial(); else alert(r.trim());
            });
        }, { si: 'Sí, enviado', title: '¿Pedido enviado?' });
    }

    $(document).ready(function () {
        listarInventario();
        listarHistorial();

        // Contador de seleccionados: delegado, porque las filas se cargan por AJAX
        $('#tablaStock').on('change', '.chk-item', actualizarContador);
    });

    function listarInventario() {
        $('#tablaStock').html('<tr><td colspan="8" class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin"></i> Cargando inventario...</td></tr>');
        $('#chkSoloFaltantes').prop('checked', false);
        $.post(CTRL, {tipo: 'listarInventario'}, function (data) {
            $('#tablaStock').html(data);
            actualizarContador();
        });
    }

    function aplicarFiltroFaltantes() {
        var soloFaltantes = $('#chkSoloFaltantes').is(':checked');
        $('#tablaStock tr.fila-item').each(function () {
            var esFaltante = $(this).data('faltante') === true || $(this).attr('data-faltante') === 'true';
            $(this).toggle(!soloFaltantes || esFaltante);
        });
    }

    function marcarTodosItems(marcar) {
        $('#tablaStock tr.fila-item:visible .chk-item').prop('checked', marcar);
        actualizarContador();
    }

    function actualizarContador() {
        var cant = $('.chk-item:checked').length;
        $('#lblSeleccionados').text(cant + (cant === 1 ? ' artículo seleccionado' : ' artículos seleccionados'));
    }

    function generarSolicitud() {
        var seleccionados = $('.chk-item:checked');
        if (seleccionados.length === 0) {
      alert('Seleccione al menos un articulo para incluir en la solicitud.');
            return;
        }

        if (!$('#selInstitucion').val()) {
            alert('Seleccione la institución a la que se dirige el pedido.');
            return;
        }
        var datos = {
            tipo: 'guardarSolicitud',
            id_donante: $('#selInstitucion').val(),
            observaciones: $('#txtObservaciones').val(),
            det_count: seleccionados.length
        };

        seleccionados.each(function (i) {
            var fila = $(this).closest('tr');
            var cantidad = fila.find('.txt-cantidad').val();
            if (!cantidad || parseFloat(cantidad) <= 0) {
                cantidad = 1;
            }
            datos['det_tipo_' + i] = $(this).data('tipo');
            datos['det_id_' + i] = $(this).data('id');
            datos['det_stock_' + i] = $(this).data('stock');
            datos['det_stockmin_' + i] = $(this).data('stockmin');
            datos['det_cantidad_' + i] = cantidad;
        });

        $.post(CTRL, datos, function (res) {
            res = res.trim();
            if (res.indexOf('success') === 0) {
                var partes = res.split('|');
                var numero = partes.length > 2 ? partes[2] : partes[1];
        alert('Solicitud de reposicion generada: ' + numero);
                $('#txtObservaciones').val('');
                listarInventario();
                $('a[href="#tab-historial"]').tab('show');
                listarHistorial();
            } else {
                alert('No se pudo generar la solicitud: ' + res);
            }
        }).fail(function () {
      alert('Error de conexion al generar la solicitud.');
        });
    }

    function listarHistorial() {
        $('#tablaHistorial').html('<tr><td colspan="6" class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin"></i> Cargando historial...</td></tr>');
        $.post(CTRL, {tipo: 'listarSolicitudes'}, function (data) {
            $('#tablaHistorial').html(data);
        });
    }

    // Anulación de solicitud de compra (Administrador). El servidor vuelve a validar el rol.
    function anularSolicitud(idSolicitud, numero) {
        Swal.fire({
            title: "Anular solicitud " + numero,
            input: "textarea",
            inputLabel: "Motivo de la anulación (obligatorio)",
            inputAttributes: { "aria-label": "Motivo de la anulación" },
            showCancelButton: true,
            confirmButtonText: "Anular solicitud",
            cancelButtonText: "Volver",
            inputValidator: function (v) { return (!v || v.trim().length < 5) ? "Escriba un motivo de al menos 5 caracteres" : null; }
        }).then(function (r) {
            if (!r.isConfirmed) { return; }
            $.post(CTRL, { tipo: "anularSolicitud", idSolicitud: idSolicitud, motivo: r.value }, function (resp) {
                if (resp.trim() === "success") {
                    Swal.fire("Solicitud anulada", "Quedó en estado Cancelada.", "success");
                    listarHistorial();
                } else {
                    Swal.fire("No se pudo anular", resp.replace("error: ", ""), "error");
                }
            }).fail(function (xhr, status, error) {
                Swal.fire("Error de comunicación", String(error), "error");
            });
        });
    }

    function imprimirSolicitud(id) {
        window.open(CTRL + '?tipo=comprobantePdf&idSolicitud=' + id, '_blank');
    }

    function listarEquipos() {
        $('#tablaEquipos').html('<tr><td colspan="7" class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin"></i> Cargando equipos...</td></tr>');
        $.post(CTRL, {tipo: 'listarEquiposStock'}, function (data) {
            $('#tablaEquipos').html(data);
        });
    }

    // Historial de ajustes (Administrador): modificar motivo/observaciones o eliminar el registro.
    // No cambia el stock: es solo el registro de auditoría.
    $(document).on('click', '.btn-edit-ajuste', function () {
        var id = $(this).data('id'), motivoActual = $(this).attr('data-motivo'), obs = $(this).attr('data-obs') || '';
        var opciones = '';
        $('#ajusteMotivo option').each(function () {
            var val = $(this).val();
            opciones += '<option value="' + val + '"' + (val === motivoActual ? ' selected' : '') + '>' + val + '</option>';
        });
        Swal.fire({
            title: 'Modificar ajuste',
            html: '<label for="swMotivo">Motivo</label><select id="swMotivo" class="swal2-select">' + opciones + '</select>' +
                  '<label for="swObs">Observaciones</label><textarea id="swObs" class="swal2-textarea"></textarea>',
            didOpen: function () { document.getElementById('swObs').value = obs; },
            showCancelButton: true,
            confirmButtonText: 'Guardar',
            cancelButtonText: 'Volver',
            preConfirm: function () {
                return { motivo: document.getElementById('swMotivo').value, observaciones: document.getElementById('swObs').value };
            }
        }).then(function (r) {
            if (!r.isConfirmed) { return; }
            $.post(CTRL, { tipo: 'modificarAjuste', idAjuste: id, motivo: r.value.motivo, observaciones: r.value.observaciones }, function (resp) {
                if (resp.trim() === 'success') { listarAjustes(); }
                else { Swal.fire('No se pudo modificar', resp.replace('error: ', ''), 'error'); }
            });
        });
    });

    $(document).on('click', '.btn-del-ajuste', function () {
        var id = $(this).data('id');
        Swal.fire({
            title: '¿Eliminar este registro?',
            text: 'Se borra solo el registro del historial; el stock no se modifica.',
            showCancelButton: true,
            confirmButtonText: 'Eliminar',
            cancelButtonText: 'Volver'
        }).then(function (r) {
            if (!r.isConfirmed) { return; }
            $.post(CTRL, { tipo: 'eliminarAjuste', idAjuste: id }, function (resp) {
                if (resp.trim() === 'success') { listarAjustes(); }
                else { Swal.fire('No se pudo eliminar', resp.replace('error: ', ''), 'error'); }
            });
        });
    });

    function listarAjustes() {
        $('#tablaAjustes').html('<tr><td colspan="8" class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin"></i> Cargando historial...</td></tr>');
        $.post(CTRL, {tipo: 'listarAjustes'}, function (data) {
            $('#tablaAjustes').html(data);
        });
    }

    // tipoItem: 'R' repuesto, 'I' insumo, 'E' equipo. stockActual solo aplica a R/I.
    function abrirAjuste(tipoItem, id, nombre, stockActual) {
        $('#modalAjuste').data('tipoItem', tipoItem).data('id', id);
        $('#ajusteItemNombre').text(nombre);
        $('#ajusteMotivo').val('Robo');
        $('#ajusteObservaciones').val('');

        var esEquipo = (tipoItem === 'E');
        $('#grupoStockActual, #grupoStockNuevo').toggle(!esEquipo);
        $('#ajusteAvisoEquipo').toggle(esEquipo);
        if (!esEquipo) {
            $('#ajusteStockActual').val(stockActual);
            $('#ajusteStockNuevo').val(stockActual);
        }
        $('#modalAjuste').modal('show');
    }

    function confirmarAjuste() {
        var modal = $('#modalAjuste');
        var tipoItem = modal.data('tipoItem');
        var id = modal.data('id');
        var motivo = $('#ajusteMotivo').val();
        var observaciones = $('#ajusteObservaciones').val();

        var datos = {tipo: 'registrarAjuste', tipoItem: tipoItem, idItem: id, motivo: motivo, observaciones: observaciones};

        if (tipoItem !== 'E') {
            var stockNuevo = $('#ajusteStockNuevo').val();
            if (stockNuevo === '' || parseFloat(stockNuevo) < 0) {
                alert('Indique el nuevo stock (0 o mayor).');
                return;
            }
            datos.cantidadNueva = stockNuevo;
        } else {
      confirmar('Confirma dar de baja este equipo por "' + motivo + '"? Esta accion no se puede deshacer desde aqui.',
           enviarAjuste, {peligro: true, si: 'Si, dar de baja', title: 'Dar de baja el equipo?'});
            return;
        }

        enviarAjuste();

        function enviarAjuste() {
        $.post(CTRL, datos, function (res) {
            res = res.trim();
            if (res === 'success') {
                modal.modal('hide');
                if (tipoItem === 'E') {
                    listarEquipos();
                } else {
                    listarInventario();
                }
            } else {
                alert('No se pudo registrar el ajuste: ' + res);
            }
        }).fail(function () {
      alert('Error de conexion al registrar el ajuste.');
        });
            }
    }

    function abrirRecepcion(idSolicitud, numero) {
        $('#modalRecepcion').data('idSolicitud', idSolicitud);
        $('#recepcionNumero').text(numero);
        $('#recNroComprobante').val('');
        $('#tablaRecepcion').html('<tr><td colspan="6" class="text-center text-muted py-3"><i class="fas fa-spinner fa-spin"></i> Cargando...</td></tr>');
        $('#modalRecepcion').modal('show');
        $.post(CTRL, {tipo: 'detalleSolicitud', idSolicitud: idSolicitud}, function (data) {
            $('#tablaRecepcion').html(data);
        });
    }

    function confirmarRecepcion() {
        var idSolicitud = $('#modalRecepcion').data('idSolicitud');
        var filas = $('#tablaRecepcion .txt-recibir-ahora');
        var datos = {tipo: 'registrarRecepcion', idSolicitud: idSolicitud, det_count: filas.length, nroComprobante: $('#recNroComprobante').val()};
        if (!$('#recNroComprobante').val().trim()) {
            alert('Ingrese el número de comprobante de lo que llegó.');
            return;
        }
        var hayCantidad = false;

        filas.each(function (i) {
            var cantidad = $(this).val();
            if (cantidad && parseFloat(cantidad) > 0) { hayCantidad = true; }
            datos['det_tipo_' + i] = $(this).data('tipo');
            datos['det_id_' + i] = $(this).data('id');
            datos['det_cantidad_' + i] = cantidad || 0;
            datos['det_costo_' + i] = $(this).closest('tr').find('.txt-costo-ahora').val() || 0;
        });

        if (!hayCantidad) {
      alert('Indique la cantidad recibida de al menos un articulo.');
            return;
        }

        $.post(CTRL, datos, function (res) {
            res = res.trim();
            if (res.indexOf('success') === 0) {
                var numeroRec = res.split('|')[1];
        alert('Recepción ' + numeroRec + ' registrada. El stock ya se actualizó.');
                $('#modalRecepcion').modal('hide');
                listarHistorial();
                listarInventario();
            } else {
        alert('No se pudo registrar la recepcion: ' + res);
            }
        }).fail(function () {
      alert('Error de conexion al registrar la recepcion.');
        });
    }
</script>
