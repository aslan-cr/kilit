package com.beranmeva.kilit

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.TimePickerDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.InputFilter
import android.text.InputType
import android.view.Gravity
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.NumberPicker
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat

/**
 * Ebeveyn tarafı: ilk açılışta kurulum sihirbazı, sonra şifreli ebeveyn paneli.
 * Çocuk ekleme/silme, yaş ve süre ayarı, ödev saatleri ve izinler burada yönetilir.
 */
class MainActivity : Activity() {

    companion object {
        @Volatile
        var visible = false

        private const val GRACE_MS = 5 * 60_000L
        private const val APP_NAME = "Aile Kilidi"
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
        if (store.hasPassword(Store.PARENT)) showAuth(false) else showWizard(0)
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

    // ---------- Küçük arayüz yardımcıları ----------

    private fun LinearLayout.text(t: String, size: Float, color: Int = Color.WHITE, bold: Boolean = false, top: Int = 8): TextView {
        val v = Ui.tv(this@MainActivity, t, size, color, bold)
        addView(v, Ui.lp(this@MainActivity, 0, top))
        return v
    }

    private fun LinearLayout.btn(label: String, top: Int = 10, action: () -> Unit) {
        addView(Ui.button(this@MainActivity, label, action), Ui.lp(this@MainActivity, 0, top))
    }

    private fun page(content: LinearLayout.() -> Unit) {
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = Ui.dp(this@MainActivity, 22)
            setPadding(pad, pad, pad, pad)
            content()
        }
        setContentView(ScrollView(this).apply {
            setBackgroundColor(Ui.BG)
            addView(col)
        })
    }

    private fun yn(b: Boolean) = if (b) "VAR" else "YOK"

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    // ---------- Giriş / ebeveyn şifresi ----------

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
                if (creating) store.createPrompt(Store.PARENT) else store.enterPrompt(Store.PARENT),
                24f,
                bold = true
            ),
            Ui.lp(this, widthDp = 0)
        )
        if (creating) {
            root.addView(
                Ui.tv(
                    this,
                    "Bu şifreyle ayarları değiştirir ve çocukların şifrelerini sıfırlarsın. Çocuklar bilmesin, sen de unutma!",
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
                    store.initKids()
                    authed = true
                    showWizard(2)
                }
            } else if (store.check(Store.PARENT, a)) {
                store.resetFails()
                authed = true
                // Kurulum yarım kaldıysa (çocuk eklenmemişse) kaldığı yerden devam eder.
                if (store.children().isEmpty()) showWizard(2) else showPanel()
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

    // ---------- Kurulum sihirbazı ----------

    /** Adımlar: 0 hoş geldin, 1 ebeveyn şifresi, 2 çocuklar, 3 izinler, 4 öneriler ve bitiş. */
    private fun showWizard(step: Int) {
        when (step) {
            0 -> page {
                text("$APP_NAME'ne hoş geldiniz", 26f, bold = true, top = 0)
                text("Adım 1 / 5", 13f, Ui.MUTED, top = 4)
                text(
                    "Telefon ya da tableti paylaşan 5-15 yaş arası çocuklar için sıra ve süre düzeni kurar.",
                    17f, top = 20
                )
                text(
                    "• Her çocuk kendi şifresiyle girer ve kendi süresi kadar kullanır.\n" +
                        "• Süresi dolunca sıra bir sonraki çocuğa geçer.\n" +
                        "• Ödev saatlerinde cihaz kilitli kalır.\n" +
                        "• Yaşa göre hazır süre önerileri vardır; hepsini değiştirebilirsiniz.",
                    16f, Ui.MUTED, top = 16
                ).gravity = Gravity.START
                text("Gizlilik", 18f, bold = true, top = 24)
                text(
                    "Uygulama internete bağlanmaz, reklam göstermez ve hiçbir bilgiyi cihazdan dışarı çıkarmaz. " +
                        "Şifreler cihazda şifrelenmiş olarak saklanır.",
                    15f, Ui.MUTED, top = 6
                ).gravity = Gravity.START
                btn("Başla", top = 28) { showAuth(true) }
            }

            2 -> showWizardChildren()

            3 -> page {
                text("İzinler", 26f, bold = true, top = 0)
                text("Adım 4 / 5", 13f, Ui.MUTED, top = 4)
                text(
                    "Kilidin çalışması için Android'in dört ayarına izin vermek gerekir. Her birinin ne için olduğu yazıyor.",
                    16f, Ui.MUTED, top = 12
                )
                perm("Diğer uygulamaların üzerinde göster", "Kilit ekranını ve süre sayacını diğer uygulamaların üstünde göstermek için. Ekrandaki içerik okunmaz.") { askOverlay() }
                perm("Bildirim", "Koruma servisinin çalıştığını gösteren sabit bir bildirim için. Gizli çalışmaz.") { askNotif() }
                perm("Pil kısıtlamasını kaldır", "Arka planda kapatılmasın diye.") { askBattery() }
                perm("Kullanım erişimi (isteğe bağlı)", "Yalnızca ön plandaki uygulamanın adını öğrenir. Arama/WhatsApp açıkken kilidin araya girmemesi ve süre sadece uygulama içindeyken aksın diye. Hiçbir yere gönderilmez.") { askUsage() }
                btn("Devam", top = 24) { showWizard(4) }
            }

            else -> showWizardFinish()
        }
    }

    private fun LinearLayout.perm(title: String, why: String, action: () -> Unit) {
        text(title, 17f, bold = true, top = 18).gravity = Gravity.START
        text(why, 14f, Ui.MUTED, top = 4).gravity = Gravity.START
        btn("İzin ver", top = 6, action = action)
    }

    private fun showWizardChildren() {
        val list = store.children()
        page {
            text("Çocuklar", 26f, bold = true, top = 0)
            text("Adım 3 / 5", 13f, Ui.MUTED, top = 4)
            text(
                "Cihazı kullanacak çocukları ekleyin (en fazla ${Store.MAX_KIDS}). Sıra, eklediğiniz sırayla döner. " +
                    "Yaş, ekranın dilini ve önerilen süreyi belirler.",
                16f, Ui.MUTED, top = 12
            )
            if (list.isEmpty()) {
                text("Henüz çocuk eklenmedi.", 16f, Ui.ERROR, top = 20)
            }
            for (c in list) {
                val row = LinearLayout(this@MainActivity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }
                val t = Ui.tv(
                    this@MainActivity,
                    "${c.name} · ${c.age} yaş · ${c.durationMin} dk",
                    17f
                )
                t.gravity = Gravity.START
                row.addView(t, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                row.addView(Ui.button(this@MainActivity, "Sil") {
                    store.removeChild(c.id)
                    showWizard(2)
                })
                addView(row, Ui.lp(this@MainActivity, 0, 10))
            }
            if (list.size < Store.MAX_KIDS) {
                btn("+ Çocuk ekle", top = 18) {
                    childDialog(null) { showWizard(2) }
                }
            }
            btn("Devam", top = 24) {
                if (store.children().isEmpty()) toast("En az bir çocuk ekleyin") else showWizard(3)
            }
        }
    }

    private fun showWizardFinish() {
        val kids = store.children()
        page {
            text("Neredeyse bitti", 26f, bold = true, top = 0)
            text("Adım 5 / 5", 13f, Ui.MUTED, top = 4)
            text("Önerilen günlük süreler", 18f, bold = true, top = 20)
            text(
                kids.joinToString("\n") { "${it.name} (${it.age} yaş): ${it.durationMin} dk" } +
                    "\n\nBu süreler yaş grubuna göre bir başlangıç önerisidir. Ebeveyn panelinden her çocuk için değiştirebilirsiniz.",
                15f, Ui.MUTED, top = 6
            ).gravity = Gravity.START

            val young = kids.minByOrNull { it.age }
            if (young != null && store.homeworkSlots().isEmpty()) {
                val h = Store.suggestedHomework(young.age)
                text("Ödev saati", 18f, bold = true, top = 22)
                text(
                    "Ödev saatinde cihaz herkes için kilitli kalır. Öneri (en küçük çocuğa göre): hafta içi ${Store.hm(h.start)} - ${Store.hm(h.end)}.",
                    15f, Ui.MUTED, top = 6
                ).gravity = Gravity.START
                btn("Önerilen ödev saatini ekle", top = 8) {
                    store.addHomework(h)
                    toast("Ödev saati eklendi")
                    showWizard(4)
                }
            }
            if (store.homeworkSlots().isNotEmpty()) {
                text("Ödev saatleri: ${store.homeworkSlots().joinToString(" | ") { Store.hwLabel(it) }}", 14f, Ui.MUTED, top = 12)
            }

            btn("Kurulumu bitir", top = 28) {
                // Kedi eğlencesi: 13 yaş altı çocuk varsa açık, yoksa kapalı başlar (panelden değişir).
                store.catVisible = kids.any { it.age < 13 }
                showPanel()
            }
        }
    }

    // ---------- Çocuk ekle / düzenle penceresi ----------

    private fun childDialog(existing: Store.Child?, onDone: () -> Unit) {
        val pad = Ui.dp(this, 20)
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad)
        }
        val name = EditText(this).apply {
            hint = "Çocuğun adı"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS
            filters = arrayOf(InputFilter.LengthFilter(Store.MAX_NAME))
            setText(existing?.name ?: "")
        }
        box.addView(name)
        box.addView(TextView(this).apply {
            text = "Yaşı"
            textSize = 16f
            setPadding(0, Ui.dp(this@MainActivity, 14), 0, 0)
        })
        val np = NumberPicker(this).apply {
            minValue = Store.MIN_AGE
            maxValue = Store.MAX_AGE
            value = existing?.age ?: 9
            wrapSelectorWheel = false
        }
        box.addView(np, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        })
        AlertDialog.Builder(this)
            .setTitle(if (existing == null) "Çocuk ekle" else "Çocuğu düzenle")
            .setView(box)
            .setPositiveButton("Kaydet") { _, _ ->
                val n = Store.cleanName(name.text.toString())
                if (n.isEmpty()) {
                    toast("Ad yazın")
                } else if (existing == null) {
                    if (store.addChild(n, np.value) == null) toast("En fazla ${Store.MAX_KIDS} çocuk eklenebilir")
                } else {
                    val groupChanged = Store.groupOf(np.value) != existing.group
                    store.updateChild(existing.copy(name = n, age = np.value))
                    if (groupChanged) toast("Yaş grubu değişti: şifre sıfırlandı, sıradaki girişte yenisi oluşturulur")
                }
                onDone()
            }
            .setNegativeButton("İptal", null)
            .show()
    }

    // ---------- İzinler (açıklamalı) ----------

    private fun disclose(title: String, msg: String, go: () -> Unit) {
        AlertDialog.Builder(this)
            .setTitle(title)
            .setMessage(msg)
            .setPositiveButton("Anladım, devam et") { _, _ -> go() }
            .setNegativeButton("Vazgeç", null)
            .show()
    }

    private fun askOverlay() = disclose(
        "Diğer uygulamaların üzerinde göster",
        "Kilit ekranı ve süre sayacı, çocuğun açtığı uygulamaların üstünde görünür. Bu izinle ekrandaki içerik okunmaz ya da kaydedilmez."
    ) {
        startActivity(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
        )
    }

    private fun askNotif() {
        if (Build.VERSION.SDK_INT >= 33) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        } else {
            toast("Bu Android sürümünde gerek yok")
        }
    }

    private fun askBattery() {
        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    private fun askUsage() = disclose(
        "Kullanım erişimi",
        "Bu izinle uygulama yalnızca o an ön planda hangi uygulamanın açık olduğunu öğrenir. " +
            "Arama ve WhatsApp açıkken kilit araya girmesin ve süre sadece uygulama içindeyken aksın diye kullanılır. " +
            "Bilgi cihazdan çıkmaz, kaydedilmez. İzin isteğe bağlıdır."
    ) {
        try {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        } catch (_: Exception) {
        }
        toast("Listeden \"$APP_NAME\" uygulamasını bulup aç")
    }

    // ---------- Panel ----------

    private fun showPanel() {
        store.parentUntil = System.currentTimeMillis() + GRACE_MS
        try {
            ContextCompat.startForegroundService(this, Intent(this, GuardService::class.java))
        } catch (_: Exception) {
        }
        authed = true

        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = Ui.dp(this@MainActivity, 20)
            setPadding(pad, pad, pad, pad)
        }
        col.text("Ebeveyn paneli", 24f, bold = true, top = 0)

        status = col.text("", 16f, Ui.MUTED, top = 12)
        perms = col.text("", 14f, Ui.MUTED, top = 12)

        col.text("İzinler", 18f, bold = true, top = 20)
        col.btn("1) Diğer uygulamaların üzerinde göster iznini ver", top = 8) { askOverlay() }
        col.btn("2) Bildirim izni ver", top = 8) { askNotif() }
        col.btn("3) Pil kısıtlamasını kaldır (arka planda kalsın)", top = 8) { askBattery() }
        col.btn("4) Kullanım erişimi ver (isteğe bağlı)", top = 8) { askUsage() }

        col.text("Çocuklar", 18f, bold = true, top = 20)
        for (c in store.children()) {
            col.btn("${c.name} · ${c.age} yaş · ${c.durationMin} dk", top = 8) { showChildMenu(c.id) }
        }
        if (store.children().size < Store.MAX_KIDS) {
            col.btn("+ Çocuk ekle", top = 8) { childDialog(null) { showPanel() } }
        }

        col.text("Ayarlar", 18f, bold = true, top = 20)
        col.btn("Ebeveyn şifresini değiştir", top = 8) {
            ask("Yeni ebeveyn şifresi", "Şifre", true) { s ->
                if (s.length < Store.MIN_LEN) {
                    toast("En az ${Store.MIN_LEN} karakter olmalı")
                } else {
                    store.setPassword(Store.PARENT, s)
                    toast("Ebeveyn şifresi değişti")
                }
            }
        }
        col.btn("Ödev saatleri (gün ve saat ekle / sil)", top = 8) { showHomework() }
        col.btn("Sayaç boyutunu değiştir", top = 8) {
            ask("Boyut (56-200, şu an ${store.overlaySizeDp})", "Örn. 96", false) { s ->
                val m = s.toIntOrNull()
                if (m == null) {
                    toast("Sayı gir")
                } else {
                    store.overlaySizeDp = m.coerceIn(56, 200)
                    toast("Sayaç boyutu: ${store.overlaySizeDp}")
                }
            }
        }
        val catBtn = Ui.button(this, "", {})
        fun catLabel() = "Sayaçta Kedi eğlencesi: ${if (store.catVisible) "AÇIK" else "KAPALI"}"
        catBtn.text = catLabel()
        catBtn.setOnClickListener {
            store.catVisible = !store.catVisible
            catBtn.text = catLabel()
        }
        col.addView(catBtn, Ui.lp(this, 0, 8))
        col.btn("Oturumu şimdi bitir", top = 8) {
            store.endSessionNow()
            toast("Oturum bitti. Sıradaki: ${store.label(store.next)}")
            updateStatus()
        }
        col.btn("Paneli kapat ve kilitle", top = 20) { finish() }

        setContentView(ScrollView(this).apply {
            setBackgroundColor(Ui.BG)
            addView(col)
        })
        updateStatus()
        updatePerms()
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }

    private fun showChildMenu(id: String) {
        val c = store.child(id) ?: return
        val items = arrayOf(
            "Adı ve yaşı değiştir",
            "Süreyi değiştir (şu an ${c.durationMin} dk)",
            "Şifresini sıfırla",
            "Çocuğu sil"
        )
        AlertDialog.Builder(this)
            .setTitle("${c.name} (${c.age} yaş, ${Store.groupName(c.group)})")
            .setItems(items) { _, i ->
                when (i) {
                    0 -> childDialog(c) { showPanel() }
                    1 -> ask("Süre (dakika, 5-600)", "Örn. ${Store.defaultMinutes(c.age)}", false) { s ->
                        val m = s.toIntOrNull()
                        if (m == null) {
                            toast("Sayı gir")
                        } else {
                            store.updateChild(c.copy(durationMin = m))
                            toast("Yeni süre: ${m.coerceIn(5, 600)} dk (sonraki girişten itibaren)")
                            showPanel()
                        }
                    }
                    2 -> confirmReset(c)
                    else -> confirmRemove(c)
                }
            }
            .setNegativeButton("Kapat", null)
            .show()
    }

    private fun confirmRemove(c: Store.Child) {
        AlertDialog.Builder(this)
            .setTitle("${c.name} silinsin mi?")
            .setMessage("Şifresi ve ayarları silinir. Bu geri alınamaz.")
            .setPositiveButton("Sil") { _, _ ->
                store.removeChild(c.id)
                toast("${c.name} silindi")
                showPanel()
            }
            .setNegativeButton("İptal", null)
            .show()
    }

    private fun updateStatus() {
        store.refresh()
        val kids = store.children()
        val now = when {
            kids.isEmpty() -> "Henüz çocuk eklenmedi."
            store.isActive() -> "Şu an: ${store.label(store.current)} (kalan ${Store.fmt(store.remainingMs())})"
            else -> "Şu an kimse girişli değil. Sıradaki: ${store.label(store.next)}"
        }
        val pws = if (kids.isEmpty()) "" else
            "Şifre durumu — " + kids.joinToString(", ") { "${it.name}: ${yn(store.hasPassword(it.id))}" } + "\n"
        val hw = store.homeworkActive()
        val hwLine = if (hw != null) {
            "ÖDEV ZAMANI şu an aktif (${Store.hm(hw.end)}'e kadar)"
        } else {
            "Ödev saati sayısı: ${store.homeworkSlots().size}"
        }
        val beat = store.beat
        val age = (System.currentTimeMillis() - beat) / 1000L
        val stale = beat == 0L || age >= 5L
        val svc = when {
            beat == 0L -> "Koruma servisi: henüz başlamadı"
            stale -> "Koruma servisi: DURMUŞ ($age sn) — yeniden başlatılıyor"
            else -> "Koruma servisi: ÇALIŞIYOR"
        }
        if (stale && authed) {
            try {
                ContextCompat.startForegroundService(this, Intent(this, GuardService::class.java))
            } catch (_: Exception) {
            }
        }
        status?.text = "$now\n$pws$hwLine\n$svc"
    }

    private fun updatePerms() {
        val overlay = Settings.canDrawOverlays(this)
        val notif = Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        perms?.text = "Üstte gösterme izni: ${yn(overlay)} | Bildirim izni: ${yn(notif)} | Kullanım erişimi: ${yn(Shortcuts.hasUsageAccess(this))}"
    }

    // ---------- Yardımcılar ----------

    private fun confirmReset(c: Store.Child) {
        AlertDialog.Builder(this)
            .setTitle("${c.name} şifresi sıfırlansın mı?")
            .setMessage("Bir sonraki girişinde yeni şifre oluşturacak.")
            .setPositiveButton("Sıfırla") { _, _ ->
                store.clearPassword(c.id)
                toast("${c.name} şifresi sıfırlandı")
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
}
