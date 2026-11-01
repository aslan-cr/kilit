package com.beranmeva.kullanimizle

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.widget.Button
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

    private fun button(s: String, color: String, onClick: () -> Unit): Button {
        val b = Button(this)
        b.text = s
        b.isAllCaps = false
        b.setTextColor(Color.WHITE)
        b.setBackgroundColor(Color.parseColor(color))
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(10)
        b.layoutParams = lp
        b.setOnClickListener { onClick() }
        return b
    }

    // ---------------- liste ----------------
    private fun showList() {
        openIndex = -1
        holder.removeAllViews()
        holder.addView(text("Kullanım İzle", 24f, "#4338CA", true))
        val d = devices()
        if (d.length() == 0) {
            val t = text("Henüz cihaz yok. \"Cihaz ekle\"ye basıp izlenecek cihazdaki \"Kullanım Kaydı\" uygulamasının gösterdiği kodu gir.", 15f, "#334155")
            t.setPadding(0, dp(12), 0, dp(8))
            holder.addView(t)
        }
        for (i in 0 until d.length()) {
            val o = d.getJSONObject(i)
            val card = LinearLayout(this)
            card.orientation = LinearLayout.VERTICAL
            card.setBackgroundColor(Color.WHITE)
            card.setPadding(dp(16), dp(14), dp(16), dp(14))
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            lp.topMargin = dp(12)
            card.layoutParams = lp
            card.addView(text(o.getString("n"), 19f, "#0F172A", true))
            card.addView(text("Kod: " + Crypto.pretty(o.getString("c")), 14f, "#64748B"))
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
        val name = EditText(this); name.hint = "Cihaz adı (örn. Beran'ın tableti)"
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
        holder.addView(button("< Geri", "#64748B") { showList() })
        holder.addView(text(dev.getString("n"), 22f, "#0F172A", true).also { it.setPadding(0, dp(12), 0, 0) })
        val d = data
        if (message.isNotEmpty()) holder.addView(text(message, 14f, "#B45309").also { it.setPadding(0, dp(8), 0, dp(4)) })
        if (d != null) {
            val t = d.optLong("t")
            val ago = (System.currentTimeMillis() - t) / 60000
            val fmt = SimpleDateFormat("d MMM HH:mm", Locale("tr"))
            holder.addView(text("Model: " + d.optString("m") + "  ·  Son güncelleme: " + fmt.format(Date(t)) +
                " (" + (if (ago < 1) "az önce" else if (ago < 60) "$ago dk önce" else "${ago / 60} sa önce") + ")", 13f, "#64748B"))
            val days = d.getJSONArray("days")
            if (dayIndex >= days.length()) dayIndex = 0
            val hs = HorizontalScrollView(this)
            val row = LinearLayout(this)
            for (k in 0 until days.length()) {
                val label = when (k) { 0 -> "Bugün"; 1 -> "Dün"; else -> days.getJSONObject(k).getString("d").substring(5) }
                val b = Button(this)
                b.text = label; b.isAllCaps = false
                b.setTextColor(if (k == dayIndex) Color.WHITE else Color.parseColor("#4338CA"))
                b.setBackgroundColor(Color.parseColor(if (k == dayIndex) "#4338CA" else "#E0E7FF"))
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
            holder.addView(text("Toplam (listelenen): " + dur(total), 17f, "#0F172A", true).also { it.setPadding(0, dp(14), 0, dp(6)) })
            if (apps.length() == 0) holder.addView(text("Bu gün için kayıt yok.", 14f, "#64748B"))
            val max = if (apps.length() > 0) apps.getJSONArray(0).getLong(1).coerceAtLeast(1) else 1
            for (k in 0 until apps.length()) {
                val a = apps.getJSONArray(k)
                val card = LinearLayout(this)
                card.orientation = LinearLayout.VERTICAL
                card.setBackgroundColor(Color.WHITE)
                card.setPadding(dp(14), dp(10), dp(14), dp(10))
                val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                lp.topMargin = dp(6); card.layoutParams = lp
                val top = LinearLayout(this)
                val nm = text(a.getString(0), 16f, "#0F172A")
                nm.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                top.addView(nm)
                top.addView(text(dur(a.getLong(1)), 16f, "#4338CA", true))
                card.addView(top)
                val bar = View(this)
                bar.setBackgroundColor(Color.parseColor("#818CF8"))
                val w = (resources.displayMetrics.widthPixels - dp(36 + 28)) * a.getLong(1) / max
                card.addView(bar, LinearLayout.LayoutParams(w.toInt().coerceAtLeast(dp(4)), dp(6)).also { it.topMargin = dp(6) })
                holder.addView(card)
            }
        }
        holder.addView(button("Yenile", "#4338CA") { message = "Yenileniyor..."; render(); fetch() })
    }
}
