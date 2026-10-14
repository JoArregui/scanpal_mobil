import 'package:flutter_test/flutter_test.dart';
import 'package:scanpalphone_app/core/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:http/http.dart' as http;
import 'package:scanpalphone_app/main.dart'; 
import 'package:scanpalphone_app/presentation/pages/login_page.dart';

void main() {
  testWidgets('El test de prueba debe correr sin error', (WidgetTester tester) async {
    // 1. Configurar SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 2. Obtener la instancia Singleton de DatabaseHelper
    final DatabaseHelper dbHelper = DatabaseHelper.instance;
    
    // Si la inicialización de la DB es async
    await dbHelper.database; 

    // 3. Crear el cliente HTTP que falta
    final httpClient = http.Client();

    // 4. Construir la app y pasar TODOS los argumentos requeridos
    await tester.pumpWidget(MyApp(
        sharedPreferences: prefs,
        dbHelper: dbHelper,
        httpClient: httpClient, // Se añade el argumento faltante
    ));

    // Verificación: El test debe construir la LoginPage sin errores de argumentos.
    expect(find.byType(LoginPage), findsOneWidget);
  });
}