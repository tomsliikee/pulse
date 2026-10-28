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
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import org.json.JSONObject

/**
 * The alarms that remind of supplements still open at their time of day. The
 * app leaves the times, the supplements and the words; whether one is still
 * open is read here, when the alarm goes off, from what the app has noted.
 */
object SupplementAlarm {
    private const val MINUTES_PER_DAY = 24 * 60
    private const val CHANNEL = "supplements"
    private const val ID = 3
    private const val REQUEST = 3

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
        Intent(context, SupplementAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** The minutes of the day the app left a reminder for, in order. */
    private fun minutes(alarm: JSONObject?): List<Int> {
        val slots = alarm?.optJSONArray("slots") ?: return emptyList()
        return (0 until slots.length())
            .mapNotNull { slots.optJSONObject(it)?.optInt("minute", -1) }
            .filter { it in 0 until MINUTES_PER_DAY }
            .sorted()
    }

    /**
     * Sets the alarm for the next minute the app left, or removes it where the
     * app left none. With [afterNow] not for the minute that is just passing.
     */
    fun schedule(context: Context, afterNow: Boolean = false) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val minutes = minutes(document(context, "supplementAlarm"))
        if (minutes.isEmpty()) {
            alarms.cancel(intent(context))
            return
        }
        val now = LocalDateTime.now()
        // A minute later than the one that rang, so it does not ring twice.
        val from = if (afterNow) now.plusMinutes(1) else now
        val today = LocalDate.now()
        val at = minutes.map { today.atTime(it / 60, it % 60) }.firstOrNull { it.isAfter(from) }
            ?: today.plusDays(1).atTime(minutes.first() / 60, minutes.first() % 60)
        // Inexact, which needs no consent, but let through while the phone dozes.
        alarms.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
            intent(context),
        )
    }

    /** The keys of the supplements the app has noted as taken today. */
    private fun takenToday(context: Context): Set<String> {
        val intakes = document(context, "supplements")?.optJSONArray("intakes") ?: return emptySet()
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val taken = mutableSetOf<String>()
        for (index in 0 until intakes.length()) {
            val intake = intakes.optJSONObject(index) ?: continue
            val day = Instant.ofEpochMilli(intake.optLong("at")).atZone(zone).toLocalDate()
            if (day == today) taken.add(intake.optString("key"))
        }
        return taken
    }

    /**
     * The alarm went off: names what is still open of the time of day that has
     * just come, once, and sets the alarm for the next time.
     */
    fun ring(context: Context) {
        try {
            val alarm = document(context, "supplementAlarm")
            val slots = alarm?.optJSONArray("slots")
            val now = LocalDateTime.now()
            val minute = now.hour * 60 + now.minute
            // The latest time of day that has come; the alarm may be late.
            val due = (0 until (slots?.length() ?: 0))
                .mapNotNull { slots?.optJSONObject(it) }
                .filter { it.optInt("minute", -1) in 0..minute }
                .maxByOrNull { it.optInt("minute") }
            val today = LocalDate.now().toEpochDay()
            val said = document(context, "supplementNotice")
            val already = said?.optLong("day", -1) == today &&
                said.optInt("minute", -1) == due?.optInt("minute")
            if (alarm != null && due != null && !already) {
                val taken = takenToday(context)
                val items = due.optJSONArray("items")
                val open = (0 until (items?.length() ?: 0))
                    .mapNotNull { items?.optJSONObject(it) }
                    .filter { it.optString("key") !in taken }
                    .map { it.optString("name") }
                if (open.isNotEmpty()) {
                    show(
                        context,
                        alarm.getString("title"),
                        alarm.getString("body").replace("%s", open.joinToString(", ")),
                        total = items?.length() ?: 0,
                        done = (items?.length() ?: 0) - open.size,
                    )
                }
                File(context.filesDir, "supplementNotice.json").writeText(
                    JSONObject().put("day", today).put("minute", due.optInt("minute")).toString()
                )
            }
        } catch (error: Exception) {
            // SecurityException included: the consent can go at any moment.
            Log.w("Pulse", "The supplements' alarm failed", error)
        }
        schedule(context, afterNow = true)
    }

    private fun show(context: Context, title: String, body: String, total: Int, done: Int) {
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
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
        if (LiveNotice.on(context, "liveSupplements")) {
            // How many of the time of day are taken, as a bar and in the chip.
            LiveNotice.apply(builder.setProgress(total, done, false), "$done/$total")
        }
        manager.notify(ID, builder.build())
    }
}

/** Receives the alarm itself. */
class SupplementAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = SupplementAlarm.ring(context)
}
