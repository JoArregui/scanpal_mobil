# ScanPal — Documentación del Proyecto (Estado Actual)

> **Proyecto:** `scanpal_OLD` / paquete `scanpalphone_app`
> **Versión:** `1.0.0+1`
> **Fecha documentación:** 14/10/2026
> **Stack:** Flutter (Dart SDK `^3.9.2`), Clean Architecture + Provider
> **Plataformas:** `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/` (operativa real en Android)
> **Idioma:** `es-ES` — `MaterialApp(locale: es_ES)`
> **Tema:** Material 3, `seedColor: Color(0,47,108)` azul oscuro, `scaffoldBackgroundColor: white`

---

## 1. Descripción general

**ScanPal** es una app móvil Flutter de gestión de almacén con escáner para operarios de tienda/almacén (caso de uso: `Viveros Nava` / `Ecomputer`).

Funcionalidades principales:

1. **Login contra ERP** (`persona/GetCodigo`) y trabajo **offline-first**.
2. **Sincronización masiva de catálogo** de artículos (`articulo/GetCodigos`) a SQLite local.
3. **Escaneo continuo con cámara** (`mobile_scanner`) + parser propio `BarcodeParser` (EAN-13/8, UPC-A, GS1-128, Code128/39, heurísticas `Ref/Lote` y `Lote - Fecha`).
4. **Tres modos de operación** separados por `TipoOperacion`:
   - **Inventario** → ruta `/lector` (`LectorPage` + `LectorProvider`)
   - **Ventas / Salidas** → ruta `/venta` (`VentasPage` + `VentaProvider`)
   - **Compras / Entradas** → ruta `/compra` (`ComprasPage` + `CompraProvider`)
5. **Registro local de `Lectura`** (código, referencia, cantidad, lote, descatalogado), edición/borrado, envío por lotes a `Lectura/Guardar` con `Tipo=I/C/V`, historial/auditoría 90 días, exportación CSV/TXT.
6. **Gestión de catálogo:** dashboard Activos / Descatalogados / Total, búsqueda global, paginación, edición local/remota (`articulo/guardar`), exportación CSV.
7. **Configuración:** `urlBase`, `cantidadMinima`, `lecturaAutomatica`. URL bloqueada salvo `admin0`.

---

## 2. Arquitectura

Patrón **Clean Architecture + MVVM con Provider**:

```
lib/main.dart (DI manual)
├── core/
│   ├── constants.dart
│   ├── database_helper.dart
│   ├── barcode_parser.dart (~805 líneas)
│   ├── exceptions.dart
│   ├── sync_progress.dart
│   └── services/logger_service.dart
├── domain/
│   ├── entities/ (articulo, lectura, configuracion, usuario, tipo_operacion, opcion_menu, articulo_duplicado)
│   ├── repositories/ (abstract: articulo, lectura, auth, configuracion)
│   └── usecases/ (13 casos de uso con método execute())
├── data/
│   ├── datasources/ (articulo_remote/local, lectura_remote/local, auth_remote/local, config_local)
│   ├── models/ (articulo_model.dart, lectura_ws_model.dart)
│   └── repositories/ (*_impl.dart)
└── presentation/
    ├── pages/ (9 pantallas)
    ├── providers/ (6 ChangeNotifierProvider)
    ├── widgets/ (9 widgets)
    └── utils/menu_options.dart
```

`main.dart`:

- `ensureInitialized`, abre `DatabaseHelper.instance.database`, `SharedPreferences.getInstance()`, `http.Client()`.
- Construye `ConfiguracionRepositoryImpl`, `ArticuloRepositoryImpl`, `LecturaRepositoryImpl`, `AuthRepositoryImpl`.
- Inyecta en `MultiProvider` 6 providers: `LoginProvider`, `ConfiguracionProvider`, `LectorProvider`, `CompraProvider`, `VentaProvider`, `ActualizarArticuloProvider`.
- `MaterialApp(home: SplashScreen, routes: /login, /home, /configuracion, /actualizar_articulos, /lector, /venta, /compra, /enviar_lecturas, /historial_envios)`.

Patrones aplicados:

- Repository + DataSource local/remoto.
- UseCase de un solo propósito.
- `Stream<SyncProgress>` para sincronización con progreso.
- Caché LRU en memoria (300 art. en local DS, 150/30 min en provider).
- `Isolate` + `Batch` SQLite para inserción masiva.
- `Provider` (`ChangeNotifier`) para estado UI.

---

## 3. Entidades del dominio (`lib/domain/entities/`)

| Entidad | Fichero | Campos |
|---|---|---|
| `Articulo` | `articulo.dart` | `codigo` PK (CodigoBarras), `descripcion`, `referencia` (split `.`), `lote?`, `cantidadMinima: int`, `descatalogado: bool`, `gestionLotes: bool` + `fromJson/toJson/copyWith/==hashCode(codigo)` tolerante int/String/bool/double |
| `Lectura` | `lectura.dart` | `id?, codigoArticulo, referenciaArticulo, cantidad: double, fechaRegistro, fechaEnvio?, idUsuario=0, sincronizado=false, lote?, esDescatalogado=false, descripcion?, tipoOperacion=inventario` + `toMap/fromMap` SQLite, `toJson` WS `{Referencia:int, CodigoBarras, Cantidad:int, Usuario, Lote, FechaEnvio: YYYY-MM-DD HH:mm:ss}` |
| `Configuracion` | `configuracion.dart` | `urlBase, cantidadMinima, lecturaAutomatica` + `inicial() = AppConstants.baseUrl, 1, false` |
| `Usuario` | `usuario.dart` | DTO `{nombre, password}` (el código real `int Codigo` lo devuelve el servidor) |
| `TipoOperacion` | `tipo_operacion.dart` | `enum {inventario, compra, venta}` → WS `I/C/V`, columna SQLite `tipo_operacion TEXT DEFAULT 'inventario'` |
| `OpcionMenu` | `opcion_menu.dart` | `{titulo, icono: IconData, ruta}` |
| `ArticuloDuplicado` | `articulo_duplicado.dart` | `{id?, articulo: Articulo, motivo, fechaDeteccion}` |

Modelos (`lib/data/models/`):

- `ArticuloModel extends Articulo`: `fromJson` acepta `CodigoBarras/Codigo`, split `codigo/lote` por `/`, `Descripcion/Nombre`, `StockMinimo/CantidadMinima`, `fromJsonList` tolerante.
- `LecturaWSModel`: `{codigoBarras, referencia:int, cantidad, usuario, lote?, fecha}` + `fromEntity` (split `/` Navas), `toJson {Referencia, CodigoBarras, Cantidad, Usuario, Lote, FechaEnvio: YYYY-MM-DD}`.

---

## 4. Persistencia local

### 4.1 `core/database_helper.dart`

- BD `ScanPalDB.db v1`, singleton.
- `PRAGMA foreign_keys=ON, journal_mode=WAL, synchronous=NORMAL, temp_store=MEMORY`.
- Path vía `path_provider` + `getDatabasePath()`.
- Utilidades: `vacuum(), analyze(), getDiagnostics(), close(), invalidate()`.

### 4.2 `core/constants.dart`

- `baseUrl = https://scanpal.ecomputer.es`
- `batchSize=500, maxRetries=3, retryDelaySeconds=2, apiTimeoutSeconds=10`
- `adminUser = admin0`
- Sonidos: `sounds/Articulo_descatalogado.mp3`, `sounds/Articulo_no_local.mp3`

### 4.3 Tablas

```sql
lecturas(_id PK AI, codigo_articulo TEXT NOT NULL, referencia_articulo TEXT NOT NULL,
 cantidad REAL NOT NULL, fecha_registro TEXT NOT NULL, fecha_envio TEXT,
 id_usuario INTEGER NOT NULL, sincronizado INTEGER DEFAULT 0,
 lote TEXT, es_descatalogado INTEGER DEFAULT 0, descripcion TEXT,
 tipo_operacion TEXT DEFAULT 'inventario');

articulos(codigo TEXT PK, descripcion TEXT NOT NULL, referencia TEXT NOT NULL,
 lote TEXT, cantidad_minima INTEGER NOT NULL,
 descatalogado INTEGER DEFAULT 0, gestion_lotes INTEGER DEFAULT 0);

logs(id PK AI, timestamp TEXT, level TEXT, message TEXT, paquete INTEGER);
metadata(key TEXT PK, value TEXT NOT NULL);
-- índices: idx_articulos_referencia, idx_lecturas_sincronizado, idx_lecturas_tipo
```

> `articulos_duplicados(id AI, codigo, descripcion, referencia, lote, cantidad_minima, descatalogado, gestion_lotes, motivo_duplicidad, fecha_deteccion)` **no se crea en `_onCreate`**, solo con `CREATE TABLE IF NOT EXISTS` en el isolate de `articulo_local_datasource.dart`.

Claves `metadata`: `total_articulos_api, total_activos_api, total_descatalogados_api, total_duplicados_api`.

---

## 5. Lógica de negocio clave

### 5.1 `core/barcode_parser.dart`

- `enum TipoCodigo {ean13, ean8, upc, gs1, code128, nava, code39, desconocido}`.
- `BarcodeData {tipo, codigoArticulo, lote?, fechaCaducidad/Produccion/Envasado/ConsumoPreferente?, cantidad?, pesoNeto/Bruto?, scc?, numeroPedido?, variante?, numeroSerie?, glnDestino?, codigoPostal?, todosLosIAs, rawData}`.
- Catálogo GS1 ~45 AIs (`00 SSCC, 01/02 GTIN, 11/12/13/15/17 fechas YYMMDD, 10 lote, 21 serie, 30/37 cantidad, 310x peso, 400 pedido, 410-415 GLN, 420/421 CP, 390-393 importe, 7001/7002, 8001-8004, 90-99 interno`).
- `parse()`:
  1. Heurística `/` → `nava (Ref/Lote)`.
  2. Heurística ` - ` o `dd/MM/yyyy` → `nava (lote=ref)`.
  3. `_esGS1 (]C1 / FNC1 \u001D / 01 / 00)` → `_parseGS1Total`.
  4. EAN-13 `^\d{13}$`, EAN-8 `^\d{8}$`, UPC `^\d{12}$ → 0+cod`.
  5. Limpieza `[%$]` → `code39`, defecto `code128`.

### 5.2 Sincronización de catálogo

`SincronizarCatalogoUseCase → ArticuloRepositoryImpl.sincronizarArticulos → ArticuloRemoteDataSource.getArticulos → ArticuloLocalDataSource.saveArticulos (Isolate)`.

- Isolate clasifica únicos/duplicados por `codigo`, transacción atómica `delete + batch chunk 1500`.
- Emite `SyncProgress {procesados, total, porcentaje, articulosPorSegundo, elapsed}` por `SendPort → StreamController.broadcast`.
- Guarda stats en `metadata`, timeout 15 min.
- `ActualizarArticuloProvider` reintenta x3 con backoff.

### 5.3 Búsqueda de artículos

`BuscarArticuloUseCase.execute(cod)`:

1. `getArticuloByCodigo` (exacto código → referencia exacta → `LIKE %cod%` código → `LIKE %cod%` referencia, caché 300).
2. `getArticuloDuplicadoByCodigo`.
3. `buscarArticulosPorTexto LIKE %q% codigo/descripcion/referencia` (1→directo, N→primero).
4. `executeFuzzy`: extrae antes de `/,%`, solo dígitos, prefijos 5→4→3, `LIKE`.
- Providers añaden fallbacks `12 → 0+cod`, `padLeft 13/14`, `2xxxxxx peso variable 7 dígitos`.

### 5.4 Lecturas

- `RegistrarLecturaUseCase`: valida `>0`, limpia NBSP, `registrarLectura → saveLectura`.
- `ObtenerLecturasUseCase(tipo) → getLecturasPendientesPorTipo (sincronizado=0 AND tipo ORDER fecha DESC)`.
- `ActualizarLecturaUseCase {execute (nuevaCantidad → sincronizado=false, fechaEnvio=null), delete(id)}`.
- `EnviarLecturasUseCase(tipo)`: marca `fechaEnvio=now`, `sendLecturas → marcarComoSincronizadas`, retorna count. Purga 90 días.

### 5.5 Login y configuración

- `LoginUseCase → AuthRepositoryImpl.login → AuthRemoteDataSource.login → AuthLocalDataSource.saveUserCode`. `ClearSessionUseCase → clearUserCode`.
- `Get/SaveConfiguracionUseCase → ConfiguracionRepositoryImpl → ConfigLocalDataSource (SharedPreferences: urlBaseKey, cantidadMinimaKey, lecturaAutomaticaKey)`.

---

## 6. Pantallas (`lib/presentation/pages/`)

| Página | Ruta | Descripción |
|---|---|---|
| `splash_page.dart` (`SplashScreen`) | `/` (home) | Animación 3800 ms (`AnimationController`, `TweenSequence` move/rot/scale, logo 200 `assets/icon/Ecomputer.jpg`) → `pushReplacement LoginPage` fade 700 ms |
| `login_page.dart` (`LoginPage`) | `/login` | `Form` usuario/pass, `logout()` al entrar, fija `_fixedDbUrl=AppConstants.baseUrl`, `logear(user,pass,lectorProvider) → /home`. `Consumer2<Login,Config>`, botón azul `0,47,108`, responsive 450 px. `LongPress` título → diálogo admin (`admin0 → /configuracion`) |
| `home_page.dart` (`HomePage`) | `/home` | `GridView menuOptions` (2/3/4 cols, max 1200), `HomeMenuItem`, `logout` con confirm, `FAB.extended Escanear → /lector` |
| `lector_page.dart` (`LectorPage`) | `/lector` | **Inventario.** `MobileScannerController(unrestricted, all, autoStart:false)`, estabilidad 5 lecturas, debounce 2 s, zoom 0.0-1.0 (1x-5x), torch, `_procesarEntradaCodigo → BarcodeParser → buscarArticulo → fuzzy dialog → DialogoRegistroArticulo o auto-registro si lecturaAutomatica && !descatalogado && loteOK`. Layout responsive (`>900` Row 30/70, else Column 30% cámara + info + tabla). `FAB.large` toggle/disparo |
| `ventas_page.dart` (`VentasPage`) | `/venta` | **Salida.** Idéntica a lector pero con `VentaProvider`, `noDuplicates`, bloqueo 3 s, sin fuzzy, sin `inicializarDatos` catálogo |
| `compras_page.dart` (`ComprasPage`) | `/compra` | **Entrada (AppBar verde).** Idéntica a ventas con `CompraProvider` |
| `actualizar_articulo_page.dart` | `/actualizar_articulos` | Catálogo + dashboard `ACTIVOS/DESCATAL./TOTAL` (metadata remota), búsqueda global debounce 500 ms + scroll infinito (50/pág, prefetch 300 px, buffer 1000), `ListTile` REF/CB/estado, `share` CSV, `cloud_download` → diálogo sync con `%`, `art/s`, `LinearProgress`. Auto-sync si `conteoFisicoReal==0`. `PopScope` gestiona búsqueda/selección |
| `configuracion_page.dart` | `/configuracion` | `urlController/cantidadController/Switch lecturaAutomatica`. URL `readOnly` salvo `isSuperAdmin \|\| desbloqueoManual` (diálogo pass `admin0`), botón `Restaurar URL`, validación, `Switch` solo si `cantidad>0`, guardar → `pop`. Responsive 600 px |
| `enviar_lecturas_page.dart` | `/enviar_lecturas` | Carga pendientes 3 providers + config, header total, 3 `ExpansionTile + DataTable (Código/Lote/Cant./Ref.)` con colores (azul/verde/naranja, naranja descat., rojo cant.<min), sync individual/global, `LoadingOverlay`, diálogos éxito/error |
| `historial_envios_page.dart` | `/historial_envios` | **Auditoría.** `TableCalendar (locale es_ES, 90d→now, monday)` con `eventLoader` punto verde (`SELECT DISTINCT substr(fecha_envio,1,10) WHERE sincronizado=1`), header `Sincronizaciones dd/MM/yyyy + N confirmados`, `ListView` hora/descripción/cod-ref/lote/cant., export TXT (`comprobante_envio_yyyyMMdd.txt` vía `share_plus`), purga 90 d. Solo `LectorProvider` (inventario) |

---

## 7. Providers (`lib/presentation/providers/`)

| Provider | Estado | Responsabilidad |
|---|---|---|
| `lector_provider.dart` (`LectorProvider`, tipo=inventario) | `LectorState {initial, loadingArticulo, loaded, descatalogado, duplicado, registering, error, loadingLecturas, sending, sendSuccess, sendError, noEncontradoFuzzy}` | Carga `userId (getUserCode ?? 1)`, config, pendientes, purga. `buscarArticulo` + 4 fallbacks + fuzzy, `registrarLectura (default=config.cantidadMinima)`, `enviarLecturasAlServidor`, `editar/borrar/borrarTodas`, `obtenerHistorialPorFecha`, `obtenerDiasConLecturas`, `limpiarHistorialAntiguo(90)`, sonidos `audioplayers` (triple warning descat.). `refrescarUsuarioDinamico()` tras login |
| `venta_provider.dart` / `compra_provider.dart` | `VentaState` / `CompraState` (sin fuzzy/duplicado, `currentUserId=1` fijo, sin auth DS) | Misma API `buscar/registrar/obtenerPendientes/historial/enviarVentas-Compras/borrar/editar/reset/limpiarHistorial` |
| `login_provider.dart` | `LoginState {initial, loading, success, error}` | `isSuperAdmin (nombre==admin0)`, `logear(nombre,pass,lectorProvider) + refrescarUsuarioDinamico`, `logout → clearSession`, `setSuperAdminManually` |
| `configuracion_provider.dart` | `ConfiguracionState {initial, loading, loaded, saving, success, error}` | `cargarConfiguracion`, `guardarConfiguracion(url,cantidad,{lecturaAutomatica})`, `clearBaseUrl → inicial` |
| `actualizar_articulo_provider.dart` | `ActualizarArticuloState {initial, searching, loaded, error, syncing, listLoaded, loadingMore, exporting, success}` | Métricas `_totalArticulos/Activos/Descatalogados (metadata) + conteoFisicoReal`, paginación `page/pageSize 50/hasMore`, caché 150/30 min, debounce, reintentos x3/90 s, `syncProgressStream → progreso`, `inicializarDatos/cargarArticulosLocal/cargarMas/buscarGlobalmenteEnBDLocal/actualizarArticulo(remoto/local)/compartirReportes(CSV Temp+share_plus)/sincronizarYRecargar/reset` |

---

## 8. Widgets y utils

- `widgets/lectura_view_model.dart`: wrapper `{lectura, descripcionArticulo}` + getters `codigo/referencia/cantidad/lote/esDescatalogado/descripcionLimpia` (limpian NBSP).
- `widgets/dialogo_registro_articulo.dart` (`DialogoRegistroArticulo`): campos cantidad (autofocus + select-all, aviso morado si `<minGlobal`) y lote (obligatorio si `gestionLotes`, badge `auto_awesome` si GS1, muestra `Caducidad dd/MM/yyyy`), valida `>0`, llama `provider.registrarLectura → pop(true)`.
- `widgets/dialogos_lector.dart` (`DialogosLector`): `confirmarBorrarTodo`, `mostrarDialogoEdicion (Borrar/Editar)`, `_mostrarDialogoCambiarCantidad`, `mostrarBuscadorFuzzy ({sugerencias, codigoEscaneado, onBuscar}) → Articulo?` con `StatefulBuilder`.
- `widgets/camera_view_section.dart`: `MobileScanner (scanWindow 70%x60%, fit cover)` + `ScannerOverlayPainter`, textos `Centra el código`, barra estabilidad, zoom 1x-5x, pantallas `ESCANEO PAUSADO (doble-tap)` / `Buscando...`.
- `widgets/scanner_overlay_painter.dart`: `CustomPaint` sombra `black54` + `RRect` borde.
- `widgets/lector_info_bar.dart`: gris, `Entrada Manual` + `Último: xxx`.
- `widgets/lecturas_data_table.dart` (`LecturasDataTable`): `DataTable (Art/Lote, Descripción, Cant.)`, orden `reversed`, colores naranja descat. / morado cant. baja, doble-tap por celda.
- `widgets/home_menu_item.dart`: `Card + InkWell → pushNamed(ruta)`, icono 48 primary + título 2 lín.
- `widgets/loading_overlay.dart`: `Stack + black54 + Card (Circular + message + no cierre)`.
- `utils/menu_options.dart`: 7 `OpcionMenu`: Configuración (`settings → /configuracion`), Actualizar Artículos (`cloud_download → /actualizar_articulos`), Leer Códigos (`qr_code_scanner → /lector`), Enviar Lecturas (`cloud_upload → /enviar_lecturas`), Historial (`history → /historial_envios`), Ventas (`point_of_sale → /venta`), Compras (`shopping_cart → /compra`).

---

## 9. Servicios y backend

### 9.1 `core/services/logger_service.dart` (singleton)

`log(msg, {level, paquete}) → INSERT logs + append sync_logs.txt (getApplicationDocumentsDirectory)`, `getDbLogs(limit 100 ORDER id DESC)`, `clearLogs()`, `getLogFile()`. Niveles `START/SUCCESS/WARNING/CRITICAL/END/INFO`.

### 9.2 `core/sync_progress.dart`

`{procesados, total, porcentaje, articulosPorSegundo, elapsed}`.

### 9.3 `core/exceptions.dart`

`ServerException, NotFoundException (404), UnauthorizedException (401), CacheException, NoLocalDataException`.

### 9.4 Endpoints HTTP (`http.Client`, `Content-Type/Accept: application/json`, `urlBase` de config)

| Método | Endpoint | Uso |
|---|---|---|
| `GET` | `{base}/persona/GetCodigo/{nombre}/{password}` timeout 15 s | Login → `[{Codigo}]\|{Codigo}\|int` → `userCode>0` OK (`auth_remote_datasource.dart`) |
| `GET` | `{base}/articulo/GetCodigos` timeout 5 min | Sync catálogo → `List` JSON utf8, rechaza HTML `<` (`articulo_remote_datasource.dart`) |
| `GET` | `{base}/articulo/GetCodigos?Filtro=CodigoBarras='{cod}'` | Búsqueda unitaria |
| `POST` | `{base}/articulo/guardar` `{CodigoBarras, Descripcion, CantidadMinima, Referencia, Lote, Descatalogado:0/1, GestionLotes:0/1}` | Actualizar artículo → 200 OK |
| `POST` | `{base}/Lectura/Guardar` chunks 500 | `[{Referencia:int (solo dígitos, split /), CodigoBarras, Cantidad:int, Usuario:idUsuario, Lote, FechaEnvio:YYYY-MM-DD HH:mm:ss, Tipo:I/C/V}]`, timeout 10 s, retry 3x2 s, valida `LecturasRecibidas==enviadas` (0 → sin permisos usuario), `LoggerService` por paquete (`lectura_remote_datasource.dart`) |

Local DS: `auth_local (SharedPreferences userCodeKey)`, `config_local (urlBaseKey, cantidadMinimaKey, lecturaAutomaticaKey)`, `articulo_local` (counts, `saveStatsAPI`, `getTotal*API` metadata, `getArticuloByCodigo` 4 intentos, `saveArticulo/replace`, `saveArticulos (Isolate)`, `getAll/buscar (LIKE LIMIT 100)`, `clear`, `generarCsvCompleto (SCANPAL_CATALOGO_COMPLETO.csv Temp: sep=; CÓDIGO;DESCRIPCIÓN;REFERENCIA;LOTE;CANT_MIN;ESTADO) / generarCsvDuplicados`), `lectura_local` (`save/update/deleteById/clear/markSynced (batch)/deleteOld (days)` + limpieza NBSP + delays 30-50 ms).

---

## 10. Assets y dependencias

### Assets declarados (`pubspec.yaml flutter.assets`)

- `assets/sounds/Articulo_descatalogado.mp3`
- `assets/sounds/Articulo_no_local.mp3`
- `assets/sounds/Caducidad.mp3` (declarado pero no referenciado en código — solo se usan los 2 anteriores)
- `assets/images/Ecomputer.jpg`
- `assets/icon/Ecomputer.jpg`

Físicos en disco: `icon/Ecomputer.jpg`, `images/Ecomputer.jpg, screen_scanpal.jpg, ScanPal.png, ScanPal-APP.jpg`, `sounds/Caducidad.mp3, Articulo_no_local.mp3, Articulo_descatalogado.mp3`.

`flutter_launcher_icons: android launcher_icon, ios true, image_path assets/images/ScanPal.png, min_sdk_android 21`. Splash usa `assets/icon/Ecomputer.jpg`.

### Dependencias (`pubspec.yaml`)

`cupertino_icons ^1.0.8, shared_preferences ^2.5.3, mobile_scanner ^7.1.2, provider ^6.1.5+1, http ^1.5.0, intl ^0.20.2, sqflite ^2.4.2, path ^1.9.1, path_provider ^2.1.5, audioplayers ^6.5.1, share_plus ^12.0.1, table_calendar ^3.2.0, flutter_localizations (sdk), sqflite_android ^2.4.2+2`.

Dev: `flutter_test, flutter_lints ^5.0.0, hive ^2.2.3, hive_flutter ^1.1.0, build_runner ^2.10.4, flutter_launcher_icons ^0.13.1`.

---

## 11. Flujo típico de uso

```
Splash (3.8 s) → Login (fija baseUrl, valida, guarda userCode, refresca LectorProvider)
 → Home (grid 7 + FAB Escanear)
 → [Actualizar Artículos primera vez: sync catálogo con progreso %/art-s + dashboard]
 → Lector / Venta / Compra: (carga config+pendientes, activa cámara si auto)
 → Escaneo (estabilidad 5 / disparo / manual)
 → BarcodeParser (GTIN + lote + caducidad)
 → buscarArticulo (fallbacks + fuzzy)
 → DialogoRegistro (cantidad default=config.cantidadMinima, lote obligatorio si gestionLotes,
    aviso descat. + triple sonido)
 → saveLectura SQLite → tabla (doble-tap edita/borra)
 → Enviar Lecturas (vista global 3 tipos, sync individual/global por lotes 500,
    valida LecturasRecibidas, marca sincronizado + fechaEnvio)
 → Historial (calendario puntos verdes, lista por fechaEnvio, export TXT comprobante, purga 90 d)
```

Configuración accesible con `admin0`.

---

## 12. Otros ficheros relevantes

- `build_release.sh`: `flutter clean → rm -rf build/ → flutter pub get → flutter build apk --release --verbose → [opcional] flutter install --release + adb logcat | grep flutter|REMOTE_DS|LOCAL_DS|DB_HELPER|REPO`.
- `test/widget_test.dart`: test plantilla por defecto (sin cobertura real).
- `.github/modernize/`: carpeta de modernización (revisar contenido aparte).
- `README.md`: genérico de plantilla Flutter, sin documentar ScanPal (este archivo lo sustituye).
- `analysis_options.yaml`: `include: package:flutter_lints/flutter.yaml` por defecto.

---

## 13. Estado actual y deuda técnica observada

1. Versión `1.0.0+1`, `description: "A new Flutter project."` sin personalizar.
2. `articulos_duplicados` solo se crea en isolate, no en `DatabaseHelper._onCreate` → riesgo en instalación limpia si no pasa por sync.
3. `Caducidad.mp3` declarado pero no usado.
4. `hive / hive_flutter / build_runner` en `dev_dependencies` sin uso aparente (no hay adaptadores).
5. `Venta/CompraProvider` con `currentUserId=1` fijo (no usan `AuthLocalDataSource` como `LectorProvider`).
6. `HistorialEnviosPage` solo muestra inventario (no ventas/compras).
7. Sin tests reales (`widget_test.dart` plantilla).
8. `README.md` original sin contenido del proyecto.

---

*Documento generado por análisis estático del código en `lib/`, `pubspec.yaml`, `assets/`, `build_release.sh` y estructura de plataformas. Para ampliar: revisar `.github/modernize/`, `android/app/build.gradle` (applicationId, minSdk, permisos cámara) y logs de `LoggerService` (`sync_logs.txt`).*
