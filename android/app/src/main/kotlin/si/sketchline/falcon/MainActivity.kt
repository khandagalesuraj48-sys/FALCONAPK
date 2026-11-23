package si.sketchline.falcon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // (23-11-2026) the update in the background – Android's Download Manager (UpdateKit.kt; lib/core/update.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "falcon/update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> result.success(UpdateKit.start(this, call.argument<String>("url") ?: "", call.argument<String>("file") ?: "falcon.apk",
                        call.argument<String>("version") ?: "", call.argument<Int>("build") ?: 0, call.argument<String>("sha") ?: ""))
                    "state" -> result.success(UpdateKit.state(this))
                    "install" -> result.success(UpdateKit.install(this, call.argument<String>("path") ?: ""))
                    "forget" -> { UpdateKit.forget(this); result.success(true) }
                    "clearNote" -> { UpdateKit.clearNote(this); result.success(true) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("update", e.message ?: e.toString(), null)
            }
        }
    }
}
