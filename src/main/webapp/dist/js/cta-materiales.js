/*
 * CTA Support - Pedido de material al depósito, dentro del ticket o del
 * mantenimiento (formato cabecera-detalle, sin ventana emergente).
 *
 * Uso:
 *   CtaMateriales.montar("#panelPedidoMaterial", "T", alCambiar);   // una vez
 *   CtaMateriales.cargar(idOrden);                                   // al abrir la orden
 *   CtaMateriales.limpiar();                                         // al cerrar la orden
 */
(function (window, $) {
    "use strict";
    var CTRL = "../controladores/materialesControlador.jsp";
    var st = { cont: null, tipoOrden: "T", idOrden: null, alCambiar: null, lineas: [] };

    function esc(t) { return $("<div>").text(t == null ? "" : String(t)).html(); }
    function num(v) { v = (v || "").toString().replace(",", "."); var n = parseFloat(v); return isNaN(n) ? 0 : n; }
    function $q(sel) { return $(st.cont).find(sel); }

    function montar(contenedor, tipoOrden, alCambiar) {
        st.cont = contenedor; st.tipoOrden = tipoOrden; st.alCambiar = alCambiar;
        $(contenedor).html(
            '<div class="card card-info card-outline shadow">' +
            ' <div class="card-header bg-white"><h3 class="card-title text-info font-weight-bold"><i class="fas fa-toolbox"></i> Pedido de Material al Depósito</h3></div>' +
            ' <div class="card-body">' +
            '  <p class="text-muted mb-0 cta-mat-vacio">Abra una orden para pedir material.</p>' +
            '  <div class="cta-mat-cuerpo d-none">' +
            '   <div class="alert alert-warning d-none cta-mat-bloqueo" role="alert"></div>' +
            '   <div class="cta-mat-form">' +
            '    <div class="cta-mat-cab border rounded p-2 mb-3"></div>' +
            '    <div class="row bg-light p-3 mb-3 rounded border">' +
            '     <div class="col-md-8 form-group"><label class="small font-weight-bold">Artículo</label><select class="form-control cta-mat-art" aria-label="Artículo"></select></div>' +
            '     <div class="col-md-4 form-group"><label class="small font-weight-bold">Cantidad</label><input type="number" class="form-control cta-mat-cant" value="1" min="0" step="any" aria-label="Cantidad"></div>' +
            '     <div class="col-md-12"><button type="button" class="btn btn-info btn-block font-weight-bold cta-mat-agregar"><i class="fas fa-plus"></i> Agregar</button></div>' +
            '    </div>' +
            '    <table class="table table-bordered table-sm text-sm"><thead class="bg-secondary text-white text-xs"><tr><th>Artículo</th><th width="100px" class="text-right">Cantidad</th><th width="60px" class="text-center">Quitar</th></tr></thead>' +
            '     <tbody class="cta-mat-detalle"></tbody></table>' +
            '    <div class="d-flex" style="gap:.5rem;"><input type="text" class="form-control cta-mat-obs" maxlength="255" aria-label="Observación del pedido">' +
            '     <button type="button" class="btn btn-success font-weight-bold text-nowrap cta-mat-enviar"><i class="fas fa-paper-plane"></i> ENVIAR PEDIDO</button></div>' +
            '   </div>' +
            '   <p class="text-muted small d-none cta-mat-cerrada">La orden está finalizada: ya no se pide material.</p>' +
            '   <h6 class="font-weight-bold text-secondary border-bottom pb-1 mt-4">Pedidos de esta orden</h6>' +
            '   <table class="table table-sm table-striped text-sm mb-3"><thead class="bg-light"><tr><th>N°</th><th>Fecha</th><th>Artículos</th><th>Estado</th></tr></thead><tbody class="cta-mat-pedidos"></tbody></table>' +
            '   <h6 class="font-weight-bold text-secondary border-bottom pb-1">Material recibido para esta orden</h6>' +
            '   <table class="table table-sm table-striped text-sm m-0"><thead class="bg-light"><tr><th>Artículo</th><th class="text-right">Recibido</th><th class="text-right">Usado</th><th class="text-right">Devuelto</th><th class="text-right">Por usar o devolver</th></tr></thead><tbody class="cta-mat-saldo"></tbody></table>' +
            '  </div>' +
            ' </div>' +
            '</div>');
        $q(".cta-mat-agregar").on("click", agregar);
        $q(".cta-mat-enviar").on("click", enviar);
    }

    function limpiar() {
        st.idOrden = null; st.lineas = [];
        $q(".cta-mat-cuerpo").addClass("d-none");
        $q(".cta-mat-vacio").removeClass("d-none text-danger").addClass("text-muted").text("Abra una orden para pedir material.");
    }

    function dibujarLineas() {
        if (st.lineas.length === 0) { $q(".cta-mat-detalle").html("<tr><td colspan='3' class='text-center text-muted'>Ningún artículo agregado.</td></tr>"); return; }
        var h = "";
        st.lineas.forEach(function (l, i) {
            h += "<tr><td>" + esc(l.nombre) + "</td><td class='text-right'>" + l.cantidad + "</td><td class='text-center'><button type='button' class='btn btn-outline-danger btn-xs' data-i='" + i + "' aria-label='Quitar'><i class='fas fa-times'></i></button></td></tr>";
        });
        $q(".cta-mat-detalle").html(h).find("button").on("click", function () { st.lineas.splice($(this).data("i"), 1); dibujarLineas(); });
    }

    function agregar() {
        var art = $q(".cta-mat-art").val(), cant = num($q(".cta-mat-cant").val());
        if (!art) { alert("Seleccione un artículo."); return; }
        if (cant <= 0) { alert("La cantidad debe ser mayor a cero."); return; }
        var ya = st.lineas.find(function (l) { return l.articulo === art; });
        if (ya) ya.cantidad += cant;
        else st.lineas.push({ articulo: art, cantidad: cant, nombre: $q(".cta-mat-art option:selected").text() });
        $q(".cta-mat-art").val(""); $q(".cta-mat-cant").val(1);
        dibujarLineas();
    }

    function cargar(idOrden) {
        if (!idOrden) { limpiar(); return; }
        if (String(st.idOrden) !== String(idOrden)) st.lineas = [];
        st.idOrden = idOrden;
        $.post(CTRL, { tipo: "saldo", tipo_orden: st.tipoOrden, id_orden: idOrden }, function (r) {
            if (!r.ok) { limpiar(); $q(".cta-mat-vacio").text(r.error); return; }
            $q(".cta-mat-vacio").addClass("d-none");
            $q(".cta-mat-cuerpo").removeClass("d-none");
            $q(".cta-mat-art").html(r.catalogo);
            // Sin revisión no se pide material
            var bloqueado = r.abierta && !r.revisado;
            $q(".cta-mat-bloqueo").toggleClass("d-none", !bloqueado).html(bloqueado ? "<i class='fas fa-lock'></i> " + esc(r.bloqueo) : "");
            $q(".cta-mat-form").toggleClass("d-none", !r.abierta || bloqueado);
            dibujarCabecera(r);
            $q(".cta-mat-cerrada").toggleClass("d-none", !!r.abierta);
            dibujarLineas();

            var p = "";
            r.solicitudes.forEach(function (s) {
                var et = s.estado_tecnico || s.estado;
                var cls = { "Rechazada": "badge-secondary", "Listo para retirar": "badge-success", "En espera de stock": "badge-danger",
                            "Pedido enviado": "badge-warning" }[et] || "badge-light border";
                p += "<tr><td class='text-nowrap'>" + esc(s.numero) + "</td><td class='text-nowrap'>" + esc(s.fecha) + "</td><td>" + esc(s.resumen) + "</td><td><span class='badge " + cls + "'>" + esc(et) + "</span>"
                   + (et === "Listo para retirar" ? "<small class='d-block text-success'>Hay stock: pasá por el depósito.</small>" : "")
                   + (s.motivo_rechazo ? "<small class='d-block text-muted'>" + esc(s.motivo_rechazo) + "</small>" : "") + "</td></tr>";
            });
            $q(".cta-mat-pedidos").html(p || "<tr><td colspan='4' class='text-center text-muted'>Sin pedidos.</td></tr>");

            var f = "";
            r.items.forEach(function (it) {
                f += "<tr><td>" + esc(it.nombre) + "</td><td class='text-right'>" + esc(it.entregado) + "</td><td class='text-right'>" + esc(it.usado) + "</td><td class='text-right'>" + esc(it.devuelto)
                   + "</td><td class='text-right font-weight-bold" + (it.saldo_num > 0 ? " text-danger" : "") + "'>" + esc(it.saldo) + "</td></tr>";
            });
            $q(".cta-mat-saldo").html(f || "<tr><td colspan='5' class='text-center text-muted'>Todavía no recibió material.</td></tr>");
        }, "json").fail(function (xhr) {
            limpiar();
            var txt = $.trim(xhr.responseText || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").substring(0, 200);
            $q(".cta-mat-vacio").removeClass("text-muted").addClass("text-danger").text(
                xhr.status === 403 || xhr.status === 401
                    ? "No se pudo cargar el pedido de material: su usuario no tiene permiso para esta función (" + xhr.status + "). Avise al Administrador."
                    : "No se pudo cargar el pedido de material" + (xhr.status ? " (" + xhr.status + ")" : "") + (txt ? ": " + txt : "."));
        });
    }

    // Cabecera del pedido: urgencia, equipo (mantenimiento) y cómo queda la orden mientras llega
    function dibujarCabecera(r) {
        var n = "cta-mat-queda-" + st.tipoOrden, h = "";
        if (st.tipoOrden === "T") {
            var p = r.prioridad === "Critica" ? "Crítica" : (r.prioridad || "-");
            h += "<div class='small mb-2'><b>Urgencia:</b> <span class='badge badge-" + ({ "Critica": "danger", "Alta": "warning", "Media": "info" }[r.prioridad] || "secondary")
               + "'>" + esc(p) + "</span> <span class='text-muted'>(la del ticket; el depósito atiende primero lo más urgente)</span></div>";
        } else {
            var eq = "<option value=''>-- ¿Para qué equipo? --</option>";
            (r.equipos || []).forEach(function (e) { eq += "<option value='" + e.id + "'>" + esc(e.texto) + "</option>"; });
            h += "<div class='form-row'><div class='col-md-7 form-group mb-2'><label class='small font-weight-bold'>Equipo <span class='text-danger'>*</span></label><select class='form-control form-control-sm cta-mat-equipo'>" + eq + "</select></div>"
               + "<div class='col-md-5 form-group mb-2'><label class='small font-weight-bold'>Urgencia <span class='text-danger'>*</span></label><select class='form-control form-control-sm cta-mat-prio'>"
               + "<option value=''>-- Elegir --</option><option value='Normal'>Normal</option><option value='Urgente'>Urgente</option></select></div></div>";
        }
        h += "<span class='small font-weight-bold d-block'>Mientras llega el material, " + (st.tipoOrden === "T" ? "el ticket" : "el mantenimiento") + "... <span class='text-danger'>*</span></span>"
           + "<div class='custom-control custom-radio custom-control-inline'><input type='radio' class='custom-control-input' name='" + n + "' id='" + n + "-s' value='sigue'><label class='custom-control-label font-weight-normal' for='" + n + "-s'>"
           + (st.tipoOrden === "T" ? "Sigo trabajando" : "Sigo con los demás equipos") + "</label></div>"
           + "<div class='custom-control custom-radio custom-control-inline'><input type='radio' class='custom-control-input' name='" + n + "' id='" + n + "-d' value='detenido'><label class='custom-control-label font-weight-normal' for='" + n + "-d'>"
           + "Queda detenido hasta que llegue</label></div>";
        $q(".cta-mat-cab").html(h);
        $q(".cta-mat-obs").attr("placeholder", st.tipoOrden === "M" ? "Qué tiene el equipo (obligatorio)" : "Observación (opcional)");
    }

    function enviar() {
        if (!st.idOrden) return;
        if (st.lineas.length === 0) { alert("Agregue al menos un artículo."); return; }
        var queda = $q(".cta-mat-cab input[type=radio]:checked").val();
        if (st.tipoOrden === "M") {
            if (!$q(".cta-mat-equipo").val()) { alert("Indicá para qué equipo es el material."); return; }
            if (!$q(".cta-mat-prio").val()) { alert("Indicá la urgencia del pedido: Normal o Urgente."); return; }
            if ($.trim($q(".cta-mat-obs").val()).length < 5) { alert("Escribí qué tiene el equipo (al menos 5 caracteres)."); return; }
        }
        if (!queda) { alert("Indicá cómo queda la orden mientras llega el material."); return; }
        var datos = { tipo_orden: st.tipoOrden, id_orden: st.idOrden, observacion: $q(".cta-mat-obs").val(), queda: queda,
                      prioridad: $q(".cta-mat-prio").val() || "", id_equipo: parseInt($q(".cta-mat-equipo").val() || "0", 10),
                      items: st.lineas.map(function (l) { return { articulo: l.articulo, cantidad: l.cantidad }; }) };
        $q(".cta-mat-enviar").prop("disabled", true);
        $.post(CTRL, { tipo: "solicitar", datos: JSON.stringify(datos) }, function (res) {
            $q(".cta-mat-enviar").prop("disabled", false);
            res = $.trim(res);
            if (res === "success") {
                st.lineas = []; $q(".cta-mat-obs").val("");
                if (typeof window.avisar === "function") window.avisar("success", "Pedido enviado al depósito.");
                cargar(st.idOrden);
                if (st.alCambiar) st.alCambiar();
            } else alert(res);
        }).fail(function () { $q(".cta-mat-enviar").prop("disabled", false); });
    }

    window.CtaMateriales = { montar: montar, cargar: cargar, limpiar: limpiar };
})(window, jQuery);
