// FALCON – Food & Site Operations, by Sketchline Industries. The phone app: the app's own screens (the approved designs) on
// FALCON's own database and server – the same rules and the same steps as the web.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'config.dart';
import 'core/clock.dart';
import 'core/prefs.dart';
import 'core/session.dart';
import 'core/update.dart';
import 'core/net.dart';
import 'routes.dart';
import 'ui/look.dart';
import 'ui/net.dart' show NetHost;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (Config.ready) {
    // (25-11-2026 – SNI) every request of Supabase is measured (core/net.dart) – the same requests as before, nothing added
    await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseKey, httpClient: supabaseHttp());
    startNet();
  }
  await Prefs.init();
  keepClock(); // (23-11-2026) the server's clock – the meal of now follows it, not the phone's
  final session = Session()..start();
  runApp(FalconApp(session: session));
}

class FalconApp extends StatefulWidget {
  const FalconApp({super.key, required this.session});
  final Session session;
  @override
  State<FalconApp> createState() => _FalconAppState();
}

class _FalconAppState extends State<FalconApp> {
  late final GoRouter router = buildRouter(widget.session);
  AppLifecycleListener? _life;
  @override
  void initState() {
    super.initState();
    // (23-11-2026) the update from inside the app (core/update.dart): offered at every opening; its download goes on in the
    // background; "Install?" over whatever screen is open
    updateContext = () => router.routerDelegate.navigatorKey.currentContext;
    _life = AppLifecycleListener(
      onResume: () {
        updateWatch(opened: true);
        updateBack(offerNewest);
      },
      onPause: updateAway,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateWatch(opened: true);
      offerNewest();
    });
  }

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: MaterialApp.router(
        title: 'FALCON',
        debugShowCheckedModeBanner: false,
        theme: falconTheme(),
        routerConfig: router,
        builder: (context, child) => NetHost(child: child ?? const SizedBox()), // (SNI) the monitor's rhythm while in front
      ),
    );
  }
}
