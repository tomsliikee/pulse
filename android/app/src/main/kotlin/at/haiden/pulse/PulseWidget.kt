package at.haiden.pulse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.io.File
import org.json.JSONObject

/**
 * The widget on the home screen: up to three of the day's numbers against
 * their goals. It draws what the app left in widget.json and reads nothing
 * itself, so it needs no access of its own.
 */
class PulseWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        draw(context, manager, ids)
    }

    companion object {
        private val LABELS = intArrayOf(R.id.label0, R.id.label1, R.id.label2)
        private val BARS = intArrayOf(R.id.bar0, R.id.bar1, R.id.bar2)

        /** Draws every widget of the app anew by what the app left. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PulseWidget::class.java))
            if (ids.isNotEmpty()) draw(context, manager, ids)
        }

        private fun read(context: Context): JSONObject? {
            val file = File(context.filesDir, "widget.json")
            if (!file.exists()) return null
            return try {
                JSONObject(file.readText())
            } catch (error: Exception) {
                Log.w("Pulse", "Could not read the widget's data", error)
                null
            }
        }

        // Whole numbers where the value is one, else one decimal.
        private fun number(value: Double): String =
            if (value >= 100 || value == Math.floor(value)) String.format("%,.0f", value)
            else String.format("%.1f", value)

        private fun draw(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val rows = read(context)?.optJSONArray("rows")
            val views = RemoteViews(context.packageName, R.layout.widget)
            for (index in LABELS.indices) {
                val row = rows?.optJSONObject(index)
                if (row == null) {
                    views.setViewVisibility(LABELS[index], View.GONE)
                    views.setViewVisibility(BARS[index], View.GONE)
                    continue
                }
                val value = row.optDouble("value")
                val goal = row.optDouble("goal")
                val unit = row.optString("unit").let { if (it.isEmpty()) "" else " $it" }
                views.setViewVisibility(LABELS[index], View.VISIBLE)
                views.setViewVisibility(BARS[index], View.VISIBLE)
                views.setTextViewText(
                    LABELS[index],
                    "${row.optString("label")}  ${number(value)} / ${number(goal)}$unit",
                )
                views.setProgressBar(
                    BARS[index],
                    100,
                    if (goal > 0) (value / goal * 100).coerceIn(0.0, 100.0).toInt() else 0,
                    false,
                )
            }
            val open = PendingIntent.getActivity(
                context,
                5,
                context.packageManager.getLaunchIntentForPackage(context.packageName),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            manager.updateAppWidget(ids, views)
        }
    }
}
