import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

const String _kUserCode = 'userCodeKey';

abstract class AuthLocalDataSource {
  Future<void> saveUserCode(int userCode);

  Future<int?> getUserCode();

  Future<void> clearUserCode();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> saveUserCode(int userCode) async {
    await sharedPreferences.setInt(_kUserCode, userCode);
  }

  @override
  Future<int?> getUserCode() async {
    return sharedPreferences.getInt(_kUserCode);
  }

  @override
  Future<void> clearUserCode() async {
    await sharedPreferences.remove(_kUserCode);
  }
}
