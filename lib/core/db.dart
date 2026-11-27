// Every read and every action goes through here: the database's own rules decide (Rec Level Security and its checked
// functions); its message, written for people, is what the person sees. The same as the web's src/lib/db.ts.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'net.dart' show netHttp;
import '../ui/kit.dart';

typedef Rec = Map<String, dynamic>;

SupabaseClient get sb => Supabase.instance.client;

class DbError implements Exception {
  DbError(this.message, [this.code = 'db']);
  final String message;
  final String code;
  @override
  String toString() => message;
}

const offlineText = 'No network – nothing was sent. Try again when you are online.';

/// Any error as the words a person reads.
String words(Object e) {
  if (e is DbError) return e.message;
  if (e is PostgrestException) return e.code == '42501' && !e.message.contains(' ') ? 'This is not open to you.' : e.message;
  if (e is AuthException) return e.message;
  if (e is StorageException) return 'The file could not be sent – try again.';
  if (e is SocketException || e is TimeoutException || e is http.ClientException) return offlineText;
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('Connection')) return offlineText;
  return s.replaceFirst('Exception: ', '');
}

/// Rows of a query (a list of maps).
Future<List<Rec>> rows(Future<dynamic> q) async {
  final r = await q;
  if (r is List) return r.map((x) => Map<String, dynamic>.from(x as Map)).toList();
  return const [];
}

Future<Rec?> one(Future<dynamic> q) async {
  final r = await rows(q);
  return r.isEmpty ? null : r.first;
}

/// A database function (checked, security definer) – its own message on refusal.
Future<T?> call<T>(String fn, [Map<String, dynamic> args = const {}]) async {
  final r = await sb.rpc(fn, params: args);
  return r as T?;
}

/// FALCON's own server steps (/api/…), with the person's token when he is signed in.
Future<Rec> api(String path, Map<String, dynamic> payload, {bool withToken = true}) async {
  final headers = {'Content-Type': 'application/json'};
  final s = Supabase.instance.client.auth.currentSession;
  if (withToken && s != null) headers['Authorization'] = 'Bearer ${s.accessToken}';
  final http.Response r;
  try {
    r = await netHttp.post(Uri.parse('${Config.server}$path'), headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 25)); // (SNI) measured
  } on TimeoutException {
    throw DbError('The server did not answer – try again.', 'timeout');
  } on SocketException {
    throw DbError(offlineText, 'offline');
  }
  Object? j;
  try {
    j = jsonDecode(r.body);
  } catch (_) {
    j = null;
  }
  final m = j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
  if (r.statusCode >= 400 || m['ok'] == false) {
    throw DbError((m['error'] is String ? m['error'] as String : null) ?? 'The server could not do it – try again.', '${m['code'] ?? r.statusCode}');
  }
  return m;
}

/// Load something and show it: loading → the screen, or the error in words with "Try again". It loads again when reload() is
/// called, and quietly when one of the watched tables changes (Supabase Realtime – only the rows the person may read).
class Load<T> extends StatefulWidget {
  const Load({super.key, required this.load, required this.builder, this.watch = const [], this.loading, this.first});
  final Future<T> Function() load;
  /// (25-11-2026) what to show at once (read a moment ago) – then it is read again quietly
  final T? first;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;
  final List<String> watch;
  final Widget? loading;
  @override
  State<Load<T>> createState() => _LoadState<T>();
}

class _LoadState<T> extends State<Load<T>> {
  T? _data;
  bool _has = false;
  String? _error;
  bool _busy = true;
  RealtimeChannel? _ch;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    final f = widget.first;
    if (f != null) {
      _data = f;
      _has = true;
      _busy = false;
    }
    _run(quiet: f != null);
    if (widget.watch.isNotEmpty) {
      var ch = sb.channel('watch-${widget.watch.join('-')}-${identityHashCode(this)}');
      for (final t in widget.watch) {
        ch = ch.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: t, callback: (_) => _soon());
      }
      _ch = ch.subscribe();
    }
  }

  // (23-11-2026, "falcon khup slow") many changes at once (a batch confirmed, the van's points) load the screen ONCE, not once each
  Timer? _wait;
  void _soon() {
    _wait ??= Timer(const Duration(milliseconds: 700), () {
      _wait = null;
      if (mounted) _run(quiet: true);
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    final ch = _ch;
    if (ch != null) unawaited(sb.removeChannel(ch));
    super.dispose();
  }

  Future<void> _run({bool quiet = false}) async {
    final g = ++_gen;
    if (!quiet && mounted) setState(() { _busy = true; _error = null; });
    try {
      final d = await widget.load();
      if (!mounted || g != _gen) return;
      setState(() { _data = d; _has = true; _busy = false; _error = null; });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() { _error = words(e); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_has) {
      final body = widget.builder(context, _data as T, _run);
      if (_error == null) return body;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min,
          children: [Failed(_error!, retry: _run), const SizedBox(height: 10), body]);
    }
    if (_busy) return widget.loading ?? const Loading();
    return Failed(_error ?? 'Could not load.', retry: _run);
  }
}

/// A button's work: busy while it runs, its error in words.
mixin Act<W extends StatefulWidget> on State<W> {
  bool busy = false;
  String? error;
  Future<R?> act<R>(Future<R> Function() fn) async {
    if (busy) return null;
    setState(() { busy = true; error = null; });
    try {
      final r = await fn();
      if (mounted) setState(() => busy = false);
      return r;
    } catch (e) {
      if (mounted) setState(() { busy = false; error = words(e); });
      return null;
    }
  }
}
