package com.beranmeva.kilit

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.telecom.TelecomManager
import android.widget.Toast

/**
 * Güvenlik kısayolları: Arama ve WhatsApp kilit ekranından şifresiz açılır.
 * Kilit, ön plandaki uygulama bunlardan biriyse devreye girmez; başka uygulamaya geçilirse hemen girer.
 */
object Shortcuts {

    private val WHATSAPP = listOf("com.whatsapp", "com.whatsapp.w4b")
    private val CALL_KNOWN = setOf(
        "com.android.incallui", "com.samsung.android.incallui", "com.google.android.dialer",
        "com.android.dialer", "com.samsung.android.dialer", "com.android.server.telecom"
    )

    @Suppress("DEPRECATION")
    fun hasUsageAccess(ctx: Context): Boolean = try {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        ops.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), ctx.packageName
        ) == AppOpsManager.MODE_ALLOWED
    } catch (_: Exception) {
        false
    }

    private fun dialIntent() = Intent(Intent.ACTION_DIAL, Uri.parse("tel:"))

    /** Şifresiz girilebilen paketler. */
    fun allowed(ctx: Context): Set<String> {
        val s = HashSet<String>(CALL_KNOWN)
        s.addAll(WHATSAPP)
        try {
            ctx.getSystemService(TelecomManager::class.java)?.defaultDialerPackage?.let { s.add(it) }
        } catch (_: Exception) {
        }
        try {
            ctx.packageManager.resolveActivity(dialIntent(), 0)?.activityInfo?.packageName?.let {
                if (it != "android") s.add(it)
            }
        } catch (_: Exception) {
        }
        return s
    }

    /** Kilit ekranındaki düğmeler çağırır. kind: "call" veya "wa". */
    fun open(ctx: Context, store: Store, kind: String) {
        val pm = ctx.packageManager
        val intent: Intent? = if (kind == "call") {
            dialIntent()
        } else {
            WHATSAPP.firstNotNullOfOrNull { pm.getLaunchIntentForPackage(it) }
        }
        if (intent == null) {
            Toast.makeText(ctx, "WhatsApp bu cihazda yok", Toast.LENGTH_LONG).show()
            return
        }
        // Kullanım erişimi varsa kısa bir pay (açılış gecikmesi), yoksa 3 dakikalık serbest süre.
        store.shortcutUntil = System.currentTimeMillis() +
            if (hasUsageAccess(ctx)) 6_000L else 180_000L
        try {
            ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
            Toast.makeText(ctx, "Açılamadı", Toast.LENGTH_LONG).show()
        }
    }

    /** Servis her saniye sorar: şu an kilit devreye girmesin mi? */
    fun skipLock(ctx: Context, store: Store, fg: Foreground): Boolean {
        if (System.currentTimeMillis() < store.shortcutUntil) return true
        if (!hasUsageAccess(ctx)) return false
        fg.update(ctx)
        val cur = fg.current ?: return false
        return cur in allowed(ctx)
    }
}

/** Ön plandaki uygulamayı kullanım olaylarından takip eder. */
class Foreground {
    var current: String? = null
    private var since = System.currentTimeMillis() - 3 * 3600_000L

    @Suppress("DEPRECATION")
    fun update(ctx: Context) {
        try {
            val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val ev = usm.queryEvents(since, now) ?: return
            val e = UsageEvents.Event()
            while (ev.hasNextEvent()) {
                ev.getNextEvent(e)
                when (e.eventType) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> current = e.packageName
                    UsageEvents.Event.MOVE_TO_BACKGROUND -> if (current == e.packageName) current = null
                }
            }
            since = now - 2000L
        } catch (_: Exception) {
        }
    }
}
