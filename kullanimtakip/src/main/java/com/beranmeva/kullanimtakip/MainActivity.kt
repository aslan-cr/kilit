package com.beranmeva.kullanimtakip

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : Activity() {

    private lateinit var prefs: Prefs
    private lateinit var codeView: TextView
    private lateinit var statusView: TextView
    private val ui = Handler(Looper.getMainLooper())
    private val refresh = object : Runnable {
        override fun run() { updateStatus(); ui.postDelayed(this, 3000) }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun button(text: String, color: Int, onClick: () -> Unit): Button {
        val b = Button(this)
        b.text = text
        b.isAllCaps = false
        b.setTextColor(Color.WHITE)
        b.setBackgroundColor(color)
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(10)
        b.layoutParams = lp
        b.setOnClickListener { onClick() }
        return b
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)
        if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)

        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setPadding(dp(20), dp(24), dp(20), dp(24))
        root.setBackgroundColor(Color.parseColor("#F1F5F9"))

        val title = TextView(this)
        title.text = "Kullanım Kaydı"
        title.textSize = 24f
        title.setTypeface(null, Typeface.BOLD)
        title.setTextColor(Color.parseColor("#0E7490"))
        root.addView(title)

        val info = TextView(this)
        info.text = "Bu cihazın kodu aşağıda. Diğer cihazdaki \"Kullanım İzle\" uygulamasına bu kodu girince bu cihazda hangi uygulamada ne kadar durulduğu görünür (Google ve Chrome hariç)."
        info.setTextColor(Color.parseColor("#334155"))
        info.setPadding(0, dp(8), 0, dp(12))
        root.addView(info)

        codeView = TextView(this)
        codeView.textSize = 38f
        codeView.setTypeface(Typeface.MONOSPACE, Typeface.BOLD)
        codeView.gravity = Gravity.CENTER
        codeView.setTextColor(Color.parseColor("#0F172A"))
        codeView.setBackgroundColor(Color.WHITE)
        codeView.setPadding(dp(8), dp(22), dp(8), dp(22))
        root.addView(codeView)

        statusView = TextView(this)
        statusView.setTextColor(Color.parseColor("#334155"))
        statusView.setPadding(0, dp(14), 0, dp(4))
        root.addView(statusView)

        root.addView(button("1) Kullanım erişimini ver", Color.parseColor("#0E7490")) {
            try { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) } catch (e: Exception) { }
            Toast.makeText(this, "Listede \"Kullanım Kaydı\"nı bulup aç", Toast.LENGTH_LONG).show()
        })
        root.addView(button("2) Pil kısıtlamasını kaldır", Color.parseColor("#0E7490")) {
            try {
                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
            } catch (e: Exception) { }
        })
        root.addView(button("Şimdi gönder", Color.parseColor("#15803D")) {
            Toast.makeText(this, "Gönderiliyor...", Toast.LENGTH_SHORT).show()
            Thread {
                Collector.send(this)
                ui.post { updateStatus() }
            }.start()
        })
        root.addView(button("Kodu kopyala", Color.parseColor("#475569")) {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("kod", prefs.code))
            Toast.makeText(this, "Kod kopyalandı", Toast.LENGTH_SHORT).show()
        })
        root.addView(button("Kodu yenile", Color.parseColor("#B91C1C")) {
            AlertDialog.Builder(this)
                .setTitle("Kod yenilensin mi?")
                .setMessage("Eski kodu giren cihaz artık bu cihazı göremez; yeni kodu ona yeniden girmen gerekir.")
                .setPositiveButton("Yenile") { _, _ -> prefs.code = Crypto.newCode(); updateStatus() }
                .setNegativeButton("Vazgeç", null)
                .show()
        })

        val sv = ScrollView(this)
        sv.addView(root)
        setContentView(sv)
    }

    override fun onResume() {
        super.onResume()
        if (Collector.hasAccess(this)) {
            try { startForegroundService(Intent(this, TrackService::class.java)) } catch (e: Exception) { }
        }
        ui.post(refresh)
    }

    override fun onPause() {
        ui.removeCallbacks(refresh)
        super.onPause()
    }

    private fun updateStatus() {
        codeView.text = prefs.code
        val access = Collector.hasAccess(this)
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val battery = pm.isIgnoringBatteryOptimizations(packageName)
        val fmt = SimpleDateFormat("d MMM HH:mm", Locale("tr"))
        val last = if (prefs.lastOk > 0) fmt.format(Date(prefs.lastOk)) else "henüz yok"
        val sb = StringBuilder()
        sb.append("Kullanım erişimi: ").append(if (access) "VAR" else "YOK (1. düğmeye bas)").append("\n")
        sb.append("Pil kısıtlaması: ").append(if (battery) "kaldırıldı" else "açık (2. düğmeye bas)").append("\n")
        sb.append("Son başarılı gönderim: ").append(last)
        if (prefs.lastErr.isNotEmpty()) sb.append("\nSon hata: ").append(prefs.lastErr)
        statusView.text = sb.toString()
    }
}
