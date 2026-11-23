# ScanPal - Guía de Usuario

## Versión 1.0.0 | Fecha: 18/11/2026

### Resumen rápido
ScanPal es una aplicación móvil para gestión de almacén con escáner de códigos de barras. Diseñada para operarios de tiendas y almacenes (caso de uso: Viveros Nava / Ecomputer). Funciona offline-first con sincronización cuando hay conexión.

---

## 1. Primeros pasos

### 1.1 Instalación
- La aplicación está disponible como APK para Android o se puede instalar desde la tienda de aplicaciones
- Primer inicio: la pantalla de bienvenida aparecerá automáticamente

### 1.2 Permisos necesarios
- **Cámara**: Necesaria para escanear códigos de barras (se solicita la primera vez que se usa el escáner)
- **Linterna**: Opcional, para activar la luz del flash durante el escaneo

---

## 2. Flujo de uso típico

```
Splash (3.8 s) → Login → Home (menú principal) → [Modo: Inventario/Ventas/Compras] → Escaneo → Registro → Enviar lecturas → Historial
```

### 2.1 Pantalla de bienvenida
- Duración: 3.8 segundos
- Animación de movimiento/rotación/escala con el logo
- Cierra automáticamente y lleva a la pantalla de login

### 2.2 Login (Autenticación ERP)
- **Campos**: Usuario y contraseña
- **Proceso**:
  1. Ingresa tu nombre de usuario y contraseña
  2. La app fija la URL base del servidor (https://scanpal.ecomputer.es)
  3. Valida las credenciales contra el ERP
  4. Guarda tu código de usuario localmente
  5. Refresca el provider de lector con tus permisos
  6. Te lleva al menú principal

- **Acceso administrador**: Pulsa largo en el título "ScanPal" para acceder al diálogo de administrador (usuario: `admin0`)

### 2.3 Menú principal (HomePage)
- **Grid**: 7 opciones de menú (disponibles en 2/3/4 columnas dependiendo del ancho de pantalla)
- **FAB (Floating Action Button)**: Botón grande "Escanear" que lleva al lector
- **Cerrar sesión**: En la parte inferior del grid

#### Opciones del menú (9 disponibles):
1. **Configuración** (`settings`) → Ir a ajustes
2. **Actualizar Artículos** (`cloud_download`) → Sincronizar catálogo
3. **Leer Códigos** (`qr_code_scanner`) → Modo lector/escáner
4. **Enviar Lecturas** (`cloud_upload`) → Enviar lecturas pendientes
5. **Historial** (`history`) → Ver histórico de envíos
6. **Ventas** (`point_of_sale`) → Modo ventas/salidas
7. **Compras** (`shopping_cart`) → Modo compras/entradas
8. **Comprobar Venta** (`playlist_add_check`) → Comprobar documento de venta
9. **Comprobar Compra** (`fact_check`) → Comprobar documento de compra

---

## 3. Modos de operación

### 3.1 Modo Inventario (`/lector`)
- **Ruta**: Accede desde el menú o el FAB "Escanear"
- **Propósito**: Contar artículos en inventario
- **Funcionamiento**:
  - Se activa la cámara con una superposición de escaneo
  - Estabilidad: requiere 5 lecturas consecutivas para confirmar
  - Debounce: 2 segundos entre lecturas
  - Zoom: 1x a 5x (pinch para zoom)
  - Linterna: Puede activarse/desactivarse
  - Al escanear, busca el artículo en la base de datos local
  - Si no encuentra, ofrece búsqueda fuzzy (similares)

### 3.2 Modo Ventas / Salidas (`/venta`)
- **Ruta**: Menú → Ventas o FAB → Modo venta
- **Propósito**: Registrar salidas de artículos
- **Diferencias con Inventario**:
  - No permite búsqueda fuzzy
  - Bloqueo de 3 segundos entre lecturas
  - Si hay un documento activo, muestra panel de líneas
  - AppBar con color distintivo

### 3.3 Modo Compras / Entradas (`/compra`)
- **Ruta**: Menú → Compras o FAB → Modo compra
- **Propósito**: Registrar entradas de artículos
- **Características**:
  - AppBar verde identificativa
  - Mismo funcionamiento que Ventas
  - Si hay documento activo, muestra panel de líneas
  - Modo entrada de stock

### 3.4 Comprobación de documento (Nuevo)
- **Rutas**: `/comprobacion_compra` o `/comprobacion_venta`
- **Propósito**: Comparar las lecturas realizadas contra un documento (albarán o factura) previamente cargado
- **Proceso**:
  1. Desde el menú selecciona "Comprobar Compra" o "Comprobar Venta"
  2. Introduce el número de documento (albarán/factura)
  3. Opción "Cargar" (intenta servidor) o "Nuevo manual" (crear documento vacío)
  4. Se muestra un resumen con chips de estado: completas, parciales, pendientes, sobrantes, sin línea
  5. Cada línea muestra su estado en vivo (verde/morado/naranja/rojo)
  6. Al escanear un código, actualiza el estado de la línea correspondiente
  7. Lecturas fuera de documento se marcan en rojo
  8. Al terminar, muestra el veredicto final
  9. El envío final se hace desde la pantalla "Enviar Lecturas" (flujo existente)

---

## 4. Flujo de escaneo y registro

### 4.1 Escaneo básico
1. Accede al modo deseado (Inventario, Ventas o Compras)
2. La cámara se activa automáticamente (o toca el FAB de disparo)
3. Coloca el código de barras dentro del marco de escaneo
4. Espera a que se confirme la lectura (5 lecturas estables)
5. El sonido de "lectura correcta" sonará

### 4.2 Diálogo de registro de artículo
Después de escanear, aparece un diálogo con los siguientes campos:

#### Campos automáticos (rellenados por el scanner):
- **Código de barras**: GTIN/ código leído
- **Lote**: Si el código incluye lote (formato Ref/Lote o GS1)
- **Fecha de caducidad**: Si viene en el código GS1
- **Peso neto**: Peso del producto (si viene en GS1)
- **Peso bruto**: Peso total empaquetado (si viene en GS1)
- **SSCC**: Código de envase logístico (si viene en GS1)

#### Campos de entrada:
- **Cantidad**: Por defecto toma el valor de `cantidadMinima` del artículo configurado
  - Se puede editar antes de guardar
- **Lote**: Obligatorio si el artículo tiene `gestionLotes: true`
  - Si falta, la app muestra un aviso morado y suena una alerta
  - **Opción**: Puedes confirmar el registro **sin lote** (badge "auto_awesome" si vino de GS1)
- **Descatalogado**: Si el artículo está dado de baja

#### Acciones:
- **Guardar**: Guarda la lectura en la base de datos local
- **Doble-tap en la tabla**: Edita o borra lecturas anteriores
- Si la cantidad es menor a `cantidadMinima`, se muestra advertencia

### 4.3 Campos GS1-128 (normativa AECOC)
El scanner identifica automáticamente códigos GS1-128 con los siguientes identificadores de aplicación (IAs):
- **01**: GTIN (14 dígitos, convierte a GTIN-13 quitando el 0 inicial)
- **10**: Fecha de caducidad (formato AAMMDD, día 00 = último día del mes)
- **11**: Fecha de caducidad alternativa
- **15/17**: Fecha de caducidad (formato legible)
- **21**: Número de lote
- **310n-369n**: Familias de medidas (3103=3.103mm, etc.)
- **390n-393n**: Familias de importes (3902=3.90€, etc.)
- **400n-403n**: Familias de peso (4003=0,035 kg)
- **7001-7002**: Campos adicionales
- **8001-8008, 8018, 8020, 8100-8102**: IAs logísticas
- **90-99**: Campos de proveedor

Los pesos se calculan automáticamente: el 4.º dígito determina el decimal (ej: (3103)000035 = 0,035 kg).

---

## 5. Sincronización de catálogo

### 5.1 Primera vez
1. Desde el menú, selecciona **"Actualizar Artículos"**
2. Se mostrará una progreso con porcentaje, artículos/segundo y tiempo estimado
3. La sincronización se ejecuta en un isolate (proceso paralelo) para no bloquear la UI
4. Se clasifican artículos únicos vs duplicados por código
5. Al finalizar, se muestra un dashboard con:
   - Artículos activos
   - Artículos descatalogados
   - Total de artículos

### 5.2 Actualizaciones posteriores
- Se recomienda sincronizar periódicamente para obtener precios y descripciones actualizadas
- El provider intenta 3 reintentos con backoff de 90 segundos si falla
- Stats de sincronización se guardan en metadata y logs

---

## 6. Búsqueda de artículos

### 6.1 Búsqueda global
1. En cualquier pantalla con catálogo, usa el campo de búsqueda
2. El sistema prueba en este orden:
   - Código exacto → referencia exacta → `LIKE %cod%` código → `LIKE %cod%` referencia
   - Búsqueda fuzzy: extrae prefijos (5→4→3 dígitos) y hace LIKE
   - Prefijos especiales: `12 → 0+cod`, `padLeft 13/14`, `2xxxxxx` (peso variable 7 dígitos)

### 6.2 Filtros avanzados
- Búsqueda por código de barras, descripción o referencia
- Debounce de 500ms para evitar búsquedas excesivas
- Paginación: 50 artículos por página, prefetch a 300px del final

---

## 7. Registro de lecturas

### 7.1 Guardado local
- Cada lectura se guarda automáticamente en SQLite local (`ScanPalDB.db`)
- Se incluye: código, referencia, cantidad, lote, fecha, tipo de operación, y los 4 campos GS1 (caducidad, peso neto, peso bruto, SSCC)
- Las lecturas tienen estado `sincronizado: false` hasta enviarse

### 7.2 Edición y borrado
- En la tabla de lecturas, **doble-tap** sobre cualquier fila
- Opciones: Editar cantidad/lote/fechas, o Borrar
- Borrado masivo disponible en Historial y Enviar Lecturas

### 7.3 Envío al servidor
1. Ve a la pantalla **"Enviar Lecturas"** desde el menú
2. Se muestran 3 tipos de lecturas pendientes: Inventario, Ventas, Compras
3. **Lotes por lotes de 500**: El envío se hace en chunks de 500 lecturas
4. Validación: Confirma que cada paquete fue recibido antes de continuar
5. **Fecha de envío**: Se asigna el momento exacto de transmisión (formato ISO-8601)
6. **Trazabilidad GS1**: Los campos de peso, caducidad y SSCC se envían con sus valores decimales completos
7. Después de enviado, se marca como `sincronizado: true` localmente

### 7.4 Historial de envíos
- **Auditoría 90 días**: Calendario con puntos verdes por día que tuvo sincronizaciones
- **Lista**: Hora, descripción, código-ref, lote, cantidad
- **Exportar**:
  - **CSV**: `SCANPAL_CATALOGO_COMPLETO.csv` (formato `;`)
  - **TXT**: `comprobante_envio_yyyMMdd.txt` (comprobante detallado)
- **Purga**: Automática de 90 días, o manual (confirma borrado de todas las lecturas locales)

---

## 8. Configuración

### 8.1 Acceso
- Desde el menú: **"Configuración"**
- **Solo administradores**: La URL base es de solo lectura salvo que seas `admin0` o desbloquees manualmente

### 8.2 Parámetros configurables:
- **URL base**: Dirección del servidor ERP (https://scanpal.ecomputer.es por defecto)
  - Bloqueada para usuarios normales
  - Desbloqueable por admin0 o mediante diálogo de contraseña
- **Cantidad mínima**: Valor por defecto para nuevo registro (configurable)
- **Lectura automática**: Intervalo entre lecturas automáticas (1-60 segundos)
  - Aplicado en modos Inventario, Compras y Ventas
  - Si está desactivado, el disparo es manual (pulsar FAB)
- **Restaurar URL**: Botón para restablecer la URL base por defecto

### 8.3 Acceso administrador (`admin0`)
- Pulsa largo en el título en la pantalla de login
- Diálogo para ingresar contraseña de administrador
- Permite modificar la URL base desbloqueada

---

## 9. Sistema de logs

La aplicación registra automáticamente todas las operaciones importantes:

### 9.1 Dónde se guardan los logs:
- **SQLite**: Base de datos `ScanPalDB.db`, tabla `logs`
- **Archivo de texto**: `sync_logs.txt` en la carpeta de documentos de la aplicación

### 9.2 Niveles de severidad:
- `START`, `SUCCESS`, `WARNING`, `CRITICAL`, `END`, `INFO`

### 9.3 Casos de uso de logs:
- Sincronización: `sync_logs.txt` se genera durante la sincronización de catálogo
- Auditoría: `getDbLogs(limit 100)` recupera los últimos 100 logs para vista auditoría
- Compartir: `getLogFile()` retorna el archivo para compartir vía share_plus
- Purga: `clearLogs()` vacía tanto la BD como el archivo (útil al cerrar sesión)

### 9.4 Para ver logs:
- Accede a la configuración o usa la opción de exportar en Historial
- Los logs incluyen información sobre qué módulo generó el evento (lectura_remote_datasource, articulo_local_datasource, etc.)

---

## 10. Preguntas frecuentes

### P: ¿Qué hago si la cámara no enfoca los códigos?
R: Asegúrate de que:
- La luz del ambiente sea suficiente
- El código de barras esté limpio y sin daños
- Intentes acercar o alejar (pinch zoom 1x-5x)
- Limpia la lente de la cámara

### P: ¿Cómo cambio el lote después de registrar?
R: Ve a la pantalla "Enviar Lecturas", selecciona la lectura y edítala (doble-tap), o ve al historial y edita desde allí.

### P: ¿Puedo usar la app sin conexión?
R: Sí, la app es **offline-first**. Todos los registros se guardan localmente y se sincronizan cuando hay conexión a internet.

### P: ¿Con qué frecuencia se sincroniza el catálogo?
- Primera vez: recomendado al iniciar
- Periódico: cada vez que haya cambios en el ERP o cada pocos días
- El provider intenta 3 reintentos automáticos si falla

### P: ¿Qué significan los estados de línea en comprobación de documento?
- **Pendiente**: La línea aún no tiene lecturas
- **Parcial**: Algunas lecturas cubrieron parte de la cantidad esperada
- **Completa**: La cantidad leída iguala o supera la esperada
- **Sobrante**: Hay más lecturas de la esperada para esa línea
- **Sin línea**: El código escaneado no corresponde a ninguna línea del documento

### P: ¿Cómo activo/desactivo la linterna?
R: En los modos de lector (Inventario, Ventas, Compras), hay un botón/toggle para activar/desactivar la flashlight/cámara torch.

### P: ¿Qué hacer si se pierde la conexión durante el envío?
R: La app tiene lógica de reintentos (3x con retraso de 2s). Las lecturas no enviadas se quedan marcadas como `sincronizado: false` y se reintentarán en el próximo envío. Puedes forzar el envío desde "Enviar Lecturas" cuando recuperes la conexión.

### P: ¿Puedo exportar mis datos?
R: Sí, desde la pantalla "Historial de envios" puedes exportar:
- **CSV**: Datos completos del catálogo (formato `;`)
- **TXT**: Comprobante de envío con fecha y hora

---

## 11. Atajos y tips

- **Pulso largo en el título** (pantalla login): Accede a modo administrador con `admin0`
- **Pinch en la vista de cámara**: Zoom 1x a 5x para mejor lectura de códigos pequeños
- **Doble-tap en tablas**: Editar o borrar lecturas rápidamente
- **FAB grande**: Always returns to scanner mode
- **Calendario en Historial**: Navega por fechas con puntos verdes = días con sincronización
- **Modo admin0**: Permite cambiar URL base y configuraciones globales

---

## 12. Contacto y soporte

- **Versión**: 1.0.0+1
- **Base URL por defecto**: https://scanpal.ecomputer.es
- **Usuario admin**: `admin0` (contraseña: obtener de tu administrador del sistema)
- **Sistema de logs**: Para reportar problemas, usa la opción "Exportar logs" en Historial

---

*Guía generada basada en el análisis del proyecto ScanPal. Para asistencia técnica, consulta los logs en `sync_logs.txt` o contacta con el administrador del sistema.*