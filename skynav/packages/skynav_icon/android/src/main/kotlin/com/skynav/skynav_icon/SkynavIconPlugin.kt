package com.skynav.skynav_icon

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Launcher ikonunu activity-alias'lar arasında değiştirir.
 *
 * Android, uygulamayı başlatan alias kapatılınca ön plandaki uygulamayı sonlandırabilir
 * (özellikle Samsung / saf Android). Bu yüzden uygulama ekrandayken değişiklik yapılmaz:
 * "deferred" döner, Dart tarafı uygulama arka plana geçince ya da arka plan görevinde tekrar dener.
 */
class SkynavIconPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "skynav/icon")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setIcon" -> {
                val target = call.argument<String>("alias")
                val all = call.argument<List<String>>("all")
                val force = call.argument<Boolean>("force") ?: false
                if (target == null || all == null) { result.error("args", "alias/all eksik", null); return }
                try { result.success(setIcon(target, all, force)) } catch (e: Exception) { result.error("icon", e.message, null) }
            }
            "current" -> {
                val all = call.argument<List<String>>("all") ?: emptyList()
                result.success(all.firstOrNull { isEnabled(it) })
            }
            "isForeground" -> result.success(isForeground())
            else -> result.notImplemented()
        }
    }

    private fun component(alias: String) = ComponentName(context.packageName, "${context.packageName}.$alias")

    private fun isEnabled(alias: String): Boolean {
        val state = context.packageManager.getComponentEnabledSetting(component(alias))
        // Varsayılan durum manifest'teki android:enabled değeridir; yalnızca açıkça etkin olanı say.
        return state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && alias == "IconSnow")
    }

    /** Uygulamanın bir ekranı şu an kullanıcıya görünüyor mu? */
    private fun isForeground(): Boolean {
        val info = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(info)
        return info.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
    }

    /** "same" | "deferred" | "changed" */
    private fun setIcon(target: String, all: List<String>, force: Boolean): String {
        if (isEnabled(target) && all.none { it != target && isEnabled(it) }) return "same"
        if (!force && isForeground()) return "deferred"
        val pm = context.packageManager
        // Önce yenisini aç, sonra eskileri kapat: launcher'da ikon hiç kaybolmaz.
        pm.setComponentEnabledSetting(component(target), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (a in all) if (a != target) {
            pm.setComponentEnabledSetting(component(a), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        }
        return "changed"
    }
}
