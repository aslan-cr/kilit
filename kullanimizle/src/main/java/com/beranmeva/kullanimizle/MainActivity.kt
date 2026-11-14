package com.beranmeva.kullanimizle

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : Activity() {

    private val ui = Handler(Looper.getMainLooper())
    private val sp by lazy { getSharedPreferences("izle", Context.MODE_PRIVATE) }
    private lateinit var holder: LinearLayout
    private var openIndex = -1
    private var dayIndex = 0
    private var data: JSONObject? = null
    private var message = ""
    private val autoRefresh = object : Runnable {
        override fun run() { if (openIndex >= 0) fetch(); ui.postDelayed(this, 60_000L) }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    // ---- kayıtlı cihazlar: [{n:ad, c:kod}] ----
    private fun devices(): JSONArray = try { JSONArray(sp.getString("devices", "[]")) } catch (e: Exception) { JSONArray() }
    private fun saveDevices(a: JSONArray) { sp.edit().putString("devices", a.toString()).apply() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        holder = LinearLayout(this)
        holder.orientation = LinearLayout.VERTICAL
        holder.setPadding(dp(18), dp(22), dp(18), dp(22))
        val sv = ScrollView(this)
        sv.setBackgroundColor(Color.parseColor("#F1F5F9"))
        sv.addView(holder)
        setContentView(sv)
        showList()
    }

    override fun onResume() { super.onResume(); ui.postDelayed(autoRefresh, 60_000L) }
    override fun onPause() { ui.removeCallbacks(autoRefresh); super.onPause() }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (openIndex >= 0) { openIndex = -1; showList() } else super.onBackPressed()
    }

    private fun text(s: String, size: Float, color: String, bold: Boolean = false): TextView {
        val t = TextView(this)
        t.text = s
        t.textSize = size
        t.setTextColor(Color.parseColor(color))
        if (bold) t.setTypeface(null, Typeface.BOLD)
        return t
    }

    /** Köşeleri yuvarlak dolgu (isteğe bağlı kenarlık). */
    private fun round(color: Int, radiusDp: Int, strokeColor: Int = 0): GradientDrawable {
        val g = GradientDrawable()
        g.setColor(color)
        g.cornerRadius = dp(radiusDp).toFloat()
        if (strokeColor != 0) g.setStroke(dp(1), strokeColor)
        return g
    }

    private fun ripple(shape: GradientDrawable, radiusDp: Int) =
        RippleDrawable(ColorStateList.valueOf(0x33000000), shape, round(Color.WHITE, radiusDp))

    /** Yuvarlak, basınca dalgalanan düğme. filled=false ise açık zeminli ikincil düğme. */
    private fun button(s: String, color: String, filled: Boolean = true, onClick: () -> Unit): TextView {
        val c = Color.parseColor(color)
        val b = TextView(this)
        b.text = s
        b.textSize = 16f
        b.gravity = Gravity.CENTER
        b.setTypeface(null, Typeface.BOLD)
        b.setTextColor(if (filled) Color.WHITE else c)
        b.setPadding(dp(16), dp(14), dp(16), dp(14))
        b.background = ripple(if (filled) round(c, 14) else round(Color.WHITE, 14, c), 14)
        b.isClickable = true
        b.isFocusable = true
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(14)
        b.layoutParams = lp
        b.setOnClickListener { onClick() }
        return b
    }

    /** Beyaz, yuvarlak köşeli kart. */
    private fun card(topDp: Int, padDp: Int): LinearLayout {
        val c = LinearLayout(this)
        c.orientation = LinearLayout.VERTICAL
        c.background = round(Color.WHITE, 16, Color.parseColor("#E2E8F0"))
        c.setPadding(dp(padDp + 2), dp(padDp), dp(padDp + 2), dp(padDp))
        c.elevation = dp(2).toFloat()
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(topDp)
        c.layoutParams = lp
        return c
    }

    /** Sayfa başlığı: renk geçişli yuvarlak şerit. */
    private fun header(title: String, sub: String): LinearLayout {
        val h = LinearLayout(this)
        h.orientation = LinearLayout.VERTICAL
        val g = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#4338CA"), Color.parseColor("#6D28D9")))
        g.cornerRadius = dp(20).toFloat()
        h.background = g
        h.setPadding(dp(20), dp(20), dp(20), dp(20))
        h.addView(text(title, 24f, "#FFFFFF", true))
        if (sub.isNotEmpty()) h.addView(text(sub, 13.5f, "#E0E7FF").also { it.setPadding(0, dp(6), 0, 0); it.setLineSpacing(dp(2).toFloat(), 1f) })
        return h
    }

    // ---------------- liste ----------------
    private fun showList() {
        openIndex = -1
        holder.removeAllViews()
        window.statusBarColor = Color.parseColor("#3730A3")
        val d = devices()
        holder.addView(header("Kullanım İzle", if (d.length() == 0) "Çocuğun cihazında hangi uygulamada ne kadar durulduğunu buradan gör." else "${d.length()} cihaz kayıtlı · bakmak için dokun"))
        if (d.length() == 0) {
            val empty = card(14, 18)
            empty.addView(text("Henüz cihaz yok", 17f, "#0F172A", true))
            empty.addView(text("\"Cihaz ekle\"ye basıp izlenecek cihazdaki \"Kullanım Kaydı\" uygulamasının gösterdiği kodu gir.", 14.5f, "#475569").also { it.setPadding(0, dp(6), 0, 0); it.setLineSpacing(dp(3).toFloat(), 1f) })
            holder.addView(empty)
        }
        for (i in 0 until d.length()) {
            val o = d.getJSONObject(i)
            val card = card(12, 14)
            card.orientation = LinearLayout.HORIZONTAL
            card.gravity = Gravity.CENTER_VERTICAL
            card.background = ripple(round(Color.WHITE, 16, Color.parseColor("#E2E8F0")), 16)
            val nmTxt = o.getString("n")
            val av = text(nmTxt.trim().take(1).uppercase(Locale("tr")).ifEmpty { "?" }, 20f, "#FFFFFF", true)   // baş harfli yuvarlak rozet
            av.gravity = Gravity.CENTER
            val avCols = arrayOf("#4338CA", "#0E7490", "#B45309", "#BE185D", "#15803D")
            av.background = round(Color.parseColor(avCols[i % avCols.size]), 24)
            card.addView(av, LinearLayout.LayoutParams(dp(48), dp(48)).also { it.rightMargin = dp(14) })
            val col = LinearLayout(this)
            col.orientation = LinearLayout.VERTICAL
            col.addView(text(nmTxt, 18f, "#0F172A", true))
            col.addView(text("Kod: " + Crypto.pretty(o.getString("c")), 13.5f, "#64748B").also { it.typeface = Typeface.MONOSPACE })
            card.addView(col, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            card.addView(text("›", 26f, "#94A3B8", true))
            card.setOnClickListener { openDevice(i) }
            card.setOnLongClickListener { confirmDelete(i); true }
            holder.addView(card)
        }
        if (d.length() > 0) holder.addView(text("Silmek için kartı basılı tut.", 12f, "#64748B").also { it.setPadding(0, dp(8), 0, 0) })
        holder.addView(button("Cihaz ekle", "#4338CA") { addDialog() })
    }

    private fun confirmDelete(i: Int) {
        AlertDialog.Builder(this)
            .setTitle("Cihaz silinsin mi?")
            .setPositiveButton("Sil") { _, _ ->
                val d = devices(); val n = JSONArray()
                for (k in 0 until d.length()) if (k != i) n.put(d.get(k))
                saveDevices(n); showList()
            }
            .setNegativeButton("Vazgeç", null).show()
    }

    private fun addDialog() {
        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.setPadding(dp(20), dp(10), dp(20), 0)
        val name = EditText(this); name.hint = "Cihaz adı (örn. Bera'nın tableti)"
        val code = EditText(this); code.hint = "Kod (XXXX-XXXX)"
        code.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
        box.addView(name); box.addView(code)
        AlertDialog.Builder(this)
            .setTitle("Cihaz ekle")
            .setView(box)
            .setPositiveButton("Ekle") { _, _ ->
                val c = code.text.toString()
                if (!Crypto.valid(c)) { Toast.makeText(this, "Kod 8 karakter olmalı", Toast.LENGTH_LONG).show(); return@setPositiveButton }
                val d = devices()
                d.put(JSONObject().put("n", name.text.toString().ifBlank { "Cihaz ${d.length() + 1}" }).put("c", Crypto.norm(c)))
                saveDevices(d); showList()
            }
            .setNegativeButton("Vazgeç", null).show()
    }

    // ---------------- ayrıntı ----------------
    private fun openDevice(i: Int) {
        openIndex = i; dayIndex = 0; data = null; message = "Yükleniyor..."
        render(); fetch()
    }

    private fun fetch() {
        val i = openIndex
        if (i < 0) return
        val code = devices().getJSONObject(i).getString("c")
        Thread {
            var err = ""
            var obj: JSONObject? = null
            try {
                val url = URL(Crypto.SERVER + "/" + Crypto.topic(code) + "/json?poll=1&since=latest")
                val con = url.openConnection() as HttpURLConnection
                con.connectTimeout = 15000; con.readTimeout = 15000
                val body = con.inputStream.bufferedReader().readText()
                con.disconnect()
                var last: String? = null
                for (line in body.lines()) {
                    if (line.isBlank()) continue
                    val j = JSONObject(line)
                    if (j.optString("event") == "message") last = j.optString("message")
                }
                if (last == null) err = "Bu kodla veri bulunamadı. Kod doğru mu, o cihazda Kullanım Kaydı açık ve internetli mi? (Veri sunucuda yaklaşık 12 saat kalır.)"
                else obj = JSONObject(Crypto.unpack(code, last))
            } catch (e: javax.crypto.AEADBadTagException) {
                err = "Veri çözülemedi (kod yanlış olabilir)."
            } catch (e: Exception) {
                err = "Bağlanılamadı. İnternetini kontrol et."
            }
            ui.post {
                if (openIndex != i) return@post
                if (obj != null) { data = obj; message = "" } else if (data == null) message = err else message = "Yenilenemedi: $err"
                render()
            }
        }.start()
    }

    private fun dur(sec: Long): String {
        val h = sec / 3600; val m = (sec % 3600) / 60
        return if (h > 0) "$h sa $m dk" else if (m > 0) "$m dk" else "$sec sn"
    }

    private fun render() {
        if (openIndex < 0) return
        val dev = devices().getJSONObject(openIndex)
        holder.removeAllViews()
        holder.addView(button("‹  Cihazlar", "#4338CA", false) { showList() }.also {
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            lp.bottomMargin = dp(12); it.layoutParams = lp; it.setPadding(dp(16), dp(9), dp(18), dp(9)); it.textSize = 14f
        })
        holder.addView(header(dev.getString("n"), "Kod: " + Crypto.pretty(dev.getString("c"))))
        val d = data
        if (message.isNotEmpty()) holder.addView(text(message, 14f, "#92400E").also {
            it.background = round(Color.parseColor("#FEF3C7"), 12, Color.parseColor("#FCD34D"))
            it.setPadding(dp(14), dp(10), dp(14), dp(10))
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            lp.topMargin = dp(12); it.layoutParams = lp
        })
        if (d != null) {
            val t = d.optLong("t")
            val ago = (System.currentTimeMillis() - t) / 60000
            val fmt = SimpleDateFormat("d MMM HH:mm", Locale("tr"))
            holder.addView(text("Model: " + d.optString("m") + "  ·  Son güncelleme: " + fmt.format(Date(t)) +
                " (" + (if (ago < 1) "az önce" else if (ago < 60) "$ago dk önce" else "${ago / 60} sa önce") + ")", 13f, "#64748B").also { it.setPadding(dp(4), dp(10), 0, 0) })
            val days = d.getJSONArray("days")
            if (dayIndex >= days.length()) dayIndex = 0
            val hs = HorizontalScrollView(this)
            hs.isHorizontalScrollBarEnabled = false
            val row = LinearLayout(this)
            for (k in 0 until days.length()) {
                val label = when (k) { 0 -> "Bugün"; 1 -> "Dün"; else -> days.getJSONObject(k).getString("d").substring(5) }
                val b = TextView(this)
                b.text = label; b.textSize = 14f; b.setTypeface(null, Typeface.BOLD)
                b.setPadding(dp(16), dp(9), dp(16), dp(9))
                b.setTextColor(if (k == dayIndex) Color.WHITE else Color.parseColor("#4338CA"))
                b.background = round(Color.parseColor(if (k == dayIndex) "#4338CA" else "#E0E7FF"), 20)
                val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                lp.rightMargin = dp(8); lp.topMargin = dp(12)
                b.layoutParams = lp
                b.setOnClickListener { dayIndex = k; render() }
                row.addView(b)
            }
            hs.addView(row); holder.addView(hs)
            val apps = days.getJSONObject(dayIndex).getJSONArray("a")
            var total = 0L
            for (k in 0 until apps.length()) total += apps.getJSONArray(k).getLong(1)
            val tot = card(14, 14)
            tot.background = round(Color.parseColor("#EEF2FF"), 16, Color.parseColor("#C7D2FE"))
            tot.elevation = 0f
            tot.addView(text("TOPLAM (LİSTELENEN)", 11.5f, "#6366F1", true).also { it.letterSpacing = 0.08f })
            tot.addView(text(dur(total), 28f, "#312E81", true))
            holder.addView(tot)
            if (apps.length() == 0) holder.addView(text("Bu gün için kayıt yok.", 14f, "#64748B"))
            val max = if (apps.length() > 0) apps.getJSONArray(0).getLong(1).coerceAtLeast(1) else 1
            for (k in 0 until apps.length()) {
                val a = apps.getJSONArray(k)
                val card = card(8, 12)
                val top = LinearLayout(this)
                val nm = text(a.getString(0), 16f, "#0F172A")
                nm.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                top.addView(nm)
                top.addView(text(dur(a.getLong(1)), 16f, "#4338CA", true))
                card.addView(top)
                val track = FrameLayout(this)                       // ilerleme çubuğu: açık zemin üstünde yuvarlak dolgu
                track.background = round(Color.parseColor("#E0E7FF"), 4)
                val bar = View(this)
                bar.background = round(Color.parseColor(if (k == 0) "#4338CA" else "#818CF8"), 4)
                val w = (resources.displayMetrics.widthPixels - dp(36 + 32)) * a.getLong(1) / max
                track.addView(bar, FrameLayout.LayoutParams(w.toInt().coerceAtLeast(dp(8)), dp(8)))
                card.addView(track, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(8)).also { it.topMargin = dp(8) })
                holder.addView(card)
            }
        }
        holder.addView(button("Yenile", "#4338CA") { message = "Yenileniyor..."; render(); fetch() })
    }
}
