import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../providers/login_provider.dart';
import '../providers/configuracion_provider.dart';
import '../providers/lector_provider.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const String _fixedDbUrl = AppConstants.baseUrl;

  @override
  void initState() {
    super.initState();
    // RESETEO DE ESTADO: 
    // Aseguramos que al entrar al Login, el estado sea 'initial' 
    // para que no detecte un 'success' de una sesión anterior.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LoginProvider>(context, listen: false).logout(); 
      // O el método que tengas para limpiar el estado (ej. resetState)
    });
  }

  void _showAdminAccessDialog(BuildContext context) {
    final TextEditingController adminPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Acceso Administrador'),
        content: TextField(
          controller: adminPassController,
          decoration: const InputDecoration(
            labelText: 'Contraseña de Admin',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (adminPassController.text == AppConstants.adminUser) {
                Navigator.pop(context);
                Provider.of<LoginProvider>(
                  context,
                  listen: false,
                ).setSuperAdminManually();
                Navigator.of(context).pushNamed('/configuracion');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Acceso denegado'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  void _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final configProvider = Provider.of<ConfiguracionProvider>(context, listen: false);
    // 1. Obtenemos el LectorProvider
    final lectorProvider = Provider.of<LectorProvider>(context, listen: false);

    await configProvider.guardarConfiguracion(
      _fixedDbUrl,
      configProvider.configuracion.cantidadMinima,
      lecturaAutomatica: configProvider.configuracion.lecturaAutomatica,
    );

    // 2. Pasamos el lectorProvider como tercer argumento
    await loginProvider.logear(
      _userController.text, 
      _passController.text, 
      lectorProvider,
    );
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onLongPress: () => _showAdminAccessDialog(context),
          child: Text(
            'ScanPal - Login',
            style: TextStyle(
              color: const Color.fromARGB(255, 0, 47, 108),       
               fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 450 : double.infinity,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Gestión de Almacén',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 40),

                  Form(
                    key: _formKey,
                    child: Consumer2<LoginProvider, ConfiguracionProvider>(
                      builder: (context, loginProvider, configProvider, child) {
                        // Solo navega si el estado acaba de cambiar a success en ESTA sesión
                        if (loginProvider.state == LoginState.success) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/home',
                                (route) => false,
                              );
                            }
                          });
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final isLoading =
                            loginProvider.state == LoginState.loading;
                        final isLoginEnabled = !isLoading;

                        return Column(
                          children: <Widget>[
                            TextFormField(
                              controller: _userController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Usuario',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              enabled: isLoginEnabled,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'El usuario es obligatorio.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passController,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                                  isLoginEnabled ? _login(context) : null,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              obscureText: true,
                              enabled: isLoginEnabled,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'La contraseña es obligatoria.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            if (loginProvider.state == LoginState.error)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: Text(
                                  loginProvider.errorMessage,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 0, 47, 108),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isLoginEnabled
                                    ? () => _login(context)
                                    : null,
                                child: isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Iniciar Sesión',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}