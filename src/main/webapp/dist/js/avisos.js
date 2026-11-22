/*
 * avisos.js - Mensajes con SweetAlert2 para todo el proyecto.
 *
 *  - window.alert(msg)            -> ventana SweetAlert2 (icono automático)
 *  - avisar(tipo, msg)            -> igual, eligiendo el icono a mano
 *                                    tipos: success | error | warning | info
 *  - confirmar(msg, siCallback)   -> pregunta Aceptar / Cancelar.
 *                                    Devuelve una Promise<boolean>.
 *
 * Si SweetAlert2 no cargó (sin internet y sin copia local), se usan los
 * cuadros nativos del navegador para que nada deje de funcionar.
 */
(function (w) {
    "use strict";

    var alertNativo = w.alert ? w.alert.bind(w) : function () {};
    var confirmNativo = w.confirm ? w.confirm.bind(w) : function () { return true; };

    // Repara texto que llegó deformado por codificación (Â¿, Ã­ ...) pero
    // conserva tildes, eñes y signos de apertura (¿ ¡) para que se lean bien.
    function sinAcentos(t) {
        var s = String(t == null ? "" : t);
        if (/[\u00c2\u00c3]/.test(s)) {
            try { s = decodeURIComponent(escape(s)); } catch (e) {}
        }
        return s;
    }

    function normalizar(t) {
        return String(t).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    // Elige el icono según el contenido del mensaje.
    function detectarTipo(msg) {
        var t = normalizar(msg);
        if (/\berror\b|no se pudo|no pudo|fallo|invalid|no tiene permiso|denegad|restringid|no existe|ya fue tomado|ya esta finalizado/.test(t)) return "error";
        if (/complete|debe |seleccione|ingrese|indique|atencion|falta|obligatori|al menos|no puede|no hay |verifique/.test(t)) return "warning";
        if (/exito|correctamente|registrad|guardad|actualizad|eliminad|cargad|procesad|devuelto|asignad|creado|enviad/.test(t)) return "success";
        return "info";
    }

    var TITULOS = {
        success: "\u00a1Listo!",
        error: "No se pudo completar",
        warning: "Atenci\u00f3n",
        info: "Aviso"
    };

    // Quita prefijos técnicos como "error: " o "Error:" para que el texto se lea limpio.
    function limpiar(msg) {
        var s = String(msg == null ? "" : msg).trim();
        s = s.replace(/^error(\s+cr[ií]tico[^:]*)?\s*:\s*/i, "");
        s = s.replace(/^success\s*:\s*/i, "");
        s = sinAcentos(s);
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function hayswal() { return typeof w.Swal !== "undefined" && w.Swal && w.Swal.fire; }

    function avisar(tipo, msg) {
        // Admite avisar("texto") y avisar("texto", "success")
        var tipos = ["success", "error", "warning", "info", "danger"];
        if (tipos.indexOf(tipo) === -1) { var tmp = tipo; tipo = msg; msg = tmp; }
        if (tipo === "danger") tipo = "error";
        if (tipos.indexOf(tipo) === -1) tipo = detectarTipo(msg);

        if (!hayswal()) { alertNativo(String(msg)); return Promise.resolve(); }

        return w.Swal.fire({
            icon: tipo,
            title: TITULOS[tipo],
            text: limpiar(msg),
            confirmButtonText: "Aceptar",
            confirmButtonColor: "#3d6ba3",
            allowOutsideClick: true
        });
    }

    function confirmar(msg, siCallback, opciones) {
        opciones = opciones || {};
        if (!hayswal()) {
            var ok = confirmNativo(String(msg));
            if (ok && typeof siCallback === "function") siCallback();
            return Promise.resolve(ok);
        }
        return w.Swal.fire({
            icon: opciones.icon || "question",
            title: sinAcentos(opciones.title || "\u00bfEst\u00e1 seguro?"),
            text: sinAcentos(msg),
            showCancelButton: true,
            confirmButtonText: sinAcentos(opciones.si || "S\u00ed, continuar"),
            cancelButtonText: sinAcentos(opciones.no || "Cancelar"),
            confirmButtonColor: opciones.peligro ? "#c0392b" : "#3d6ba3",
            cancelButtonColor: "#6c757d",
            reverseButtons: true,
            focusCancel: !!opciones.peligro
        }).then(function (r) {
            if (r.isConfirmed && typeof siCallback === "function") siCallback();
            return r.isConfirmed;
        });
    }

    // alert() global -> SweetAlert2 (mantiene la misma firma: alert("texto"))
    w.alert = function (msg) { avisar(detectarTipo(msg), msg); };
    w.avisar = avisar;
    w.confirmar = confirmar;
})(window);
