package at.haiden.pulse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * The rest between two sets as an ongoing notification with a countdown, so
 * its end can be seen with the app in the background. It goes away by itself
 * when the rest is over, and is left alone when the app is opened again.
 */
object TrainingNotice {
    const val TAG = "rest"
    private const val CHANNEL = "training"
    private const val ID = 7
    private const val REQUEST = 7

    fun rest(context: Context, end: Long, title: String) {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        val left = end - System.currentTimeMillis()
        if (left <= 0) {
            clear(context)
            return
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, title.ifEmpty { "Training" }, NotificationManager.IMPORTANCE_LOW)
        )
        val open = PendingIntent.getActivity(
            context,
            REQUEST,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(title)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(end)
            .setShowWhen(true)
            .setTimeoutAfter(left)
            .setContentIntent(open)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
        manager.notify(TAG, ID, LiveNotice.apply(builder, null).build())
    }

    fun clear(context: Context) {
        NotificationManagerCompat.from(context).cancel(TAG, ID)
    }
}
