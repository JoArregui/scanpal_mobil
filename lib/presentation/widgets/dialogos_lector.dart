/* import 'package:flutter/material.dart';
import '../widgets/lectura_view_model.dart';

class DialogosLector {
  /// Diálogo para confirmar la eliminación de todas las lecturas
  static Future<void> confirmarBorrarTodo({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar todas las lecturas?"),
        content: const Text(
          "Se eliminarán todos los registros locales de esta pantalla.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text(
              "Borrar Todo",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Diálogo principal de gestión (Borrar o Editar)
  static Future<void> mostrarDialogoEdicion({
    required BuildContext context,
    required LecturaViewModel viewModel,
    required Function(LecturaViewModel) onDelete, // Callback para borrar
    required Function(LecturaViewModel, double) onEdit, // Callback para editar
  }) async {
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gestionar Lectura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ref: ${viewModel.referencia}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Código: ${viewModel.codigo}'),
            Text('Cant. actual: ${viewModel.cantidad.toInt()}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop('delete'),
          ),
          TextButton(
            child: const Text('Editar Cantidad'),
            onPressed: () => Navigator.of(ctx).pop('edit'),
          ),
          TextButton(
            child: const Text('Cerrar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );

    if (!context.mounted || resultado == null) return;

    if (resultado == 'edit') {
      await _mostrarDialogoCambiarCantidad(
        context: context,
        viewModel: viewModel,
        onConfirmEdit: (nuevaCant) => onEdit(viewModel, nuevaCant),
      );
    } else if (resultado == 'delete') {
      onDelete(viewModel);
    }
  }

  /// Diálogo específico para cambiar la cantidad numérica con selección automática
  static Future<void> _mostrarDialogoCambiarCantidad({
    required BuildContext context,
    required LecturaViewModel viewModel,
    required Function(double) onConfirmEdit,
  }) async {
    // Inicializamos el controlador con la cantidad actual
    final String valorInicial = viewModel.cantidad.toInt().toString();
    final TextEditingController cantidadController = TextEditingController(
      text: valorInicial,
    );

    // Seleccionamos el texto inmediatamente para que al abrir el teclado se pueda borrar
    cantidadController.selection = TextSelection(
      baseOffset: 0, 
      extentOffset: valorInicial.length,
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modificar Cantidad'),
        content: TextField(
          controller: cantidadController,
          keyboardType: TextInputType.number,
          autofocus: true,
          // Reforzamos la selección al hacer tap por si el usuario pierde el foco y vuelve
          onTap: () {
            cantidadController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: cantidadController.text.length,
            );
          },
          decoration: const InputDecoration(
            labelText: 'Nueva Cantidad',
            border: OutlineInputBorder(),
          ),
          // Permite guardar también al pulsar "Enter" en el teclado del terminal
          onSubmitted: (value) {
            final nuevaCantidad = double.tryParse(value);
            if (nuevaCantidad != null && nuevaCantidad > 0) {
              onConfirmEdit(nuevaCantidad);
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () {
              final nuevaCantidad = double.tryParse(cantidadController.text);
              if (nuevaCantidad != null && nuevaCantidad > 0) {
                onConfirmEdit(nuevaCantidad);
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }
} */



import 'package:flutter/material.dart';
import '../widgets/lectura_view_model.dart';
import '../../domain/entities/articulo.dart';

class DialogosLector {
  /// Diálogo para confirmar la eliminación de todas las lecturas
  static Future<void> confirmarBorrarTodo({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar todas las lecturas?"),
        content: const Text(
          "Se eliminarán todos los registros locales de esta pantalla.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text(
              "Borrar Todo",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Diálogo principal de gestión (Borrar o Editar)
  static Future<void> mostrarDialogoEdicion({
    required BuildContext context,
    required LecturaViewModel viewModel,
    required Function(LecturaViewModel) onDelete,
    required Function(LecturaViewModel, double) onEdit,
  }) async {
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gestionar Lectura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ref: ${viewModel.referencia}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Código: ${viewModel.codigo}'),
            Text('Cant. actual: ${viewModel.cantidad.toInt()}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop('delete'),
          ),
          TextButton(
            child: const Text('Editar Cantidad'),
            onPressed: () => Navigator.of(ctx).pop('edit'),
          ),
          TextButton(
            child: const Text('Cerrar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );

    if (!context.mounted || resultado == null) return;

    if (resultado == 'edit') {
      await _mostrarDialogoCambiarCantidad(
        context: context,
        viewModel: viewModel,
        onConfirmEdit: (nuevaCant) => onEdit(viewModel, nuevaCant),
      );
    } else if (resultado == 'delete') {
      onDelete(viewModel);
    }
  }

  /// Diálogo específico para cambiar la cantidad numérica
  static Future<void> _mostrarDialogoCambiarCantidad({
    required BuildContext context,
    required LecturaViewModel viewModel,
    required Function(double) onConfirmEdit,
  }) async {
    final String valorInicial = viewModel.cantidad.toInt().toString();
    final TextEditingController cantidadController = TextEditingController(
      text: valorInicial,
    );
    cantidadController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: valorInicial.length,
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modificar Cantidad'),
        content: TextField(
          controller: cantidadController,
          keyboardType: TextInputType.number,
          autofocus: true,
          onTap: () {
            cantidadController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: cantidadController.text.length,
            );
          },
          decoration: const InputDecoration(
            labelText: 'Nueva Cantidad',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final nuevaCantidad = double.tryParse(value);
            if (nuevaCantidad != null && nuevaCantidad > 0) {
              onConfirmEdit(nuevaCantidad);
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () {
              final nuevaCantidad = double.tryParse(cantidadController.text);
              if (nuevaCantidad != null && nuevaCantidad > 0) {
                onConfirmEdit(nuevaCantidad);
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  /// Buscador manual con sugerencias fuzzy y campo de texto libre.
  /// Se muestra cuando el escáner no reconoce el código exacto pero hay candidatos.
  /// Devuelve el Articulo seleccionado o null si el usuario cancela.
  static Future<Articulo?> mostrarBuscadorFuzzy({
    required BuildContext context,
    required List<Articulo> sugerencias,
    required String codigoEscaneado,
    required Future<List<Articulo>> Function(String query) onBuscar,
  }) async {
    final TextEditingController busquedaController = TextEditingController();
    List<Articulo> resultadosBusqueda = List.from(sugerencias);
    bool buscando = false;

    return showDialog<Articulo>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Código no reconocido',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Escaneado: "$codigoEscaneado"',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo de búsqueda manual
                    TextField(
                      controller: busquedaController,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Buscar por código, ref. o descripción...',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: buscando
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (query) async {
                        if (query.trim().isEmpty) return;
                        setState(() => buscando = true);
                        final nuevos = await onBuscar(query.trim());
                        setState(() {
                          resultadosBusqueda = nuevos;
                          buscando = false;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // Lista de resultados
                    if (resultadosBusqueda.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Sin resultados. Prueba otra búsqueda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: resultadosBusqueda.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final art = resultadosBusqueda[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: art.descatalogado
                                    ? Colors.red.shade100
                                    : Colors.blue.shade100,
                                child: Text(
                                  art.referencia.length > 3
                                      ? art.referencia.substring(0, 3)
                                      : art.referencia,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: art.descatalogado
                                        ? Colors.red
                                        : Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                art.descripcion,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Ref: ${art.referencia} · Cód: ${art.codigo}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: art.descatalogado
                                  ? const Icon(Icons.warning,
                                      color: Colors.red, size: 16)
                                  : const Icon(Icons.chevron_right, size: 20),
                              onTap: () => Navigator.of(ctx).pop(art),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Buscar'),
                  onPressed: () async {
                    final query = busquedaController.text.trim();
                    if (query.isEmpty) return;
                    setState(() => buscando = true);
                    final nuevos = await onBuscar(query);
                    setState(() {
                      resultadosBusqueda = nuevos;
                      buscando = false;
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}