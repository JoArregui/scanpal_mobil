import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';
import '../utils/menu_options.dart';
import '../widgets/home_menu_item.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _confirmarLogout(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Cerrar Sesión'),
            ],
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('¿Está seguro de que desea salir del sistema?'),
                SizedBox(height: 10),
                Text(
                  'Deberá introducir sus credenciales de acceso nuevamente para continuar.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 47, 108),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'ACEPTAR',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    await loginProvider.logout();

    if (context.mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinamos el ancho de la pantalla
    final double screenWidth = MediaQuery.of(context).size.width;

    // Lógica para determinar el número de columnas (Responsividad)
    int crossAxisCount = 2;
    if (screenWidth > 900) {
      crossAxisCount = 4; // Tablets grandes o Web
    } else if (screenWidth > 600) {
      crossAxisCount = 3; // Tablets medianas
    }

    // Ajustamos el aspect ratio para que los items no se vean demasiado altos en tablets
    double childAspectRatio = screenWidth > 600 ? 1.1 : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScanPal - Menú Principal'),
        centerTitle: true,
        automaticallyImplyLeading:
            false, // Evitamos que salga el botón volver si venimos del login
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _confirmarLogout(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // Limitamos el ancho máximo para que en pantallas ultra-wide no se pierda la estética
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: GridView.builder(
              itemCount: menuOptions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20.0,
                mainAxisSpacing: 20.0,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final opcion = menuOptions[index];
                return HomeMenuItem(opcion: opcion);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/lector');
        },
        label: const Text(
          'Escanear',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        icon: const Icon(Icons.qr_code_scanner),
        elevation: 4,
      ),
    );
  }
}
