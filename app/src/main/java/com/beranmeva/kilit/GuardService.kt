package com.beranmeva.kilit

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat

/**
 * Arka planda çalışan, bildirimi HER ZAMAN görünen servis.
 * Her saniye bakar:
 *  - Ödev saatindeyse: kimin sırası olursa olsun kilit ekranını getirir.
 *    Ödev sırasında kullanıcının süresi akmaz (duraklatılır).
 *  - Aktif oturum yoksa ve ekran açık/kilidi açıksa şifre kilit ekranını getirir.
 */
class GuardService : Service() {

    companion object {
        private const val CH = "kilit_durum"
        private const val ID = 1
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var store: Store
    private var lastText = ""
    private var lastTick = System.currentTimeMillis()

    private val tick = object : Runnable {
        override fun run() {
            try {
                check()
            } catch (_: Exception) {
            }
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = Store(this)
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CH, "Kilit durumu", NotificationManager.IMPORTANCE_LOW)
        )
        val n = notif("Çalışıyor")
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ID, n)
        }
        handler.post(tick)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        super.onDestroy()
    }

    private fun check() {
        val now = System.currentTimeMillis()
        val hw = store.homeworkActive()

        // Ödev saatinde aktif kullanıcının süresi akmasın: bitişi geçen süre kadar ileri al.
        if (hw != null && store.current.isNotEmpty()) {
            store.sessionEnd += (now - lastTick).coerceIn(0L, 5000L)
        }
        lastTick = now

        store.refresh()

        val text = when {
            hw != null -> "ÖDEV ZAMANI — ${Store.hm(hw.end)} saatine kadar kilitli"
            store.isActive() ->
                "${Store.label(store.current)} kullanıyor — kalan ${Store.fmt(store.remainingMs())}"
            else -> "Kilit ekranı bekliyor — sıradaki: ${Store.label(store.next)}"
        }
        if (text != lastText) {
            lastText = text
            getSystemService(NotificationManager::class.java).notify(ID, notif(text))
        }

        // Ebeveyn şifresi henüz oluşturulmadıysa hiçbir şeyi kilitleme.
        if (!store.hasPassword(Store.PARENT)) return
        if (hw == null && store.isActive()) return
        if (store.parentGraceActive()) return
        if (LockActivity.visible || MainActivity.visible) return

        val pm = getSystemService(PowerManager::class.java)
        val km = getSystemService(KeyguardManager::class.java)
        if (!pm.isInteractive || km.isKeyguardLocked) return
        if (!Settings.canDrawOverlays(this)) return

        startActivity(
            Intent(this, LockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        )
    }

    private fun notif(text: String): Notification =
        NotificationCompat.Builder(this, CH)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Tablet kilidi")
            .setContentText(text)
            .setOngoing(true)
            .build()
}
