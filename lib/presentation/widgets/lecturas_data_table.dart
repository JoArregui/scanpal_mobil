import 'package:flutter/material.dart';
import '../widgets/lectura_view_model.dart';

class LecturasDataTable extends StatelessWidget {
  final dynamic provider;
  final Function(BuildContext, dynamic, LecturaViewModel) onRowDoubleTap;

  const LecturasDataTable({
    super.key,
    required this.provider,
    required this.onRowDoubleTap,
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
            DataColumn(label: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: registros.reversed.map((vm) {
            final bool esDescatalogado = vm.lectura.esDescatalogado;
            final bool esCantidadBaja = vm.cantidad < cantidadMinimaGlobal && cantidadMinimaGlobal > 0;
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
                              color: esDescatalogado ? Colors.orange[900] : Colors.black)),
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
                // Celda 2: Descripción
                cellWithDoubleTap(
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.55,
                    child: Row(
                      children: [
                        if (esDescatalogado)
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                          )
                        else if (esCantidadBaja)
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.info_outline, color: colorAvisoCantidad, size: 14),
                          ),
                        Expanded(
                          child: Text(
                            vm.descripcionLimpia,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 11,
                              color: esDescatalogado
                                  ? Colors.orange[900]
                                  : (esCantidadBaja ? colorAvisoCantidad : Colors.black87),
                              fontWeight: (esDescatalogado || esCantidadBaja) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Celda 3: Cantidad
                cellWithDoubleTap(
                  alignment: Alignment.center,
                  Text(
                    vm.cantidad.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: esDescatalogado
                          ? Colors.orange[900]
                          : (esCantidadBaja ? colorAvisoCantidad : Colors.blue[800]),
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