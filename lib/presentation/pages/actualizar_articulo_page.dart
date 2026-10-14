import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/actualizar_articulo_provider.dart';

class ActualizarArticuloPage extends StatefulWidget {
  const ActualizarArticuloPage({super.key});

  @override
  State<ActualizarArticuloPage> createState() => _ActualizarArticuloPageState();
}

class _ActualizarArticuloPageState extends State<ActualizarArticuloPage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _hintScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final provider = context.read<ActualizarArticuloProvider>();
        await provider.inicializarDatos();

        if (provider.conteoFisicoReal == 0) {
          _dialogoSincronizacion(provider);
        }

        _setupScrollListener();
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        final provider = context.read<ActualizarArticuloProvider>();
        if (provider.hasMore &&
            !provider.isLoadingMore &&
            _searchController.text.isEmpty) {
          provider.cargarMasArticulos();
        }
      }
    });
  }

  void _onSearchChanged(String query, ActualizarArticuloProvider provider) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        provider.inicializarDatos();
        if (_isSearching) _iniciarScrollHint();
      } else {
        provider.buscarGlobalmenteEnBDLocal(query);
      }
    });
  }

  void _iniciarScrollHint() async {
    if (!_hintScrollController.hasClients) return;

    await Future.delayed(const Duration(seconds: 1));
    while (_isSearching && _hintScrollController.hasClients) {
      if (_searchController.text.isNotEmpty) break;

      await _hintScrollController.animateTo(
        _hintScrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 3),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(seconds: 1));
      if (_hintScrollController.hasClients) {
        await _hintScrollController.animateTo(
          0,
          duration: const Duration(seconds: 1),
          curve: Curves.easeOut,
        );
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hintScrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActualizarArticuloProvider>(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;

    return PopScope(
      canPop: !_isSearching && provider.articuloEncontrado == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (provider.articuloEncontrado != null) {
          provider.reset();
        } else if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            provider.inicializarDatos();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (_searchController.text.isEmpty)
                      IgnorePointer(
                        child: SingleChildScrollView(
                          controller: _hintScrollController,
                          scrollDirection: Axis.horizontal,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'Buscar por nombre, referencia o código...',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '',
                      ),
                      onChanged: (value) => _onSearchChanged(value, provider),
                    ),
                  ],
                )
              : const Text('Catálogo de Artículos'),
          actions: [
            IconButton(
              icon: provider.state == ActualizarArticuloState.exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              tooltip: 'Exportar Reportes',
              onPressed: provider.state == ActualizarArticuloState.exporting
                  ? null
                  : () => provider.compartirReportes(),
            ),
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    provider.inicializarDatos();
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _iniciarScrollHint(),
                    );
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: () => _dialogoSincronizacion(provider),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 850 : double.infinity,
            ),
            child: Column(
              children: [
                // Dashboard Responsive
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _dashboardItem(
                        label: 'ACTIVOS',
                        count: provider.totalActivos,
                        color: Colors.green.shade700,
                        icon: Icons.check_circle_outline,
                        isTablet: isTablet,
                      ),
                      _dashboardItem(
                        label: 'DESCATAL.',
                        count: provider.totalDescatalogados,
                        color: Colors.red.shade700,
                        icon: Icons.block_flipped,
                        isTablet: isTablet,
                      ),
                      _dashboardItem(
                        label: 'TOTAL',
                        count: provider.totalArticulos,
                        color: Colors.blue.shade800,
                        icon: Icons.cloud_done_outlined,
                        isTablet: isTablet,
                      ),
                    ],
                  ),
                ),

                Expanded(child: _buildBody(provider, isTablet)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboardItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isTablet,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color.withValues(alpha: 0.6),
          size: isTablet ? 26 : 20,
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 12 : 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Future<void> _dialogoSincronizacion(
    ActualizarArticuloProvider provider,
  ) async {
    bool finalizado = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer<ActualizarArticuloProvider>(
          builder: (context, prov, child) {
            final progreso = prov.progreso;
            final double valorProgreso = (progreso?.porcentaje ?? 0);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!finalizado) ...[
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: valorProgreso > 0 ? valorProgreso : null,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        Text(
                          '${(valorProgreso * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'Sincronizando Catálogo...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (progreso != null) ...[
                      Text(
                        '${progreso.procesados} de ${progreso.total} artículos',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Velocidad: ${progreso.articulosPorSegundo.toStringAsFixed(1)} art/s',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                    LinearProgressIndicator(
                      value: valorProgreso > 0 ? valorProgreso : null,
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 6,
                    ),
                  ] else ...[
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 60,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '¡Sincronización Exitosa!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Se han descargado ${prov.totalArticulos} artículos correctamente.',
                    ),
                  ],
                ],
              ),
              actions: [
                if (finalizado)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('CONTINUAR'),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    try {
      await provider.sincronizarYRecargar();
      if (mounted) {
        setState(() => finalizado = true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${provider.errorMessage.isEmpty ? e : provider.errorMessage}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBody(ActualizarArticuloProvider provider, bool isTablet) {
    if (provider.state == ActualizarArticuloState.searching &&
        provider.articulos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final listaActual = provider.articulos;

    if (listaActual.isEmpty && !provider.isLoadingMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron artículos',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 0),
      itemCount: listaActual.length + (provider.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == listaActual.length) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final art = listaActual[index];
        final bool esDescatalogado = art.descatalogado;

        return ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 30 : 20,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: esDescatalogado
                ? Colors.red.shade50
                : Colors.blue.shade50,
            child: Icon(
              esDescatalogado
                  ? Icons.priority_high
                  : Icons.inventory_2_outlined,
              color: esDescatalogado ? Colors.red : Colors.blue,
              size: 20,
            ),
          ),
          title: Text(
            art.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 17 : 15,
              color: esDescatalogado ? Colors.red.shade900 : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'REF: ${art.referencia}',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CB: ${art.codigo}',
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (esDescatalogado)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ ARTÍCULO DESCATALOGADO',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () => provider.buscarArticulo(art.codigo),
        );
      },
    );
  }
}
