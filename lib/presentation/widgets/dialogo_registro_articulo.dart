import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/articulo.dart';
import '../utils/lectura_feedback.dart';

class DialogoRegistroArticulo extends StatefulWidget {
  final String codigo;
  final Articulo articulo;
  final int cantidadConfigurada;
  final String descripcionLimpia;
  final dynamic provider;
  final bool gestionLotesHabilitada;

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
    this.gestionLotesHabilitada = false,
    this.loteExtraido,
    this.fechaExtraida,
    this.pesoNetoExtraido,
    this.pesoBrutoExtraido,
    this.ssccExtraido,
  });

  @override
  State<DialogoRegistroArticulo> createState() =>
      _DialogoRegistroArticuloState();
}

class _DialogoRegistroArticuloState extends State<DialogoRegistroArticulo> {
  late TextEditingController _cantidadController;
  late TextEditingController _loteController;
  final FocusNode _cantidadFocusNode = FocusNode();
  final FocusNode _loteFocusNode = FocusNode();
  bool _esCantidadBaja = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    final String textoInicial = widget.cantidadConfigurada == 0
        ? ''
        : widget.cantidadConfigurada.toString();
    _cantidadController = TextEditingController(text: textoInicial);

    if (textoInicial.isNotEmpty) {
      _cantidadController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: textoInicial.length,
      );
    }

    final String loteInicial =
        widget.loteExtraido ?? widget.articulo.lote ?? '';
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
    _cantidadFocusNode.dispose();
    _loteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int cantidadMinimaGlobal = widget.provider.cantidadMinimaGlobal
        .toInt();
    final bool esDescatalogado = widget.articulo.descatalogado;
    final bool loteGestionado = widget.gestionLotesHabilitada;

    const Color colorAvisoCantidad = Colors.deepPurple;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            esDescatalogado
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_outlined,
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
            Text(
              'Código: ${widget.codigo}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'Descripción: ${widget.descripcionLimpia}',
              style: const TextStyle(fontSize: 13),
            ),
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
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Caducidad: ${DateFormat('dd/MM/yyyy').format(widget.fechaExtraida!)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
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
              autofocus: !loteGestionado,
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
                  color: _esCantidadBaja
                      ? colorAvisoCantidad
                      : Colors.grey[600],
                  fontWeight: _esCantidadBaja
                      ? FontWeight.bold
                      : FontWeight.normal,
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
                  _esCantidadBaja
                      ? Icons.info_outline
                      : Icons.shopping_basket_outlined,
                  color: _esCantidadBaja ? colorAvisoCantidad : Colors.blue,
                ),
              ),
            ),
            if (loteGestionado) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _loteController,
                focusNode: _loteFocusNode,
                autofocus: widget.loteExtraido == null,
                enabled: !_guardando,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Lote',
                  hintText: 'Ingrese el lote',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.tag,
                    color: widget.loteExtraido != null
                        ? Colors.green
                        : Colors.blue,
                  ),
                  suffixIcon: widget.loteExtraido != null
                      ? Tooltip(
                          message: 'Extraído de GS1',
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.green,
                          ),
                        )
                      : null,
                ),
              ),
              if (widget.loteExtraido == null &&
                  widget.articulo.lote != null &&
                  widget.articulo.lote!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Lote en ficha: ${widget.articulo.lote}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _guardando
              ? null
              : () async {
                  final cantidadStr = _cantidadController.text.trim();
                  final cantidad = double.tryParse(cantidadStr) ?? 0.0;
                  final loteIntroducido = _loteController.text.trim();

                  if (cantidad <= 0) {
                    await LecturaFeedback.error();
                    _mostrarError('Por favor, introduzca una cantidad válida.');
                    return;
                  }

                  if (loteGestionado && loteIntroducido.isEmpty) {
                    await LecturaFeedback.error();
                    if (!context.mounted) return;
                    final continuarSinLote = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Falta el lote'),
                        content: const Text(
                          'No se ha introducido el lote. ¿Quieres continuar sin lote?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Introducir lote'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Continuar sin lote'),
                          ),
                        ],
                      ),
                    );
                    if (!context.mounted) return;
                    if (continuarSinLote != true) {
                      _loteFocusNode.requestFocus();
                      return;
                    }
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
                      await LecturaFeedback.error();
                      if (!context.mounted) return;
                      setState(() => _guardando = false);
                      final detalle = widget.provider.errorMessage
                          ?.toString()
                          .trim();
                      _mostrarError(
                        detalle == null || detalle.isEmpty
                            ? 'Error al registrar la lectura. Consulte los registros de la aplicación para más detalles.'
                            : detalle,
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    await LecturaFeedback.error();
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
