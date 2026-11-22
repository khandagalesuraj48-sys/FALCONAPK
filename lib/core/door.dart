// The first screen's code, kept on this phone (his decision of 23-11-2026: the company code first – the app then knows where the
// person comes from; a mess contractor has his own code). Only the code and the names the server gave are kept – the same as the web
// (src/lib/door.ts).
import 'dart:convert';

import '../config.dart';
import 'prefs.dart';

class Door {
  const Door({required this.kind, required this.code, required this.name, required this.company, required this.companyName});
  final String kind, code, name, company, companyName; // kind: company | contractor
  bool get isContractor => kind == 'contractor';

  static Door? from(Object? j) {
    if (j is! Map) return null;
    final kind = '${j['kind'] ?? ''}', code = '${j['code'] ?? ''}';
    if (!(kind == 'company' || kind == 'contractor') || !RegExp(r'^[A-Z0-9]{2,12}$').hasMatch(code)) return null;
    return Door(kind: kind, code: code, name: '${j['name'] ?? ''}', company: '${j['company'] ?? ''}', companyName: '${j['company_name'] ?? ''}');
  }

  Map<String, String> toJson() => {'kind': kind, 'code': code, 'name': name, 'company': company, 'company_name': companyName};

  static Door? get saved {
    try { return from(jsonDecode(Prefs.door ?? 'null')); } catch (_) { return null; }
  }
  static set saved(Door? d) => Prefs.door = d == null ? null : jsonEncode(d.toJson());

  /// FALCON's own company when no code was typed (a sign-in of before); never shown.
  static String get theCompany => saved?.company ?? Config.company;
  /// What the server is told: the code typed (a company's, or a contractor's – the server finds its company).
  static String? get theCode => saved?.code;
}
