package com.beranmeva.kilit

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.TimePickerDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat

/** Ebeveyn paneli: önce ebeveyn şifresi istenir. */
class MainActivity : Activity() {

    companion object {
        @Volatile
        var visible = false

        private const val GRACE_MS = 5 * 60_000L
    }

    private lateinit var store: Store
    private var authed = false
    private var status: TextView? = null
    private var perms: TextView? = null
    private val handler = Handler(Looper.getMainLooper())

    private val ticker = object : Runnable {
        override fun run() {
            updateStatus()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = Store(this)
        if (store.hasPassword(Store.PARENT)) showAuth(false) else showAuth(true)
    }

    override fun onResume() {
        super.onResume()
        visible = true
        if (authed) {
            store.parentUntil = System.currentTimeMillis() + GRACE_MS
            updatePerms()
            handler.removeCallbacks(ticker)
            handler.post(ticker)
        }
    }

    override fun onPause() {
        visible = false
        handler.removeCallbacks(ticker)
        super.onPause()
    }

    override fun onDestroy() {
        // Panel kapanınca ebeveyn izni biter, kilit tekrar devreye girer.
        if (isFinishing) store.parentUntil = 0L
        super.onDestroy()
    }

    // ---------- Giriş / ilk kurulum ----------

    private fun showAuth(creating: Boolean) {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Ui.BG)
            val pad = Ui.dp(this@MainActivity, 32)
            setPadding(pad, pad, pad, pad)
        }
        root.addView(
            Ui.tv(
                this,
                if (creating) Store.createPrompt(Store.PARENT) else Store.enterPrompt(Store.PARENT),
                24f,
                bold = true
            ),
            Ui.lp(this, widthDp = 0)
        )
        if (creating) {
            root.addView(
                Ui.tv(
                    this,
                    "Bu şifreyle çocukların şifrelerini sıfırlayabilirsin. Unutma!",
                    15f,
                    Ui.MUTED
                ),
                Ui.lp(this, widthDp = 0, topDp = 8)
            )
        }

        val pw = Ui.pwField(this, "Şifre")
        root.addView(pw, Ui.lp(this, topDp = 24))
        var pw2: EditText? = null
        if (creating) {
            pw2 = Ui.pwField(this, "Şifre (tekrar)")
            root.addView(pw2, Ui.lp(this, topDp = 8))
        }
        val err = Ui.tv(this, "", 14f, Ui.ERROR)
        root.addView(err, Ui.lp(this, topDp = 8))

        fun submit() {
            val left = store.lockoutLeftMs()
            val a = pw.text.toString()
            if (left > 0) {
                err.text = "Çok fazla yanlış deneme. ${(left + 999) / 1000} sn bekle"
            } else if (creating) {
                val b = pw2?.text?.toString() ?: ""
                if (a.length < Store.MIN_LEN) {
                    err.text = "En az ${Store.MIN_LEN} karakter olmalı"
                } else if (a != b) {
                    err.text = "Şifreler aynı değil"
                } else {
                    store.setPassword(Store.PARENT, a)
                    authed = true
                    showPanel()
                }
            } else if (store.check(Store.PARENT, a)) {
                store.resetFails()
                authed = true
                showPanel()
            } else {
                store.registerFail()
                pw.text.clear()
                err.text = "Şifre yanlış"
            }
        }

        val last = pw2 ?: pw
        last.imeOptions = EditorInfo.IME_ACTION_DONE
        last.setOnEditorActionListener { _, _, _ ->
            submit()
            true
        }
        root.addView(
            Ui.button(this, if (creating) "Şifreyi kaydet" else "Giriş") { submit() },
            Ui.lp(this, topDp = 16)
        )
        setContentView(root)
    }

    // ---------- Panel ----------

    private fun showPanel() {
        store.parentUntil = System.currentTimeMillis() + GRACE_MS
        try {
            ContextCompat.startForegroundService(this, Intent(this, GuardService::class.java))
        } catch (_: Exception) {
        }

        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = Ui.dp(this@MainActivity, 20)
            setPadding(pad, pad, pad, pad)
        }
        col.addView(Ui.tv(this, "Ebeveyn paneli", 24f, bold = true), Ui.lp(this, 0))

        status = Ui.tv(this, "", 16f, Ui.MUTED)
        col.addView(status, Ui.lp(this, 0, 12))
        perms = Ui.tv(this, "", 14f, Ui.MUTED)
        col.addView(perms, Ui.lp(this, 0, 12))

        fun add(label: String, action: () -> Unit) {
            col.addView(Ui.button(this, label, action), Ui.lp(this, 0, 8))
        }

        add("1) Diğer uygulamaların üzerinde göster iznini ver") {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
            )
        }
        add("2) Bildirim izni ver") {
            if (Build.VERSION.SDK_INT >= 33) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
            } else {
                toast("Bu Android sürümünde gerek yok")
            }
        }
        add("3) Pil kısıtlamasını kaldır (arka planda kalsın)") {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
        add("Beran'ın şifresini sıfırla") { confirmReset(Store.BERAN) }
        add("Meva'nın şifresini sıfırla") { confirmReset(Store.MEVA) }
        add("Ebeveyn şifresini değiştir") {
            ask("Yeni ebeveyn şifresi", "Şifre", true) { s ->
                if (s.length < Store.MIN_LEN) {
                    toast("En az ${Store.MIN_LEN} karakter olmalı")
                } else {
                    store.setPassword(Store.PARENT, s)
                    toast("Ebeveyn şifresi değişti")
                }
            }
        }
        add("Kullanım süresini değiştir") {
            ask("Süre (dakika, 5-600)", "Örn. 120", false) { s ->
                val m = s.toIntOrNull()
                if (m == null) {
                    toast("Sayı gir")
                } else {
                    store.durationMin = m.coerceIn(5, 600)
                    toast("Yeni süre: ${store.durationMin} dk (sonraki girişten itibaren)")
                    updateStatus()
                }
            }
        }
        add("Ödev saatleri (gün ve saat ekle / sil)") { showHomework() }
        add("Oturumu şimdi bitir") {
            store.endSessionNow()
            toast("Oturum bitti. Sıradaki: ${Store.label(store.next)}")
            updateStatus()
        }
        add("Paneli kapat ve kilitle") { finish() }

        setContentView(ScrollView(this).apply {
            setBackgroundColor(Ui.BG)
            addView(col)
        })
        updateStatus()
        updatePerms()
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }

    private fun updateStatus() {
        store.refresh()
        val now = if (store.isActive()) {
            "Şu an: ${Store.label(store.current)} (kalan ${Store.fmt(store.remainingMs())})"
        } else {
            "Şu an kimse girişli değil. Sıradaki: ${Store.label(store.next)}"
        }
        val pws = "Şifre durumu — Beran: ${yn(store.hasPassword(Store.BERAN))}, " +
            "Meva: ${yn(store.hasPassword(Store.MEVA))}"
        val hw = store.homeworkActive()
        val hwLine = if (hw != null) {
            "\nÖDEV ZAMANI şu an aktif (${Store.hm(hw.end)}'e kadar)"
        } else {
            "\nÖdev saati sayısı: ${store.homeworkSlots().size}"
        }
        val beat = store.beat
        val age = (System.currentTimeMillis() - beat) / 1000L
        val stale = beat == 0L || age >= 5L
        val svc = when {
            beat == 0L -> "Koruma servisi: henüz başlamadı"
            stale -> "Koruma servisi: DURMUŞ ($age sn) — yeniden başlatılıyor"
            else -> "Koruma servisi: ÇALIŞIYOR"
        }
        if (stale) {
            try {
                ContextCompat.startForegroundService(this, Intent(this, GuardService::class.java))
            } catch (_: Exception) {
            }
        }
        status?.text = "$now\n$pws\nSüre: ${store.durationMin} dk$hwLine\n$svc"
    }

    private fun updatePerms() {
        val overlay = Settings.canDrawOverlays(this)
        val notif = Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        perms?.text = "Üstte gösterme izni: ${yn(overlay)} | Bildirim izni: ${yn(notif)}"
    }

    private fun yn(b: Boolean) = if (b) "VAR" else "YOK"

    // ---------- Yardımcılar ----------

    private fun confirmReset(u: String) {
        AlertDialog.Builder(this)
            .setTitle("${Store.label(u)} şifresi sıfırlansın mı?")
            .setMessage("Bir sonraki girişinde yeni şifre oluşturacak.")
            .setPositiveButton("Sıfırla") { _, _ ->
                store.clearPassword(u)
                toast("${Store.label(u)} şifresi sıfırlandı")
                updateStatus()
            }
            .setNegativeButton("İptal", null)
            .show()
    }

    private fun ask(title: String, hint: String, password: Boolean, onOk: (String) -> Unit) {
        val e = EditText(this).apply {
            this.hint = hint
            inputType = if (password) {
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            } else {
                InputType.TYPE_CLASS_NUMBER
            }
        }
        AlertDialog.Builder(this)
            .setTitle(title)
            .setView(e)
            .setPositiveButton("Tamam") { _, _ -> onOk(e.text.toString()) }
            .setNegativeButton("İptal", null)
            .show()
    }

    // ---------- Ödev saatleri ----------

    private fun showHomework() {
        val slots = store.homeworkSlots()
        val items = slots.map { Store.hwLabel(it) } + "+ Yeni ödev saati ekle"
        AlertDialog.Builder(this)
            .setTitle("Ödev saatleri (silmek için dokun)")
            .setItems(items.toTypedArray()) { _, i ->
                if (i == slots.size) pickDays() else confirmDeleteHw(i)
            }
            .setNegativeButton("Kapat", null)
            .show()
    }

    private fun confirmDeleteHw(i: Int) {
        val slot = store.homeworkSlots().getOrNull(i) ?: return
        AlertDialog.Builder(this)
            .setTitle("Silinsin mi?")
            .setMessage(Store.hwLabel(slot))
            .setPositiveButton("Sil") { _, _ ->
                store.removeHomework(i)
                toast("Silindi")
                updateStatus()
                showHomework()
            }
            .setNegativeButton("İptal") { _, _ -> showHomework() }
            .show()
    }

    private fun pickDays() {
        val checked = BooleanArray(7) { it < 5 }
        AlertDialog.Builder(this)
            .setTitle("Hangi günler?")
            .setMultiChoiceItems(Store.DAY_NAMES, checked) { _, which, isChecked ->
                checked[which] = isChecked
            }
            .setPositiveButton("İleri") { _, _ ->
                val days = (0..6).filter { checked[it] }.joinToString("") { (it + 1).toString() }
                if (days.isEmpty()) {
                    toast("En az bir gün seç")
                } else {
                    pickTime("Başlangıç saati", 16, 0) { s ->
                        pickTime("Bitiş saati", 18, 0) { e -> addSlot(days, s, e) }
                    }
                }
            }
            .setNegativeButton("İptal", null)
            .show()
    }

    private fun pickTime(title: String, h: Int, m: Int, done: (Int) -> Unit) {
        val d = TimePickerDialog(this, { _, hh, mm -> done(hh * 60 + mm) }, h, m, true)
        d.setTitle(title)
        d.show()
    }

    private fun addSlot(days: String, s: Int, e: Int) {
        if (e <= s) {
            toast("Bitiş saati başlangıçtan sonra olmalı")
            return
        }
        store.addHomework(Store.Hw(days, s, e))
        toast("Ödev saati eklendi")
        updateStatus()
        showHomework()
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
