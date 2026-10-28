package at.haiden.pulse

import android.Manifest
import android.app.LocaleManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.LocaleList
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Health Connect's permission dialog needs a FragmentActivity on Android 14+.
class MainActivity : FlutterFragmentActivity() {
    // One file dialog at a time; the answer goes to whoever opened it.
    private var pendingText: String? = null
    private var pending: MethodChannel.Result? = null

    private val createFile =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
            val text = pendingText
            pendingText = null
            answer(uri) { target ->
                contentResolver.openOutputStream(target, "wt")!!.use {
                    it.write(text!!.toByteArray())
                }
                true
            }
        }

    private val openFile =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            answer(uri) { source ->
                contentResolver.openInputStream(source)!!.use { it.readBytes().decodeToString() }
            }
        }

    // The answer to the question whether notifications may be shown.
    private var pendingConsent: MethodChannel.Result? = null

    private val askConsent =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            pendingConsent?.success(granted)
            pendingConsent = null
        }

    // The answer to the question whether a workout's route may be read.
    private var pendingRoute: MethodChannel.Result? = null

    private val askRoute =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { answer ->
            pendingRoute?.success(answer.resultCode == RESULT_OK)
            pendingRoute = null
        }

    // Live messages go when the app is in front.
    override fun onResume() {
        super.onResume()
        LiveNotice.cancel(this)
    }

    // A notification tapped while the app is open arrives here; kept so the
    // app can ask what it was about.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    /** Works on the chosen file off the main thread; no file is no answer but null. */
    private fun answer(uri: Uri?, work: (Uri) -> Any) {
        val result = pending ?: return
        pending = null
        if (uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val value = work(uri)
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread { result.error("file", error.message, null) }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The system's file dialogs, for keeping a backup outside the app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "at.haiden.pulse/files")
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("busy", "A file dialog is already open.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "save" -> {
                        pending = result
                        pendingText = call.argument<String>("text")
                        createFile.launch(call.argument<String>("name"))
                    }
                    "open" -> {
                        pending = result
                        // Some file apps hand JSON over as plain data.
                        openFile.launch(arrayOf("application/json", "application/octet-stream", "text/*"))
                    }
                    else -> result.notImplemented()
                }
            }
        // The morning's alarm, and the consent to its notification. Android asks from 13 on;
        // before that an app may notify unless the user switched it off.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "at.haiden.pulse/morning")
            .setMethodCallHandler { call, result ->
                if (call.method == "schedule") {
                    // The app left a new time or text for one of its alarms.
                    MorningAlarm.schedule(this)
                    WeekAlarm.schedule(this)
                    DayAlarm.schedule(this)
                    SupplementAlarm.schedule(this)
                    PulseWidget.refresh(this)
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method == "promotable") {
                    // Whether Android lets live messages be highlighted.
                    result.success(LiveNotice.promotable(this))
                    return@setMethodCallHandler
                }
                if (call.method == "promotionSettings") {
                    // Android 16 only; its page for live messages of this app.
                    if (Build.VERSION.SDK_INT >= 36) {
                        startActivity(
                            Intent("android.settings.MANAGE_APP_PROMOTED_NOTIFICATIONS")
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        )
                    }
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method == "opened") {
                    // What the notification the app was opened from was about,
                    // told once.
                    val what = intent?.getStringExtra(WeekAlarm.OPEN)
                    intent?.removeExtra(WeekAlarm.OPEN)
                    result.success(what)
                    return@setMethodCallHandler
                }
                if (call.method == "allowed") {
                    // Whether notifications may be shown, without asking.
                    result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                    return@setMethodCallHandler
                }
                if (call.method != "allow") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                if (enabled || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    pendingConsent != null
                ) {
                    result.success(enabled)
                } else {
                    pendingConsent = result
                    askConsent.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        // Health Connect's own question for the route of a workout another app
        // recorded, which also offers to allow every route. Part of Android
        // from 14 on.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "at.haiden.pulse/routes")
            .setMethodCallHandler { call, result ->
                val session = call.arguments as? String
                if (call.method != "request" || session == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                    pendingRoute != null
                ) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    pendingRoute = result
                    askRoute.launch(
                        Intent("android.health.connect.action.REQUEST_EXERCISE_ROUTE")
                            .putExtra("android.health.connect.extra.SESSION_ID", session)
                    )
                } catch (error: ActivityNotFoundException) {
                    pendingRoute = null
                    result.success(false)
                }
            }
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
