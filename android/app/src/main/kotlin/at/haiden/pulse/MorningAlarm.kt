package at.haiden.pulse

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import org.json.JSONObject

/**
 * The alarm that says good morning at the time the user usually gets up. The
 * refresh in the background cannot be relied on for it: the system lets a
 * seldom opened app run for a few minutes a day.
 */
object MorningAlarm {
    private const val MINUTES_PER_DAY = 24 * 60

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
        0,
        Intent(context, MorningAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /**
     * Sets the alarm for the next time the minute the app left comes round, or
     * removes it where the app left none. With [afterToday] not before tomorrow.
     */
    fun schedule(context: Context, afterToday: Boolean = false) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val minute = document(context, "morningAlarm")?.optInt("minute", -1) ?: -1
        if (minute !in 0 until MINUTES_PER_DAY) {
            alarms.cancel(intent(context))
            return
        }
        var at = LocalDate.now().atTime(minute / 60, minute % 60)
        if (afterToday || !at.isAfter(LocalDateTime.now())) at = at.plusDays(1)
        // Inexact, which needs no consent, but let through while the phone
        // dozes: in the morning it has usually lain still all night.
        alarms.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
            intent(context),
        )
    }

    /**
     * The alarm went off: greets unless the day was greeted or the cards were
     * seen already, and sets the alarm for tomorrow, so the mornings go on
     * while the app stays closed.
     */
    fun ring(context: Context) {
        try {
            // The app numbers its days like this: days since 1970 by the calendar.
            val today = LocalDate.now().toEpochDay()
            val alarm = document(context, "morningAlarm")
            val settings = document(context, "settings")
            val said = document(context, "morning")?.optLong("notified", -1) == today
            val seen = settings?.optLong("morningSeen", -1) == today
            val on = settings?.optBoolean("morningBrief", true) ?: true
            if (alarm != null && on && !said && !seen) {
                MorningNotice.show(context, alarm.getString("title"), alarm.getString("body"))
                File(context.filesDir, "morning.json")
                    .writeText(JSONObject().put("notified", today).toString())
            }
        } catch (error: Exception) {
            Log.w("Pulse", "The morning's alarm failed", error)
        }
        schedule(context, afterToday = true)
    }
}

/** Receives the alarm itself. */
class MorningAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = MorningAlarm.ring(context)
}

/** Alarms are lost with a restart and with an update of the app. */
class MorningAlarmRestorer : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                MorningAlarm.schedule(context)
        }
    }
}
