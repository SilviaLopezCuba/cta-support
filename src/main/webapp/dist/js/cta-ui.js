/* CTA SUPPORT - utilidades de interfaz: skeletons de carga y mejoras de accesibilidad.
   JavaScript puro (sin jQuery) para poder cargarse desde el <head>. */
(function () {
    "use strict";

    var CTA = window.CTA = window.CTA || {};
    var root = document.documentElement;

    /* Skeletons */
    function resolve(target) {
        return typeof target === "string" ? document.querySelector(target) : target;
    }

    CTA.skeleton = {
        /* Muestra filas de esqueleto dentro de un <tbody> (o un bloque en cualquier otro contenedor)
           mientras llega la respuesta AJAX. Se limpia solo cuando la vista reemplaza el contenido. */
        show: function (target, rows) {
            var el = resolve(target);
            if (!el) { return; }
            rows = rows || 4;
            el.setAttribute("aria-busy", "true");
            var html = "";
            if (el.tagName === "TBODY") {
                var table = el.closest("table");
                var cols = table && table.tHead && table.tHead.rows[0] ? table.tHead.rows[0].cells.length : 1;
                for (var i = 0; i < rows; i++) {
                    html += '<tr class="cta-skeleton-tr" aria-hidden="true"><td colspan="' + cols +
                            '"><span class="cta-skeleton"></span></td></tr>';
                }
            } else {
                el.classList.add("cta-skeleton-host");
                for (var j = 0; j < rows; j++) {
                    html += '<span class="cta-skeleton cta-skeleton-text" aria-hidden="true" style="margin-bottom:.5rem"></span>';
                }
            }
            el.innerHTML = html;
        },
        /* Quita el estado de carga. Llamar al terminar de pintar el contenido real. */
        hide: function (target) {
            var el = resolve(target);
            if (!el) { return; }
            el.removeAttribute("aria-busy");
            el.classList.remove("cta-skeleton-host");
        }
    };

    /* Carga inicial de la página: el skeleton lo dibuja el CSS (html.cta-loading). */
    function finishLoading() {
        root.classList.remove("cta-loading");
        var busy = document.querySelectorAll("[aria-busy='true']");
        for (var i = 0; i < busy.length; i++) {
            if (!busy[i].querySelector(".cta-skeleton-tr, .cta-skeleton")) { busy[i].removeAttribute("aria-busy"); }
        }
    }
    window.addEventListener("load", function () { setTimeout(finishLoading, 0); });
    setTimeout(finishLoading, 8000); /* red de seguridad: nunca dejar la pantalla oculta */

    /* Accesibilidad */
    var uid = 0;
    function ensureId(el, prefix) {
        if (!el.id) { el.id = prefix + "-" + (++uid); }
        return el.id;
    }
    function textOf(el) { return (el.textContent || "").replace(/\s+/g, " ").trim(); }

    function enhance(scope) {
        scope = scope || document;
        var i, el, list;

        /* Íconos decorativos: fuera del árbol de accesibilidad. */
        list = scope.querySelectorAll("i.fas, i.far, i.fab, i.fa");
        for (i = 0; i < list.length; i++) {
            if (!list[i].hasAttribute("aria-hidden")) { list[i].setAttribute("aria-hidden", "true"); }
        }

        /* Botones/enlaces que solo tienen ícono: nombre accesible tomado de title. */
        list = scope.querySelectorAll("button, a.btn, a.nav-link");
        for (i = 0; i < list.length; i++) {
            el = list[i];
            if (!el.hasAttribute("aria-label") && !el.hasAttribute("aria-labelledby") && !textOf(el) && el.title) {
                el.setAttribute("aria-label", el.title);
            }
            if (el.tagName === "BUTTON" && !el.hasAttribute("type")) { el.setAttribute("type", "button"); }
        }

        /* Encabezados de tabla con alcance de columna. */
        list = scope.querySelectorAll("thead th:not([scope])");
        for (i = 0; i < list.length; i++) { list[i].setAttribute("scope", "col"); }

        /* Tablas sin nombre: usar el título de su tarjeta. */
        list = scope.querySelectorAll("table:not([aria-label]):not([aria-labelledby])");
        for (i = 0; i < list.length; i++) {
            el = list[i];
            if (el.caption) { continue; }
            var card = el.closest(".card");
            var title = card && card.querySelector(".card-title, h3, h2");
            if (title) { el.setAttribute("aria-labelledby", ensureId(title, "cta-t")); }
        }

        /* Campos de formulario sin etiqueta: usar placeholder o title como nombre accesible. */
        list = scope.querySelectorAll("input:not([type=hidden]):not([type=submit]):not([type=button]), select, textarea");
        for (i = 0; i < list.length; i++) {
            el = list[i];
            if (el.hasAttribute("aria-label") || el.hasAttribute("aria-labelledby")) { continue; }
            if (el.id && document.querySelector('label[for="' + el.id + '"]')) { continue; }
            if (el.closest("label")) { continue; }
            var name = el.getAttribute("placeholder") || el.title;
            if (!name) {
                var group = el.closest(".form-group");
                var lab = group && group.querySelector("label");
                if (lab) { lab.setAttribute("for", ensureId(el, "cta-f")); continue; }
            }
            if (name) { el.setAttribute("aria-label", name); }
        }

        /* Modales de Bootstrap: rol y título asociado. */
        list = scope.querySelectorAll(".modal");
        for (i = 0; i < list.length; i++) {
            el = list[i];
            if (!el.hasAttribute("role")) { el.setAttribute("role", "dialog"); }
            if (!el.hasAttribute("aria-labelledby")) {
                var mt = el.querySelector(".modal-title");
                if (mt) { el.setAttribute("aria-labelledby", ensureId(mt, "cta-m")); }
            }
        }
    }

    function landmarks() {
        var main = document.querySelector(".content-wrapper");
        if (main) {
            if (!main.id) { main.id = "contenido-principal"; }
            main.setAttribute("role", "main");
            main.setAttribute("tabindex", "-1");
        }
        var top = document.querySelector("nav.main-header");
        if (top && !top.hasAttribute("aria-label")) { top.setAttribute("aria-label", "Barra superior"); }
        var side = document.querySelector(".main-sidebar nav");
        if (side && !side.hasAttribute("aria-label")) { side.setAttribute("aria-label", "Menú principal"); }
        var foot = document.querySelector("footer.main-footer");
        if (foot) { foot.setAttribute("role", "contentinfo"); }

        /* Menús desplegables del sidebar: son enlaces "#" que actúan como botones. */
        var toggles = document.querySelectorAll(".nav-sidebar > .nav-item > a.nav-link[href='#']");
        for (var i = 0; i < toggles.length; i++) {
            (function (a) {
                a.setAttribute("role", "button");
                var item = a.parentNode;
                function sync() { a.setAttribute("aria-expanded", item.classList.contains("menu-open") ? "true" : "false"); }
                sync();
                new MutationObserver(sync).observe(item, { attributes: true, attributeFilter: ["class"] });
            })(toggles[i]);
        }
        var current = document.querySelector(".nav-sidebar a.nav-link.active");
        if (current) { current.setAttribute("aria-current", "page"); }

        /* Título de pestaña descriptivo: "<encabezado de la vista> | CTA SUPPORT". */
        var h1 = document.querySelector(".content-header h1, h1");
        if (h1 && textOf(h1)) { document.title = textOf(h1) + " | CTA SUPPORT"; }
    }

    function skipLink() {
        var target = document.getElementById("contenido-principal");
        if (!target || document.querySelector(".cta-skip-link")) { return; }
        var a = document.createElement("a");
        a.className = "cta-skip-link";
        a.href = "#contenido-principal";
        a.textContent = "Saltar al contenido principal";
        document.body.insertBefore(a, document.body.firstChild);
    }


    /* Skeleton automático para tablas que se llenan por AJAX */
    function limpiarEsqueletos(conError) {
        var filas = document.querySelectorAll("tbody > tr.cta-skeleton-tr");
        var vistos = [];
        for (var i = 0; i < filas.length; i++) {
            var tb = filas[i].parentNode;
            if (vistos.indexOf(tb) === -1) { vistos.push(tb); }
        }
        vistos.forEach(function (tb) {
            var soloEsqueleto = tb.querySelectorAll("tr:not(.cta-skeleton-tr)").length === 0;
            if (!soloEsqueleto) { return; }
            var tabla = tb.closest("table");
            var cols = tabla && tabla.tHead && tabla.tHead.rows[0] ? tabla.tHead.rows[0].cells.length : 1;
            tb.innerHTML = conError
                ? '<tr><td colspan="' + cols + '" class="text-center text-danger" role="alert">No se pudieron cargar los datos. Actualice la página e intente de nuevo.</td></tr>'
                : "";
            tb.removeAttribute("aria-busy");
        });
    }

    function autoSkeletons() {
        var cuerpos = document.querySelectorAll(".content-wrapper table tbody[id]");
        for (var i = 0; i < cuerpos.length; i++) {
            var tb = cuerpos[i];
            /* Solo tablas vacías y visibles al cargar; las de ventanas modales se arman a mano. */
            if (tb.children.length || tb.closest(".modal") || tb.closest(".dataTables_wrapper") || !tb.offsetParent) { continue; }
            CTA.skeleton.show(tb, 5);
        }
        if (window.jQuery) {
            var hayError = false;
            window.jQuery(document).ajaxError(function () { hayError = true; });
            window.jQuery(document).ajaxStop(function () { setTimeout(function () { limpiarEsqueletos(hayError); hayError = false; }, 0); });
        }
        /* Red de seguridad: si ninguna petición reemplazó el esqueleto, se retira. */
        setTimeout(function () { limpiarEsqueletos(false); }, 10000);
    }

    function init() {
        landmarks();
        autoSkeletons();
        skipLink();
        enhance(document);
        /* Las bandejas se rellenan por AJAX: se mejora también lo que se inserte después. */
        var pending = false;
        new MutationObserver(function () {
            if (pending) { return; }
            pending = true;
            setTimeout(function () { pending = false; enhance(document); }, 100);
        }).observe(document.body, { childList: true, subtree: true });
    }

    if (document.readyState === "loading") { document.addEventListener("DOMContentLoaded", init); }
    else { init(); }
})();

/* CTA SUPPORT - comportamiento común de las pantallas de gestión.
   Foco en el primer campo, Enter para guardar, aviso breve de guardado/eliminado,
   mensajes de tabla vacía y nombre emergente para los botones que solo tienen ícono. */
(function () {
    "use strict";
    var $ = window.jQuery;

    /* Nombre emergente según el ícono, para botones que solo muestran un dibujo. */
    var NOMBRES_ICONO = {
        "fa-edit": "Modificar",
        "fa-pencil-alt": "Modificar",
        "fa-trash": "Eliminar",
        "fa-trash-alt": "Eliminar",
        "fa-file-pdf": "Ver informe en PDF",
        "fa-print": "Imprimir",
        "fa-eye": "Ver detalle",
        "fa-search": "Buscar",
        "fa-times": "Cerrar",
        "fa-undo": "Deshacer",
        "fa-sync": "Actualizar",
        "fa-sync-alt": "Actualizar",
        "fa-plus": "Agregar",
        "fa-ban": "Anular"
    };

    function nombresDeIconos(scope) {
        var lista = (scope || document).querySelectorAll(".content-wrapper button, .content-wrapper a.btn, .modal button");
        for (var i = 0; i < lista.length; i++) {
            var el = lista[i];
            if (el.title || el.getAttribute("aria-label") || (el.textContent || "").replace(/\s+/g, "").length) { continue; }
            var ic = el.querySelector("i[class*='fa-']");
            if (!ic) { continue; }
            var clases = ic.className.split(/\s+/);
            for (var k = 0; k < clases.length; k++) {
                if (NOMBRES_ICONO[clases[k]]) {
                    el.title = NOMBRES_ICONO[clases[k]];
                    el.setAttribute("aria-label", NOMBRES_ICONO[clases[k]]);
                    break;
                }
            }
        }
    }

    /* Mensajes de tabla vacía. */
    function columnas(tbody) {
        var t = tbody.closest("table");
        return t && t.tHead && t.tHead.rows[0] ? t.tHead.rows[0].cells.length : 1;
    }
    function filaMensaje(tbody, clase, texto) {
        var tr = document.createElement("tr");
        tr.className = clase;
        var td = document.createElement("td");
        td.colSpan = columnas(tbody);
        td.textContent = texto;
        tr.appendChild(td);
        return tr;
    }
    function estadosVacios() {
        var cuerpos = document.querySelectorAll(".content-wrapper table tbody[id]");
        for (var i = 0; i < cuerpos.length; i++) {
            var tb = cuerpos[i];
            if (tb.closest(".modal") || tb.closest(".dataTables_wrapper") || tb.getAttribute("aria-busy") === "true") { continue; }
            var reales = tb.querySelectorAll("tr:not(.cta-empty-row):not(.cta-nomatch-row):not(.cta-skeleton-tr)");
            var vacia = tb.querySelector(".cta-empty-row");
            if (reales.length === 0 && !tb.querySelector(".cta-skeleton-tr")) {
                if (!vacia) { tb.appendChild(filaMensaje(tb, "cta-empty-row", "Todavía no hay registros")); }
            } else if (vacia) {
                vacia.parentNode.removeChild(vacia);
            }
        }
    }
    window.CTA = window.CTA || {};
    window.CTA.estadosVacios = estadosVacios;

    /* Llamado por filtrarTabla (footer.jsp) después de ocultar filas. */
    window.CTA.mensajeSinCoincidencias = function (tbody) {
        var previa = tbody.querySelector(".cta-nomatch-row");
        if (previa) { previa.parentNode.removeChild(previa); }
        var filas = tbody.querySelectorAll("tr:not(.cta-nomatch-row):not(.cta-empty-row)");
        var visibles = 0;
        for (var i = 0; i < filas.length; i++) { if (filas[i].style.display !== "none") { visibles++; } }
        if (filas.length > 0 && visibles === 0) {
            var tr = filaMensaje(tbody, "cta-nomatch-row cta-empty-row", "Ningún registro coincide con la búsqueda");
            tbody.appendChild(tr);
        }
    };

    /* Aviso breve de guardado / eliminado en las pantallas de gestión. */
    var PANTALLAS = /\/(marcas|categorias|especialidades|roles|salas|tecnicos|usuarios|personas|equipos|repuestos|insumos|donantes|unidadesMedida)Controlador\.jsp/;
    var MENSAJES = { guardar: "Registro guardado", modificar: "Cambios guardados", borrar: "Registro eliminado", eliminar: "Registro eliminado" };
    function avisoBreve(texto) {
        if (window.Swal && window.Swal.fire) {
            window.Swal.fire({ toast: true, position: "top-end", icon: "success", title: texto, showConfirmButton: false, timer: 2200, timerProgressBar: true });
        }
    }
    function parametro(datos, nombre) {
        if (typeof datos !== "string") { return null; }
        var m = datos.match(new RegExp("(?:^|&)" + nombre + "=([^&]*)"));
        return m ? decodeURIComponent(m[1].replace(/\+/g, " ")) : null;
    }

    function init() {
        nombresDeIconos(document);
        if (!$) { return; }

        $(document).ajaxSuccess(function (ev, xhr, opciones, respuesta) {
            if (!opciones || !PANTALLAS.test(opciones.url || "")) { return; }
            if (String(respuesta).trim() !== "success") { return; }
            var accion = (parametro(opciones.data, "tipo") || parametro(opciones.data, "accion") || "").toLowerCase();
            if (MENSAJES[accion]) { avisoBreve(MENSAJES[accion]); }
        });
        $(document).ajaxStop(function () { setTimeout(function () { estadosVacios(); nombresDeIconos(document); }, 60); });

        /* Al abrir una ventana de formulario, el cursor queda en el primer campo editable. */
        $(document).on("shown.bs.modal", ".modal", function () {
            var campo = $(this).find("input:not([type=hidden]):not([readonly]):not([disabled]):not([type=checkbox]):not([type=radio]), select:not([disabled]), textarea:not([readonly])").filter(":visible").first();
            if (campo.length) { campo.trigger("focus"); }
        });

        /* Enter guarda el formulario (salvo en áreas de texto, listas y botones). */
        $(document).on("keydown", ".modal input", function (e) {
            if (e.key !== "Enter" || e.isComposing) { return; }
            var tipo = (this.type || "").toLowerCase();
            if (tipo === "button" || tipo === "submit" || tipo === "checkbox" || tipo === "radio") { return; }
            var modal = $(this).closest(".modal");
            var guardar = modal.find("#btnAccion:visible").first();
            if (!guardar.length) { guardar = modal.find(".modal-footer .btn-primary:visible").last(); }
            if (guardar.length && !guardar.prop("disabled")) {
                e.preventDefault();
                guardar.trigger("click");
            }
        });
    }

    if (document.readyState === "loading") { document.addEventListener("DOMContentLoaded", init); }
    else { init(); }
})();
