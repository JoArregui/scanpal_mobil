import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// === SPLASH SCREEN ===
import 'presentation/pages/splash_page.dart';

// === CORE ===
import 'core/database_helper.dart';

// === DATASOURCES ===
import 'data/datasources/articulo_local_datasource.dart';
import 'data/datasources/articulo_remote_datasource.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/config_local_datasource.dart';
import 'data/datasources/lectura_local_datasource.dart';
import 'data/datasources/lectura_remote_datasource.dart';
// PRESENTACION: datasources de documentos (solo Ventas/Compras/Comprobar) ocultos.
// import 'data/datasources/documento_local_datasource.dart';
// import 'data/datasources/documento_remote_datasource.dart';

// === REPOSITORIES ===
import 'data/repositories/articulo_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/configuracion_repository_impl.dart';
import 'data/repositories/lectura_repository_impl.dart';
// PRESENTACION: repositorio de documentos oculto.
// import 'data/repositories/documento_repository_impl.dart';

// === DOMAIN ===
import 'domain/usecases/actualizar_articulo_usecase.dart';
import 'domain/usecases/actualizar_lectura_usecase.dart';
import 'domain/usecases/buscar_articulo_usecase.dart';
import 'domain/usecases/clear_session_usecase.dart';
import 'domain/usecases/enviar_lecturas_usecase.dart';
import 'domain/usecases/get_configuracion_usecase.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/obtener_articulos_usecase.dart';
import 'domain/usecases/obtener_lecturas_usecase.dart';
import 'domain/usecases/obtener_lecturas_por_fecha_usecase.dart';
import 'domain/usecases/registrar_lectura_usecase.dart';
import 'domain/usecases/save_configuracion_usecase.dart';
import 'domain/usecases/sincronizar_catalogo_usecase.dart';
// PRESENTACION: Ventas/Compras/Comprobar ocultos.
// import 'domain/usecases/obtener_documento_usecase.dart';
// import 'domain/usecases/guardar_documento_usecase.dart';
// import 'domain/usecases/comparar_documento_usecase.dart';
// import 'domain/entities/tipo_operacion.dart';

// === PROVIDERS ===
import 'presentation/providers/actualizar_articulo_provider.dart';
import 'presentation/providers/configuracion_provider.dart';
import 'presentation/providers/lector_provider.dart';
import 'presentation/providers/login_provider.dart';
// PRESENTACION: providers de Ventas/Compras/Comprobar ocultos.
// import 'presentation/providers/compra_provider.dart';
// import 'presentation/providers/venta_provider.dart';
// import 'presentation/providers/comprobacion_provider.dart';

// === PAGES ===
import 'presentation/pages/actualizar_articulo_page.dart';
import 'presentation/pages/configuracion_page.dart';
import 'presentation/pages/enviar_lecturas_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/lector_page.dart';
import 'presentation/pages/login_page.dart';
// PRESENTACION: páginas de Ventas/Compras/Comprobar ocultas.
// import 'presentation/pages/ventas_page.dart';
// import 'presentation/pages/compras_page.dart';
import 'presentation/pages/historial_envios_page.dart';
// import 'presentation/pages/comprobacion_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    // Definición de dependencias compartidas para ser usadas en los 'create' de los Providers
    final configRepository = ConfiguracionRepositoryImpl(
      localDataSource: ConfigLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
      ),
    );

    final articuloLocalDataSource = ArticuloLocalDataSourceImpl(
      getDatabase: () => dbHelper.database,
    );

    final articuloRepository = ArticuloRepositoryImpl(
      remoteDataSource: ArticuloRemoteDataSourceImpl(
        client: httpClient,
        configRepository: configRepository,
      ),
      localDataSource: articuloLocalDataSource,
    );

    final lecturaRepository = LecturaRepositoryImpl(
      localDataSource: LecturaLocalDataSourceImpl(dbHelper: dbHelper),
      remoteDataSource: LecturaRemoteDataSourceImpl(
        client: httpClient,
        configRepository: configRepository,
      ),
    );

    final authRepository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSourceImpl(
        client: httpClient,
        configRepository: configRepository,
      ),
      localDataSource: AuthLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
      ),
    );

    final authLocal = AuthLocalDataSourceImpl(
      sharedPreferences: sharedPreferences,
    );

    final obtenerLecturasPorFechaUseCase = ObtenerLecturasPorFechaUseCase(
      lecturaRepository,
    );

    // PRESENTACION: repositorio de documentos (solo Ventas/Compras/Comprobar) oculto.
    // final documentoRepository = DocumentoRepositoryImpl(
    //   localDataSource: DocumentoLocalDataSourceImpl(dbHelper: dbHelper),
    //   remoteDataSource: DocumentoRemoteDataSourceImpl(
    //     client: httpClient,
    //     configRepository: configRepository,
    //   ),
    // );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LoginProvider(
            LoginUseCase(authRepository),
            ClearSessionUseCase(authRepository),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ConfiguracionProvider(
            getConfiguracionUseCase: GetConfiguracionUseCase(configRepository),
            saveConfiguracionUseCase: SaveConfiguracionUseCase(configRepository),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LectorProvider(
            buscarArticuloUseCase: BuscarArticuloUseCase(articuloRepository),
            registrarLecturaUseCase: RegistrarLecturaUseCase(lecturaRepository),
            enviarLecturasUseCase: EnviarLecturasUseCase(lecturaRepository),
            obtenerLecturasUseCase: ObtenerLecturasUseCase(lecturaRepository),
            actualizarLecturaUseCase: ActualizarLecturaUseCase(lecturaRepository),
            getConfiguracionUseCase: GetConfiguracionUseCase(configRepository),
            authLocalDataSource: authLocal,
            obtenerLecturasPorFechaUseCase: obtenerLecturasPorFechaUseCase,
          ),
        ),
        // PRESENTACION: providers de Ventas/Compras/Comprobar ocultos.
        // ChangeNotifierProvider(
        //   create: (_) => CompraProvider(
        //     buscarArticuloUseCase: BuscarArticuloUseCase(articuloRepository),
        //     registrarLecturaUseCase: RegistrarLecturaUseCase(lecturaRepository),
        //     enviarLecturasUseCase: EnviarLecturasUseCase(lecturaRepository),
        //     obtenerLecturasUseCase: ObtenerLecturasUseCase(lecturaRepository),
        //     actualizarLecturaUseCase: ActualizarLecturaUseCase(lecturaRepository),
        //     getConfiguracionUseCase: GetConfiguracionUseCase(configRepository),
        //     obtenerLecturasPorFechaUseCase: obtenerLecturasPorFechaUseCase,
        //   ),
        // ),
        // ChangeNotifierProvider(
        //   create: (_) => VentaProvider(
        //     buscarArticuloUseCase: BuscarArticuloUseCase(articuloRepository),
        //     registrarLecturaUseCase: RegistrarLecturaUseCase(lecturaRepository),
        //     enviarLecturasUseCase: EnviarLecturasUseCase(lecturaRepository),
        //     obtenerLecturasUseCase: ObtenerLecturasUseCase(lecturaRepository),
        //     actualizarLecturaUseCase: ActualizarLecturaUseCase(lecturaRepository),
        //     getConfiguracionUseCase: GetConfiguracionUseCase(configRepository),
        //     obtenerLecturasPorFechaUseCase: obtenerLecturasPorFechaUseCase,
        //   ),
        // ),
        // ChangeNotifierProvider(
        //   create: (_) => ComprobacionProvider(
        //     obtenerDocumentoUseCase: ObtenerDocumentoUseCase(
        //       documentoRepository,
        //     ),
        //     guardarDocumentoUseCase: GuardarDocumentoUseCase(
        //       documentoRepository,
        //     ),
        //     compararDocumentoUseCase: CompararDocumentoUseCase(
        //       documentoRepository,
        //       lecturaRepository,
        //     ),
        //     documentoRepository: documentoRepository,
        //   ),
        // ),
        ChangeNotifierProvider(
          create: (_) => ActualizarArticuloProvider(
            buscarArticuloUseCase: BuscarArticuloUseCase(articuloRepository),
            actualizarArticuloUseCase: ActualizarArticuloUseCase(articuloRepository),
            sincronizarCatalogoUseCase: SincronizarCatalogoUseCase(
              articuloRepository,
            ),
            obtenerArticulosUseCase: ObtenerArticulosUseCase(articuloRepository),
            localDataSource: articuloLocalDataSource,
            repository: articuloRepository,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'ScanPal',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 0, 47, 108)),
          scaffoldBackgroundColor: Colors.white,
        ),
        // Usamos home en lugar de initialRoute para asegurar que la Splash cargue primero
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const LoginPage(),
          '/home': (_) => const HomePage(),
          '/configuracion': (_) => const ConfiguracionPage(),
          '/actualizar_articulos': (_) => const ActualizarArticuloPage(),
          '/lector': (_) => const LectorPage(),
          // PRESENTACION: rutas de Ventas/Compras/Comprobar ocultas.
          // '/venta': (_) => const VentasPage(),
          // '/compra': (_) => const ComprasPage(),
          '/enviar_lecturas': (_) => const EnviarLecturasPage(),
          '/historial_envios': (_) => const HistorialEnviosPage(),
          // '/comprobacion_compra': (_) =>
          //     const ComprobacionPage(tipo: TipoOperacion.compra),
          // '/comprobacion_venta': (_) =>
          //     const ComprobacionPage(tipo: TipoOperacion.venta),
        },
      ),
    );
  }
}