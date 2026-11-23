import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/database_helper.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/pages/actualizar_articulo_page.dart';
import 'presentation/pages/configuracion_page.dart';
import 'presentation/pages/enviar_lecturas_page.dart';
import 'presentation/pages/historial_envios_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/lector_page.dart';
import 'presentation/pages/login_page.dart';
import 'data/datasources/articulo_local_datasource.dart';
import 'data/datasources/articulo_remote_datasource.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/config_local_datasource.dart';
import 'data/datasources/lectura_local_datasource.dart';
import 'data/datasources/lectura_remote_datasource.dart';
import 'data/repositories/articulo_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/configuracion_repository_impl.dart';
import 'data/repositories/lectura_repository_impl.dart';
import 'core/services/catalog_version_service.dart';
import 'domain/usecases/actualizar_lectura_usecase.dart';
import 'domain/usecases/actualizar_articulo_usecase.dart';
import 'domain/usecases/buscar_articulo_usecase.dart';
import 'domain/usecases/clear_session_usecase.dart';
import 'domain/usecases/enviar_lecturas_usecase.dart';
import 'domain/usecases/get_configuracion_usecase.dart';
import 'domain/usecases/obtener_articulos_usecase.dart';
import 'domain/usecases/obtener_lecturas_usecase.dart';
import 'domain/usecases/obtener_lecturas_por_fecha_usecase.dart';
import 'domain/usecases/registrar_lectura_usecase.dart';
import 'domain/usecases/save_configuracion_usecase.dart';
import 'domain/usecases/sincronizar_catalogo_usecase.dart';
import 'presentation/providers/actualizar_articulo_provider.dart';
import 'presentation/providers/configuracion_provider.dart';
import 'presentation/providers/lector_provider.dart';
import 'presentation/providers/login_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';

  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  await dbHelper.database;

  final SharedPreferences sharedPreferences =
      await SharedPreferences.getInstance();
  final http.Client httpClient = http.Client();

  runApp(
    MyApp(
      sharedPreferences: sharedPreferences,
      dbHelper: dbHelper,
      httpClient: httpClient,
    ),
  );
}

class MyApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;
  final DatabaseHelper dbHelper;
  final http.Client httpClient;

  const MyApp({
    super.key,
    required this.sharedPreferences,
    required this.dbHelper,
    required this.httpClient,
  });

  @override
  Widget build(BuildContext context) {
    final configRepository = ConfiguracionRepositoryImpl(
      localDataSource: ConfigLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
      ),
    );

    final authLocal = AuthLocalDataSourceImpl(
      sharedPreferences: sharedPreferences,
    );

    final articuloLocalDataSource = ArticuloLocalDataSourceImpl(
      getDatabase: () => dbHelper.database,
    );

    final articuloRepository = ArticuloRepositoryImpl(
      remoteDataSource: ArticuloRemoteDataSourceImpl(
        client: httpClient,
        configRepository: configRepository,
        authLocalDataSource: authLocal,
      ),
      localDataSource: articuloLocalDataSource,
    );

    final lecturaRepository = LecturaRepositoryImpl(
      localDataSource: LecturaLocalDataSourceImpl(dbHelper: dbHelper),
      remoteDataSource: LecturaRemoteDataSourceImpl(
        client: httpClient,
        configRepository: configRepository,
        authLocalDataSource: authLocal,
      ),
    );

    final authRepository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSourceImpl(
        client: httpClient,
        configRepository: configRepository,
      ),
      localDataSource: authLocal,
    );

    final obtenerLecturasPorFechaUseCase = ObtenerLecturasPorFechaUseCase(
      lecturaRepository,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LoginProvider(
            ClearSessionUseCase(authRepository),
            AuthRemoteDataSourceImpl(
              client: httpClient,
              configRepository: configRepository,
            ),
            authLocal,
            CatalogVersionService(preferences: sharedPreferences),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ConfiguracionProvider(
            getConfiguracionUseCase: GetConfiguracionUseCase(configRepository),
            saveConfiguracionUseCase: SaveConfiguracionUseCase(
              configRepository,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ActualizarArticuloProvider(
            buscarArticuloUseCase: BuscarArticuloUseCase(articuloRepository),
            actualizarArticuloUseCase: ActualizarArticuloUseCase(
              articuloRepository,
            ),
            sincronizarCatalogoUseCase: SincronizarCatalogoUseCase(
              articuloRepository,
            ),
            obtenerArticulosUseCase: ObtenerArticulosUseCase(
              articuloRepository,
            ),
            localDataSource: articuloLocalDataSource,
            repository: articuloRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LectorProvider(
            buscarArticuloUseCase: BuscarArticuloUseCase(articuloRepository),
            registrarLecturaUseCase: RegistrarLecturaUseCase(lecturaRepository),
            enviarLecturasUseCase: EnviarLecturasUseCase(lecturaRepository),
            obtenerLecturasUseCase: ObtenerLecturasUseCase(lecturaRepository),
            actualizarLecturaUseCase: ActualizarLecturaUseCase(
              lecturaRepository,
            ),
            getConfiguracionUseCase: GetConfiguracionUseCase(configRepository),
            authLocalDataSource: authLocal,
            obtenerLecturasPorFechaUseCase: obtenerLecturasPorFechaUseCase,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Scanpal',
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const LoginPage(),
          '/home': (_) => const HomePage(),
          '/configuracion': (_) => const ConfiguracionPage(),
          '/actualizar_articulos': (_) => const ActualizarArticuloPage(),
          '/lector': (_) => const LectorPage(),
          '/enviar_lecturas': (_) => const EnviarLecturasPage(),
          '/historial_envios': (_) => const HistorialEnviosPage(),
        },
      ),
    );
  }
}
