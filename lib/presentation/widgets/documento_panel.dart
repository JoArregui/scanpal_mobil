import 'package:flutter/material.dart';
import '../../domain/entities/documento_esperado.dart';

/// Panel compacto con las líneas del documento activo y su estado en vivo.
/// Se muestra en Compras/Ventas cuando hay un documento cargado en
/// Comprobar Compra/Venta. Mismo lenguaje visual que el resto de la app.
class DocumentoPanel extends StatefulWidget {
  final DocumentoEsperado documento;
  final ResultadoComprobacion? resultado;

  const DocumentoPanel({
    super.key,
    required this.documento,
    required this.resultado,
  });

  @override
  State<DocumentoPanel> createState() => _DocumentoPanelState();
}

class _DocumentoPanelState extends State<DocumentoPanel> {
  bool _expandido = true;

  Color _colorEstado(EstadoLinea estado) {
    switch (estado) {
      case EstadoLinea.completa:
        return Colors.green;
      case EstadoLinea.parcial:
        return Colors.deepPurple;
      case EstadoLinea.pendiente:
        return Colors.orange;
      case EstadoLinea.sobrante:
        return Colors.red;
    }
  }

  String _fmt(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.resultado;
    final total = widget.documento.lineas.length;
    final hechas = res?.completas ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 20,
                    color: Color.fromARGB(255, 0, 47, 108),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Doc. ${widget.documento.numero} · $hechas/$total completas',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (res != null && res.estaCompleto)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            SizedBox(
              height: 150,
              child: res == null || res.lineas.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin líneas en el documento.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      itemCount: res.lineas.length,
                      itemBuilder: (ctx, i) {
                        final lc = res.lineas[i];
                        final color = _colorEstado(lc.estado);
                        final titulo =
                            (lc.esperada.descripcion ?? '').trim().isNotEmpty
                                ? lc.esperada.descripcion!.trim()
                                : 'Ref. ${lc.esperada.referencia}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 3.0,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  titulo,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                '${_fmt(lc.cantidadLeida)}/${_fmt(lc.esperada.cantidadEsperada)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
