import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/articulo.dart';

class DialogoRegistroArticulo extends StatefulWidget {
  final String codigo;
  final Articulo articulo;
  final int cantidadConfigurada;
  final String descripcionLimpia;
  final dynamic provider;

  final String? loteExtraido;
  final DateTime? fechaExtraida;
  final double? pesoNetoExtraido;
  final double? pesoBrutoExtraido;
  final String? ssccExtraido;

  const DialogoRegistroArticulo({
    super.key,
    required this.codigo,
    required this.articulo,
    required this.cantidadConfigurada,
    required this.provider,
    required this.descripcionLimpia,
    this.loteExtraido,
    this.fechaExtraida,
    this.pesoNetoExtraido,
    this.pesoBrutoExtraido,
    this.ssccExtraido,
  });

  @override
  State<DialogoRegistroArticulo> createState() => _DialogoRegistroArticuloState();
}

class _DialogoRegistroArticuloState extends State<DialogoRegistroArticulo> {
  late TextEditingController _cantidadController;
  late TextEditingController _loteController;
  // Añadimos el FocusNode para controlar la selección del texto
  final FocusNode _cantidadFocusNode = FocusNode();
  bool _esCantidadBaja = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    final String textoInicial = widget.cantidadConfigurada == 0 ? '' : widget.cantidadConfigurada.toString();
    _cantidadController = TextEditingController(text: textoInicial);

    if (textoInicial.isNotEmpty) {
      _cantidadController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: textoInicial.length,
      );
    }

    final String loteInicial = widget.loteExtraido ?? widget.articulo.lote ?? '';
    _loteController = TextEditingController(text: loteInicial);

    _cantidadController.addListener(_comprobarCantidadMinima);

    // Lógica para que al recibir el foco se seleccione todo el texto
    _cantidadFocusNode.addListener(() {
      if (_cantidadFocusNode.hasFocus) {
        _cantidadController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _cantidadController.text.length,
        );
      }
    });

    _comprobarCantidadMinima();
  }

  void _comprobarCantidadMinima() {
    final int cantidadMinima = widget.provider.cantidadMinimaGlobal.toInt();
    final int? valorActual = int.tryParse(_cantidadController.text);

    if (mounted) {
      setState(() {
        _esCantidadBaja = valorActual != null && valorActual < cantidadMinima;
      });
    }
  }

  @override
  void dispose() {
    _cantidadController.removeListener(_comprobarCantidadMinima);
    _cantidadController.dispose();
    _loteController.dispose();
    _cantidadFocusNode.dispose(); // Liberamos el FocusNode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int cantidadMinimaGlobal = widget.provider.cantidadMinimaGlobal.toInt();
    final bool esDescatalogado = widget.articulo.descatalogado;
    final bool requiereLote = widget.articulo.gestionLotes;

    const Color colorAvisoCantidad = Colors.deepPurple;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            esDescatalogado ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            color: esDescatalogado ? Colors.orange : Colors.blue,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              esDescatalogado ? 'DESCATALOGADO' : 'Detalle Artículo',
              style: TextStyle(
                color: esDescatalogado ? Colors.orange[900] : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: esDescatalogado ? 18 : null,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Referencia: ${widget.articulo.referencia.trim()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('Código: ${widget.codigo}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Descripción: ${widget.descripcionLimpia}', style: const TextStyle(fontSize: 13)),
            if (widget.fechaExtraida != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Caducidad: ${DateFormat('dd/MM/yyyy').format(widget.fechaExtraida!)}',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 25),

            // CAMPO: CANTIDAD con FocusNode para selección automática
            TextField(
              controller: _cantidadController,
              focusNode: _cantidadFocusNode,
              autofocus: !requiereLote && widget.loteExtraido == null, 
              keyboardType: TextInputType.number,
              onTap: () => _cantidadController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _cantidadController.text.length,
              ),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                helperText: _esCantidadBaja
                    ? 'Aviso: Stock menor al esperado ($cantidadMinimaGlobal)'
                    : 'Cantidad mínima global: $cantidadMinimaGlobal',
                helperStyle: TextStyle(
                  color: _esCantidadBaja ? colorAvisoCantidad : Colors.grey[600],
                  fontWeight: _esCantidadBaja ? FontWeight.bold : FontWeight.normal,
                ),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _esCantidadBaja ? colorAvisoCantidad : Colors.grey,
                    width: _esCantidadBaja ? 2.0 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _esCantidadBaja ? colorAvisoCantidad : Colors.blue,
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(
                  _esCantidadBaja ? Icons.info_outline : Icons.shopping_basket_outlined,
                  color: _esCantidadBaja ? colorAvisoCantidad : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _loteController,
              autofocus: requiereLote && widget.loteExtraido == null,
              enabled: !_guardando,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: requiereLote ? 'LOTE OBLIGATORIO' : 'Lote (Opcional)',
                labelStyle: TextStyle(
                    color: requiereLote ? Colors.blue : Colors.grey,
                    fontWeight: requiereLote ? FontWeight.bold : FontWeight.normal),
                hintText: 'Ingrese el lote',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag, color: widget.loteExtraido != null ? Colors.green : Colors.blue),
                suffixIcon: widget.loteExtraido != null
                    ? Tooltip(
                        message: 'Extraído de GS1',
                        child: const Icon(Icons.auto_awesome, color: Colors.green),
                      )
                    : null,
              ),
            ),
            if (widget.loteExtraido == null && widget.articulo.lote != null && widget.articulo.lote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Lote en ficha: ${widget.articulo.lote}',
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: esDescatalogado ? Colors.orange : Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _guardando
              ? null
              : () async {
                  final cantidadStr = _cantidadController.text.trim();
                  final cantidad = double.tryParse(cantidadStr) ?? 0.0;
                  final loteIntroducido = _loteController.text.trim();

                  if (cantidad <= 0) {
                    _mostrarError('Por favor, introduzca una cantidad válida.');
                    return;
                  }

                  if (requiereLote && loteIntroducido.isEmpty) {
                    _mostrarError('El LOTE es obligatorio para este artículo.');
                    return;
                  }

                  final navigator = Navigator.of(context);
                  setState(() => _guardando = true);

                  try {
                    final exito = await widget.provider.registrarLectura(
                      widget.codigo,
                      cantidad,
                      widget.descripcionLimpia,
                      referenciaArticulo: widget.articulo.referencia,
                      lote: loteIntroducido.isNotEmpty ? loteIntroducido : null,
                      esDescatalogado: esDescatalogado,
                      fechaCaducidad: widget.fechaExtraida,
                      pesoNeto: widget.pesoNetoExtraido,
                      pesoBruto: widget.pesoBrutoExtraido,
                      sscc: widget.ssccExtraido,
                    );

                    if (!mounted) return;

                    if (exito) {
                      navigator.pop(true);
                    } else {
                      setState(() => _guardando = false);
                      _mostrarError('Error al registrar la lectura');
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _guardando = false);
                    _mostrarError('Error: ${e.toString()}');
                  }
                },
          child: _guardando
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('ACEPTAR'),
        ),
      ],
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}