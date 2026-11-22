// What this phone remembers (not secret): the mess picked (a QR scanned, or chosen); the first screen's code (23-11-2026).
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static SharedPreferences? _p;
  static Future<void> init() async => _p ??= await SharedPreferences.getInstance();
  static String? get mess => _p?.getString('falcon.mess');
  static set mess(String? v) {
    if (v == null) {
      unawaited(_p?.remove('falcon.mess'));
    } else {
      unawaited(_p?.setString('falcon.mess', v));
    }
  }
  static String? get door => _p?.getString('falcon.door');
  static set door(String? v) {
    if (v == null) {
      unawaited(_p?.remove('falcon.door'));
    } else {
      unawaited(_p?.setString('falcon.door', v));
    }
  }
}
