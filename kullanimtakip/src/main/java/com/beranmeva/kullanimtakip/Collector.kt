package com.beranmeva.kullanimtakip

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Kullanım verisini toplar ve şifreli gönderir. */
object Collector {

    private val OWN = setOf("com.beranmeva.kullanimtakip", "com.beranmeva.kilit", "com.android.systemui")

    /** Google ve Chrome sayılmaz. */
    private fun skipped(pkg: String): Boolean =
        pkg.startsWith("com.google.") || pkg == "com.android.chrome" ||
            pkg == "com.android.vending" || pkg in OWN

    @Suppress("DEPRECATION")
    fun hasAccess(ctx: Context): Boolean = try {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        ops.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(), ctx.packageName) == android.app.AppOpsManager.MODE_ALLOWED
    } catch (e: Exception) { false }

    private fun dayStart(daysAgo: Int): Long {
        val c = Calendar.getInstance()
        c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0)
        c.add(Calendar.DAY_OF_YEAR, -daysAgo)
        return c.timeInMillis
    }

    private fun build(ctx: Context, perDay: Int): String {
        val pm = ctx.packageManager
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val home = pm.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            ?.activityInfo?.packageName
        val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val days = JSONArray()
        val now = System.currentTimeMillis()
        for (i in 0 until 7) {
            val start = dayStart(i)
            val end = if (i == 0) now else dayStart(i - 1)
            val map = usm.queryAndAggregateUsageStats(start, end)
            val rows = ArrayList<Pair<String, Long>>()
            for ((pkg, st) in map) {
                val ms = st.totalTimeInForeground
                if (ms < 30_000L || skipped(pkg) || pkg == home) continue
                if (pm.getLaunchIntentForPackage(pkg) == null) continue
                val label = try {
                    pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                } catch (e: Exception) { pkg }
                rows.add(label.take(24) to ms)
            }
            rows.sortByDescending { it.second }
            val apps = JSONArray()
            for (r in rows.take(perDay)) apps.put(JSONArray().put(r.first).put(r.second / 1000))
            days.put(JSONObject().put("d", fmt.format(Date(start))).put("a", apps))
        }
        return JSONObject().put("v", 1).put("m", Build.MODEL ?: "Cihaz").put("t", now).put("days", days).toString()
    }

    /** Gönderir. Başarılıysa null, değilse hata metni döner. */
    fun send(ctx: Context): String? {
        val p = Prefs(ctx)
        return try {
            if (!hasAccess(ctx)) return "Kullanım erişimi verilmemiş"
            var msg = ""
            var n = 20
            while (n >= 4) {
                msg = Crypto.pack(p.code, build(ctx, n))
                if (msg.length < 3800) break
                n -= 4
            }
            val con = URL(Crypto.SERVER + "/" + Crypto.topic(p.code)).openConnection() as HttpURLConnection
            con.requestMethod = "POST"
            con.connectTimeout = 15000
            con.readTimeout = 15000
            con.doOutput = true
            con.outputStream.use { it.write(msg.toByteArray()) }
            val code = con.responseCode
            con.disconnect()
            if (code in 200..299) { p.lastOk = System.currentTimeMillis(); p.lastErr = ""; null }
            else { p.lastErr = "Sunucu hatası $code"; p.lastErr }
        } catch (e: Exception) {
            p.lastErr = "Gönderilemedi (internet?)"
            p.lastErr
        }
    }
}
