# ScanPal — Documentación del Proyecto (Rama `prueba`)

Proyecto: scanpal_OLD / paquete scanpalphone_app
Versión: 1.0.0+1
Fecha documentación: 14/10/2026 (actualiza a `ScanPal_Movil_Documentacion.pdf` del 14/10/2026)
Rama: `prueba` (parte de `prueba-gs1-128`, commit `24e9586 Normativa GS1_128 Parseada` + cambios sin consolidar)
Stack: Flutter (Dart SDK ^3.9.2), Clean Architecture + Provider
Plataformas: android/, ios/, linux/, macos/, web/, windows/ (operativa real en Android)
Idioma: es-ES — MaterialApp(locale: es_ES)
Tema: Material 3, seedColor: Color(0,47,108) azul oscuro, scaffoldBackgroundColor: white

## 1. Descripción general

ScanPal es una app móvil Flutter de gestión de almacén con escáner para operarios de tienda/almacén
(caso de uso: Viveros Nava / Ecomputer).
Funcionalidades principales:

1. Login contra ERP (`persona/GetCodigo`) y trabajo offline-first.
2. Sincronización masiva de catálogo de artículos (`articulo/GetCodigos`) a SQLite local.
3. Escaneo continuo con cámara (`mobile_scanner`) + parser propio `BarcodeParser` (EAN-13/8, UPC-A,
   GS1-128 conforme a la guía AECOC/GS1, Code128/39, heurísticas Ref/Lote y Lote-Fecha).
4. Tres modos de operación separados por `TipoOperacion`:
   – Inventario → ruta `/lector` (`LectorPage` + `LectorProvider`)
   – Ventas / Salidas → ruta `/venta` (`VentasPage` + `VentaProvider`)
   – Compras / Entradas → ruta `/compra` (`ComprasPage` + `CompraProvider`)
5. Registro local de `Lectura` (código, referencia, cantidad, lote, descatalogado **+ trazabilidad
   GS1: caducidad, peso neto/bruto, SSCC**), edición/borrado, envío por lotes a `Lectura/Guardar`
   con `Tipo=I/C/V`, historial/auditoría 90 días, exportación CSV/TXT.
6. **Comprobación contra documento (nuevo): rutas `/comprobacion_compra` y `/comprobacion_venta`
   (`ComprobacionPage` + `ComprobacionProvider`). Al recepcionar (compra) o expedir (venta) se
   compara el albarán/factura con las lecturas: pendiente, parcial, completa, sobrante y
   "leído sin línea". Entrada al menú: "Comprobar Compra" / "Comprobar Venta".**
7. Gestión de catálogo: dashboard Activos / Descatalogados / Total, búsqueda global, paginación,
   edición local/remota (`articulo/guardar`), exportación CSV.
8. Configuración: `urlBase`, `cantidadMinima`, `lecturaAutomatica`. URL bloqueada salvo `admin0`.

## 2. Arquitectura

Patrón Clean Architecture + MVVM con Provider.
Novedades de la rama `prueba` marcadas con **(NUEVO)**:

```
lib/main.dart (DI manual)
├── core/
│ ├── constants.dart
│ ├── database_helper.dart          # BD v3 (migraciones v1→v2→v3)
│ ├── barcode_parser.dart           # GS1-128 conforme a normativa AECOC/GS1
│ ├── exceptions.dart
│ ├── sync_progress.dart
│ └── services/logger_service.dart
├── domain/
│ ├── entities/ (articulo, lectura [+4 campos GS1], configuracion, usuario,
│ │               tipo_operacion, opcion_menu, articulo_duplicado,
│ │               documento_esperado.dart (NUEVO))
│ ├── repositories/ (abstract: articulo, lectura, auth, configuracion,
│ │                   documento_repository.dart (NUEVO))
│ └── usecases/ (13 previos + obtener/guardar/comparar_documento (NUEVOS))
├── data/
│ ├── datasources/ (articulo_remote/local, lectura_remote/local, auth_remote/local,
│ │                 config_local, documento_local + documento_remote stub (NUEVOS))
│ ├── models/ (articulo_model.dart, lectura_ws_model.dart [+campos GS1])
│ └── repositories/ (*_impl.dart + documento_repository_impl.dart (NUEVO))
└── presentation/
  ├── pages/ (9 previas + comprobacion_page.dart (NUEVA))
  ├── providers/ (6 previos + comprobacion_provider.dart (NUEVO))
  ├── widgets/ (9 widgets; dialogo_registro_articulo con 3 params opcionales más,
  │              sin cambios visuales)
  └── utils/menu_options.dart (7 → 9 opciones)
```

`main.dart`: además de lo previo, construye `DocumentoRepositoryImpl` (local SQLite + remoto stub),
inyecta `ComprobacionProvider` y registra las rutas `/comprobacion_compra` y `/comprobacion_venta`.

## 3. Entidades del dominio

### 3.1 Cambios en `Lectura` (`lib/domain/entities/lectura.dart`)

Nuevos campos opcionales con trazabilidad de la etiqueta GS1-128:

| Campo | Tipo | Origen (IA) | Columna SQLite |
|---|---|---|---|
| `fechaCaducidad` | `DateTime?` | IA 17 (también 11/13/15 disponibles en `BarcodeData`) | `fecha_caducidad` TEXT ISO |
| `pesoNeto` | `double?` | IA 310n (decimal según 4.º dígito) | `peso_neto` REAL |
| `pesoBruto` | `double?` | IA 330n | `peso_bruto` REAL |
| `sscc` | `String?` | IA 00 | `sscc` TEXT |

`toMap`/`fromMap`/`copyWith` actualizados. `fromMap` tolera filas antiguas sin columnas (lee `null`).
`copyWith` conserva los campos, por lo que **editar una cantidad no pierde la trazabilidad**.

`toJson` WS de la entidad: `Cantidad` viaja como INT si es entera y como DOUBLE si trae decimales
(antes `toInt()` truncaba 0,035 kg a 0); añade `FechaCaducidad` (YYYY-MM-DD o `""`), `PesoNeto`,
`PesoBruto` (número o `null`) y `SSCC` (`""` si no hay).

### 3.2 Nuevas entidades (`lib/domain/entities/documento_esperado.dart`)

- `LineaDocumentoEsperada { referencia, codigoBarras?, descripcion?, cantidadEsperada, lote? }`
- `DocumentoEsperado { id?, tipo (compra=albarán, venta=factura), numero, fecha?, tercero?, lineas }`
  con `toMap`/`fromMap` (líneas serializadas como JSON).
- `EstadoLinea { pendiente, parcial, completa, sobrante }`, `LineaComprobada { esperada, cantidadLeida,
  estado }`, `LecturaSobrante { codigo, referencia, lote?, cantidad }`,
  `ResultadoComprobacion { lineas, sinLinea, completas/parciales/pendientes/sobrantes,
  cantidadEsperadaTotal, cantidadLeidaTotal, estaCompleto }`.
- Función pura `compararDocumentoConLecturas(documento, lecturas)`: empareja por referencia
  (solo dígitos) o código exacto; si la línea exige lote, solo suman las lecturas con ese lote.
  Las lecturas pendientes del mismo tipo que no encajan en ninguna línea van a `sinLinea`.
  Tolerancia de comparación `1e-9` para cantidades con decimales (pesos).

## 4. Persistencia local

### 4.1 `core/database_helper.dart` — BD `ScanPalDB.db` v3

- **v1 → v2**: `ALTER TABLE lecturas ADD COLUMN fecha_caducidad TEXT / peso_neto REAL /
  peso_bruto REAL / sscc TEXT` (filas antiguas en NULL).
- **v2 → v3**: `CREATE TABLE documentos (id PK AI, tipo TEXT NOT NULL, numero TEXT NOT NULL,
  fecha TEXT, tercero TEXT, lineas_json TEXT NOT NULL DEFAULT '[]', UNIQUE(tipo, numero))`.
- `_onCreate` ya crea ambas estructuras para instalaciones limpias.

### 4.2 Tablas

`lecturas` = esquema previo + `fecha_caducidad TEXT, peso_neto REAL, peso_bruto REAL, sscc TEXT`.
`documentos` = esquema del punto 4.1 (una fila por (tipo, número); la más reciente manda).
Resto de tablas (`articulos`, `logs`, `metadata`, índices) sin cambios.

## 5. Lógica de negocio clave

### 5.1 `core/barcode_parser.dart` — GS1-128 conforme a normativa (rama `prueba-gs1-128`)

API pública sin cambios (`BarcodeParser.parse()` → `BarcodeData`; solo consumido por las 3 páginas
de lectura). Cambios internos de decodificación según la guía AECOC/GS1:

- Catálogo completo del Anexo II: 20, 30, 240/241/250/251, 400-403, 410-415, 420/421, 422-426,
  7001/7002, 703x, 8001-8008, 8018, 8020, 8100-8102, 90-99 (antes un `(20)` cortaba el parseo).
- Familias de 4 dígitos resueltas por rango: medidas 310n-369n, importes 390n-393n, 703x.
- **Pesos**: el 4.º dígito sitúa el decimal (`(3103)000035` = 0,035 kg); `pesoNeto`/`pesoBruto`
  (antes siempre `null`) y `cantidad` salen correctos, con prioridad 37 > 30 > neto 310n > bruto 330n.
- **FNC1**: tabla de qué IAs lo exigen (pág. 10-11); el separador corta los campos variables.
- **Referencias**: el (02) identifica el contenido y prevalece sobre el (01); **un (00) solo
  (picking/multirreferencia) ya no se busca como artículo** — su contenido viaja en el DESADV.
- **GTIN-14 → 13**: solo se quita el `0` inicial si el resto supera el dígito de control
  (los indicadores logísticos 1-8 se conservan).
- **Fechas AAMMDD** validadas; día `00` = último día del mes.
- Acepta la forma humanamente legible con paréntesis `(01)...(10)...` (entrada manual) y el
  identificador `]C1`; dígito de control GS1 verificado (modo informativo, el catálogo manda).
- Rutas no GS1 intactas: EAN-13/8, UPC-A, heurísticas Nava (`Ref/Lote`, `Lote - Fecha`), Code39/128.

### 5.2 Registro de lecturas (con trazabilidad)

`RegistrarLecturaUseCase.execute` acepta `fechaCaducidad?`, `pesoNeto?`, `pesoBruto?`, `sscc?`
(opcionales). Los 3 providers (`registrarLectura`) los reenvían; las 3 páginas los toman del
`barcode` tanto en auto-registro como vía `DialogoRegistroArticulo` (nuevos parámetros opcionales
`pesoNetoExtraido/pesoBrutoExtraido/ssccExtraido`; el diálogo ya mostraba `fechaExtraida` y ahora
también la persiste). Ningún widget cambia de aspecto.

### 5.3 Comparación contra documento (nuevo)

- `ObtenerDocumentoUseCase(tipo, numero)`: intenta servidor y cachea; si el endpoint no existe o
  falla la red, devuelve la copia local (o `null`).
- `GuardarDocumentoUseCase`: valida (nº no vacío, líneas con referencia o código y cantidad > 0)
  y guarda en local. Sirve a la carga manual y a la futura importación.
- `CompararDocumentoUseCase(documento)`: lee las pendientes del tipo y aplica
  `compararDocumentoConLecturas`.
- `documento_remote_datasource.dart` es un **stub**: valida configuración y lanza
  `ServerException('Endpoint de documentos pendiente de integrar en el servidor.')`.
  Contrato previsto (a confirmar): `GET {base}/documento/GetDocumento?tipo=C|V&numero=XXX` →
  `{ Numero, Fecha, Tercero, Lineas: [{ Referencia, CodigoBarras, Descripcion, Cantidad, Lote }] }`.

### 5.4 Resto sin cambios

Búsqueda de artículos (cascada + fuzzy + fallbacks), envío por lotes (500, reintentos 3×2 s,
`LecturasRecibidas`), purga 90 días, login/configuración: igual que en el PDF del 14/10/2026.

## 6. Pantallas

| Página | Ruta | Descripción |
|---|---|---|
| … (7 previas salvo Ventas/Compras) | … | Sin cambios. Inventario y resto, intactos |
| `ventas_page.dart` / `compras_page.dart` | `/venta`, `/compra` | Igual que antes **más**: si hay documento activo del tipo, muestran `DocumentoPanel` (líneas con estado en vivo) y las filas fuera de documento en rojo; tras cada registro llaman a `refrescarTipo`. Sin documento activo, aspecto idéntico al original |
| `comprobacion_page.dart` (`ComprobacionPage(tipo)`) **(NUEVA)** | `/comprobacion_compra`, `/comprobacion_venta` | Card de documento (nº + Cargar / Nuevo manual), aviso de endpoint pendiente, tarjeta resumen con chips (completas/parciales/pendientes/sobrantes/sin línea) o banner verde si cuadra todo, lista de líneas con estado por color (verde/morado/naranja/rojo, convención existente) y borrado por línea, sección "Leído sin línea", diálogo "Añadir línea", FAB Escanear → `/compra` o `/venta` (al volver recompara), acciones refrescar y borrar documento |

Menú (`menu_options.dart`): se añaden `Comprobar Venta` (`playlist_add_check` →
`/comprobacion_venta`) y `Comprobar Compra` (`fact_check` → `/comprobacion_compra`). El resto
del menú y todas las pantallas existentes quedan visualmente idénticas.

## 7. Providers

| Provider | Novedad en `prueba` |
|---|---|
| `LectorProvider`, `CompraProvider`, `VentaProvider` | `registrarLectura` acepta `fechaCaducidad?/pesoNeto?/pesoBruto?/sscc?` (opcionales, reenvío al usecase) |
| `ComprobacionProvider` **(NUEVO)** | `ComprobacionState {initial, loading, loaded, saving, error}`; `fijarTipo`, `cargarDocumento`, `crearDocumentoVacio`, `agregarLinea`, `borrarLinea`, `borrarDocumento`, `refrescar`, `refrescarTipo(tipo)`; expone `documento`, `resultado`, `avisoRemoto` del contexto más `documentoDe(tipo)`/`resultadoDe(tipo)`. **Multi-tipo**: mantiene un documento activo por tipo (compra y venta a la vez); el cargado en Comprobar es el que ven Compras/Ventas |
| Login, Configuración, ActualizarArtículo | Sin cambios |

## 8. Widgets y utils

`DialogoRegistroArticulo` suma 3 parámetros opcionales y los persiste al confirmar (sin cambios
visuales). **Nuevos con comprobación en vivo**: `widgets/documento_panel.dart` (`DocumentoPanel`:
cabecera con nº y completas + lista colapsable de líneas con `leído/esperado` por color; se muestra
en Ventas/Compras cuando hay documento activo) y parámetro opcional `esInesperada` en
`LecturasDataTable` (filas fuera de documento en rojo con icono; `null` = aspecto de siempre, como
en Inventario). Entidad: `documentoContieneLectura()` y `unidadesFaltantes/unidadesSobrantes`.
confirmar; `LecturasDataTable`, `CameraViewSection`, resto de widgets y `menu_options.dart`
(salvo las 2 entradas nuevas) intactos.

## 9. Servicios y backend

Sin cambios en `LoggerService`, `SyncProgress`, excepciones y endpoints previos, salvo el payload
de envío.

### 9.1 `POST {base}/Lectura/Guardar` — payload actualizado

Por lectura: `{Referencia:int, CodigoBarras, Cantidad:int|double, Usuario, Lote, FechaEnvio:
YYYY-MM-DD HH:mm:ss, Tipo:I/C/V, FechaCaducidad:YYYY-MM-DD|"", PesoNeto:number|null,
PesoBruto:number|null, SSCC:""}`. `Cantidad` es INT cuando es entera (contrato histórico) y
DOUBLE con decimales cuando viene de peso GS1. Respuesta y reintentos igual que antes
(`LecturasRecibidas`, lotes de 500). **Pendiente de validar contra el ERP real**: si el servidor
es estricto con campos extra, ignorará o rechazará las 4 claves nuevas.

### 9.2 Endpoint de documentos — pendiente de integrar (ERP)

Ver contrato previsto en 5.3. Hasta entonces la app trabaja con copia local / líneas manuales.

## 10. Assets y dependencias

Sin cambios respecto al PDF del 14/10/2026.

## 11. Flujos típicos de uso

### 11.1 Inventario / ventas / compras (actualizado)

Escaneo → `BarcodeParser` (GTIN + lote + caducidad + pesos + SSCC) → `buscarArticulo`
→ auto-registro o diálogo → `saveLectura` SQLite **con trazabilidad GS1** → tabla →
`Enviar Lecturas` (payload con decimales y trazabilidad) → historial.

### 11.2 Comprobación contra documento (nuevo)

Menú Comprobar Compra/Venta → introducir nº → Cargar (servidor cuando exista; hoy copia local)
o Nuevo manual + Añadir líneas → las líneas **se cargan en la página Ventas/Compras**, que muestra
un panel con cada línea y su estado en vivo (pendiente, parcial, completa, sobrante) → al escanear,
cada lectura actualiza el estado de su línea y **lo leído fuera de documento va en rojo** →
al terminar, Comprobar muestra el veredicto ("Documento correcto" o qué falta/sobra en unidades
y líneas) → el envío final se hace desde **Enviar Lecturas** (flujo existente, sin cambios).
El documento activo es global por tipo (`ComprobacionProvider` multi-tipo): el cargado en Comprobar
es el mismo que ven Compras/Ventas. Inventario (`/lector`) no muestra documento ni resaltado.

## 12. Ficheros y ramas

- Rama `prueba-gs1-128` (commit `24e9586`): normativa GS1-128 en `barcode_parser.dart`.
- Rama `prueba` (actual): lo anterior + columnas GS1, envío con decimales/trazabilidad y
  comprobación contra documento (13 ficheros modificados + 10 nuevos, ver `git status`).
- Tests temporales de verificación (`gs1_parser_check_test`, `lectura_gs1_check_test`,
  `comprobacion_check_test`) ejecutados en verde y eliminados; `test/widget_test.dart` sigue
  siendo la plantilla sin cobertura.

## 13. Estado actual y deuda técnica observada

Resuelto en `prueba`: pesos GS1 mal calculados, `pesoNeto/Bruto` siempre `null`, SSCC usado como
artículo, IAs ausentes que cortaban el parseo, truncado de decimales en el envío, falta de
columnas de trazabilidad, ausencia de comprobación contra documento.
Pendiente:

1. Integrar el endpoint de documentos en el ERP e implementarlo en
   `documento_remote_datasource.dart`.
2. Validar un envío real con los 4 campos nuevos (`FechaCaducidad`, `PesoNeto`, `PesoBruto`,
   `SSCC`) por si el servidor es estricto.
3. `Venta/CompraProvider` siguen con `currentUserId=1` fijo (no usan `AuthLocalDataSource`).
4. `HistorialEnviosPage` solo muestra inventario (no ventas/compras).
5. `Caducidad.mp3` declarado pero no usado; `hive/build_runner` en dev sin uso aparente.
6. Sin tests permanentes; `README.md` de plantilla.
7. `articulos_duplicados` solo se crea en el isolate de sincronización, no en `_onCreate`.
