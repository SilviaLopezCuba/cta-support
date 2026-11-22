<%@page pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2"><div class="col-sm-12"><h1>Informe de Existencias y Movimientos</h1></div></div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <ul class="nav nav-pills mb-3" role="tablist"><li class="nav-item"><a class="nav-link active" data-toggle="pill" href="#tab_informeExistencias" role="tab" data-ctrl="informeExistencias"><i class="fas fa-warehouse mr-1"></i> Existencias</a></li><li class="nav-item"><a class="nav-link" data-toggle="pill" href="#tab_informeMovimientosStock" role="tab" data-ctrl="informeMovimientosStock"><i class="fas fa-exchange-alt mr-1"></i> Movimientos</a></li></ul>
            <div class="tab-content"><div class="tab-pane fade show active" id="tab_informeExistencias" role="tabpanel">
                    <div class="row justify-content-center"><div class="col-lg-10"><div class="card card-outline card-primary shadow informe-panel" data-ctrl="informeExistencias" data-sinfechas="1" data-pre="informeExistencias_">
                        <div class="card-header"><h3 class="card-title"><i class="fas fa-warehouse mr-1"></i> Existencias</h3></div>
                        <div class="card-body pb-1">
                            <p class="text-muted mb-2">Stock actual de repuestos e insumos, lo que está bajo el mínimo y el valor del depósito.</p>
                            <div class="form-row">
                                
                                <div class="form-group col-md-3"><label for="informeExistencias_tipo">Tipo</label><select class="form-control filtro" id="informeExistencias_tipo" data-p="tipo"><option value=''>-- Todos --</option><option value='Repuesto'>Repuesto</option><option value='Insumo'>Insumo</option></select></div>
                                <div class="form-group col-md-3"><label for="informeExistencias_situacion">Situación</label><select class="form-control filtro" id="informeExistencias_situacion" data-p="situacion"><option value=''>-- Todos --</option><option value='Sin stock'>Sin stock</option><option value='Bajo mínimo'>Bajo mínimo</option><option value='Normal'>Normal</option></select></div>
                                <div class="form-group col-md-3"><label for="informeExistencias_articulo">Artículo contiene</label><input type="text" class="form-control filtro" id="informeExistencias_articulo" data-p="articulo" maxlength="60"></div>
                            </div>
                        </div>
                        <div class="card-footer text-center">
                            <button type="button" class="btn btn-outline-secondary shadow-sm" onclick="cargarPantalla('informeExistencias')" title="Actualizar datos"><i class="fas fa-sync-alt"></i></button>
                            <button type="button" class="btn btn-primary shadow" onclick="abrir('informeExistencias', null)"><i class="fas fa-file-pdf"></i> Generar Informe</button>
                            
                        </div>
                    </div></div></div>
                    <div class="row"><div class="col-12" id="res_informeExistencias"></div></div>
                </div><div class="tab-pane fade" id="tab_informeMovimientosStock" role="tabpanel">
                    <div class="row justify-content-center"><div class="col-lg-10"><div class="card card-outline card-primary shadow informe-panel" data-ctrl="informeMovimientosStock" data-sinfechas="0" data-pre="informeMovimientosStock_">
                        <div class="card-header"><h3 class="card-title"><i class="fas fa-exchange-alt mr-1"></i> Movimientos</h3></div>
                        <div class="card-body pb-1">
                            <p class="text-muted mb-2">Todo lo que entró y salió del depósito en el período: entradas, entregas, devoluciones y ajustes.</p>
                            <div class="form-row">
                                <div class="form-group col-md-3"><label for="informeMovimientosStock_fechaDesde">Fecha Inicio</label><input type="date" class="form-control fecha" id="informeMovimientosStock_fechaDesde"></div>
                                <div class="form-group col-md-3"><label for="informeMovimientosStock_fechaHasta">Fecha Fin</label><input type="date" class="form-control fecha" id="informeMovimientosStock_fechaHasta"></div>
                                <div class="form-group col-md-3"><label for="informeMovimientosStock_movimiento">Movimiento</label><select class="form-control filtro" id="informeMovimientosStock_movimiento" data-p="movimiento"><option value=''>-- Todos --</option><option value='ENTRADA'>Entrada por recepción</option><option value='ENTREGA'>Entrega a técnico</option><option value='DEVOLUCION'>Devolución del técnico</option><option value='AJUSTE'>Ajuste de inventario</option><option value='SALDO INICIAL'>Saldo inicial</option></select></div>
                                <div class="form-group col-md-3"><label for="informeMovimientosStock_tipoArticulo">Tipo</label><select class="form-control filtro" id="informeMovimientosStock_tipoArticulo" data-p="tipoArticulo"><option value=''>-- Todos --</option><option value='R'>Repuesto</option><option value='I'>Insumo</option></select></div>
                                <div class="form-group col-md-3"><label for="informeMovimientosStock_articulo">Artículo contiene</label><input type="text" class="form-control filtro" id="informeMovimientosStock_articulo" data-p="articulo" maxlength="60"></div>
                            </div>
                        </div>
                        <div class="card-footer text-center">
                            <button type="button" class="btn btn-outline-secondary shadow-sm" onclick="cargarPantalla('informeMovimientosStock')" title="Actualizar datos"><i class="fas fa-sync-alt"></i></button>
                            <button type="button" class="btn btn-primary shadow" onclick="abrir('informeMovimientosStock', null)"><i class="fas fa-file-pdf"></i> Generar Informe</button>
                            
                        </div>
                    </div></div></div>
                    <div class="row"><div class="col-12" id="res_informeMovimientosStock"></div></div>
                </div></div>
        </div>
    </section>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    // Cada panel (.informe-panel) tiene su controlador: carga los datos en pantalla al entrar y al cambiar un filtro.
    var BASE = '<%=request.getContextPath()%>/controladores/';
    var xhrDatos = {}, temporizador = null, ctrlActivo = null;

    $(document).ready(function () {
        var hoy = new Date(), primero = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
        $('.fecha[id$="fechaDesde"]').val(aTexto(primero));
        $('.fecha[id$="fechaHasta"]').val(aTexto(hoy));
        // Opciones de los combos que vienen de la base
        $('.informe-panel').each(function () {
            var n = $(this).data('ctrl'), $p = $(this);
            if ($p.find('.combo').length) {
                $.getJSON(BASE + n + '.jsp', { accion: 'combos' }, function (r) {
                    $p.find('.combo').each(function () { if (r[$(this).data('p')]) $(this).html(r[$(this).data('p')]); });
                });
            }
        });
        $('.informe-panel').on('change', '.fecha, select.filtro, input[type=checkbox].filtro', function () { programarRecarga($(this).closest('.informe-panel').data('ctrl')); });
        $('.informe-panel').on('input', 'input[type=text].filtro', function () { programarRecarga($(this).closest('.informe-panel').data('ctrl')); });
        $('a[data-toggle="pill"]').on('shown.bs.tab', function () { cargarPantalla($(this).data('ctrl')); });
        cargarPantalla($('.informe-panel').first().data('ctrl'));
    });

    function aTexto(f) { return f.getFullYear() + '-' + ('0' + (f.getMonth() + 1)).slice(-2) + '-' + ('0' + f.getDate()).slice(-2); }
    function programarRecarga(n) { clearTimeout(temporizador); temporizador = setTimeout(function () { cargarPantalla(n); }, 400); }

    function construirParametros(n, silencioso) {
        var $p = $('.informe-panel[data-ctrl="' + n + '"]'), pre = $p.data('pre');
        var params = new URLSearchParams();
        if (String($p.data('sinfechas')) !== '1') {
            var desde = $('#' + pre + 'fechaDesde').val(), hasta = $('#' + pre + 'fechaHasta').val(), error = '';
            if (!desde || !hasta) error = 'Debe indicar Fecha Inicio y Fecha Fin.';
            else if (desde > hasta) error = 'La Fecha Inicio no puede ser mayor que la Fecha Fin.';
            if (error) { if (silencioso) $('#res_' + n).empty(); else avisar(error); return null; }
            params.set('fechaInicio', desde);
            params.set('fechaFin', hasta);
        }
        $p.find('.filtro').each(function () {
            var v = this.type === 'checkbox' ? (this.checked ? '1' : '') : $.trim($(this).val() || '');
            if (v) params.set($(this).data('p'), v);
        });
        return params;
    }

    function cargarPantalla(n) {
        ctrlActivo = n;
        var params = construirParametros(n, true);
        if (params === null) return;
        params.set('accion', 'datos');
        if (xhrDatos[n]) xhrDatos[n].abort();
        $('#res_' + n).html('<div class="text-center text-muted py-4"><i class="fas fa-spinner fa-spin"></i> Cargando datos...</div>');
        xhrDatos[n] = $.get(BASE + n + '.jsp', params.toString())
            .done(function (html) {
                if ($.trim(html).indexOf('error') === 0) { $('#res_' + n).html('<div class="alert alert-warning">' + $('<div>').text(html).html() + '</div>'); return; }
                $('#res_' + n).html(html);
            })
            .fail(function (xhr, estado) { if (estado !== 'abort') { $('#res_' + n).empty(); avisar('No se pudieron cargar los datos.', 'error'); } });
    }

    function abrir(n, accion) {
        var params = construirParametros(n, false);
        if (params === null) return;
        if (accion) params.set('accion', accion);
        window.open(BASE + n + '.jsp?' + params.toString(), '_blank');
    }

    // Impresión individual / por selección (comprobante detallado en PDF)
    function imprimirRegistro(id) { window.open(BASE + ctrlActivo + '.jsp?accion=comprobante&ids=' + id, '_blank'); }
    function imprimirSeleccionados() {
        var ids = $('#res_' + ctrlActivo + ' .chk-registro:checked').map(function () { return this.value; }).get();
        if (!ids.length) { avisar('Seleccione al menos un registro.'); return; }
        window.open(BASE + ctrlActivo + '.jsp?accion=comprobante&ids=' + ids.join(','), '_blank');
    }
    function marcarTodos(chk) { $('#res_' + ctrlActivo + ' .chk-registro').prop('checked', chk.checked); }
</script>
