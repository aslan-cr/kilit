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
import java.time.LocalDateTime

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
    private var lastArm = 0L
    private lateinit var overlay: TimerOverlay
    private val fg = Foreground()
    private var paused = false
    private var homeCache: String? = null

    private fun homePkg(): String? {
        if (homeCache == null) {
            homeCache = try {
                packageManager.resolveActivity(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0
                )?.activityInfo?.packageName ?: ""
            } catch (_: Exception) {
                ""
            }
        }
        return homeCache
    }

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
        overlay = TimerOverlay(this, store)
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
        overlay.hide()
        super.onDestroy()
    }

    private fun check() {
        val now = System.currentTimeMillis()
        val hw = store.homeworkActive()

        val prevTick = lastTick
        val pm0 = getSystemService(PowerManager::class.java)
        val interactive = pm0.isInteractive
        val hasSession = store.current.isNotEmpty()

        // Ekran kapalıyken süre akmasın: kapalı kalınan süre oturuma geri eklenir.
        if (!interactive) {
            if (store.screenOffAt == 0L) store.screenOffAt = prevTick
        } else if (store.screenOffAt > 0L) {
            val off = store.screenOffAt
            if (hasSession && store.sessionEnd > off) store.sessionEnd += (now - off).coerceAtLeast(0L)
            store.screenOffAt = 0L
        }

        // Uygulamaların dışındayken (ana ekran, son uygulamalar, kilit/ebeveyn ekranı) süre akmasın.
        paused = hasSession && interactive && getSystemService(KeyguardManager::class.java).isKeyguardLocked
        if (hasSession && interactive && hw == null && !paused && Shortcuts.hasUsageAccess(this)) {
            fg.update(this)
            val cur = fg.current
            if (cur != null && (cur == homePkg() || cur == "com.android.systemui" || cur == packageName)) {
                paused = true
            }
        }

        // Ödev saatinde ya da uygulama dışındayken aktif kullanıcının süresi akmasın.
        if ((hw != null || paused) && hasSession && interactive) {
            store.sessionEnd += (now - prevTick).coerceIn(0L, 5000L)
        }
        lastTick = now

        store.refresh()

        // Servis çalıştığının işareti + nöbetçi alarmı yenile + ekrandaki sayacı güncelle.
        store.beat = now
        if (now - lastArm > 30_000L) {
            Watchdog.arm(this)
            lastArm = now
        }
        updateOverlay(hw)

        val text = when {
            hw != null -> "ÖDEV ZAMANI — ${Store.hm(hw.end)} saatine kadar kilitli"
            store.isActive() ->
                "${store.label(store.current)} kullanıyor — kalan ${Store.fmt(store.remainingMs())}" +
                    (if (paused) " (uygulama dışında, süre durdu)" else "")
            else -> "Kilit ekranı bekliyor — sıradaki: ${store.label(store.next)}"
        }
        if (text != lastText) {
            lastText = text
            getSystemService(NotificationManager::class.java).notify(ID, notif(text))
        }

        // Ebeveyn şifresi henüz oluşturulmadıysa hiçbir şeyi kilitleme.
        if (!store.hasPassword(Store.PARENT)) return
        // Çocuk tanımlanmadan (kurulum yarımsa) kilit devreye girmez.
        if (store.children().isEmpty()) return
        if (hw == null && store.isActive()) return
        if (store.parentGraceActive()) return
        if (LockActivity.visible || MainActivity.visible) return
        // Arama / WhatsApp açıkken kilit araya girmez (güvenlik kısayolu).
        if (Shortcuts.skipLock(this, store, fg)) return

        val pm = getSystemService(PowerManager::class.java)
        val km = getSystemService(KeyguardManager::class.java)
        if (!pm.isInteractive || km.isKeyguardLocked) return
        if (!Settings.canDrawOverlays(this)) return

        startActivity(
            Intent(this, LockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        )
    }

    /** Yuvarlak sayaç: ödevde turuncu geri sayım, girişliyken kalan süre, değilse "SIRA". */
    private fun updateOverlay(hw: Store.Hw?) {
        if (MainActivity.visible || !Settings.canDrawOverlays(this)) {
            overlay.hide()
            return
        }
        val main: String
        val sub: String
        val prog: Float
        val color: Int
        if (hw != null) {
            val n = LocalDateTime.now()
            val left = (hw.end - (n.hour * 60 + n.minute)).coerceAtLeast(0)
            val total = (hw.end - hw.start).coerceAtLeast(1)
            main = "$left dk"
            sub = "ÖDEV"
            prog = left / total.toFloat()
            color = Store.HW_COLOR
        } else if (store.isActive()) {
            val rem = store.remainingMs()
            main = if (rem >= 60_000L) "${(rem + 59_999L) / 60_000L} dk" else "${rem / 1000L} sn"
            sub = store.label(store.current).take(7)
            val total = maxOf(store.sessionTotal, rem)
            prog = if (total > 0L) rem.toFloat() / total.toFloat() else 0f
            color = Store.COLORS[store.colorIndex(store.current)]
        } else {
            main = "SIRA"
            sub = store.label(store.next).take(7)
            prog = 0f
            color = Store.IDLE_COLOR
        }
        try {
            overlay.update(main, sub, prog.coerceIn(0f, 1f), color)
        } catch (_: Exception) {
            overlay.hide()
        }
    }

    private fun notif(text: String): Notification =
        NotificationCompat.Builder(this, CH)
            .setSmallIcon(R.drawable.ic_stat_lock)
            .setContentTitle("Tablet kilidi")
            .setContentText(text)
            .setOngoing(true)
            .build()
}
