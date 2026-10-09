package at.haiden.pulse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File
import org.json.JSONObject

/** The notification that says good morning. */
object MorningNotice {
    private const val CHANNEL = "morning"
    private const val ID = 1

    // Where the app keeps its documents: path_provider's application support
    // directory is the files directory on Android.
    private fun pending(context: Context) = File(context.filesDir, "morningNotice.json")

    /**
     * Shows what the refresh in the background left to be said, and removes it,
     * so it is said once. Without the consent to notifications it is dropped.
     */
    fun showPending(context: Context) {
        val file = pending(context)
        if (!file.exists()) return
        try {
            val notice = JSONObject(file.readText())
            file.delete()
            val manager = NotificationManagerCompat.from(context)
            if (!manager.areNotificationsEnabled()) return
            val title = notice.getString("title")
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                // Named by the greeting itself, in the app's language.
                NotificationChannel(
                    CHANNEL,
                    title.substringBefore(","),
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                context.packageManager.getLaunchIntentForPackage(context.packageName),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            manager.notify(
                ID,
                NotificationCompat.Builder(context, CHANNEL)
                    .setSmallIcon(R.drawable.ic_launcher_monochrome)
                    .setContentTitle(title)
                    .setContentText(notice.getString("body"))
                    .setContentIntent(open)
                    .setAutoCancel(true)
                    // Gone by itself when the morning is over.
                    .setTimeoutAfter(3 * 60 * 60 * 1000L)
                    .build(),
            )
        } catch (error: Exception) {
            // SecurityException included: the consent can go at any moment.
            Log.w("Pulse", "The morning's notification failed", error)
            file.delete()
        }
    }
}
