<footer class="main-footer">
    <div class="float-right d-none d-sm-inline">
        Soporte Técnico Especializado
    </div>
    <strong>Copyright &copy; 2025-2026 CTA SUPPORT.</strong> Todos los derechos reservados.
</footer>

</div>
<script src="<%=request.getContextPath()%>/plugins/bootstrap/js/bootstrap.bundle.min.js"></script>
<script src="<%=request.getContextPath()%>/dist/js/adminlte.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/sweetalert2/sweetalert2.all.min.js"></script>
<script src="<%=request.getContextPath()%>/dist/js/avisos.js"></script>
<script src="<%=request.getContextPath()%>/dist/js/cta-avisos-material.js"></script>

<script src="<%=request.getContextPath()%>/plugins/datatables/jquery.dataTables.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/datatables-bs4/js/dataTables.bootstrap4.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/datatables-responsive/js/dataTables.responsive.min.js"></script>

<script src="<%=request.getContextPath()%>/plugins/datatables-buttons/js/dataTables.buttons.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/datatables-buttons/js/buttons.bootstrap4.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/jszip/jszip.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/pdfmake/pdfmake.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/pdfmake/vfs_fonts.js"></script>
<script src="<%=request.getContextPath()%>/plugins/datatables-buttons/js/buttons.html5.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/datatables-buttons/js/buttons.print.min.js"></script>
<script src="<%=request.getContextPath()%>/plugins/datatables-buttons/js/buttons.colVis.min.js"></script>

<script>
    $(document).ready(function () {
        var url = window.location;
        $('ul.nav-sidebar a').filter(function () {
            return this.href == url;
        }).addClass('active');

        $('ul.nav-treeview a').filter(function () {
            return this.href == url;
        }).parentsUntil(".nav-sidebar > .nav-item").addClass('menu-open').prev('a').addClass('active');
    });

    // Tablas con scroll horizontal en pantallas angostas: envuelve en
    // .table-responsive las que todavía no lo están, para que los botones
    // de acción (Editar / Eliminar / PDF) no queden cortados.
    $(function () {
        $(".content-wrapper table").each(function () {
            if (!$(this).closest(".table-responsive, .dataTables_wrapper").length) {
                $(this).wrap('<div class="table-responsive"></div>');
            }
        });
    });

    // Aviso cuando header.jsp redirige por falta de permisos sobre una vista.
    $(function () {
        if (/[?&]acceso=denegado\b/.test(window.location.search) && typeof avisar === "function") {
            avisar("warning", "No tiene permiso para abrir esa pantalla.");
            if (window.history && history.replaceState) {
                history.replaceState(null, "", window.location.pathname);
            }
        }
    });

    // Filtro de búsqueda para las tablas de Referenciales.
    // Oculta las filas de <tbody id="tbodyId"> cuyo texto no contenga "valor".
    function filtrarTabla(valor, tbodyId) {
        var filtro = valor.toLowerCase();
        var filas = document.querySelectorAll('#' + tbodyId + ' tr:not(.cta-nomatch-row):not(.cta-empty-row)');
        filas.forEach(function (fila) {
            var texto = fila.textContent.toLowerCase();
            fila.style.display = texto.indexOf(filtro) > -1 ? '' : 'none';
        });
        var cuerpo = document.getElementById(tbodyId);
        if (cuerpo && window.CTA && CTA.mensajeSinCoincidencias) { CTA.mensajeSinCoincidencias(cuerpo); }
    }
</script>

<script>
    // Forzar que los submenús NO se cierren entre sí (AdminLTE ignora data-accordion="false")
    $(document).ready(function () {
        $('[data-widget="treeview"]').each(function () {
            var api = $(this).data('lte.treeview');
            if (api && api._config) {
                api._config.accordion = false;
            }
        });
    });
</script>
</body>
</html>
