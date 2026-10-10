package at.haiden.pulse

import android.app.Application
import android.content.Context
import dev.fluttercommunity.workmanager.TaskDebugInfo
import dev.fluttercommunity.workmanager.TaskResult
import dev.fluttercommunity.workmanager.WorkmanagerDebug
import dev.fluttercommunity.workmanager.pigeon.TaskStatus

class PulseApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // The refresh in the background runs in an engine of its own, which a
        // channel of the activity does not reach. It leaves what it has to say
        // in a file, and this is told when it has ended.
        WorkmanagerDebug.setCurrent(object : WorkmanagerDebug() {
            override fun onTaskStatusUpdate(
                context: Context,
                taskInfo: TaskDebugInfo,
                status: TaskStatus,
                result: TaskResult?,
            ) {
                if (status == TaskStatus.COMPLETED) {
                    MorningNotice.showPending(context)
                    MorningAlarm.schedule(context)
                }
            }
        })
    }
}
