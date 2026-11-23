import 'package:flutter_test/flutter_test.dart';
import 'package:scanpalphone_app/core/services/catalog_version_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('refreshes catalog when installed app version has changed', () async {
    SharedPreferences.setMockInitialValues({'catalogVersionKey': '1.0.0+1'});
    final preferences = await SharedPreferences.getInstance();
    final service = CatalogVersionService(
      preferences: preferences,
      getCurrentVersion: () async => '1.0.1+2',
    );
    var refreshCount = 0;

    final refreshed = await service.refreshIfVersionChanged(() async {
      refreshCount++;
    });

    expect(refreshed, isTrue);
    expect(refreshCount, 1);
    expect(preferences.getString('catalogVersionKey'), '1.0.1+2');
  });

  test(
    'does not refresh catalog when installed app version is unchanged',
    () async {
      SharedPreferences.setMockInitialValues({'catalogVersionKey': '1.0.1+2'});
      final preferences = await SharedPreferences.getInstance();
      final service = CatalogVersionService(
        preferences: preferences,
        getCurrentVersion: () async => '1.0.1+2',
      );
      var refreshCount = 0;

      final refreshed = await service.refreshIfVersionChanged(() async {
        refreshCount++;
      });

      expect(refreshed, isFalse);
      expect(refreshCount, 0);
    },
  );

  test('does not record version when catalog refresh fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = CatalogVersionService(
      preferences: preferences,
      getCurrentVersion: () async => '1.0.1+2',
    );

    await expectLater(
      service.refreshIfVersionChanged(() async {
        throw StateError('Catalog download failed');
      }),
      throwsA(isA<StateError>()),
    );

    expect(preferences.getString('catalogVersionKey'), isNull);
  });
}
