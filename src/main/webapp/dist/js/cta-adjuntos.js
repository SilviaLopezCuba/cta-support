/* CTA Support - Archivos adjuntos de tickets (fotos y PDF).
 *
 *  var sel = CtaAdjuntos.selector("#contenedor", { max: 4 });   // arma el selector de archivos
 *  sel.archivos();  sel.limpiar();
 *  CtaAdjuntos.subir(idTicket, "solicitud" | "cierre", sel.archivos())  -> Promise {subidos, errores[]}
 *  CtaAdjuntos.mostrar("#contenedor", idTicket)                     -> lista los adjuntos guardados
 *
 * Las fotos grandes se reducen en el navegador (lado mayor 1600 px, JPEG) antes de enviarlas:
 * una foto de celular de 4 MB queda en unos 300 KB. Los PDF se envían tal cual (máx. 5 MB).
 */
(function (global) {
    "use strict";
    var URL_CTRL = "../controladores/adjuntosControlador.jsp";
    var TIPOS = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
    var MAX_PDF = 5 * 1024 * 1024;
    var LADO_MAX = 1600;

    function tamano(bytes) {
        return bytes < 1024 * 1024 ? Math.max(1, Math.round(bytes / 1024)) + " KB" : (bytes / 1024 / 1024).toFixed(1).replace(".", ",") + " MB";
    }

    /** Reduce una imagen grande a JPEG; si ya es chica, la deja igual. */
    function comprimir(archivo) {
        return new Promise(function (resolve) {
            if (archivo.type === "application/pdf" || archivo.size < 400 * 1024) { resolve(archivo); return; }
            var url = URL.createObjectURL(archivo);
            var img = new Image();
            img.onload = function () {
                var escala = Math.min(1, LADO_MAX / Math.max(img.naturalWidth, img.naturalHeight));
                var c = document.createElement("canvas");
                c.width = Math.round(img.naturalWidth * escala);
                c.height = Math.round(img.naturalHeight * escala);
                var ctx = c.getContext("2d");
                ctx.fillStyle = "#ffffff";               // fondo blanco para PNG con transparencia
                ctx.fillRect(0, 0, c.width, c.height);
                ctx.drawImage(img, 0, 0, c.width, c.height);
                URL.revokeObjectURL(url);
                c.toBlob(function (blob) {
                    if (!blob || blob.size >= archivo.size) { resolve(archivo); return; }
                    var nombre = archivo.name.replace(/\.[^.]+$/, "") + ".jpg";
                    resolve(new File([blob], nombre, { type: "image/jpeg" }));
                }, "image/jpeg", 0.82);
            };
            img.onerror = function () { URL.revokeObjectURL(url); resolve(archivo); };
            img.src = url;
        });
    }

    function selector(contenedor, opciones) {
        opciones = opciones || {};
        var max = opciones.max || 4;
        var $c = $(contenedor).empty().addClass("cta-adj");
        var id = "adj_" + Math.random().toString(36).slice(2, 8);
        var lista = [];

        var $input = $("<input>", { type: "file", id: id, multiple: true, accept: "image/jpeg,image/png,image/webp,application/pdf", "class": "cta-adj-input" });
        var $zona = $("<label>", { "for": id, "class": "cta-adj-zona", tabindex: 0 })
            .append($("<i>", { "class": "fas fa-paperclip", "aria-hidden": "true" }))
            .append($("<span>").text(opciones.texto || "Agregar fotos o PDF"))
            .append($("<small>").text("Hasta " + max + " archivos. Las fotos se reducen automáticamente."));
        var $items = $("<ul>", { "class": "cta-adj-lista" });
        var $estado = $("<div>", { "class": "cta-adj-estado", role: "status", "aria-live": "polite" });
        $c.append($input, $zona, $items, $estado);

        $zona.on("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); $input.trigger("click"); } });
        $zona.on("dragover", function (e) { e.preventDefault(); $zona.addClass("is-arrastrando"); });
        $zona.on("dragleave drop", function () { $zona.removeClass("is-arrastrando"); });
        $zona.on("drop", function (e) { e.preventDefault(); agregar(e.originalEvent.dataTransfer.files); });
        $input.on("change", function () { agregar(this.files); this.value = ""; });

        function agregar(archivos) {
            var avisos = [];
            Array.prototype.forEach.call(archivos, function (f) {
                if (lista.length >= max) { avisos.push("Se alcanzó el máximo de " + max + " archivos."); return; }
                if (TIPOS.indexOf(f.type) < 0) { avisos.push(f.name + ": solo se aceptan imágenes JPG, PNG, WEBP o PDF."); return; }
                if (f.type === "application/pdf" && f.size > MAX_PDF) { avisos.push(f.name + ": el PDF supera los 5 MB."); return; }
                lista.push(f);
            });
            dibujar();
            $estado.text(avisos.filter(function (a, i) { return avisos.indexOf(a) === i; }).join(" "));
        }

        function dibujar() {
            $items.empty();
            lista.forEach(function (f, i) {
                var $vista = f.type === "application/pdf"
                    ? $("<span>", { "class": "cta-adj-ico" }).append($("<i>", { "class": "fas fa-file-pdf", "aria-hidden": "true" }))
                    : $("<img>", { src: URL.createObjectURL(f), alt: "" });
                var $quitar = $("<button>", { type: "button", "class": "cta-adj-quitar", "aria-label": "Quitar " + f.name, title: "Quitar" })
                    .append($("<i>", { "class": "fas fa-times", "aria-hidden": "true" }))
                    .on("click", function () { lista.splice(i, 1); dibujar(); $estado.text(""); });
                $items.append($("<li>").append($vista, $("<span>", { "class": "cta-adj-nombre" }).text(f.name),
                    $("<span>", { "class": "cta-adj-peso" }).text(tamano(f.size)), $quitar));
            });
            $zona.toggleClass("is-lleno", lista.length >= max);
        }

        return {
            archivos: function () { return lista.slice(); },
            limpiar: function () { lista = []; dibujar(); $estado.text(""); },
            estado: function (texto) { $estado.text(texto || ""); }
        };
    }

    /** Sube los archivos en orden; nunca rechaza: informa cuántos subió y los errores. */
    function subir(idTicket, etapa, archivos, alAvanzar) {
        var resultado = { subidos: 0, errores: [] };
        var cadena = Promise.resolve();
        (archivos || []).forEach(function (f, i) {
            cadena = cadena.then(function () {
                if (alAvanzar) alAvanzar(i + 1, archivos.length, f.name);
                return comprimir(f).then(function (listo) {
                    var url = URL_CTRL + "?tipo=subir&idTicket=" + encodeURIComponent(idTicket) +
                        "&etapa=" + encodeURIComponent(etapa) + "&nombre=" + encodeURIComponent(listo.name);
                    return fetch(url, { method: "POST", body: listo, credentials: "same-origin",
                                        headers: { "Content-Type": listo.type || "application/octet-stream" } })
                        .then(function (r) { return r.text(); })
                        .then(function (txt) {
                            txt = (txt || "").trim();
                            if (txt.indexOf("success") === 0) resultado.subidos++;
                            else resultado.errores.push(f.name + ": " + txt.replace(/^error:\s*/, ""));
                        });
                }).catch(function () { resultado.errores.push(f.name + ": no se pudo enviar (revise la conexión)."); });
            });
        });
        return cadena.then(function () { return resultado; });
    }

    /** Lista los adjuntos guardados de un ticket con miniatura; devuelve la cantidad. */
    function mostrar(contenedor, idTicket) {
        var $c = $(contenedor).empty();
        return $.getJSON(URL_CTRL, { tipo: "listar", idTicket: idTicket }).then(function (data) {
            var lista = (data && data.ok) ? data.adjuntos : [];
            if (!lista.length) return 0;
            var $ul = $("<ul>", { "class": "cta-adj-lista cta-adj-guardados" });
            lista.forEach(function (a) {
                var href = URL_CTRL + "?tipo=ver&id_adjunto=" + a.id;
                var $vista = a.imagen ? $("<img>", { src: href, alt: "", loading: "lazy" })
                    : $("<span>", { "class": "cta-adj-ico" }).append($("<i>", { "class": "fas fa-file-pdf", "aria-hidden": "true" }));
                $ul.append($("<li>").append(
                    $("<a>", { href: href, target: "_blank", rel: "noopener", "class": "cta-adj-enlace" }).append($vista,
                        $("<span>", { "class": "cta-adj-nombre" }).text(a.nombre)),
                    $("<span>", { "class": "cta-adj-peso" }).text(a.fecha + " · " + a.kb + " KB")));
            });
            $c.append($ul);
            return lista.length;
        }, function () { return 0; });
    }

    global.CtaAdjuntos = { selector: selector, subir: subir, mostrar: mostrar };
})(window);
