package com.beranmeva.kullanimtakip

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { context.startForegroundService(Intent(context, TrackService::class.java)) } catch (e: Exception) { }
    }
}
