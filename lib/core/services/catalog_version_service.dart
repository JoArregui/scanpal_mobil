import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CatalogVersionService {
  static const _lastCatalogVersionKey = 'catalogVersionKey';

  final SharedPreferences _preferences;
  final Future<String> Function() _getCurrentVersion;

  CatalogVersionService({
    required SharedPreferences preferences,
    Future<String> Function()? getCurrentVersion,
  }) : _preferences = preferences,
       _getCurrentVersion = getCurrentVersion ?? _readCurrentVersion;

  Future<bool> refreshIfVersionChanged(
    Future<void> Function() refreshCatalog,
  ) async {
    final currentVersion = await _getCurrentVersion();
    final previousVersion = _preferences.getString(_lastCatalogVersionKey);
    if (previousVersion == currentVersion) return false;

    await refreshCatalog();
    final saved = await _preferences.setString(
      _lastCatalogVersionKey,
      currentVersion,
    );
    if (!saved) {
      throw StateError(
        'No se pudo guardar la versión del catálogo actualizado.',
      );
    }

    return true;
  }

  static Future<String> _readCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
