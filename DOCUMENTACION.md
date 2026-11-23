# ScanPal — Documentación del Proyecto

**Proyecto:** scanpalphone_app  
**Versión:** 1.0.0+1  
**Fecha documentación:** 18/11/2026  
**Stack:** Flutter (Dart SDK ^3.9.2), Clean Architecture + Provider  
**Plataformas:** android/, ios/, linux/, macos/, web/, windows/ (operativa real en Android)  
**Idioma:** es-ES — MaterialApp(locale: es_ES)  
**Tema:** Material 3, seedColor: Color(0,47,108) azul oscuro, scaffoldBackgroundColor: white

---

## 1. Descripción general

**ScanPal** es una app móvil Flutter de gestión de almacén con escáner para operarios de tienda/almacén (caso de uso: Viveros Nava / Ecomputer).

Funcionalidades principales:

1. **Login contra ERP** (`persona/GetCodigo`) y trabajo **offline-first**.
2. **Sincronización masiva de catálogo** de artículos (`articulo/GetCodigos`) a SQLite local.
3. **Escaneo continuo con cámara** (`mobile_scanner`) + parser propio `BarcodeParser` (EAN-13/8, UPC-A, GS1-128 conformante a normativa AECOC/128, Code128/39, heurísticas `Ref/Lote` y `Lote - Fecha`).
4. **Tres modos de operación** separados por `TipoOperacion`:
   - **Inventario** → ruta `/lector` (`LectorPage` + `LectorProvider`)
   - **Ventas / Salidas** → ruta `/venta` (`VentasPage` + `VentaProvider`)
   - **Compras / Entradas** → ruta `/compra` (`ComprasPage` + `CompraProvider`)
5. **Registro local de `Lectura`** (código, referencia, cantidad, lote, descatalogado, **trazabilidad GS1: caducidad, peso neto/bruto, SSCC**), edición/borrado, envío por lotes a `Lectura/Guardar` con `Tipo=I/C/V`, historial/auditoría 90 días, exportación CSV/TXT.
6. **Comprobación contra documento** (nuevo): rutas `/comprobacion_compra` y `/comprobacion_venta` (`ComprobacionPage` + `ComprobacionProvider`). Al recepcionar (compra) o expedir (venta) se compara el albarán/factura con las lecturas: pendiente, parcial, completa, sobrante y "leído sin línea". Entrada al menú: "Comprobar Compra" / "Comprobar Venta".
7. **Gestión de catálogo:** dashboard Activos / Descatalogados / Total, búsqueda global, paginación, edición local/remota (`articulo/guardar`), exportación CSV.
8. **Configuración:** `urlBase`, `cantidadMinima`, `lecturaAutomatica` e intervalo configurable (1–60 segundos) entre lecturas. El intervalo se aplica en inventario, compras y ventas. URL bloqueada salvo `admin0`.

---

## 2. Arquitectura

Patrón **Clean Architecture + MVVM con Provider**:

```
lib/main.dart (DI manual)
├── core/
│   ├── constants.dart
│   ├── database_helper.dart          # BD v3, migraciones v1→v2→v3, WAL mode
│   ├── barcode_parser.dart           # GS1-128 normativa AECOC/GS1 (~805 líneas)
│   ├── exceptions.dart
│   ├── sync_progress.dart
│   └── services/logger_service.dart
├── domain/
│   ├── entities/ (articulo, lectura [+4 campos GS1: fechaCaducidad, pesoNeto, pesoBruto, scc], configuracion, usuario,
│   │               tipo_operacion, opcion_menu, articulo_duplicado,
│   │               documento_esperado.dart, linea_documento_esperada.dart)
│   ├── repositories/ (abstract: articulo, lectura, auth, configuracion, documento)
│   └── usecas/ (15 casos de uso con método execute())
├── data/
│   ├── datasources/ (articulo_remote/local, lectura_remote/local, auth_remote/local, config_local, documento_local + documento_remote stub)
│   ├── models/ (articulo_model.dart, lectura_ws_model.dart [+campos GS1])
│   └── repositories/ (*_impl.dart + documento_repository_impl.dart)
└── presentation/
    ├── pages/ (11 pantallas: splash, login, home, lector, ventas, compras, actualizar_articulos, configuracion, enviar_lecturas, historial_envios, comprobacion)
    ├── providers/ (7 ChangeNotifierProvider: login, configuracion, actualizar_articulo, lector, venta, compra, comprobacion)
    ├── widgets/ (11 widgets + documento_panel.dart)
    └── utils/menu_options.dart (9 opciones)
```

`main.dart`:
- `ensureInitialized`, abre `DatabaseHelper.instance.database`, `SharedPreferences.getInstance()`, `http.Client()`.
- Construye todos los repositories e inyecta en `MultiProvider` 7 providers.
- `MaterialApp(home: SplashScreen, routes: /login, /home, /configuracion, /actualizar_articulos, /lector, /venta, /compra, /comprobacion_compra, /comprobacion_venta, /enviar_lecturas, /historial_envios)`.

Patrones aplicados:

- Repository + DataSource local/remoto.
- UseCase de un solo propósito.
- `Stream<SyncProgress>` para sincronización con progreso.
- Caché LRU en memoria (300 art. en local DS, 150/30 min en provider).
- `Isolate` + `Batch` SQLite para inserción masiva.
- `Provider` (`ChangeNotifier`) para estado UI.
- `CompararDocumentoUseCase` con tolerancia `1e-9` para cantidades decimales.

---

## 3. Entidades del dominio (`lib/domain/entities/`)

| Entidad | Fichero | Campos |
|---|---|---|
| `Articulo` | `articulo.dart` | `codigo` PK (CodigoBarras), `descripcion`, `referencia` (split `.`), `lote?`, `cantidadMinima: int`, `descatalogado: bool`, `gestionLotes: bool` + `fromJson/toJson/copyWith/==hashCode(codigo)` tolerante int/String/bool/double |
| `Lectura` | `lectura.dart` | `id?, codigoArticulo, referenciaArticulo, cantidad: double, fechaRegistro, fechaEnvio?, idUsuario=0, sincronizado=false, lote?, esDescatalogado=false, descripcion?, tipoOperacion=inventario, fechaCaducidad?, pesoNeto?, pesoBruto?, scc?` + `toMap/fromMap` SQLite, `toJson` WS con campos GS1 opcionales |
| `Configuracion` | `configuracion.dart` | `urlBase, cantidadMinima, lecturaAutomatica` + `inicial() = AppConstants.baseUrl, 1, false` |
| `Usuario` | `usuario.dart` | DTO `{nombre, password}` (el código real `int Codigo` lo devuelve el servidor) |
| `TipoOperacion` | `tipo_operacion.dart` | `enum {inventario, compra, venta}` → WS `I/C/V`, columna SQLite `tipo_operacion TEXT DEFAULT 'inventario'` |
| `OpcionMenu` | `opcion_menu.dart` | `{titulo, icono: IconData, ruta}` |
| `ArticuloDuplicado` | `articulo_duplicado.dart` | `{id?, articulo: Articulo, motivo, fechaDeteccion}` |
| `DocumentoEsperado` | `documento_esperado.dart` **(NUEVO)** | `id?, tipo (compra=albarán, venta=factura), numero, fecha?, tercero?, lineas` con `toMap/fromMap` (líneas serializadas como JSON) |
| `LineaDocumentoEsperada` | `documento_esperado.dart` **(NUEVO)** | `{ referencia, codigoBarras?, descripcion?, cantidadEsperada, lote? }` |
| `EstadoLinea` | `documento_esperado.dart` **(NUEVO)** | `pendiente, parcial, completa, sobrante` |
| `LecturaSobrante` | `documento_esperado.dart` **(NUEVO)** | `{ codigo, referencia, lote?, cantidad }` |
| `ResultadoComprobacion` | `documento_esperado.dart` **(NUEVO)** | `{ lineas, sinLinea, completas/parciales/pendientes/sobrantes, cantidadEsperadaTotal, cantidadLeidaTotal, estaCompleto }` |

Modelos (`lib/data/models/`):
- `ArticuloModel extends Articulo`: `fromJson` acepta `CodigoBarras/Codigo`, split `codigo/lote` por `/`, `Descripcion/Nombre`, `StockMinimo/CantidadMinima`, `fromJsonList` tolerante.
- `LecturaWSModel`: `{codigoBarras, referencia:int, cantidad, usuario, lote?, fecha} + fechaCaducidad, pesoNeto, pesoBruto, scc` + `fromEntity` (split `/` Navas), `toJson` con campos GS1 opcionales.

---

## 4. Persistencia local

### 4.1 `core/database_helper.dart`

- BD `ScanPalDB.db` v3, singleton.
- `PRAGMA foreign_keys=ON, journal_mode=WAL, synchronous=NORMAL, temp_store=MEMORY`.
- Path vía `path_provider` + `getDatabasePath()`.
- Migraciones: v1→v2 (`ALTER TABLE lecturas ADD columnas GS1`), v2→v3 (`CREATE TABLE documentos`).
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
  tipo_operacion TEXT DEFAULT 'inventario', fecha_caducidad TEXT,
  peso_neto REAL, peso_bruto REAL, sscc TEXT);

articulos(codigo TEXT PK, descripcion TEXT NOT NULL, referencia TEXT NOT NULL,
  lote TEXT, cantidad_minima INTEGER NOT NULL,
  descatalogado INTEGER DEFAULT 0, gestion_lotes INTEGER DEFAULT 0);

documentos(id PK AI, tipo TEXT NOT NULL, numero TEXT NOT NULL,
  fecha TEXT, tercero TEXT, lineas_json TEXT NOT NULL DEFAULT '[]', UNIQUE(tipo, numero));

logs(id PK AI, timestamp TEXT, level TEXT, message TEXT, paquete INTEGER);
metadata(key TEXT PK, value TEXT NOT NULL);
-- índices: idx_articulos_referencia, idx_lecturas_sincronizado, idx_lecturas_tipo, idx_documentos_tipo_numero
```

> `articulos_duplicados(id AI, codigo, descripcion, referencia, lote, cantidad_minima, descatalogado, gestion_lotes, motivo_duplicidad, fecha_deteccion)` **no se crea en `_onCreate`**, solo con `CREATE TABLE IF NOT EXISTS` en el isolate de `articulo_local_datasource.dart`.

Claves `metadata`: `total_articulos_api, total_activos_api, total_descatalogados_api, total_duplicados_api`.

---

## 5. Lógica de negocio clave

### 5.1 `core/barcode_parser.dart`

- `enum TipoCodigo {ean13, ean8, upc, gs1, code128, nava, code39, desconocido}`.
- `BarcodeData {tipo, codigoArticulo, lote?, fechaCaducidad?, pesoNeto?, pesoBruto?, scc?, ...}`.
- `parse()`:
  1. Heurística `/` → `nava (Ref/Lote)`.
  2. Heurística ` - ` o `dd/MM/yyyy` → `nava (lote=ref)`.
  3. `_esGS1 (]C1 / FNC1 \u001D / 01 / 00)` → `_parseGS1Total`.
  4. EAN-13 `^\d{13}$`, EAN-8 `^\d{8}$`, UPC `^\d{12}$ → 0+cod`.
  5. Limpieza `[%$]` → `code39`, defecto `code128`.

**Características GS1-128 (normativa AECOC):**
- Catálogo completo de IAs (20, 30, 240-241, 250-251, 400-403, 410-415, 420-426, 7001-7002, 703x, 8001-8008, 8018, 8020, 8100-8102, 90-99).
- Familias de 4 dígitos resueltas por rango: medidas 310n-369n, importes 390n-393n, 703x.
- **Pesos**: el 4.º dígito sitúa el decimal (`(3103)000035` = 0,035 kg); `pesoNeto`/`pesoBruto` ya no son siempre `null`.
- **FNC1**: tabla de qué IAs lo exigen; el separador corta los campos variables.
- **Referencias**: el (02) identifica el contenido y prevalece sobre el (01); (00) solo se usa en picking/multirreferencia, su contenido viaja en DESADV.
- **GTIN-14 → 13**: solo se quita el `0` inicial si el resto supera el dígito de control (los indicadores logísticos 1-8 se conservan).
- Fechas AAMMDD validadas; día `00` = último día del mes.
- Acepta forma legible con paréntesis `(01)...(10)...` e identificador `]C1`; dígito de control GS1 verificado (modo informativo).

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

- `RegistrarLecturaUseCase.execute` acepta `fechaCaducidad?`, `pesoNeto?`, `pesoBruto?`, `sscc?` (opcionales). Los 3 providers los reenvían; las 3 páginas los toman del `barcode` tanto en auto-registro como vía `DialogoRegistroArticulo`.
- `ObtenerLecturasUseCase(tipo) → getLecturasPendientesPorTipo (sincronizado=0 AND tipo ORDER fecha DESC)`.
- `ActualizarLecturaUseCase {execute (nuevaCantidad → sincronizado=false, fechaEnvio=null), delete(id)}`.
- `EnviarLecturasUseCase(tipo)`: marca `fechaEnvio=now`, `sendLecturas → marcarComoSincronizadas`, retorna count. Purga 90 días.

### 5.5 Login y configuración

- `LoginUseCase → AuthRepositoryImpl.login → AuthRemoteDataSource.login → AuthLocalDataSource.saveUserCode`. `ClearSessionUseCase → clearUserCode`.
- `Get/SaveConfiguracionUseCase → ConfiguracionRepositoryImpl → ConfigLocalDataSource (SharedPreferences: urlBaseKey, cantidadMinimaKey, lecturaAutomaticaKey)`.

### 5.6 Comparación contra documento (nuevo)

- `ObtenerDocumentoUseCase(tipo, numero)`: intenta servidor y cachea; si falla, devuelve copia local o `null`.
- `GuardarDocumentoUseCase`: valida (nº no vacío, líneas con referencia o código y cantidad > 0) y guarda en local.
- `CompararDocumentoUseCase(documento)`: lee las pendientes del tipo y aplica `compararDocumentoConLecturas`.
- `documento_remote_datasource.dart` es un **stub**: valida configuración y lanza `ServerException('Endpoint de documentos pendiente de integrar en el servidor.')`. Contrato previsto: `GET {base}/documento/GetDocumento?tipo=C|V&numero=XXX` → `{ Numero, Fecha, Tercero, Lineas: [{ Referencia, CodigoBarras, Descripcion, Cantidad, Lote }] }`.

---

## 6. Pantallas (`lib/presentation/pages/`)

| Página | Ruta | Descripción |
|---|---|---|
| `splash_page.dart` (`SplashScreen`) | `/` (home) | Animación 3800 ms (`AnimationController`, `TweenSequence` move/rot/scale, logo 200 `assets/icon/Ecomputer.jpg`) → `pushReplacement LoginPage` fade 700 ms |
| `login_page.dart` (`LoginPage`) | `/login` | `Form` usuario/pass, `logout()` al entrar, fija `_fixedDbUrl=AppConstants.baseUrl`, `logear(user,pass,lectorProvider) → /home`. `Consumer2<Login,Config>`, botón azul `0,47,108`, responsive 450 px. `LongPress` título → diálogo admin (`admin0 → /configuracion`) |
| `home_page.dart` (`HomePage`) | `/home` | `GridView menuOptions` (2/3/4 cols, max 1200), `HomeMenuItem`, `logout` con confirm, `FAB.extended Escanear → /lector` |
| `lector_page.dart` (`LectorPage`) | `/lector` | **Inventario.** `MobileScannerController(unrestricted, all, autoStart:false)`, estabilidad 5 lecturas, debounce 2 s, zoom 0.0-1.0 (1x-5x), torch, `_procesarEntradaCodigo → BarcodeParser → buscarArticulo → fuzzy dialog → DialogoRegistroArticulo o auto-registro si lecturaAutomatica && !descatalogado && loteOK`. Layout responsive (`>900` Row 30/70, else Column 30% cámara + info + tabla). `FAB.large` toggle/disparo |
| `ventas_page.dart` (`VentasPage`) | `/venta` | **Salida.** Idéntica a lector pero con `VentaProvider`, `noDuplicates`, bloqueo 3 s, sin fuzzy, sin `inicializarDatos` catálogo. **Si hay documento activo**, muestra `DocumentoPanel` con líneas y estados en vivo; filas fuera de documento en rojo. |
| `compras_page.dart` (`ComprasPage`) | `/compra` | **Entrada (AppBar verde).** Idéntica a ventas con `CompraProvider`. **Si hay documento activo**, muestra `DocumentoPanel` con líneas y estados en vivo; filas fuera de documento en rojo. |
| `comprobacion_page.dart` (`ComprobacionPage(tipo)`) | `/comprobacion_compra`, `/comprobacion_venta` | **NUEVA.** Card de documento (nº + Cargar / Nuevo manual), aviso de endpoint pendiente, tarjeta resumen con chips (completas/parciales/pendientes/sobrantes/sin línea) o banner verde si cuadra todo, lista de líneas con estado por color (verde/morado/naranja/rojo) y borrado por línea, sección "Leído sin línea", diálogo "Añadir línea", FAB Escanear → `/compra` o `/venta` (al volver recompara), acciones refrescar y borrar documento |
| `actualizar_articulo_page.dart` | `/actualizar_articulos` | Catálogo + dashboard `ACTIVOS/DESCATAL./TOTAL` (metadata remota), búsqueda global debounce 500 ms + scroll infinito (50/pág, prefetch 300 px, buffer 1000), `ListTile` REF/CB/estado, `share` CSV, `cloud_download` → diálogo sync con `%`, `art/s`, `LinearProgress`. Auto-sync si `conteoFisicoReal==0`. `PopScope` gestiona búsqueda/selección |
| `configuracion_page.dart` | `/configuracion` | `urlController/cantidadController/Switch lecturaAutomatica`. URL `readOnly` salvo `isSuperAdmin \|\| desbloqueoManual` (diálogo pass `admin0`), botón `Restaurar URL`, validación, `Switch` solo si `cantidad>0`, guardar → `pop`. Responsive 600 px |
| `enviar_lecturas_page.dart` | `/enviar_lecturas` | Carga pendientes 3 providers + config, header total, 3 `ExpansionTile + DataTable (Código/Lote/Cant./Ref.)` con colores (azul/verde/naranja, naranja descat., rojo cant.<min), sync individual/global, `LoadingOverlay`, diálogos éxito/error |
| `historial_envios_page.dart` | `/historial_envios` | **Auditoría.** `TableCalendar (locale es_ES, 90d→now, monday)` con `eventLoader` punto verde (`SELECT DISTINCT substr(fecha_envio,1,10) WHERE sincronizado=1`), header `Sincronizaciones dd/MM/yyyy + N confirmados`, `ListView` hora/descripción/cod-ref/lote/cant., export CSV (fecha y hora del envío + detalle de lectura) y TXT (`comprobante_envio_yyyyMMdd.txt` vía `share_plus`), purga 90 d y borrado manual confirmado de todas las lecturas locales (enviadas y pendientes, todos los tipos). |

---

## 7. Providers (`lib/presentation/providers/`)

| Provider | Estado | Responsabilidad |
|---|---|---|
| `lector_provider.dart` (`LectorProvider`, tipo=inventario) | `LectorState {initial, loadingArticulo, loaded, descatalogado, duplicado, registering, error, loadingLecturas, sending, sendSuccess, sendError, noEncontradoFuzzy}` | Carga `userId (getUserCode ?? 1)`, config, pendientes, purga. `buscarArticulo` + 4 fallbacks + fuzzy, `registrarLectura (default=config.cantidadMinima, acepta fechaCaducidad/pesoNeto/pesoBruto/sscc opcionales)`, `enviarLecturasAlServidor`, `editar/borrar/borrarTodas`, `obtenerHistorialPorFecha`, `obtenerDiasConLecturas`, `limpiarHistorialAntiguo(90)`, sonidos `audioplayers` (triple warning descat.). `refrescarUsuarioDinamico()` tras login |
| `venta_provider.dart` / `compra_provider.dart` | `VentaState` / `CompraState` (sin fuzzy/duplicado, `currentUserId=1` fijo, sin auth DS) | Misma API `buscar/registrar/obtenerPendientes/historial/enviarVentas-Compras/borrar/editar/reset/limpiarHistorial`. **Si hay documento activo**, muestra `DocumentoPanel` y resalta filas fuera de documento en rojo. |
| `comprobacion_provider.dart` (**NUEVO**) | `ComprobacionState {initial, loading, loaded, saving, error}`; `fijarTipo`, `cargarDocumento`, `crearDocumentoVacio`, `agregarLinea`, `borrarLinea`, `borrarDocumento`, `refrescar`, `refrescarTipo(tipo)`; expone `documento`, `resultado`, `avisoRemoto` del contexto más `documentoDe(tipo)`/`resultadoDe(tipo)`. **Multi-tipo**: mantiene un documento activo por tipo (compra y venta a la vez); el cargado en Comprobar es el que ven Compras/Ventas |
| `login_provider.dart` | `LoginState {initial, loading, success, error}` | `isSuperAdmin (nombre==admin0)`, `logear(nombre,pass,lectorProvider) + refrescarUsuarioDinamico`; tras autenticar, compara versión/build instalado y fuerza borrado + sincronización del catálogo si cambió; guarda la versión solo tras sincronizar correctamente; `logout → clearSession`, `setSuperAdminManually` |
| `configuracion_provider.dart` | `ConfiguracionState {initial, loading, loaded, saving, success, error}` | `cargarConfiguracion`, `guardarConfiguracion(url,cantidad,{lecturaAutomatica})`, `clearBaseUrl → inicial` |
| `actualizar_articulo_provider.dart` | `ActualizarArticuloState {initial, searching, loaded, error, syncing, listLoaded, loadingMore, exporting, success}` | Métricas `_totalArticulos/Activos/Descatalogados (metadata) + conteoFisicoReal`, paginación `page/pageSize 50/hasMore`, caché 150/30 min, debounce, reintentos x3/90 s, `syncProgressStream → progreso`, `inicializarDatos/cargarArticulosLocal/cargarMas/buscarGlobalmenteEnBDLocal/actualizarArticulo(remoto/local)/compartirReportes(CSV Temp+share_plus)/sincronizarYRecargar/reset` |

---

## 8. Widgets y utils

- `widgets/lectura_view_model.dart`: wrapper `{lectura, descripcionArticulo}` + getters `codigo/referencia/cantidad/lote/esDescatalogado/descripcionLimpia` (limpian NBSP).
- `widgets/dialogo_registro_articulo.dart` (`DialogoRegistroArticulo`): campos cantidad (autofocus + select-all, aviso morado si `<minGlobal`) y lote (solo si el servidor y el artículo habilitan su gestión; si falta, avisa con sonido y permite confirmar el registro sin lote; badge `auto_awesome` si GS1, muestra `Caducidad dd/MM/yyyy`), valida `>0`, llama `provider.registrarLectura → pop(true)`. **Suma 3 parámetros opcionales: `fechaCaducidaExtraida`, `pesoNetoExtraido`, `pesoBrutoExtraido/ssccExtraido`**.
- `widgets/dialogos_lector.dart` (`DialogosLector`): `confirmarBorrarTodo`, `mostrarDialogoEdicion (Borrar/Editar)`, `_mostrarDialogoCambiarCantidad`, `mostrarBuscadorFuzzy ({sugerencias, codigoEscaneado, onBuscar}) → Articulo?` con `StatefulBuilder`.
- `widgets/camera_view_section.dart`: `MobileScanner (scanWindow 70%x60%, fit cover)` + `ScannerOverlayPainter`, textos `Centra el código`, barra estabilidad, zoom 1x-5x, pantallas `ESCANEO PAUSADO (doble-tap)` / `Buscando...`.
- `widgets/scanner_overlay_painter.dart`: `CustomPaint` sombra `black54` + `RRect` borde.
- `widgets/lector_info_bar.dart`: gris, `Entrada Manual` + `Último: xxx`.
- `widgets/lecturas_data_table.dart` (`LecturasDataTable`): `DataTable (Art/Lote, Descripción, Cant.)`, orden `reversed`, colores naranja descat. / morado cant. baja, doble-tap por celda. **Parámetro opcional `esInesperada`**: filas fuera de documento en rojo con icono; `null` = aspecto de siempre (Inventario). Entidad: `documentoContieneLectura()` y `unidadesFaltantes/unidadesSobrantes`.
- `widgets/documento_panel.dart` (**NUEVO**): cabecera con nº y completas + lista colapsable de líneas con `leído/esperado` por color; se muestra en Ventas/Compras cuando hay documento activo.
- `widgets/home_menu_item.dart`: `Card + InkWell → pushNamed(ruta)`, icono 48 primary + título 2 lín.
- `widgets/loading_overlay.dart`: `Stack + black54 + Card (Circular + message + no cierre)`.
- `utils/menu_options.dart`: 9 `OpcionMenu`: Configuración (`settings → /configuracion`), Actualizar Artículos (`cloud_download → /actualizar_articulos`), Leer Códigos (`qr_code_scanner → /lector`), Enviar Lecturas (`cloud_upload → /enviar_lecturas`), Historial (`history → /historial_envios`), Ventas (`point_of_sale → /venta`), Compras (`shopping_cart → /compra`), **Comprobar Venta** (`playlist_add_check → /comprobacion_venta`), **Comprobar Compra** (`fact_check → /comprobacion_compra`).

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
| `GET` | `{base}/persona/GetCodigo/{nombre}/{password}` timeout 15 s | Login → `[{Codigo}]\|{Codigo}\|int` → `auth_remote_datasource.dart` |
| `GET` | `{base}/articulo/GetCodigos` timeout 5 min | Sync catálogo → `List` JSON utf8, rechaza HTML `<` |
| `GET` | `{base}/articulo/GetCodigos?Filtro=CodigoBarras='{cod}'` | Búsqueda unitaria |
| `POST` | `{base}/articulo/guardar` `{CodigoBarras, Descripcion, CantidadMinima, Referencia, Lote, Descatalogado:0/1, GestionLotes:0/1}` | Actualizar artículo → 200 OK |
| `POST` | `{base}/Lectura/Guardar` chunks 500 | Array JSON de lecturas: `{Referencia:int, CodigoBarras, Cantidad:int|double, Usuario, Lote, FechaEnvio:ISO-8601, Tipo:I/C/V, FechaCaducidad:YYYY-MM-DD|"", PesoNeto:number|null, PesoBruto:number|null, SSCC:""}`. `Cantidad` es INT cuando es entera y DOUBLE con decimales cuando viene de peso GS1. `FechaEnvio` en ISO-8601 permite conversión a `System.DateTime`; se asigna al momento de transmitir cada paquete, no al registrar la lectura. Cada paquete confirmado se marca como sincronizado localmente antes de enviar el siguiente, para que una interrupción posterior no reenvíe los paquetes ya aceptados. Timeout 10 s, retry 3x2 s, `LoggerService` por paquete |
| `GET` | `{base}/documento/GetDocumento?tipo=C|V&numero=XXX` **(pending)** | Contrato previsto: `{ Numero, Fecha, Tercero, Lineas: [{ Referencia, CodigoBarras, Descripcion, Cantidad, Lote }] }` |

Local DS: `auth_local (SharedPreferences userCodeKey)`, `config_local (urlBaseKey, cantidadMinimaKey, lecturaAutomaticaKey)`, `articulo_local` (counts, `saveStatsAPI`, `getTotal*API` metadata, `getArticuloByCodigo` 4 intentos, `saveArticulo/replace`, `saveArticulos (Isolate)`, `getAll/buscar (LIKE LIMIT 100)`, `clear`, `generarCsvCompleto (SCANPAL_CATALOGO_COMPLETO.csv Temp: sep=; CÓDIGO;DESCRIPCIÓN;REFERENCIA;LOTE;CANT_MIN;ESTADO) / generarCsvDuplicados`), `lectura_local` (`save/update/deleteById/clear/markSynced (batch)/deleteOld (days)` + limpieza NBSP + delays 30-50 ms), `documento_local` (`getByTipoNumero, save, clear`).

---

## 10. Assets y dependencias

### Assets declarados (`pubspec.yaml flutter.assets`)

- `assets/sounds/Articulo_descatalogado.mp3`
- `assets/sounds/Articulo_no_local.mp3`
- `assets/sounds/Caducidad.mp3` (declarado pero no referenciado en código — solo se usan los 2 anteriores)
- `assets/sounds/error_lectura.mp3`
- `assets/sounds/lectura_correcta.mp3`
- `assets/images/Ecomputer.jpg`
- `assets/icon/Ecomputer.jpg`

Físicos en disco: `icon/Ecomputer.jpg`, `images/Ecomputer.jpg, screen_scanpal.jpg, ScanPal.png, ScanPal-APP.jpg`, `sounds/Caducidad.mp3, Articulo_no_local.mp3, Articulo_descatalogado.mp3`.

`flutter_launcher_icons: android launcher_icon, ios true, image_path assets/images/ScanPal.png, min_sdk_android 21`. Splash usa `assets/icon/Ecomputer.jpg`.

### Dependencias (`pubspec.yaml`)

`cupertino_icons ^1.0.8, shared_preferences ^2.5.3, mobile_scanner ^7.1.2, provider ^6.1.5+1, http ^1.5.0, intl ^0.20.2, sqflite ^2.4.2, path ^1.9.1, path_provider ^2.1.5, audioplayers ^6.5.1, share_plus ^12.0.1, table_calendar ^3.2.0, flutter_localizations (sdk), sqflite_android ^2.4.2+2`.

Dev: `flutter_test, flutter_lints ^5.0.0, hive ^2.2.3, hive_flutter ^1.1.0, build_runner ^2.10.4, flutter_launcher_icons ^0.13.1, sqflite_common_ffi ^2.4.0+3`.

---

## 11. Flujos típicos de uso

```
Splash (3.8 s) → Login (fija baseUrl, valida, guarda userCode, refresca LectorProvider)
→ Home (grid 7 + FAB Escanear)
→ [Actualizar Artículos primera vez: sync catálogo con progreso %/art-s + dashboard]
→ Lector / Venta / Compra: (carga config+pendientes, activa cámara si auto)
→ Escaneo (estabilidad 5 lecturas / disparo / manual)
→ BarcodeParser (GTIN + lote + caducidad + pesos + SSCC)
→ buscarArticulo (fallbacks + fuzzy dialog)
→ DialogoRegistro (cantidad default=config.cantidadMinima; lote obligatorio si gestionLotes; si falta, avisa con sonido y permite confirmar sin lote; aviso descat. + triple sonido; nuevos params GS1: fechaCaducidad, pesoNeto, pesoBruto, SSCC)
→ saveLectura SQLite → tabla (doble-tap edita/borra)
→ Enviar Lecturas (vista global 3 tipos, sync por lotes 500, valida LecturasRecibidas, marca sincronizado + fechaEnvio)
→ Historial (calendario puntos verdes 90d, lista export TXT, purga 90 d)
```

### 11.2 Comprobación contra documento (nuevo)

Menú Comprobar Compra/Venta → introducir nº → Cargar (servidor cuando exista; hoy copia local) o Nuevo manual + Añadir líneas → las líneas se cargan en la página Ventas/Compras, que muestra un panel con cada línea y su estado en vivo (pendiente, parcial, completa, sobrante) → al escanear, cada lectura actualiza el estado de su línea y **lo leído fuera de documento va en rojo** → al terminar, Comprobar muestra el veredicto ("Documento correcto" o qué falta/sobra en unidades y líneas) → el envío final se hace desde **Enviar Lecturas** (flujo existente, sin cambios). El documento activo es global por tipo (`ComprobacionProvider` multi-tipo): el cargado en Comprobar es el mismo que ven Compras/Ventas. Inventario (`/lector`) no muestra documento ni resaltado.

Configuración accesible con `admin0`.

---

## 12. Ficheros y ramas

- Rama `prueba-gs1-128` (commit `24e9586`): normativa GS1-128 en `barcode_parser.dart`.
- Rama `prueba` (actual): lo anterior + columnas GS1, envío con decimales/trazabilidad y comprobación contra documento (13 ficheros modificados + 10 nuevos, ver `git status`).
- Tests de verificación `gs1_parser_check_test`, `lectura_gs1_check_test`, `comprobacion_check_test` ejecutados en verde y eliminados; `test/widget_test.dart` sigue siendo la plantilla sin cobertura.

---

## 13. Estado actual y deuda técnica observada

Resuelto en `prueba`: pesos GS1 mal calculados, `pesoNeto/Bruto` siempre `null`, SSCC usado como artículo, IAs ausentes que cortaban el parseo, truncado de decimales en el envío, falta de columnas de trazabilidad, ausencia de comprobación contra documento.

Pendiente:

1. Integrar el endpoint de documentos en el ERP e implementarlo en `documento_remote_datasource.dart`.
2. Validar un envío real con los 4 campos nuevos (`FechaCaducidad`, `PesoNeto`, `PesoBruto`, `SSCC`) por si el servidor es estricto.
3. `Venta/CompraProvider` siguen con `currentUserId=1` fijo (no usan `AuthLocalDataSource`).
4. `HistorialEnviosPage` solo muestra inventario (no ventas/compras).
5. `Caducidad.mp3` declarado pero no usado; `hive/build_runner` en dev sin uso aparente.
6. Sin tests permanentes; `README.md` de plantilla.
7. `articulos_duplicados` solo se crea en el isolate de sincronización, no en `_onCreate`.

---

*Documento generado por análisis estático y auditación del código en `lib/`, `pubspec.yaml`, `assets/`, `build_release.sh` y estructura de plataformas. Para ampliar: revisar `android/app/build.gradle` (applicationId, minSdk, permisos cámara) y logs de `LoggerService` (`sync_logs.txt`).*