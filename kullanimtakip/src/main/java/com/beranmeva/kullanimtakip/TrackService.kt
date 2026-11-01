package com.beranmeva.kullanimtakip

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder

/** Her 5 dakikada bir kullanım verisini gönderir. */
class TrackService : Service() {

    private var thread: HandlerThread? = null
    private var handler: Handler? = null

    private val tick = object : Runnable {
        override fun run() {
            Collector.send(this@TrackService)
            handler?.postDelayed(this, 5 * 60_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(NotificationChannel("takip", "Kullanım kaydı", NotificationManager.IMPORTANCE_LOW))
        val pi = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(this, "takip")
            .setContentTitle("Kullanım kaydı çalışıyor")
            .setContentText("Uygulama kullanımı kod ile paylaşılıyor")
            .setSmallIcon(R.drawable.ic_stat)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(1, n)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (thread == null) {
            thread = HandlerThread("takip").also { it.start() }
            handler = Handler(thread!!.looper)
        }
        handler?.removeCallbacks(tick)
        handler?.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler?.removeCallbacks(tick)
        thread?.quitSafely()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
