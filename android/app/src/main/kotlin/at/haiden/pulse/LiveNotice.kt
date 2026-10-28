package at.haiden.pulse

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import org.json.JSONObject

/**
 * Makes a notification a live message when the user asked for it: ongoing, so
 * it stays on top until it is swiped away or the app is opened, and marked
 * for Android 16, which may show it as a chip in the status bar. Android
 * decides about the chip; without its consent the message is an ordinary
 * ongoing notification.
 */
object LiveNotice {
    // The names of the extras Notification.EXTRA_REQUEST_PROMOTED_ONGOING and
    // EXTRA_SHORT_CRITICAL_TEXT carry, set here so older builds link as well.
    private const val PROMOTED = "android.requestPromotedOngoing"
    private const val CRITICAL = "android.shortCriticalText"

    /** Whether the user turned the live message [key] on in the profile. */
    fun on(context: Context, key: String): Boolean {
        val file = File(context.filesDir, "settings.json")
        if (!file.exists()) return false
        return try {
            JSONObject(file.readText()).optBoolean(key, false)
        } catch (error: Exception) {
            Log.w("Pulse", "Could not read the settings", error)
            false
        }
    }

    /** Turns [builder] into a live message; [short] is for the chip. */
    fun apply(builder: NotificationCompat.Builder, short: String?): NotificationCompat.Builder {
        val extras = Bundle().apply {
            putBoolean(PROMOTED, true)
            if (short != null) putString(CRITICAL, short)
        }
        return builder.setOngoing(true).setOnlyAlertOnce(true).addExtras(extras)
    }

    /** Takes the live messages away; the app was opened. */
    fun cancel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        for (shown in manager.activeNotifications) {
            if (shown.notification.flags and Notification.FLAG_ONGOING_EVENT != 0) {
                manager.cancel(shown.tag, shown.id)
            }
        }
    }

    /** Whether Android lets the app highlight live messages. */
    fun promotable(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 36) return false
        return context.getSystemService(NotificationManager::class.java).canPostPromotedNotifications()
    }
}
