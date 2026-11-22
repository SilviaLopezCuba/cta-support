<%@page pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-12"><h1>Informe de Donaciones Recibidas</h1></div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <div class="row justify-content-center">
                <div class="col-md-6">
                    <div class="card card-outline card-warning shadow">
                        <div class="card-header">
                            <h3 class="card-title">
                                <i class="fas fa-hand-holding-heart mr-1"></i> Donaciones
                            </h3>
                        </div>
                        <div class="card-body">
                            <p class="text-muted">Donaciones recibidas con su donante, comprobante y cantidad de artículos.</p>
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
                        </div>
                        <div class="card-footer text-center">
                            <button type="button" class="btn btn-outline-secondary shadow-sm" onclick="cargarPantalla()" title="Actualizar datos">
                                            <i class="fas fa-sync-alt"></i>
                                        </button>
                                        <button type="button" class="btn btn-warning shadow" onclick="generarInformeGeneral()">
                                            <i class="fas fa-file-pdf"></i> Generar Informe
                                        </button>
                                        <button type="button" class="btn btn-outline-warning shadow-sm" onclick="imprimirDetallado('general')">
                                            <i class="fas fa-print"></i> Imprimir detallado
                                        </button>
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
    var CTRL = '<%=request.getContextPath()%>/controladores/informeDonaciones.jsp';
    var xhrDatos = null;
    var temporizador = null;

    $(document).ready(function () {
        var hoy = new Date();
        var primero = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
        $('#fechaDesde').val(aTexto(primero));
        $('#fechaHasta').val(aTexto(hoy));

        // Al cambiar un filtro, la pantalla se actualiza sola
        $('#fechaDesde, #fechaHasta').on('change', programarRecarga);
        $('#noexiste').on('input', programarRecarga);
        $('a[data-toggle="pill"]').on('shown.bs.tab', cargarPantalla);

        // Datos al entrar, con el filtro por defecto (mes actual)
        cargarPantalla();
    });

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

    // Impresion individual / por seleccion (comprobante detallado en PDF)
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
