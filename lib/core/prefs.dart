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

  /// (23-11-2026, picture N8) opened from HR: what HR said for today – {day, in, banner} (JSON) – kept until the next day
  static String? get hr => _p?.getString('falcon.hr');
  static set hr(String? v) {
    if (v == null) {
      unawaited(_p?.remove('falcon.hr'));
    } else {
      unawaited(_p?.setString('falcon.hr', v));
    }
  }
}
