package com.skynav.skynav

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val aliases = mapOf(
        "snow" to "IconSnow", "lentil" to "IconLentil", "blizzard" to "IconBlizzard", "rain" to "IconRain",
        "sleet" to "IconSleet", "cloudy" to "IconCloudy", "night" to "IconNight", "sun" to "IconSun",
        "sun_hot" to "IconSunHot", "sun_extreme" to "IconSunExtreme"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "skynav/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "installer" -> result.success(installer())
                "setIcon" -> { setIcon(call.arguments as? String ?: "snow"); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun installer(): String? = try {
        if (android.os.Build.VERSION.SDK_INT >= 30) packageManager.getInstallSourceInfo(packageName).installingPackageName
        else @Suppress("DEPRECATION") packageManager.getInstallerPackageName(packageName)
    } catch (e: Exception) { null }

    /** Seçilen alias'ı etkinleştirir, diğerlerini kapatır (uygulamayı öldürmeden). */
    private fun setIcon(key: String) {
        val target = aliases[key] ?: return
        val pm = packageManager
        // Önce yenisini aç, sonra eskileri kapat: launcher'da ikon hiç kaybolmaz.
        pm.setComponentEnabledSetting(ComponentName(this, "$packageName.$target"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for ((k, a) in aliases) if (k != key) pm.setComponentEnabledSetting(ComponentName(this, "$packageName.$a"),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
    }
}
