import 'package:scanpalphone_app/core/constants.dart';
import 'package:scanpalphone_app/domain/entities/lectura.dart';
import 'package:scanpalphone_app/domain/entities/tipo_operacion.dart';
import 'package:scanpalphone_app/domain/repositories/lectura_repository.dart';
import 'package:scanpalphone_app/domain/usecases/enviar_lecturas_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks each acknowledged batch before sending the next one', () async {
    final repository = _FakeLecturaRepository(
      List.generate(
        AppConstants.batchSize + 1,
        (index) => Lectura(
          id: index + 1,
          codigoArticulo: 'ART-${index + 1}',
          referenciaArticulo: 'REF-${index + 1}',
          cantidad: 1,
          fechaRegistro: DateTime(2020),
        ),
      ),
    )..failOnSecondSend = true;
    final useCase = EnviarLecturasUseCase(repository);

    await expectLater(
      useCase.execute(TipoOperacion.inventario),
      throwsA(isA<StateError>()),
    );

    expect(repository.enviadas.map((batch) => batch.length), [500, 1]);
    expect(repository.sincronizadas.map((batch) => batch.length), [500]);
    expect(repository.pendientes, hasLength(1));
    expect(repository.enviadas.first.first.fechaEnvio, isNotNull);
    expect(
      repository.enviadas.first.first.fechaEnvio,
      isNot(repository.enviadas.first.first.fechaRegistro),
    );

    repository.failOnSecondSend = false;
    final totalReenviado = await useCase.execute(TipoOperacion.inventario);

    expect(totalReenviado, 1);
    expect(repository.enviadas.last, hasLength(1));
    expect(repository.sincronizadas.last, hasLength(1));
    expect(repository.pendientes, isEmpty);
  });
}

class _FakeLecturaRepository implements LecturaRepository {
  _FakeLecturaRepository(this.pendientes);

  final List<Lectura> pendientes;
  final List<List<Lectura>> enviadas = [];
  final List<List<Lectura>> sincronizadas = [];
  bool failOnSecondSend = false;

  @override
  Future<void> enviarLecturas(List<Lectura> lecturas) async {
    enviadas.add(lecturas);
    if (failOnSecondSend && enviadas.length == 2) {
      throw StateError('Simulated interruption');
    }
  }

  @override
  Future<List<Lectura>> obtenerLecturasPendientes(TipoOperacion tipo) async =>
      pendientes.where((lectura) => lectura.tipoOperacion == tipo).toList();

  @override
  Future<void> marcarLecturasComoSincronizadas(List<Lectura> lecturas) async {
    sincronizadas.add(lecturas);
    final ids = lecturas.map((lectura) => lectura.id).toSet();
    pendientes.removeWhere((lectura) => ids.contains(lectura.id));
  }

  @override
  Future<void> registrarLectura(Lectura lectura) async {}

  @override
  Future<List<Lectura>> obtenerLecturasPorFecha(DateTime fecha) async => [];

  @override
  Future<void> borrarLecturas() async {}

  @override
  Future<void> marcarLecturaComoSincronizada(
    String codigoArticulo,
    DateTime fechaRegistro,
  ) async {}

  @override
  Future<void> actualizarLectura(Lectura lectura) async {}

  @override
  Future<void> borrarLecturaPorId(int id) async {}
}
