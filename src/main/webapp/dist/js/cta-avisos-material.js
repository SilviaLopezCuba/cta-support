/* Campanita de avisos de material (menú superior).
 *  Técnico: tickets sin revisar, pedidos listos para retirar y en espera de stock.
 *  Encargado de depósito y Administrador: "N pedidos por entregar · N ya tienen stock".
 *  Se actualiza al cargar la página y cada minuto. */
(function (window, $) {
    "use strict";
    function item(href, icono, texto, extra) {
        return "<a href='" + href + "' class='dropdown-item'><i class='" + icono + " mr-2'></i>" + texto
             + (extra ? "<span class='float-right text-muted text-sm'>" + extra + "</span>" : "") + "</a><div class='dropdown-divider'></div>";
    }
    function plural(n, uno, varios) { return n + " " + (n === 1 ? uno : varios); }

    function ctaAvisos() {
        var $li = $("#ctaAvisos");
        if (!$li.length) return;
        var ctx = $li.data("ctx") || "", deposito = String($li.data("deposito")) === "1";
        $.post(ctx + "/controladores/materialesControlador.jsp", { tipo: "avisos" }, function (r) {
            if (!r || !r.ok) return;
            var h = "", total = 0, urgente = 0;
            if (deposito && r.deposito) {
                var d = r.deposito, porEntregar = d.nuevos + d.con_stock;
                total += porEntregar;
                if (porEntregar > 0)
                    h += item(ctx + "/vistas/entregasVista.jsp", "fas fa-hand-holding text-primary",
                              plural(porEntregar, "pedido por entregar", "pedidos por entregar"),
                              d.con_stock > 0 ? plural(d.con_stock, "ya tiene stock", "ya tienen stock") : "");
                if (d.sin_stock > 0)
                    h += item(ctx + "/vistas/entregasVista.jsp", "fas fa-hourglass-half text-danger",
                              plural(d.sin_stock, "pedido esperando stock", "pedidos esperando stock"), "");
            }
            if (r.tecnico) {
                var t = r.tecnico, vt = ctx + "/vistas/ordenUnificadaVista.jsp", vm = ctx + "/vistas/mantenimientoUnificadoVista.jsp";
                total += t.listos + (t.sin_revisar || 0); urgente += t.listos;
                if (t.sin_revisar > 0)
                    h += item(vt, "fas fa-exclamation-circle text-danger",
                              plural(t.sin_revisar, "ticket sin revisar", "tickets sin revisar"), "hacé la primera revisión");
                if (t.listos_t > 0)
                    h += item(vt, "fas fa-check-circle text-success",
                              plural(t.listos_t, "pedido listo para retirar", "pedidos listos para retirar") + " (tickets)", "pasá por el depósito");
                if (t.listos_m > 0)
                    h += item(vm, "fas fa-check-circle text-success",
                              plural(t.listos_m, "pedido listo para retirar", "pedidos listos para retirar") + " (mantenimiento)", "pasá por el depósito");
                if (t.espera_t > 0)
                    h += item(vt, "fas fa-hourglass-half text-danger",
                              plural(t.espera_t, "pedido en espera de stock", "pedidos en espera de stock") + " (tickets)", "");
                if (t.espera_m > 0)
                    h += item(vm, "fas fa-hourglass-half text-danger",
                              plural(t.espera_m, "pedido en espera de stock", "pedidos en espera de stock") + " (mantenimiento)", "");
            }
            // Solo se muestra si hay algo para ver
            $li.toggleClass("d-none", h === "");
            if (h === "") return;
            $("#ctaAvisosNum").text(total > 0 ? total : "").toggleClass("badge-success", urgente > 0 && urgente === total).toggleClass("badge-danger", !(urgente > 0 && urgente === total));
            $("#ctaAvisosMenu").html("<span class='dropdown-item dropdown-header'>Material</span><div class='dropdown-divider'></div>"
                                     + h.replace(/<div class='dropdown-divider'><\/div>$/, ""));
        }, "json");
    }
    window.ctaAvisos = ctaAvisos;
    $(function () { ctaAvisos(); setInterval(ctaAvisos, 60000); });
})(window, jQuery);
