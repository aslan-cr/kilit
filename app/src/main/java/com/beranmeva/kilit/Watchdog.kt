package com.beranmeva.kilit

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Nöbetçi: sistem koruma servisini kapatırsa (pil tasarrufu vb.) dakikada bir alarm çalar
 * ve servisi yeniden başlatır.
 */
object Watchdog {
    fun arm(ctx: Context) {
        try {
            val am = ctx.getSystemService(AlarmManager::class.java)
            val pi = PendingIntent.getBroadcast(
                ctx,
                7,
                Intent(ctx, WatchdogReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 60_000L,
                pi
            )
        } catch (_: Exception) {
        }
    }
}

class WatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            ContextCompat.startForegroundService(
                context, Intent(context, GuardService::class.java)
            )
        } catch (_: Exception) {
        }
        Watchdog.arm(context)
    }
}
