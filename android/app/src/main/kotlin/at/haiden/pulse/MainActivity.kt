package at.haiden.pulse

import android.app.LocaleManager
import android.os.Build
import android.os.LocaleList
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Health Connect's permission dialog needs a FragmentActivity on Android 14+.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The language Android keeps for this app, so the profile and the
        // system's settings show and change the same value.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "at.haiden.pulse/language")
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    // No language per app before Android 13; the app keeps its own.
                    if (call.method == "get") result.success(null) else result.notImplemented()
                    return@setMethodCallHandler
                }
                val manager = getSystemService(LocaleManager::class.java)
                when (call.method) {
                    "get" -> {
                        val locales = manager.applicationLocales
                        result.success(
                            mapOf("language" to if (locales.isEmpty) null else locales[0].language)
                        )
                    }
                    "set" -> {
                        val language = call.arguments as? String
                        manager.applicationLocales =
                            if (language == null) LocaleList.getEmptyLocaleList()
                            else LocaleList.forLanguageTags(language)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
