package org.localsend.localsend_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * MG4: starts LocalSend when the head unit boots, so the device is discoverable
 * and ready to receive files without anyone opening the app.
 *
 * Starting an activity from the background is restricted on Android 10+.
 * If the head unit refuses it, grant "display over other apps" once, e.g.:
 *   adb shell appops set org.localsend.localsend_app.mg4 SYSTEM_ALERT_WINDOW allow
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED && action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        try {
            val launchIntent = MainActivity.createDefaultIntent(context).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(launchIntent)
        } catch (e: Exception) {
            Log.e("LocalSendBootReceiver", "Could not start LocalSend at boot", e)
        }
    }
}
