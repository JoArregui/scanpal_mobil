import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/configuracion_provider.dart';
import '../providers/login_provider.dart';
import '../../core/constants.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final _urlController = TextEditingController();
  final _cantidadController = TextEditingController();
  bool _lecturaAutomatica = false;
  bool _initialized = false;
  bool _urlDesbloqueadaManual = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    
    // Listener optimizado para evitar setState si el valor no cambia realmente el estado de la UI
    _cantidadController.addListener(_onCantidadChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ConfiguracionProvider>(
        context,
        listen: false,
      ).cargarConfiguracion();
    });
  }

  void _onCantidadChanged() {
    final val = int.tryParse(_cantidadController.text) ?? 0;
    if (val <= 0 && _lecturaAutomatica) {
      setState(() {
        _lecturaAutomatica = false;
      });
    } else {
      // Solo hacemos setState si necesitamos refrescar el botón de guardado o validaciones visuales
      setState(() {});
    }
  }

  void _solicitarDesbloqueoUrl(BuildContext context) {
    final TextEditingController passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desbloquear URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Introduzca la clave de Administrador para modificar la URL de conexión.',
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passController.text == AppConstants.adminUser) {
                  setState(() {
                    _urlDesbloqueadaManual = true;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Campo URL desbloqueado')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contraseña incorrecta'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Desbloquear'),
            ),
          ],
        );
      },
    );
  }

  void _restaurarUrl() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar URL de Pruebas'),
        content: Text(
          'Se volverá a establecer la dirección:\n\n${AppConstants.baseUrl}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _urlController.text = AppConstants.baseUrl;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar Restaurar'),
          ),
        ],
      ),
    );
  }

  void _guardarConfiguracion() async {
    if (_formKey.currentState!.validate()) {
      final url = _urlController.text.replaceAll(RegExp(r'\u00a0'), ' ').trim();
      final cantidad = int.tryParse(_cantidadController.text) ?? 0;

      final provider = Provider.of<ConfiguracionProvider>(
        context,
        listen: false,
      );

      final exito = await provider.guardarConfiguracion(
        url,
        cantidad,
        lecturaAutomatica: _lecturaAutomatica,
      );

      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada con éxito')),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${provider.errorMessage}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginProvider = Provider.of<LoginProvider>(context);
    final isSuperAdmin = loginProvider.isSuperAdmin || _urlDesbloqueadaManual;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración'), centerTitle: true),
      body: Consumer<ConfiguracionProvider>(
        builder: (context, provider, child) {
          if (provider.state == ConfiguracionState.loading ||
              provider.state == ConfiguracionState.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          // CORRECCIÓN: Inicialización segura de controladores
          if (!_initialized) {
            // Usamos postFrameCallback para que la asignación ocurra después del build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _urlController.text = provider.configuracion.urlBase;
                  _cantidadController.text =
                      provider.configuracion.cantidadMinima == 0
                          ? ''
                          : provider.configuracion.cantidadMinima.toString();
                  _lecturaAutomatica = provider.configuracion.lecturaAutomatica;
                  _initialized = true;
                });
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          final int cantActual = int.tryParse(_cantidadController.text) ?? 0;
          final bool canEnableAuto = cantActual > 0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 600 : double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'URL de Conexión:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isSuperAdmin)
                            TextButton.icon(
                              onPressed: _restaurarUrl,
                              icon: const Icon(
                                Icons.settings_backup_restore,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              label: const Text(
                                'Restaurar URL',
                                style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _urlController,
                        readOnly: !isSuperAdmin,
                        onTap: () {
                          if (!isSuperAdmin) {
                            _solicitarDesbloqueoUrl(context);
                          }
                        },
                        style: TextStyle(
                          color: isSuperAdmin ? Colors.black : Colors.grey[700],
                        ),
                        decoration: InputDecoration(
                          labelText: 'URL Base',
                          hintText: 'http://ejemplo.com/api',
                          border: const OutlineInputBorder(),
                          suffixIcon: !isSuperAdmin
                              ? const Icon(Icons.lock, color: Colors.red)
                              : const Icon(
                                  Icons.lock_open,
                                  color: Colors.green,
                                ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese una URL válida.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Cantidad por defecto:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cantidadController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad (Vacío = Manual)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (int.tryParse(value) == null ||
                                int.parse(value) < 0) {
                              return 'Debe ser un número válido.';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      Container(
                        decoration: BoxDecoration(
                          color: canEnableAuto
                              ? const Color.fromARGB(255, 0, 47, 108).withValues(alpha: 0.05)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canEnableAuto
                                ? const Color.fromARGB(255, 0, 47, 108).withValues(alpha: 0.2)
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            'Lectura Automática',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: canEnableAuto ? Colors.black : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            canEnableAuto
                                ? 'No pide cantidad si la lectura es correcta.'
                                : 'Requiere una cantidad por defecto > 0',
                            style: TextStyle(
                              fontSize: 13,
                              color: canEnableAuto
                                  ? Colors.black54
                                  : Colors.grey,
                            ),
                          ),
                          value: _lecturaAutomatica,
                          onChanged: canEnableAuto
                              ? (bool value) {
                                  setState(() {
                                    _lecturaAutomatica = value;
                                  });
                                }
                              : null,
                          secondary: CircleAvatar(
                            backgroundColor: _lecturaAutomatica
                                ? const Color.fromARGB(255, 0, 47, 108)
                                : Colors.grey[400],
                            child: Icon(
                              _lecturaAutomatica
                                  ? Icons.flash_on
                                  : Icons.touch_app,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      SizedBox(
                        height: 55,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: provider.state == ConfiguracionState.saving
                              ? null
                              : _guardarConfiguracion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 0, 47, 108),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          icon: provider.state == ConfiguracionState.saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            provider.state == ConfiguracionState.saving
                                ? 'Guardando...'
                                : 'Guardar Configuración',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _cantidadController.removeListener(_onCantidadChanged);
    _urlController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }
}