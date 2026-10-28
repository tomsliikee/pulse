package at.haiden.pulse

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import org.json.JSONObject

/**
 * The alarm that says on Sunday evening that the week's report is ready. Like
 * the morning's it does not wait for a refresh in the background, which the
 * system grants a seldom opened app too rarely.
 */
object WeekAlarm {
    private const val CHANNEL = "week"
    private const val ID = 2

    // Not the morning's 0: the two alarms and their notifications are apart.
    private const val REQUEST = 1

    /** The hour of Sunday the report is ready, as the app's own rule has it. */
    private const val HOUR = 19

    /** Tells the app what the notification it was opened from was about. */
    const val OPEN = "open"
    const val OPEN_WEEK = "week"

    // Where the app keeps its documents, as in MorningNotice.
    private fun document(context: Context, name: String): JSONObject? {
        val file = File(context.filesDir, "$name.json")
        if (!file.exists()) return null
        return try {
            JSONObject(file.readText())
        } catch (error: Exception) {
            Log.w("Pulse", "Could not read $name", error)
            null
        }
    }

    private fun intent(context: Context) = PendingIntent.getBroadcast(
        context,
        REQUEST,
        Intent(context, WeekAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /**
     * Sets the alarm for the next Sunday evening, or removes it where the app
     * left none. With [afterToday] not before the Sunday after this one.
     */
    fun schedule(context: Context, afterToday: Boolean = false) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        if (document(context, "weekAlarm") == null) {
            alarms.cancel(intent(context))
            return
        }
        var at = LocalDate.now()
            .with(TemporalAdjusters.nextOrSame(DayOfWeek.SUNDAY))
            .atTime(HOUR, 0)
        if (afterToday || !at.isAfter(LocalDateTime.now())) at = at.plusWeeks(1)
        // Inexact, which needs no consent, but let through while the phone dozes.
        alarms.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
            intent(context),
        )
    }

    /**
     * The alarm went off: says that the report is ready unless this week's was
     * said already, and sets the alarm for the next Sunday.
     */
    fun ring(context: Context) {
        try {
            // The app numbers its days like this: days since 1970 by the calendar.
            val today = LocalDate.now()
            val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)).toEpochDay()
            val alarm = document(context, "weekAlarm")
            val on = document(context, "settings")?.optBoolean("weekReport", true) ?: true
            val said = document(context, "week")?.optLong("notified", -1) == monday
            if (alarm != null && on && !said) {
                // The score only as it stands today; an older one would be
                // short of the days since.
                val fresh = alarm.optLong("day", -1) == today.toEpochDay()
                show(
                    context,
                    alarm.getString("title"),
                    alarm.getString(if (fresh) "body" else "plain"),
                    if (fresh) alarm.optString("short").ifEmpty { null } else null,
                )
                File(context.filesDir, "week.json")
                    .writeText(JSONObject().put("notified", monday).toString())
            }
        } catch (error: Exception) {
            // SecurityException included: the consent can go at any moment.
            Log.w("Pulse", "The week's alarm failed", error)
        }
        schedule(context, afterToday = true)
    }

    /** Shows the notification. Without the consent to notifications it is dropped. */
    private fun show(context: Context, title: String, body: String, short: String?) {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            // Named by the notification's own title, in the app's language.
            NotificationChannel(CHANNEL, title, NotificationManager.IMPORTANCE_DEFAULT)
        )
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.putExtra(OPEN, OPEN_WEEK)
        val open = PendingIntent.getActivity(
            context,
            REQUEST,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
        if (LiveNotice.on(context, "liveWeek")) LiveNotice.apply(builder, short)
        manager.notify(ID, builder.build())
    }
}

/** Receives the alarm itself. */
class WeekAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = WeekAlarm.ring(context)
}
