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
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import org.json.JSONObject

/**
 * The alarm that says at nine in the evening how the day went. The user has
 * to switch it on, and the app leaves the words; like the other alarms it does
 * not wait for a refresh in the background.
 */
object DayAlarm {
    private const val CHANNEL = "day"
    private const val ID = 4

    // Apart from the other alarms' requests.
    private const val REQUEST = 4
    private const val HOUR = 21

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
        Intent(context, DayAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /**
     * Sets the alarm for the next nine in the evening, or removes it where the
     * app left none. With [afterToday] not before tomorrow.
     */
    fun schedule(context: Context, afterToday: Boolean = false) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        if (document(context, "dayAlarm") == null) {
            alarms.cancel(intent(context))
            return
        }
        var at = LocalDate.now().atTime(HOUR, 0)
        if (afterToday || !at.isAfter(LocalDateTime.now())) at = at.plusDays(1)
        // Inexact, which needs no consent, but let through while the phone dozes.
        alarms.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
            intent(context),
        )
    }

    /**
     * The alarm went off: says how the day went unless today was said already,
     * and sets the alarm for tomorrow.
     */
    fun ring(context: Context) {
        try {
            // The app numbers its days like this: days since 1970 by the calendar.
            val today = LocalDate.now().toEpochDay()
            val alarm = document(context, "dayAlarm")
            val on = document(context, "settings")?.optBoolean("dayNotice", false) ?: false
            val said = document(context, "dayNotice")?.optLong("notified", -1) == today
            if (alarm != null && on && !said) {
                // The score only as it stands today; an older one would be
                // short of the hours since.
                val fresh = alarm.optLong("day", -1) == today
                show(
                    context,
                    alarm.getString("title"),
                    alarm.getString(if (fresh) "body" else "plain"),
                    if (fresh) alarm.optString("short").ifEmpty { null } else null,
                )
                File(context.filesDir, "dayNotice.json")
                    .writeText(JSONObject().put("notified", today).toString())
            }
        } catch (error: Exception) {
            // SecurityException included: the consent can go at any moment.
            Log.w("Pulse", "The day's alarm failed", error)
        }
        schedule(context, afterToday = true)
    }

    /** Shows the notification. Without the consent to notifications it is dropped. */
    private fun show(context: Context, title: String, body: String, short: String?) {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, title, NotificationManager.IMPORTANCE_DEFAULT)
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
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
        if (LiveNotice.on(context, "liveDay")) LiveNotice.apply(builder, short)
        manager.notify(ID, builder.build())
    }
}

/** Receives the alarm itself. */
class DayAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = DayAlarm.ring(context)
}
