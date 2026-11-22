package com.skynav.skynav

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** İkon değiştirme artık skynav_icon eklentisinde (arka plan görevinde de çalışır). */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "skynav/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "installer" -> result.success(installer())
                else -> result.notImplemented()
            }
        }
    }

    private fun installer(): String? = try {
        if (android.os.Build.VERSION.SDK_INT >= 30) packageManager.getInstallSourceInfo(packageName).installingPackageName
        else @Suppress("DEPRECATION") packageManager.getInstallerPackageName(packageName)
    } catch (e: Exception) { null }
}
