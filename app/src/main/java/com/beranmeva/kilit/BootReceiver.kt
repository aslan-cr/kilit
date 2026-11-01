package com.beranmeva.kilit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Tablet yeniden başlayınca (veya uygulama güncellenince) kilit servisini tekrar başlatır. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            try {
                ContextCompat.startForegroundService(
                    context, Intent(context, GuardService::class.java)
                )
            } catch (_: Exception) {
            }
            Watchdog.arm(context)
        }
    }
}
