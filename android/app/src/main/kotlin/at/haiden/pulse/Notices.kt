package at.haiden.pulse

import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * What every notice of Pulse shares: the pulse line as its small icon and
 * the accent of the app, so they all look alike in the shade.
 */
object Notices {
    fun base(context: Context, channel: String): NotificationCompat.Builder =
        NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_stat_pulse)
            .setColor(ContextCompat.getColor(context, R.color.notice_accent))

    /** A title and one sentence that may run over more than one line. */
    fun text(builder: NotificationCompat.Builder, title: String, body: String): NotificationCompat.Builder =
        builder
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
}
