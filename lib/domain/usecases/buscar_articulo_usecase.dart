import '../entities/articulo.dart';
import '../repositories/articulo_repository.dart';

class BuscarArticuloUseCase {
  final ArticuloRepository repository;

  BuscarArticuloUseCase(this.repository);

  /// Ejecuta la búsqueda de un artículo por código o referencia.
  /// Implementa una lógica de cascada:
  /// 1. Busca en la tabla principal (Artículos operativos).
  /// 2. Si no lo encuentra, busca en la tabla de duplicados/auditoría.
  /// 3. Si tampoco, busca por texto libre en descripción, código y referencia.
  Future<Articulo?> execute(String codigo) async {
    final String valorBusqueda = codigo.trim();

    if (valorBusqueda.isEmpty) {
      throw Exception("El código de búsqueda no puede estar vacío.");
    }

    // 1. Intentar obtener de la tabla principal (Operativos)
    final articuloPrincipal = await repository.getArticuloByCodigo(
      valorBusqueda,
    );

    if (articuloPrincipal != null) {
      return articuloPrincipal;
    }

    // 2. Si no existe en la principal, buscamos en los descartados por duplicidad
    // Esto es vital para informar al usuario si el artículo existe pero fue ignorado.
    final articuloDuplicado = await repository.getArticuloDuplicadoByCodigo(
      valorBusqueda,
    );

    if (articuloDuplicado != null) {
      return articuloDuplicado;
    }

    // 3. Fallback por texto libre: busca con LIKE en descripción, código y referencia.
    // Útil para etiquetas fitosanitarias (Nava) donde el lote escaneado puede coincidir
    // parcialmente con la descripción o referencia del artículo en BD.
    final List<Articulo> porDescripcion = await repository
        .buscarArticulosPorTexto(valorBusqueda);

    if (porDescripcion.length == 1) {
      // Coincidencia única: devolvemos directamente
      return porDescripcion.first;
    }

    if (porDescripcion.length > 1) {
      // Varias coincidencias: devolvemos la primera (ORDER BY descripcion ASC de la BD).
      // El provider mostrará el resultado y el usuario podrá confirmar o corregir.
      return porDescripcion.first;
    }

    // 4. No encontrado en ninguna fuente
    return null;
  }

  /// Búsqueda fuzzy: extrae solo los dígitos numéricos del código escaneado
  /// y busca artículos que los contengan. Devuelve lista para que el usuario elija.
  /// Ejemplo: "10450/222898" → busca con "10450" → encuentra "10548"
  Future<List<Articulo>> executeFuzzy(String codigoRaw) async {
    final String valorBusqueda = codigoRaw.trim();
    if (valorBusqueda.isEmpty) return [];

    // Extraer la parte antes de "/" o "%" si existe (es la referencia)
    String parteReferencia = valorBusqueda;
    if (valorBusqueda.contains('/')) {
      parteReferencia = valorBusqueda.split('/').first;
    } else if (valorBusqueda.contains('%')) {
      parteReferencia = valorBusqueda.split('%').first;
    }

    // Quedarse solo con dígitos numéricos
    final String soloDigitos = parteReferencia.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (soloDigitos.length < 3) return [];

    // Buscar con los primeros N dígitos (mínimo 3, máximo lo que tengamos)
    // Intentamos con longitudes decrecientes para maximizar resultados útiles
    final Set<String> codigosYaVistos = {};
    final List<Articulo> resultados = [];

    // Intento con los primeros 5 dígitos, luego 4, luego 3
    final List<String> prefijos = [];
    if (soloDigitos.length >= 5) prefijos.add(soloDigitos.substring(0, 5));
    if (soloDigitos.length >= 4) prefijos.add(soloDigitos.substring(0, 4));
    if (soloDigitos.length >= 3) prefijos.add(soloDigitos.substring(0, 3));

    for (final prefijo in prefijos) {
      final lista = await repository.buscarArticulosPorTexto(prefijo);
      for (final art in lista) {
        if (!codigosYaVistos.contains(art.codigo)) {
          codigosYaVistos.add(art.codigo);
          resultados.add(art);
        }
      }
      // Si ya tenemos resultados con el prefijo más largo, no seguimos
      if (resultados.isNotEmpty) break;
    }

    return resultados;
  }
}
