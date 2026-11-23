import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  test('Spanish date locale formats without uninitialized locale data', () async {
    await initializeDateFormatting('es_ES');

    expect(DateFormat('MMMM', 'es_ES').format(DateTime(2026, 1, 1)), 'enero');
  });
}
