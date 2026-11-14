package com.beranmeva.kullanimtakip

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
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
    private lateinit var statusBox: LinearLayout
    private val ui = Handler(Looper.getMainLooper())
    private val refresh = object : Runnable {
        override fun run() { updateStatus(); ui.postDelayed(this, 3000) }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    /** Köşeleri yuvarlak dolgu (isteğe bağlı kenarlık). */
    private fun round(color: Int, radiusDp: Int, strokeColor: Int = 0): GradientDrawable {
        val g = GradientDrawable()
        g.setColor(color)
        g.cornerRadius = dp(radiusDp).toFloat()
        if (strokeColor != 0) g.setStroke(dp(1), strokeColor)
        return g
    }

    private fun lp(top: Int): LinearLayout.LayoutParams {
        val p = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        p.topMargin = dp(top)
        return p
    }

    private fun card(): LinearLayout {
        val c = LinearLayout(this)
        c.orientation = LinearLayout.VERTICAL
        c.background = round(Color.WHITE, 18, Color.parseColor("#E2E8F0"))
        c.setPadding(dp(16), dp(16), dp(16), dp(16))
        c.elevation = dp(2).toFloat()
        c.layoutParams = lp(14)
        return c
    }

    private fun label(text: String): TextView {
        val t = TextView(this)
        t.text = text
        t.textSize = 12f
        t.letterSpacing = 0.08f
        t.setTypeface(null, Typeface.BOLD)
        t.setTextColor(Color.parseColor("#64748B"))
        return t
    }

    /** Yuvarlak, basınca dalgalanan düğme. filled=false ise açık zeminli ikincil düğme. */
    private fun button(text: String, color: Int, filled: Boolean = true, onClick: () -> Unit): TextView {
        val b = TextView(this)
        b.text = text
        b.textSize = 16f
        b.gravity = Gravity.CENTER
        b.setTypeface(null, Typeface.BOLD)
        b.setTextColor(if (filled) Color.WHITE else color)
        b.setPadding(dp(16), dp(14), dp(16), dp(14))
        val shape = if (filled) round(color, 14) else round(Color.WHITE, 14, color)
        b.background = RippleDrawable(ColorStateList.valueOf(0x33000000), shape, round(Color.WHITE, 14))
        b.isClickable = true
        b.isFocusable = true
        b.layoutParams = lp(10)
        b.setOnClickListener { onClick() }
        return b
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)
        if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        window.statusBarColor = Color.parseColor("#0E7490")

        val teal = Color.parseColor("#0E7490")
        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setBackgroundColor(Color.parseColor("#F1F5F9"))

        // Üst başlık: renk geçişli şerit
        val head = LinearLayout(this)
        head.orientation = LinearLayout.VERTICAL
        val hg = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#0E7490"), Color.parseColor("#155E75"), Color.parseColor("#1E3A8A")))
        hg.cornerRadii = floatArrayOf(0f, 0f, 0f, 0f, dp(26).toFloat(), dp(26).toFloat(), dp(26).toFloat(), dp(26).toFloat())
        head.background = hg
        head.setPadding(dp(22), dp(26), dp(22), dp(26))
        val title = TextView(this)
        title.text = "Kullanım Kaydı"
        title.textSize = 26f
        title.setTypeface(null, Typeface.BOLD)
        title.setTextColor(Color.WHITE)
        head.addView(title)
        val info = TextView(this)
        info.text = "Bu cihazın kodunu diğer cihazdaki \"Kullanım İzle\" uygulamasına gir; bu cihazda hangi uygulamada ne kadar durulduğu orada görünür (Google ve Chrome hariç)."
        info.textSize = 14f
        info.setLineSpacing(dp(3).toFloat(), 1f)
        info.setTextColor(Color.parseColor("#CFFAFE"))
        info.setPadding(0, dp(8), 0, 0)
        head.addView(info)
        root.addView(head)

        val body = LinearLayout(this)
        body.orientation = LinearLayout.VERTICAL
        body.setPadding(dp(16), dp(2), dp(16), dp(24))
        root.addView(body)

        // Kod kartı
        val codeCard = card()
        codeCard.addView(label("BU CİHAZIN KODU"))
        codeView = TextView(this)
        codeView.textSize = 36f
        codeView.letterSpacing = 0.12f
        codeView.setTypeface(Typeface.MONOSPACE, Typeface.BOLD)
        codeView.gravity = Gravity.CENTER
        codeView.setTextColor(Color.parseColor("#0F172A"))
        codeView.background = round(Color.parseColor("#ECFEFF"), 14, Color.parseColor("#A5F3FC"))
        codeView.setPadding(dp(8), dp(18), dp(8), dp(18))
        codeView.layoutParams = lp(10)
        codeCard.addView(codeView)
        codeCard.addView(button("Kodu kopyala", teal, false) {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("kod", prefs.code))
            Toast.makeText(this, "Kod kopyalandı", Toast.LENGTH_SHORT).show()
        })
        body.addView(codeCard)

        // Durum kartı
        val stCard = card()
        stCard.addView(label("DURUM"))
        statusBox = LinearLayout(this)
        statusBox.orientation = LinearLayout.VERTICAL
        stCard.addView(statusBox)
        body.addView(stCard)

        // Kurulum kartı
        val setup = card()
        setup.addView(label("KURULUM"))
        setup.addView(button("1) Kullanım erişimini ver", teal) {
            try { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) } catch (e: Exception) { }
            Toast.makeText(this, "Listede \"Kullanım Kaydı\"nı bulup aç", Toast.LENGTH_LONG).show()
        })
        setup.addView(button("2) Pil kısıtlamasını kaldır", teal) {
            try {
                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
            } catch (e: Exception) { }
        })
        body.addView(setup)

        body.addView(button("Şimdi gönder", Color.parseColor("#15803D")) {
            Toast.makeText(this, "Gönderiliyor...", Toast.LENGTH_SHORT).show()
            Thread {
                Collector.send(this)
                ui.post { updateStatus() }
            }.start()
        }.also { (it.layoutParams as LinearLayout.LayoutParams).topMargin = dp(16) })
        body.addView(button("Kodu yenile", Color.parseColor("#B91C1C"), false) {
            AlertDialog.Builder(this)
                .setTitle("Kod yenilensin mi?")
                .setMessage("Eski kodu giren cihaz artık bu cihazı göremez; yeni kodu ona yeniden girmen gerekir.")
                .setPositiveButton("Yenile") { _, _ -> prefs.code = Crypto.newCode(); updateStatus() }
                .setNegativeButton("Vazgeç", null)
                .show()
        })

        val sv = ScrollView(this)
        sv.setBackgroundColor(Color.parseColor("#F1F5F9"))
        sv.addView(root)
        setContentView(sv)
    }

    /** Durum satırı: renkli nokta + başlık + değer. */
    private fun statusRow(ok: Boolean?, name: String, value: String) {
        val row = LinearLayout(this)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        row.setPadding(0, dp(10), 0, 0)
        val dot = View(this)
        val color = when (ok) { true -> "#16A34A"; false -> "#DC2626"; else -> "#94A3B8" }
        dot.background = round(Color.parseColor(color), 6)
        val dl = LinearLayout.LayoutParams(dp(10), dp(10))
        dl.rightMargin = dp(10)
        row.addView(dot, dl)
        val n = TextView(this)
        n.text = name
        n.textSize = 14f
        n.setTextColor(Color.parseColor("#334155"))
        row.addView(n, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        val v = TextView(this)
        v.text = value
        v.textSize = 14f
        v.gravity = Gravity.END
        v.setTypeface(null, Typeface.BOLD)
        v.setTextColor(Color.parseColor(if (ok == false) "#B91C1C" else "#0F172A"))
        row.addView(v, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.2f))
        statusBox.addView(row)
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
        statusBox.removeAllViews()
        statusRow(access, "Kullanım erişimi", if (access) "var" else "yok (1. düğme)")
        statusRow(battery, "Pil kısıtlaması", if (battery) "kaldırıldı" else "açık (2. düğme)")
        statusRow(if (prefs.lastOk > 0) true else null, "Son başarılı gönderim", last)
        if (prefs.lastErr.isNotEmpty()) statusRow(false, "Son hata", prefs.lastErr)
    }
}
