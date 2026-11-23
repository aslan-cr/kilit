package com.skynav.skynav

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder

/**
 * Uyku mikseri çalarken ön plan servisi (medya oynatma): ekran kapanınca ya da uygulama arka plandayken
 * Android'in (özellikle Samsung'un) uygulamayı kapatıp sesi kesmesini önler. Ses Dart tarafında çalar;
 * bu servis yalnızca süreci ayakta tutar ve "Durdur" düğmeli bildirimi gösterir.
 */
class MixerService : Service() {
    companion object {
        private const val CHANNEL = "skynav_mixer"
        private const val ID = 4207
        private const val ACTION_STOP = "com.skynav.skynav.MIXER_STOP"
        var onStop: (() -> Unit)? = null

        fun start(ctx: Context, title: String, text: String) {
            val i = Intent(ctx, MixerService::class.java).putExtra("title", title).putExtra("text", text)
            ctx.startForegroundService(i)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, MixerService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            onStop?.invoke()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            val ch = NotificationChannel(CHANNEL, "Uyku mikseri", NotificationManager.IMPORTANCE_LOW)
            ch.setShowBadge(false)
            nm.createNotificationChannel(ch)
        }
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stopPi = PendingIntent.getService(
            this, 1,
            Intent(this, MixerService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stopAction = Notification.Action.Builder(
            Icon.createWithResource(this, android.R.drawable.ic_media_pause), "Durdur", stopPi,
        ).build()
        val n = Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(intent?.getStringExtra("title") ?: "Uyku mikseri")
            .setContentText(intent?.getStringExtra("text") ?: "Gerçek doğa kayıtları çalıyor")
            .setContentIntent(open)
            .setOngoing(true)
            .setShowWhen(false)
            .addAction(stopAction)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(ID, n)
        }
        return START_NOT_STICKY
    }
}
