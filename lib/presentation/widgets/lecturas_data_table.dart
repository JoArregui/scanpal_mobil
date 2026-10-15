import 'package:flutter/material.dart';
import '../widgets/lectura_view_model.dart';

class LecturasDataTable extends StatelessWidget {
  final dynamic provider;
  final Function(BuildContext, dynamic, LecturaViewModel) onRowDoubleTap;

  /// Marca las filas fuera de documento (Compras/Ventas con comprobación
  /// activa) con un color distintivo. Null = comportamiento de siempre.
  final bool Function(LecturaViewModel)? esInesperada;

  const LecturasDataTable({
    super.key,
    required this.provider,
    required this.onRowDoubleTap,
    this.esInesperada,
  });

  @override
  Widget build(BuildContext context) {
    final List<LecturaViewModel> registros = provider.registrosViewModel;

    if (registros.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            "Sin registros.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    final int cantidadMinimaGlobal = provider.cantidadMinimaGlobal.toInt();
    const Color colorAvisoCantidad = Colors.deepPurple;
    const Color colorAvisoDescatalogado = Colors.orange;
    // FIFO: orden por caducidad (sin fecha al final). Solo visual.
    final List<LecturaViewModel> ordenados = [...registros]
      ..sort(LecturaViewModel.compararFifo);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Theme(
        
        data: Theme.of(context).copyWith(
          dividerColor: Colors.grey[300],
          splashFactory: NoSplash.splashFactory,
        ),
        child: DataTable(
          columnSpacing: 10,
          horizontalMargin: 8,
          showCheckboxColumn: false,
          headingRowHeight: 40,
          dataRowMinHeight: 45,
          dataRowMaxHeight: 62,
          headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
          columns: const [
            DataColumn(label: Text('Art / Lote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Cad.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: ordenados.map((vm) {
            final bool esDescatalogado = vm.lectura.esDescatalogado;
            final bool esCantidadBaja = vm.cantidad < cantidadMinimaGlobal && cantidadMinimaGlobal > 0;
            final bool fueraDeDocumento = esInesperada?.call(vm) ?? false;
            const Color colorFueraDeDocumento = Colors.red;
            // FIFO: aviso graduado por cercanía de caducidad
            // (rojo pasado/hoy → naranja 1-3 días → ámbar 4-7 días).
            final NivelAvisoCaducidad nivelCad = vm.nivelAvisoCaducidad;
            final bool avisaCad = nivelCad != NivelAvisoCaducidad.ok;
            final Color colorCad = vm.colorAvisoCaducidad;
            final String? lote = vm.lectura.lote;

            // Función interna para envolver cada celda en el detector de doble toque
            DataCell cellWithDoubleTap(Widget child, {Alignment alignment = Alignment.centerLeft}) {
              return DataCell(
                GestureDetector(
                 
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => onRowDoubleTap(context, provider, vm),
                  child: Container(
                    
                    width: double.infinity,
                    height: double.infinity,
                    alignment: alignment,
                    child: child,
                  ),
                ),
              );
            }

            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (fueraDeDocumento) return colorFueraDeDocumento.withValues(alpha: 0.12);
                if (avisaCad) return colorCad.withValues(alpha: vm.fondoAvisoCaducidad);
                if (esDescatalogado) return colorAvisoDescatalogado.withValues(alpha: 0.12);
                if (esCantidadBaja) return colorAvisoCantidad.withValues(alpha: 0.08);
                return null;
              }),
              cells: [
                // Celda 1: Código y Lote
                cellWithDoubleTap(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(vm.codigo,
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: fueraDeDocumento
                                  ? colorFueraDeDocumento
                                  : (esDescatalogado ? Colors.orange[900] : Colors.black))),
                      if (lote != null && lote.isNotEmpty)
                        Text('L: $lote',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.blue[700],
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                // Celda 2: Descripción (más estrecha para que quepa Cad.;
                // si el texto desborda, gira solo en marquee para leerlo todo)
                cellWithDoubleTap(
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.40,
                    child: Row(
                      children: [
                        if (fueraDeDocumento)
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.report_problem_outlined, color: colorFueraDeDocumento, size: 14),
                          )
                        else if (esDescatalogado)
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                          )
                        else if (esCantidadBaja)
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.info_outline, color: colorAvisoCantidad, size: 14),
                          )
                        else if (avisaCad)
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Icon(
                              nivelCad == NivelAvisoCaducidad.caducada
                                  ? Icons.warning_amber_rounded
                                  : Icons.schedule,
                              color: colorCad,
                              size: 14,
                            ),
                          ),
                        Expanded(
                          child: _DescripcionMarquee(
                            text: vm.descripcionLimpia,
                            style: TextStyle(
                              fontSize: 11,
                              color: fueraDeDocumento
                                  ? colorFueraDeDocumento
                                  : (esDescatalogado
                                      ? Colors.orange[900]
                                      : (esCantidadBaja ? colorAvisoCantidad : Colors.black87)),
                              fontWeight: (fueraDeDocumento || esDescatalogado || esCantidadBaja) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Celda 3: Caducidad FIFO con tonalidad según cercanía
                cellWithDoubleTap(
                  alignment: Alignment.center,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (avisaCad)
                        Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Icon(
                            nivelCad == NivelAvisoCaducidad.caducada
                                ? Icons.warning_amber_rounded
                                : Icons.schedule,
                            color: colorCad,
                            size: 13,
                          ),
                        ),
                      Text(
                        vm.caducidadCorta,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: avisaCad ? FontWeight.bold : FontWeight.normal,
                          color: avisaCad
                              ? colorCad
                              : (vm.tieneCaducidad ? Colors.black87 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                // Celda 4: Cantidad
                cellWithDoubleTap(
                  alignment: Alignment.center,
                  Text(
                    vm.cantidad.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: fueraDeDocumento
                          ? colorFueraDeDocumento
                          : (esDescatalogado
                              ? Colors.orange[900]
                              : (esCantidadBaja ? colorAvisoCantidad : Colors.blue[800])),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Texto de descripción con marquee automático: si cabe entero se queda
/// quieto; si desborda, se desplaza solo hasta el final, pausa y vuelve,
/// en bucle, para poder leerlo todo sin agrandar la casilla.
class _DescripcionMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _DescripcionMarquee({required this.text, required this.style});

  @override
  State<_DescripcionMarquee> createState() => _DescripcionMarqueeState();
}

class _DescripcionMarqueeState extends State<_DescripcionMarquee> {
  late final ScrollController _controller;
  bool _enMarcha = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarSiDesborda());
  }

  @override
  void didUpdateWidget(covariant _DescripcionMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _enMarcha = false;
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarSiDesborda());
    }
  }

  Future<void> _iniciarSiDesborda() async {
    if (!mounted || _enMarcha || !_controller.hasClients) return;
    if (_controller.position.maxScrollExtent <= 0) return; // cabe entero
    _enMarcha = true;
    const pausa = Duration(seconds: 1);
    await Future.delayed(const Duration(milliseconds: 1500));
    while (mounted && _enMarcha && _controller.hasClients) {
      final double max = _controller.position.maxScrollExtent;
      if (max <= 0) break;
      try {
        await _controller.animateTo(
          max,
          duration: Duration(
            milliseconds: (600 + max * 8).toInt().clamp(800, 6000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }
      await Future.delayed(pausa);
      if (!mounted || !_enMarcha || !_controller.hasClients) break;
      try {
        await _controller.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }
      await Future.delayed(pausa);
    }
    _enMarcha = false;
  }

  @override
  void dispose() {
    _enMarcha = false;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        style: widget.style,
      ),
    );
  }
}