<%@page pageEncoding="UTF-8"%>
<%@include file="../includes/header.jsp" %>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2"><div class="col-sm-12"><h1>Informe de Material para Técnicos</h1></div></div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <div class="row justify-content-center"><div class="col-lg-10">
                    <div class="card card-outline card-info shadow informe-panel" data-ctrl="informeMaterial" data-sinfechas="0" data-pre="">
                        <div class="card-header"><h3 class="card-title"><i class="fas fa-toolbox mr-1"></i> Material para técnicos</h3></div>
                        <div class="card-body pb-1">
                            <p class="text-muted mb-2">Pedidos de material de los técnicos: estado, urgencia, días de espera y lo entregado.</p>
                            <div class="form-row">
                                <div class="form-group col-md-3"><label for="fechaDesde">Fecha Inicio</label><input type="date" class="form-control fecha" id="fechaDesde"></div>
                                <div class="form-group col-md-3"><label for="fechaHasta">Fecha Fin</label><input type="date" class="form-control fecha" id="fechaHasta"></div>
                                <div class="form-group col-md-3"><label for="estado">Estado</label><select class="form-control filtro" id="estado" data-p="estado"><option value=''>-- Todos --</option><option value='Pendiente'>Pendiente</option><option value='En espera'>En espera</option><option value='Entregada'>Entregada</option><option value='Entregada parcial'>Entregada parcial</option><option value='Rechazada'>Rechazada</option></select></div>
                                <div class="form-group col-md-3"><label for="prioridad">Urgencia</label><select class="form-control filtro" id="prioridad" data-p="prioridad"><option value=''>-- Todos --</option><option value='Critica'>Crítica</option><option value='Alta'>Alta</option><option value='Media'>Media</option><option value='Baja'>Baja</option><option value='Urgente'>Urgente</option><option value='Normal'>Normal</option></select></div>
                                <div class="form-group col-md-3"><label for="tipoOrden">Orden</label><select class="form-control filtro" id="tipoOrden" data-p="tipoOrden"><option value=''>-- Todos --</option><option value='T'>Tickets</option><option value='M'>Mantenimientos</option></select></div>
                                <% if (!"Técnico".equals(session.getAttribute("nombreRol"))) { %><div class="form-group col-md-3"><label for="idUsuario">Técnico</label><select class="form-control filtro combo" id="idUsuario" data-p="idUsuario"><option value="">-- Todos --</option></select></div><% } %>
                            </div>
                        </div>
                        <div class="card-footer text-center">
                            <button type="button" class="btn btn-outline-secondary shadow-sm" onclick="cargarPantalla('informeMaterial')" title="Actualizar datos"><i class="fas fa-sync-alt"></i></button>
                            <button type="button" class="btn btn-info shadow" onclick="abrir('informeMaterial', null)"><i class="fas fa-file-pdf"></i> Generar Informe</button>
                            <button type="button" class="btn btn-outline-info shadow-sm" onclick="abrir('informeMaterial', 'detalle')"><i class="fas fa-print"></i> Imprimir detallado</button>
                        </div>
                    </div>
                </div></div>
            <div class="row"><div class="col-12" id="res_informeMaterial"></div></div>
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
