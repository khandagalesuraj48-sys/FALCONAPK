// FALCON – Food & Site Operations, by Sketchline Industries. The phone app: the app's own screens (the approved designs) on
// FALCON's own database and server – the same rules and the same steps as the web.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'config.dart';
import 'core/prefs.dart';
import 'core/session.dart';
import 'routes.dart';
import 'ui/look.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (Config.ready) {
    await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseKey);
  }
  await Prefs.init();
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
  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: MaterialApp.router(
        title: 'FALCON',
        debugShowCheckedModeBanner: false,
        theme: falconTheme(),
        routerConfig: router,
      ),
    );
  }
}
