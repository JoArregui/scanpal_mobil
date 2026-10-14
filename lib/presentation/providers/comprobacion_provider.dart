import 'package:flutter/foundation.dart';
import '../../domain/entities/documento_esperado.dart';
import '../../domain/entities/tipo_operacion.dart';
import '../../domain/repositories/documento_repository.dart';
import '../../domain/usecases/comparar_documento_usecase.dart';
import '../../domain/usecases/guardar_documento_usecase.dart';
import '../../domain/usecases/obtener_documento_usecase.dart';

enum ComprobacionState { initial, loading, loaded, saving, error }

/// Comprobación de lecturas contra el albarán (compra) o factura (venta).
/// Mantiene un documento activo por tipo: el que se carga en
/// Comprobar Compra/Venta es el mismo que ven Compras/Ventas al escanear.
/// El documento llega del servidor cuando el ERP lo exponga; mientras tanto
/// se trabaja con la copia local o con líneas introducidas a mano.
class ComprobacionProvider with ChangeNotifier {
  final ObtenerDocumentoUseCase obtenerDocumentoUseCase;
  final GuardarDocumentoUseCase guardarDocumentoUseCase;
  final CompararDocumentoUseCase compararDocumentoUseCase;
  final DocumentoRepository documentoRepository;

  ComprobacionProvider({
    required this.obtenerDocumentoUseCase,
    required this.guardarDocumentoUseCase,
    required this.compararDocumentoUseCase,
    required this.documentoRepository,
  });

  /// Tipo que muestra la página de comprobación (contexto de sus getters).
  TipoOperacion _tipo = TipoOperacion.compra;

  final Map<TipoOperacion, DocumentoEsperado?> _documentos = {};
  final Map<TipoOperacion, ResultadoComprobacion?> _resultados = {};
  final Map<TipoOperacion, String> _avisos = {};

  ComprobacionState _state = ComprobacionState.initial;
  String _errorMessage = '';

  TipoOperacion get tipo => _tipo;
  DocumentoEsperado? get documento => _documentos[_tipo];
  ResultadoComprobacion? get resultado => _resultados[_tipo];
  ComprobacionState get state => _state;
  String get errorMessage => _errorMessage;

  /// Mensaje informativo cuando el servidor aún no expone documentos.
  String get avisoRemoto => _avisos[_tipo] ?? '';

  /// Documento activo de un tipo (lo ven Compras/Ventas al escanear).
  DocumentoEsperado? documentoDe(TipoOperacion tipo) => _documentos[tipo];

  /// Última comparación de un tipo (null si aún no se calculó).
  ResultadoComprobacion? resultadoDe(TipoOperacion tipo) =>
      _resultados[tipo];

  void fijarTipo(TipoOperacion tipo) {
    if (_tipo == tipo) return;
    _tipo = tipo;
    _state = _documentos[tipo] == null
        ? ComprobacionState.initial
        : ComprobacionState.loaded;
    _errorMessage = '';
    notifyListeners();
  }

  /// Carga el documento por número: intenta servidor, si no existe el
  /// endpoint usa la copia local. Después compara con las lecturas.
  Future<void> cargarDocumento(String numero) async {
    final num = numero.trim();
    if (num.isEmpty) {
      _errorMessage = 'Indique el número de documento.';
      _state = ComprobacionState.error;
      notifyListeners();
      return;
    }

    _state = ComprobacionState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final doc = await obtenerDocumentoUseCase.execute(_tipo, num);
      if (doc == null) {
        _errorMessage =
            'Documento no encontrado en local y sin conexión al servidor.';
        _state = ComprobacionState.error;
        notifyListeners();
        return;
      }
      _documentos[_tipo] = doc;
      _avisos[_tipo] =
          'Servidor sin endpoint de documentos: se usa la copia local.';
      await refrescar();
    } catch (e) {
      _errorMessage = 'Error al cargar el documento.';
      _state = ComprobacionState.error;
      notifyListeners();
      if (kDebugMode) print('❌ [COMPROBACION] $e');
    }
  }

  /// Crea un documento vacío para ir añadiendo líneas a mano.
  Future<void> crearDocumentoVacio(String numero) async {
    final num = numero.trim();
    if (num.isEmpty) {
      _errorMessage = 'Indique el número de documento.';
      _state = ComprobacionState.error;
      notifyListeners();
      return;
    }
    _documentos[_tipo] =
        DocumentoEsperado(tipo: _tipo, numero: num, lineas: const []);
    await _guardarYComparar();
  }

  /// Añade una línea esperada a mano al documento actual.
  Future<void> agregarLinea({
    required String referencia,
    String? codigoBarras,
    String? descripcion,
    required double cantidad,
    String? lote,
  }) async {
    final actual = _documentos[_tipo];
    if (actual == null) return;
    final lineas = List<LineaDocumentoEsperada>.from(actual.lineas)
      ..add(
        LineaDocumentoEsperada(
          referencia: referencia.trim(),
          codigoBarras: (codigoBarras ?? '').trim().isEmpty
              ? null
              : codigoBarras!.trim(),
          descripcion: (descripcion ?? '').trim().isEmpty
              ? null
              : descripcion!.trim(),
          cantidadEsperada: cantidad,
          lote: (lote ?? '').trim().isEmpty ? null : lote!.trim(),
        ),
      );
    _documentos[_tipo] = actual.copyWith(lineas: lineas);
    await _guardarYComparar();
  }

  Future<void> borrarLinea(int indice) async {
    final actual = _documentos[_tipo];
    if (actual == null) return;
    if (indice < 0 || indice >= actual.lineas.length) return;
    final lineas = List<LineaDocumentoEsperada>.from(actual.lineas)
      ..removeAt(indice);
    _documentos[_tipo] = actual.copyWith(lineas: lineas);
    await _guardarYComparar();
  }

  Future<void> borrarDocumento() async {
    final actual = _documentos[_tipo];
    if (actual == null) return;
    try {
      await documentoRepository.borrarDocumento(actual.tipo, actual.numero);
    } catch (e) {
      if (kDebugMode) print('❌ [COMPROBACION] Borrado: $e');
    }
    _documentos.remove(_tipo);
    _resultados.remove(_tipo);
    _avisos.remove(_tipo);
    _state = ComprobacionState.initial;
    notifyListeners();
  }

  /// Recompara el documento actual con las lecturas (tras escanear).
  Future<void> refrescar() => refrescarTipo(_tipo);

  /// Recompara el documento de [tipo] sin tocar el contexto visible.
  /// Lo invocan Compras/Ventas tras cada registro para el estado en vivo.
  Future<void> refrescarTipo(TipoOperacion tipo) async {
    final doc = _documentos[tipo];
    if (doc == null) return;
    final esContexto = tipo == _tipo;
    if (esContexto) {
      _state = ComprobacionState.loading;
      notifyListeners();
    }
    try {
      _resultados[tipo] = await compararDocumentoUseCase.execute(doc);
      if (esContexto) _state = ComprobacionState.loaded;
    } catch (e) {
      if (esContexto) {
        _errorMessage = 'Error al comparar con las lecturas.';
        _state = ComprobacionState.error;
      }
      if (kDebugMode) print('❌ [COMPROBACION] $e');
    }
    notifyListeners();
  }

  Future<void> _guardarYComparar() async {
    _state = ComprobacionState.saving;
    _errorMessage = '';
    notifyListeners();
    try {
      await guardarDocumentoUseCase.execute(_documentos[_tipo]!);
      await refrescar();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _state = ComprobacionState.error;
      notifyListeners();
    }
  }
}
