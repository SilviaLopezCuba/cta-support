<%@page pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>
<%
    // Acceso restringido: solo el rol Administrador puede ver este informe.
    if (!esAdmin) {
        response.sendRedirect(request.getContextPath() + "/vistas/mantenimientoUnificadoVista.jsp");
        return;
    }
%>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-12"><h1>Informe de Pedidos de Reposición</h1></div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <div class="row justify-content-center">
                <div class="col-md-8">
                    <div class="card card-outline card-primary shadow">
                        <div class="card-header p-0 pt-1">
                            <ul class="nav nav-tabs" id="tabsInforme" role="tablist">
                                <li class="nav-item">
                                    <a class="nav-link active" id="tab-general-link" data-toggle="pill" href="#tab-general" role="tab">
                                        <i class="fas fa-calendar-alt mr-1"></i> General (por fechas)
                                    </a>
                                </li>
                                <li class="nav-item">
                                    <a class="nav-link" id="tab-personalizado-link" data-toggle="pill" href="#tab-personalizado" role="tab">
                                        <i class="fas fa-filter mr-1"></i> Personalizado (filtros)
                                    </a>
                                </li>
                            </ul>
                        </div>
                        <div class="card-body">
                            <p class="text-muted">Pedidos de reposición de stock (repuestos e insumos) hechos en el período.</p>

                            <div class="tab-content">
                                <!-- Tab general -->
                                <div class="tab-pane fade show active" id="tab-general" role="tabpanel">
                                    <div class="form-row">
                                        <div class="form-group col-md-6">
                                            <label for="fechaDesde">Fecha Inicio</label>
                                            <input type="date" class="form-control" id="fechaDesde">
                                        </div>
                                        <div class="form-group col-md-6">
                                            <label for="fechaHasta">Fecha Fin</label>
                                            <input type="date" class="form-control" id="fechaHasta">
                                        </div>
                                    </div>
                                    <div class="text-center">
                                        <button type="button" class="btn btn-outline-secondary shadow-sm" onclick="cargarPantalla()" title="Actualizar datos">
                                            <i class="fas fa-sync-alt"></i>
                                        </button>
                                        <button type="button" class="btn btn-primary shadow" onclick="generarInformeGeneral()">
                                            <i class="fas fa-file-pdf"></i> Generar Informe
                                        </button>
                                        <button type="button" class="btn btn-outline-primary shadow-sm" onclick="imprimirDetallado('general')">
                                            <i class="fas fa-print"></i> Imprimir detallado
                                        </button>
                                    </div>
                                </div>

                                <!-- Tab personalizado -->
                                <div class="tab-pane fade" id="tab-personalizado" role="tabpanel">
                                    <div class="form-row">
                                        <div class="form-group col-md-6">
                                            <label for="fp_fechaDesde">Fecha Inicio</label>
                                            <input type="date" class="form-control" id="fp_fechaDesde">
                                        </div>
                                        <div class="form-group col-md-6">
                                            <label for="fp_fechaHasta">Fecha Fin</label>
                                            <input type="date" class="form-control" id="fp_fechaHasta">
                                        </div>
                                    </div>
                                    <div class="form-row">
                                        <div class="form-group col-md-4">
                                            <label for="fp_estado">Estado</label>
                                            <select id="fp_estado" class="form-control">
                                                <option value="">-- Todos --</option>
                                                <option value="Generada">Generada</option>
                                                <option value="Enviada">Enviada</option>
                                                <option value="Recibida parcial">Recibida parcial</option>
                                                <option value="Recibida">Recibida</option>
                                            </select>
                                        </div>
                                        <div class="form-group col-md-4" id="grupoSolicitante">
                                            <label for="fp_solicitante">Solicitante</label>
                                            <select id="fp_solicitante" class="form-control">
                                                <option value="">-- Todos --</option>
                                            </select>
                                        </div>
                                        <div class="form-group col-md-4">
                                            <label for="fp_numeroSolicitud">N Solicitud</label>
                                            <input type="text" class="form-control" id="fp_numeroSolicitud" placeholder="Ej: SR-0001">
                                        </div>
                                    </div>
                                    <div class="text-center">
                                        <button type="button" class="btn btn-outline-secondary shadow-sm" onclick="cargarPantalla()" title="Actualizar datos">
                                            <i class="fas fa-sync-alt"></i>
                                        </button>
                                        <button type="button" class="btn btn-primary shadow" onclick="generarInformePersonalizado()">
                                            <i class="fas fa-file-pdf"></i> Generar Informe Filtrado
                                        </button>
                                        <button type="button" class="btn btn-outline-primary shadow-sm" onclick="imprimirDetallado('personalizado')">
                                            <i class="fas fa-print"></i> Imprimir detallado
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="row">
                <div class="col-12" id="panelResultados"></div>
            </div>
        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    var CTRL = '<%=request.getContextPath()%>/controladores/informeInventario.jsp';
    var xhrDatos = null;
    var temporizador = null;

    $(document).ready(function () {
        var hoy = new Date();
        var primero = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
        $('#fechaDesde, #fp_fechaDesde').val(aTexto(primero));
        $('#fechaHasta, #fp_fechaHasta').val(aTexto(hoy));

        $.get(CTRL, { accion: 'combos' }, function (data) {
            var solicitantes = extraerBloque(data, 'SOLICITANTES');
            if (solicitantes) { $('#fp_solicitante').append(solicitantes); }
        });

        // Al cambiar un filtro, la pantalla se actualiza sola
        $('#tab-general input, #tab-personalizado select, #tab-personalizado input[type=date]').on('change', programarRecarga);
        $('#tab-personalizado input[type=text]').on('input', programarRecarga);
        $('a[data-toggle="pill"]').on('shown.bs.tab', cargarPantalla);

        // Datos al entrar, con el filtro por defecto (mes actual)
        cargarPantalla();
    });

    function extraerBloque(xml, tag) {
        var m = xml.match(new RegExp('<' + tag + '>([\\s\\S]*?)</' + tag + '>'));
        return m ? m[1] : '';
    }

    function aTexto(fecha) {
        var mes = ('0' + (fecha.getMonth() + 1)).slice(-2);
        var dia = ('0' + fecha.getDate()).slice(-2);
        return fecha.getFullYear() + '-' + mes + '-' + dia;
    }

    function programarRecarga() {
        clearTimeout(temporizador);
        temporizador = setTimeout(cargarPantalla, 400);
    }

    function modoActual() {
        return $('#tab-personalizado').hasClass('active') ? 'personalizado' : 'general';
    }

    // Arma los parametros; silencioso = true muestra el aviso en pantalla en vez de alert
    function construirParametros(modo, silencioso) {
        var pre = (modo === 'personalizado') ? 'fp_' : '';
        var desde = $('#' + pre + 'fechaDesde').val();
        var hasta = $('#' + pre + 'fechaHasta').val();
        var error = '';
        if (!desde || !hasta) {
            error = 'Debe indicar Fecha Inicio y Fecha Fin.';
        } else if (desde > hasta) {
            error = 'La Fecha Inicio no puede ser mayor que la Fecha Fin.';
        }
        if (error) {
            if (silencioso) {
                $('#panelResultados').empty();
            } else {
                avisar(error);
            }
            return null;
        }
        var params = new URLSearchParams();
        params.set('modo', modo);
        params.set('fechaInicio', desde);
        params.set('fechaFin', hasta);
        if (modo === 'personalizado') {
            var estado = $('#fp_estado').val();
            var solicitante = $('#fp_solicitante').val();
            var numeroSolicitud = $('#fp_numeroSolicitud').val().trim();

            if (estado) { params.set('estado', estado); }
            if (solicitante) { params.set('idSolicitante', solicitante); }
            if (numeroSolicitud) { params.set('numeroSolicitud', numeroSolicitud); }
        }
        return params;
    }

    function cargarPantalla() {
        var params = construirParametros(modoActual(), true);
        if (params === null) { return; }
        params.set('accion', 'datos');
        if (xhrDatos) { xhrDatos.abort(); }
        $('#panelResultados').html('<div class="text-center text-muted py-4"><i class="fas fa-spinner fa-spin"></i> Cargando datos...</div>');
        xhrDatos = $.get(CTRL, params.toString())
            .done(function (html) { $('#panelResultados').html(html); })
            .fail(function (xhr, estado) {
                if (estado !== 'abort') {
                    $('#panelResultados').empty(); avisar('No se pudieron cargar los datos.', 'error');
                }
            });
    }

    function generarInformeGeneral() { abrir('general', null); }
    function generarInformePersonalizado() { abrir('personalizado', null); }
    function imprimirDetallado(modo) { abrir(modo, 'detalle'); }

    function abrir(modo, accion) {
        var params = construirParametros(modo, false);
        if (params === null) { return; }
        if (accion) { params.set('accion', accion); }
        window.open(CTRL + '?' + params.toString(), '_blank');
    }

    function imprimirRegistro(id) {
        window.open(CTRL + '?accion=comprobante&ids=' + id, '_blank');
    }
    function imprimirSeleccionados() {
        var ids = $('.chk-registro:checked').map(function () { return this.value; }).get();
        if (!ids.length) { avisar('Seleccione al menos un registro.'); return; }
        window.open(CTRL + '?accion=comprobante&ids=' + ids.join(','), '_blank');
    }
    function marcarTodos(chk) {
        $('.chk-registro').prop('checked', chk.checked);
    }
</script>
