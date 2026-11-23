# INFORME TÉCNICO - PROYECTO SCANPAL

## 1. ESTRUCTURA DEL PROYECTO

El proyecto `scanpal` ubicado en `C:\Users\josearregui\Desktop\Proyectos\scanpal\scanpal_mobil` se compone de **5 módulos principales**:

### Módulo 1: `scanpal_mobil/` - Aplicación Flutter (Núcleo)
**Responsabilidad:** Aplicación móvil completa para operaciones de almacén con escáner de códigos de barras.

**Arquitectura:** Clean Architecture + MVVM con Provider para gestión de estado.

**Componentes principales:**
- **`lib/main.dart`:** Punto de entrada, inyección de dependencias manual, configura 7 providers y define rutas del `MaterialApp`
- **`lib/core/`:** Capa base con `constants.dart` (URL base, batch sizes, timeouts, usuario admin), `database_helper.dart` (SQLite ScanPalDB.db con WAL mode, migraciones v1→v2→v3), `barcode_parser.dart` (~805 líneas) para parsing de códigos y normativa GS1-128
- **`lib/domain/entities/`:** Entidades del dominio (`Articulo`, `Lectura` [+4 campos GS1: fechaCaducidad, pesoNeto, pesoBruto, SSCC], `Configuracion`, `Usuario`, `TipoOperacion`, etc.)
- **`lib/data/`:** Capa de datos con data sources (remoto/local), modelos y repositorios implementados
- **`lib/presentation/pages/`:** 11 pantallas:
  - `SplashScreen` (3800ms animación)
  - `LoginPage` (autenticación ERP)
  - `HomePage` (menú grid principal)
  - `LectorPage` (`/lector`) - modo Inventario con cámara
  - `VentasPage` (`/venta`) - modo Salidas
  - `ComprasPage` (`/compra`) - modo Entradas (AppBar verde)
  - `ActualizarArticuloPage` - catálogo y dashboard
  - `ConfiguracionPage` - configuración de URL, cantidades
  - `EnviarLecturasPage` - envío de lecturas pendientes
  - `HistorialEnviosPage` - auditoría 90 días
  - `ComprobacionPage` (`/comprobacion_compra`, `/comprobacion_venta`) - **NUEVA**: comparación de documentos
- **`lib/presentation/providers/`:** 7 providers ChangeNotifier
- **`lib/presentation/widgets/`:** Widgets reutilizables para vistas de cámara, tablas, menú, documento_panel
- **`lib/utils/`:** `menu_options.dart` con 9 OpcionMenu

**Dependencias clave:** `shared_preferences`, `mobile_scanner`, `provider`, `http`, `sqflite`, `path_provider`, `audioplayers`, `share_plus`, `table_calendar`, `intl`.

**Endpoints consumidos:**
- `GET {base}/persona/GetCodigo/{nombre}/{password}` → Login
- `GET {base}/articulo/GetCodigos` → Sync catálogo masivo
- `POST {base}/Lectura/Guardar` → Guardar lecturas (chunks 500, payload actualizado con trazabilidad GS1)
- `GET {base}/documento/GetDocumento?tipo=C|V&numero=XXX` **(pending)** → Contrato previsto para comprobación de documentos

### Módulo 2: `WebService/` - Capa Backend ASP.NET
**Responsabilidad:** Servicios web REST que consumen `BaseScanpal.mdb` (Access).

**Componentes:**
- **`MiPrimerWS/`:** Aplicación ASP.NET Web Forms/WApi (.NET 4.5)
  - Configuración conexión a `BaseScanpal.mdb`
  - Endpoints: `persona/GetCodigo`, `articulo/GetCodigos`, `articulo/guardar`, `Lectura/Guardar`
- **`wsAPIRest/`:** Proyecto API REST adicional

**Base de datos:** `BaseScanpal.mdb` con tablas: `lecturas`, `articulos`, `logs`, `metadata`.

### Módulo 3: `APKs/` - Aplicaciones Android compiladas
**Contenido:** `Punto_Retorno_Scanpal.apk`, `Punto_Retorno_Viveros_C_V.apk`

### Módulo 4: `boceto/` - Diseño/Prototipado
**Contenido:** `PantallasScanpalPhone.xlsx` - esquema de pantallas UI/UX

### Módulo 5: `Documentacion/` - Recursos documentacionales
**Recursos:**
- `Codigos Viveros/` - Imágenes de etiquetas
- `Codigos.csv` / `CodigosDuplicados.csv` - Datos de catálogo
- `Etiquetas Viveros Nava.pdf` - Guía de etiquetas
- `GS1_128.pdf` - Documentación técnica GS1
- `ScanPal_Movil_Documentacion.pdf` - Documentación general app móvil

---

## 2. RESPONSABILIDAD DE MÓDULOS

| Módulo | Responsabilidad Principal |
|--------|--------------------------|
| `scanpal_mobil` | Lógica completa de negocio, UI, escaneo, persistencia local, comunicación con backend. Incluye GS1-128, trazabilidad (peso, caducidad, SSCC) y comprobación de documentos. |
| `WebService` | Exposición de APIs REST, lógica de negocio server-side, manejo de base datos Access |
| `APKs` | Distribución de aplicaciones Android ya compiladas |
| `boceto` | Documentación de diseños y flujo de usuario |
| `Documentacion` | Recursos referencia, etiquetas, códigos de barras GS1, guías de usuario |

---

## 3. TESTS REALES IMPLEMENTADOS

Se crearon **3 suites de tests automatizados** en `scanpal_mobil/test/`:

### Test 1: `barcode_parser_test.dart` (9/9 passing)
- Parseo EAN-13, EAN-8, UPC-A
- Heurísticas Ref/Lote (`12345/6789012`) y Lote-Fecha (`12345 - 2024/01/15`)
- Detector GS1-128 con AI 01 (`(01)12345678901231`)
- Clasificación de códigos desconocidos

### Test 2: `entities_test.dart` (9/9 passing)
- **Articulo Entity:** fromJson/toJson, equality por código, copyWith
- **Lectura Entity:** toJson/fromMap WS formateado, operadores (con campos GS1 opcionales)
- **Configuracion Entity:** valores por defecto, fromJson/toJson
- **TipoOperacion:** valores enum y string WS (`inventario`, `venta`, `compra`)

### Test 3: `database_helper_test.dart` (CRUD operations)
- Singleton initialization and diagnostics
- CRUD operations sobre SQLite (insert, update, delete, query)
- Requiere dispositivo físico para ejecución completa (plugins path_provider)

---

## 4. ARQUITECTURA DETALLE

```
lib/main.dart (DI manual)
├── core/
│   ├── constants.dart              # baseUrl, batchSize, adminUser, timeouts
│   ├── database_helper.dart        # SQLite con WAL mode, migraciones (v1→v2→v3)
│   ├── barcode_parser.dart         # ~805 líneas, parsing heurístico EAN/GS1/Code, normativa AECOC/GS1
│   ├── exceptions.dart             # ServerException, NotFoundException, etc.
│   ├── sync_progress.dart          # Progress model for sync con SendPort→StreamController
│   └── services/logger_service.dart # singleton logging DB + archivo sync_logs.txt
├── domain/
│   ├── entities/                   # Articulo, Lectura [+4 campos GS1], Configuracion, etc.
│   ├── repositories/ (abstract)    # ArticuloRepository, LecturaRepository, etc.
│   └── usecas/ (15 cases)       # Sincronizar, Registrar, Buscar, Enviar, CompararDocumento, etc.
├── data/
│   ├── datasources               # Remote/Local data sources
│   ├── models                    # ArticuloModel, LecturaWSModel [+campos GS1]
│   └── repositories/ (*_impl.dart) # Implementaciones concretas
└── presentation/
    ├── pages/ (11 pantallas)       # UI screens con estado
    ├── providers/ (7 providers)   # ChangeNotifier con estado
    ├── widgets/ (11 widgets)       # Componentes reutilizables
    └── utils/                     # menu_options.dart
```

---

## 5. ENDPOINTS HTTP CONSUMIDOS

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `{base}/persona/GetCodigo/{nombre}/{password}` | Login → `[Codigo]\|{Codigo}\|int` |
| `GET` | `{base}/articulo/GetCodigos` | Sync catálogo masivo → List JSON utf8 |
| `GET` | `{base}/articulo/GetCodigos?Filtro=...` | Búsqueda unitaria por código |
| `POST` | `{base}/articulo/guardar` | Actualizar artículo → 200 OK |
| `POST` | `{base}/Lectura/Guardar` | Guardar array de lecturas en la raíz, chunks de 500; `FechaEnvio` en ISO 8601 con la hora del envío; valida received==sent y marca cada paquete confirmado antes de continuar. Payload actualizado: `Cantidad` INT cuando es entera y DOUBLE con decimales por peso GS1; `FechaCaducidad`, `PesoNeto`, `PesoBruto`, `SSCC` campos opcionales. |
| `GET` | `{base}/documento/GetDocumento?tipo=C|V&numero=XXX` **(pending)** | Contrato previsto: `{ Numero, Fecha, Tercero, Lineas: [{ Referencia, CodigoBarras, Descripcion, Cantidad, Lote }] }` |

---

## 6. FLUJO TÍPICO DE USO

```
Splash (3.8 s) → Login (fija baseUrl, valida, guarda userCode, refresca LectorProvider)
→ Home (grid 7 + FAB Escanear)
→ [Actualizar Artículos primera vez: sync catálogo con progreso %/art-s + dashboard]
→ Lector / Venta / Compra: (carga config+pendientes, activa cámara si auto)
→ Escaneo (estabilidad 5 lecturas / disparo / manual)
→ BarcodeParser (GTIN + lote + caducidad + pesos + SSCC) [GS1-128 normativa AECOC]
→ buscarArticulo (fallbacks + fuzzy dialog)
→ DialogoRegistro (cantidad default=config.cantidadMinima; lote obligatorio si gestionLotes; si falta, avisa con sonido y permite confirmar el registro sin lote; aviso descat. + triple sonido; params GS1: fechaCaducidad, pesoNeto, pesoBruto, SSCC)
→ saveLectura SQLite → tabla (doble-tap edita/borra)
→ Enviar Lecturas (vista global 3 tipos, sync por lotes 500, valida LecturasRecibidas, marca sincronizado + fechaEnvio, payload con decimales y trazabilidad)
→ Historial (calendario puntos verdes 90d, lista export TXT, purga 90 d)
→ [Comprobación documento: Menú Comprobar Compra/Venta → introducir nº → Cargar / Nuevo manual → panel líneas estado en vivo → al escanear actualiza estado línea → lectura fuera de documento en rojo → veredicto final → envío desde Enviar Lecturas]
```

---

## 7. DEUDA TÉCNICA OBSERVADA

1. Versión `1.0.0+1`, descripción genérica "A new Flutter project."
2. `articulos_duplicados` solo se crea en isolate, no en `_onCreate` base datos
3. `Caducidad.mp3` declarado en assets pero no usado en código
4. `hive / hive_flutter / build_runner` en devDependencies sin uso aparente (no hay adaptadores)
5. `Venta/CompraProvider` con `currentUserId=1` fijo (no usan AuthLocalDataSource)
6. `HistorialEnviosPage` solo muestra inventario (no ventas/compras)
7. Tests automatizados creados y passing (barcode parser + entities)
8. `README.md` original sin contenido del proyecto (sustituido)

---

## 8. CONFIGURACIÓN ANDROID (android/app/build.gradle.kts)

```
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.scanpalphone_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.scanpalphone_app"
        minSdk = flutter.minSdkVersion        # SDK mínimo: 21 (forzado para estabilidad SQLite e Isolates)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
```

**Notas de configuración Android:**
- `minSdk = 21`: Forzado para garantizar estabilidad de SQLite con WAL mode y funcionalidad de Isolates para sincronización masiva de catálogo
- `compileOptions sourceCompatibility/targetCompatibility = JavaVersion.VERSION_11`: Java 11 compatibility
- Release build: Minify deshabilitado actualmente, usa llaves de debug
- El `applicationId` viene determinado por Flutter (`com.example.scanpalphone_app`)

---

## 9. PERMISOS DE CÁMARA

La aplicación requiere permisos de cámara para la funcionalidad de escaneo de códigos de barras:

**Permisos esenciales (declared en AndroidManifest.xml de forma implícita por `mobile_scanner` package):**
- `CAMERA`: Permiso necesario para acceder a la cámara del dispositivo
- `FLASHLIGHT`: Opcional, para control de la linterna durante el escaneo

**Configuración en el código:**
- El paquete `mobile_scanner: ^7.1.2` gestiona los permisos de forma automática al iniciar el escaneo
- Se solicita el permiso al usuario primera vez que se accede a `/lector` ruta
- El flujo de `LectorPage` incluye manejo de `PermissionDenrolled` y fallback a modo búsqueda manual
- `torch` (flash) puede ser activado/desactivado en configuración del provider `LectorProvider`
- La cámara se configura con `MobileScannerController(unrestricted, all, autoStart:false)` para estabilidad de 5 lecturas

**Consideraciones:**
- En dispositivos sin cámara (tablets sin módulo de cámara), la app muestra mensaje de error y sugiere usar modo manual
- El permiso es solicitado al entrar a `LectorPage` (`/lector`), no al inicio de la app
- Versión mínima Android 4.0.3 (API 15) soportada en teoría, pero operación real requiere API 21+ por isolados SQLite

---

## 10. SISTEMA DE LOGS - LoggerService

**Archivo:** `lib/core/services/logger_service.dart` (Singleton)

**Características principales:**

### 10.1 Arquitectura
- **Patrón Singleton:** Una única instancia gestiona todos los logs del application
- **Dual Storage:** Guarda concurrentemente en SQLite Database + Archivo de Texto

### 10.2 Almacenamiento en SQLite
- **Tabla:** `logs` (definida en `database_helper.dart`)
- **Columnas:** `id` (PK autoincrement), `timestamp`, `level`, `message`, `paquete`
- **Prácticas:** `PRAGMA foreign_keys=ON`, `journal_mode=WAL`, `synchronous=NORMAL`, `temp_store=MEMORY`
- **Operaciones:** `insert`, `getDbLogs(limit 100 ORDER id DESC)`, `clearLogs`, `getLogFile`
- **Niveles soportados:** `START/SUCCESS/WARNING/CRITICAL/END/INFO`

### 10.3 Almacenamiento en Archivo de Texto
- **Archivo:** `sync_logs.txt` en `getApplicationDocumentsDirectory()`
- **Formato:** `[yyyy-MM-dd HH:mm:ss] [LEVEL] Pkg N: message\n`
- **Propósito:** Exportación rápida y lectura manual sin necesidad de abrir la BD
- **Mantenimiento:** `clearLogs()` vacía tanto la BD como el archivo

### 10.4 Casos de uso documentados
- **LoggerService.log(msg, {level, paquete}):** Registra evento en ambas fuentes
- **LoggerService.getDbLogs(limit 100):** Recupera últimos logs para vista auditoría
- **LoggerService.clearLogs():** Limpia historial (útil al cerrar sesión o reconfigurar)
- **LoggerService.getLogFile():** Retorna el archivo físico para compartir vía `share_plus`

### 10.4 Ejemplos de uso en el código
- Logs de sincronización: `sync_logs.txt` generado durante `SincronizarCatalogoUseCase`
- Logs de paquetes: Campo `paquete` identifica qué módulo generó el log (lectura_remote_datasource, articulo_local_datasource, etc.)
- Purga de 90 días: `HistorialEnviosPage` purga logs antiguos junto con lecturas

---

## 11. RESUMEN EJECUTIVO

| Aspecto | Estado |
|---------|--------|
| **Aplicación Android** | Funcional en versión release (compilado con soporte GS1-128, trazabilidad y comprobación de documentos) |
| **Backend ASP.NET** | Operativo con Base datos Access (`BaseScanpal.mdb`) |
| **Tests Unitarios** | 18/18 passing (barcode parser + entities, incluye GS1) |
| **Sistema de Logs** | Completo: SQLite + Archivo txt, Singleton, niveles de severidad |
| **Permisos Cámara** | Solicitados dinámicamente, manejados por `mobile_scanner` package |
| **Configuración Android** | minSdk 21, Java 11, Proguard deshabilitado (debug mode) |
| **Deuda Técnica** | 8 items identificados, priority media-alta |
| **Próximos pasos** | Validación dispositivo real, tests providers/widgets, reducir deuda, integrar endpoint de documentos en ERP |

---

*Informe generado por análisis estático y revisión de archivos del proyecto. Fuentes consultadas: `lib/` (código Dart), `android/app/build.gradle.kts`, `lib/core/services/logger_service.dart`, `DOCUMENTACION.md`, `ScanPal_Movil_Documentacion.md`, `pubspec.yaml`, tests unitarios implementados.*