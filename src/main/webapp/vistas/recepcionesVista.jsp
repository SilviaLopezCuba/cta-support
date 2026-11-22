<%@page isELIgnored="true"%>
<%@include file="../includes/header.jsp" %>
<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-8">
                    <h1 class="font-weight-bold text-primary"><i class="fas fa-truck-loading"></i> Entradas</h1>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            <ul class="nav nav-pills mb-3">
                <li class="nav-item"><a class="nav-link active" href="recepcionesVista.jsp"><i class="fas fa-dolly"></i> Recibir</a></li>
                <li class="nav-item"><a class="nav-link" href="controlStockVista.jsp"><i class="fas fa-truck"></i> Pedir reposición</a></li>
            </ul>
            <div class="row">
                <!-- Cabecera -->
                <div class="col-md-4">
                    <div class="card card-info card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-info font-weight-bold"><i class="fas fa-file-alt"></i> Datos de la Recepción</h3>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label for="recConcepto" class="text-secondary font-weight-bold">Concepto</label>
                                <select id="recConcepto" class="form-control"></select>
                            </div>
                            <div class="form-group">
                                <label for="recInstitucion" class="text-secondary font-weight-bold">Institución de origen</label>
                                <select id="recInstitucion" class="form-control"></select>
                            </div>
                            <div class="form-group">
                                <label for="recComprobante" class="text-secondary font-weight-bold">N° de Comprobante</label>
                                <input type="text" id="recComprobante" class="form-control" maxlength="50" placeholder="Factura, nota de donación, remisión...">
                            </div>
                            <div class="form-group">
                                <label for="recFecha" class="text-secondary font-weight-bold">Fecha</label>
                                <input type="date" id="recFecha" class="form-control">
                            </div>
                            <div class="form-group mb-0">
                                <label for="recObservacion" class="text-secondary font-weight-bold">Observación</label>
                                <input type="text" id="recObservacion" class="form-control" maxlength="255" placeholder="Opcional">
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Detalle -->
                <div class="col-md-8">
                    <div class="card card-secondary card-outline shadow">
                        <div class="card-header bg-white">
                            <h3 class="card-title text-secondary font-weight-bold"><i class="fas fa-boxes"></i> Equipos y Artículos Recibidos</h3>
                        </div>
                        <div class="card-body">
                            <div class="bg-light p-3 mb-3 rounded border">
                                <div class="btn-group btn-group-toggle mb-3" data-toggle="buttons" role="group" aria-label="Qué se agrega">
                                    <label class="btn btn-outline-info btn-sm active"><input type="radio" name="tipoLinea" value="A" checked onchange="cambiarTipoLinea()"> Repuesto o insumo</label>
                                    <label class="btn btn-outline-info btn-sm"><input type="radio" name="tipoLinea" value="E" onchange="cambiarTipoLinea()"> Equipo</label>
                                </div>
                                <!-- Línea de artículo -->
                                <div class="form-row" id="lineaArticulo">
                                    <div class="col-md-6 form-group">
                                        <label for="ldArticulo" class="small font-weight-bold">Artículo</label>
                                        <select id="ldArticulo" class="form-control"></select>
                                    </div>
                                    <div class="col-md-3 form-group">
                                        <label for="ldArtCant" class="small font-weight-bold">Cantidad</label>
                                        <input type="number" id="ldArtCant" class="form-control" value="1" min="0" step="any">
                                    </div>
                                    <div class="col-md-3 form-group">
                                        <label for="ldArtCosto" class="small font-weight-bold">Costo unitario (Gs.)</label>
                                        <input type="number" id="ldArtCosto" class="form-control" value="0" min="0" step="1">
                                    </div>
                                </div>
                                <!-- Línea de equipo -->
                                <div class="form-row d-none" id="lineaEquipo">
                                    <div class="col-md-4 form-group">
                                        <label for="ldCat" class="small font-weight-bold">Categoría</label>
                                        <select id="ldCat" class="form-control"></select>
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label for="ldMarca" class="small font-weight-bold">Marca</label>
                                        <select id="ldMarca" class="form-control"></select>
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label for="ldModelo" class="small font-weight-bold">Modelo</label>
                                        <input type="text" id="ldModelo" class="form-control" maxlength="100">
                                    </div>
                                    <div class="col-md-8 form-group">
                                        <label for="ldEspec" class="small font-weight-bold">Especificaciones técnicas</label>
                                        <input type="text" id="ldEspec" class="form-control" maxlength="500" placeholder="CPU, RAM, disco...">
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label for="ldCond" class="small font-weight-bold">Condición</label>
                                        <select id="ldCond" class="form-control"><option>Nuevo</option><option>Seminuevo</option><option>Usado</option></select>
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label for="ldEqCant" class="small font-weight-bold">Cantidad</label>
                                        <input type="number" id="ldEqCant" class="form-control" value="1" min="1" max="500" step="1">
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label for="ldEqCosto" class="small font-weight-bold">Costo unitario (Gs.)</label>
                                        <input type="number" id="ldEqCosto" class="form-control" value="0" min="0" step="1">
                                    </div>
                                    <div class="col-md-4 form-group">
                                        <label for="ldGarantia" class="small font-weight-bold">Garantía hasta</label>
                                        <input type="date" id="ldGarantia" class="form-control">
                                    </div>
                                </div>
                                <button class="btn btn-info btn-block font-weight-bold" type="button" onclick="agregarLinea()"><i class="fas fa-plus"></i> Agregar</button>
                            </div>
                            <table class="table table-bordered table-sm m-0 text-sm">
                                <thead class="bg-secondary text-white text-xs">
                                    <tr>
                                        <th>Tipo</th>
                                        <th>Descripción</th>
                                        <th width="80px" class="text-right">Cantidad</th>
                                        <th width="110px" class="text-right">Costo unit.</th>
                                        <th width="120px" class="text-right">Subtotal</th>
                                        <th width="60px" class="text-center">Quitar</th>
                                    </tr>
                                </thead>
                                <tbody id="tbodyDetalle">
                                    <tr><td colspan="6" class="text-center text-muted py-3">Ningún equipo o artículo agregado.</td></tr>
                                </tbody>
                            </table>
                        </div>
                        <div class="card-footer bg-white border-top">
                            <span class="font-weight-bold d-inline-block mt-2">Total: Gs. <span id="recTotal">0</span></span>
                            <button type="button" id="btnGuardarRecepcion" class="btn btn-success float-right font-weight-bold shadow" onclick="registrarRecepcion()">
                                <i class="fas fa-check-circle"></i> REGISTRAR RECEPCIÓN
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Historial -->
            <div class="card card-success card-outline shadow mt-4">
                <div class="card-header bg-white">
                    <h3 class="card-title text-success font-weight-bold"><i class="fas fa-history"></i> Historial de Recepciones</h3>
                    <div class="card-tools d-flex" style="gap:.5rem;">
                        <input type="text" class="form-control form-control-sm" id="buscarRecepcion" placeholder="Buscar..." aria-label="Buscar" oninput="filtrarTabla(this.value, 'tablaRecepciones')" style="width:220px;">
                        <button type="button" class="btn btn-tool" onclick="listar()" title="Actualizar" aria-label="Actualizar"><i class="fas fa-sync-alt"></i></button>
                    </div>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-striped m-0 text-sm">
                            <thead class="bg-light">
                                <tr>
                                    <th>N°</th>
                                    <th>Fecha</th>
                                    <th>Concepto</th>
                                    <th>Institución</th>
                                    <th>Comprobante</th>
                                    <th class="text-center">Equipos</th>
                                    <th class="text-center">Artículos</th>
                                    <th class="text-right">Total (Gs.)</th>
                                    <th>Registró</th>
                                    <th class="text-center">Acciones</th>
                                </tr>
                            </thead>
                            <tbody id="tablaRecepciones">
                                <tr><td colspan="10" class="text-center text-muted py-3">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </section>
</div>

<div class="modal fade" id="modalVer">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-secondary text-white">
                <h4 class="modal-title" id="tituloVer">Recepción</h4>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Cerrar">&times;</button>
            </div>
            <div class="modal-body" id="cuerpoVer"></div>
        </div>
    </div>
</div>

<%@include file="../includes/footer.jsp" %>

<script>
    const CTRL_REC = "../controladores/recepcionesControlador.jsp";
    let detalle = [];   // {tipo:"A"|"E", ...}

    $(document).ready(function () {
        $.post(CTRL_REC, { tipo: "combos" }, function (c) {
            $("#recConcepto").html(c.conceptos);
            $("#recInstitucion").html(c.instituciones);
            $("#ldArticulo").html(c.articulos);
            $("#ldCat").html(c.categorias);
            $("#ldMarca").html(c.marcas);
        }, "json");
        $("#ldArticulo").on("change", function () {
            let costo = $(this).find("option:selected").data("costo");
            if (costo) $("#ldArtCosto").val(costo);
        });
        $("#recFecha").val(hoy());
        listar();
    });

    function listar() {
        $.post(CTRL_REC, { tipo: "listar" }, function (data) {
            $("#tablaRecepciones").html(data);
            filtrarTabla($("#buscarRecepcion").val(), "tablaRecepciones");
        });
    }

    function hoy() { let d = new Date(); return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().substring(0, 10); }
    function gs(n) { return Math.round(n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, "."); }
    function num(v) { v = (v || "").toString().replace(",", "."); let n = parseFloat(v); return isNaN(n) ? 0 : n; }
    function esc(t) { return $("<div>").text(t == null ? "" : t).html(); }

    function cambiarTipoLinea() {
        let eq = $("input[name=tipoLinea]:checked").val() === "E";
        $("#lineaEquipo").toggleClass("d-none", !eq);
        $("#lineaArticulo").toggleClass("d-none", eq);
    }

    function agregarLinea() {
        if ($("input[name=tipoLinea]:checked").val() === "E") {
            let cat = $("#ldCat").val(), modelo = $("#ldModelo").val().trim(), cant = parseInt($("#ldEqCant").val(), 10);
            if (!cat || !modelo) { alert("Complete la categoría y el modelo del equipo."); return; }
            if (!(cant >= 1 && cant <= 500)) { alert("La cantidad de equipos debe estar entre 1 y 500."); return; }
            detalle.push({
                tipo: "E", id_categoria: cat, id_marca: $("#ldMarca").val(), modelo: modelo,
                especificaciones: $("#ldEspec").val().trim(), condicion: $("#ldCond").val(),
                cantidad: cant, costo: num($("#ldEqCosto").val()), garantia: $("#ldGarantia").val(),
                desc: $("#ldCat option:selected").text() + " " + ($("#ldMarca").val() ? $("#ldMarca option:selected").text() + " " : "") + modelo + " (" + $("#ldCond").val() + ")"
            });
            $("#ldModelo, #ldEspec, #ldGarantia").val(""); $("#ldEqCant").val(1); $("#ldEqCosto").val(0);
        } else {
            let art = $("#ldArticulo").val(), cant = num($("#ldArtCant").val());
            if (!art) { alert("Seleccione un artículo."); return; }
            if (cant <= 0) { alert("La cantidad debe ser mayor a cero."); return; }
            let ya = detalle.find(function (d) { return d.tipo === "A" && d.articulo === art; });
            if (ya) { ya.cantidad += cant; }
            else detalle.push({ tipo: "A", articulo: art, cantidad: cant, costo: num($("#ldArtCosto").val()),
                                desc: $("#ldArticulo option:selected").text(), clase: art.charAt(0) === "R" ? "Repuesto" : "Insumo" });
            $("#ldArticulo").val(""); $("#ldArtCant").val(1); $("#ldArtCosto").val(0);
        }
        dibujarDetalle();
    }

    function quitarLinea(i) { detalle.splice(i, 1); dibujarDetalle(); }

    function dibujarDetalle() {
        if (detalle.length === 0) {
            $("#tbodyDetalle").html("<tr><td colspan='6' class='text-center text-muted py-3'>Ningún equipo o artículo agregado.</td></tr>");
            $("#recTotal").text("0");
            return;
        }
        let h = "", total = 0;
        detalle.forEach(function (d, i) {
            let sub = d.cantidad * d.costo; total += sub;
            h += "<tr><td>" + (d.tipo === "E" ? "Equipo" : d.clase) + "</td><td>" + esc(d.desc)
               + (d.tipo === "E" && d.especificaciones ? "<small class='d-block text-muted'>" + esc(d.especificaciones) + "</small>" : "")
               + "</td><td class='text-right'>" + d.cantidad + "</td><td class='text-right'>" + gs(d.costo) + "</td><td class='text-right'>" + gs(sub)
               + "</td><td class='text-center'><button type='button' class='btn btn-outline-danger btn-xs' title='Quitar' aria-label='Quitar' onclick='quitarLinea(" + i + ")'><i class='fas fa-times'></i></button></td></tr>";
        });
        $("#tbodyDetalle").html(h);
        $("#recTotal").text(gs(total));
    }

    function limpiar() {
        detalle = [];
        $("#recConcepto, #recInstitucion").val("");
        $("#recComprobante, #recObservacion").val("");
        $("#recFecha").val(hoy());
        dibujarDetalle();
    }

    function registrarRecepcion() {
        let datos = {
            id_concepto: $("#recConcepto").val(), id_donante: $("#recInstitucion").val(),
            nro_comprobante: $("#recComprobante").val(), fecha: $("#recFecha").val(), observacion: $("#recObservacion").val(),
            equipos: detalle.filter(function (d) { return d.tipo === "E"; }).map(function (d) {
                return { id_categoria: d.id_categoria, id_marca: d.id_marca, modelo: d.modelo, especificaciones: d.especificaciones,
                         condicion: d.condicion, cantidad: d.cantidad, costo: d.costo, garantia: d.garantia };
            }),
            articulos: detalle.filter(function (d) { return d.tipo === "A"; }).map(function (d) {
                return { articulo: d.articulo, cantidad: d.cantidad, costo: d.costo };
            })
        };
        if (!datos.id_concepto || !datos.id_donante || !datos.nro_comprobante.trim() || !datos.fecha) {
            alert("Complete el concepto, la institución, el número de comprobante y la fecha.");
            return;
        }
        if (detalle.length === 0) { alert("Agregue al menos un equipo o un artículo."); return; }
        confirmar("¿Registrar la recepción? Los equipos y artículos ingresan al inventario.", function () {
            $("#btnGuardarRecepcion").prop("disabled", true);
            $.post(CTRL_REC, { tipo: "guardar", datos: JSON.stringify(datos) }, function (res) {
                $("#btnGuardarRecepcion").prop("disabled", false);
                res = res.trim();
                if (res.indexOf("success") === 0) {
                    let p = res.split("|");
                    limpiar();
                    listar();
                    avisar("success", "Recepción registrada." + (parseInt(p[2] || "0", 10) > 0 ? " Se registraron " + p[2] + " equipos en el Depósito." : ""));
                } else alert(res);
            }).fail(function () { $("#btnGuardarRecepcion").prop("disabled", false); alert("No se pudo registrar. Intente de nuevo."); });
        }, { si: "Sí, registrar", title: "Registrar recepción" });
    }

    function ingresarRecepcion(id, numero) {
        confirmar("¿Ingresar al inventario la recepción " + numero + "?", function () {
            $.post(CTRL_REC, { tipo: "confirmar", id: id }, function (res) {
                res = res.trim();
                if (res.indexOf("success") === 0) { listar(); avisar("success", "Recepción ingresada al inventario."); }
                else alert(res);
            });
        }, { si: "Sí, ingresar", title: "Ingresar al inventario" });
    }

    function verRecepcion(id) {
        $.post(CTRL_REC, { tipo: "obtener", id: id }, function (r) {
            let t = function (x) { return $("<div>").text(x == null ? "" : x).html(); };
            let html = `<p class="mb-2"><b>Concepto:</b> ${t(r.concepto)} &nbsp; <b>Institución:</b> ${t(r.institucion)}<br>
                        <b>Comprobante:</b> ${t(r.nro_comprobante)} &nbsp; <b>Fecha:</b> ${t(r.fecha.split("-").reverse().join("/"))} </p>`;
            if (r.observacion) html += `<p class="mb-2"><b>Observación:</b> ${t(r.observacion)}</p>`;
            let total = 0;
            html += `<h6 class="text-primary border-bottom pb-1">Equipos</h6>`;
            if (r.equipos.length === 0) html += `<p class="text-muted">Sin equipos.</p>`;
            else {
                html += `<table class="table table-sm table-bordered"><thead class="thead-light"><tr><th>Categoría</th><th>Marca</th><th>Modelo</th><th>Condición</th><th class="text-center">Cant.</th><th class="text-right">Costo unit.</th></tr></thead><tbody>`;
                r.equipos.forEach(function (e) {
                    total += e.cantidad * num(e.costo);
                    html += `<tr><td>${t(e.categoria)}</td><td>${t(e.marca)}</td><td>${t(e.modelo)}${e.especificaciones ? "<small class='d-block text-muted'>" + t(e.especificaciones) + "</small>" : ""}</td><td>${t(e.condicion)}</td><td class="text-center">${e.cantidad}</td><td class="text-right">${gs(e.costo)}</td></tr>`;
                });
                html += `</tbody></table>`;
            }
            html += `<h6 class="text-primary border-bottom pb-1">Repuestos e insumos</h6>`;
            if (r.articulos.length === 0) html += `<p class="text-muted">Sin repuestos ni insumos.</p>`;
            else {
                html += `<table class="table table-sm table-bordered"><thead class="thead-light"><tr><th>Tipo</th><th>Artículo</th><th class="text-center">Cant.</th><th class="text-right">Costo unit.</th></tr></thead><tbody>`;
                r.articulos.forEach(function (a) {
                    total += num(a.cantidad) * num(a.costo);
                    html += `<tr><td>${t(a.tipo)}</td><td>${t(a.nombre)}</td><td class="text-center">${t(a.cantidad)}</td><td class="text-right">${gs(a.costo)}</td></tr>`;
                });
                html += `</tbody></table>`;
            }
            html += `<p class="text-right h5 mb-0">Total: <b>Gs. ${gs(total)}</b></p>`;
            $("#tituloVer").text("Recepción " + r.numero);
            $("#cuerpoVer").html(html);
            $("#modalVer").modal("show");
        }, "json");
    }

</script>
