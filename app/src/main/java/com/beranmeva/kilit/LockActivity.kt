package com.beranmeva.kilit

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Dört hali var:
 *  - ÖDEV ZAMANI: şifre alanı yok, kimse giremez (sadece Ebeveyn düğmesi).
 *  - Normal giriş: sıradaki çocuk şifresini girer (5-8 yaş: 4 hayvan seçer).
 *  - İlk giriş: çocuk kendi şifresini oluşturur.
 *  - Çocuk tanımlı değilse: ebeveyni kuruluma yönlendirir.
 * Görünüm yaş grubuna göre değişir: küçüklerde büyük ve renkli, büyüklerde sade.
 */
class LockActivity : Activity() {

    companion object {
        @Volatile
        var visible = false
    }

    private lateinit var store: Store
    private var user = ""
    private var hwMode = false
    private var group = Store.Group.MID
    private var err: TextView? = null
    private var pw: EditText? = null
    private var pw2: EditText? = null
    private var go: Button? = null
    private val handler = Handler(Looper.getMainLooper())

    // 5-8 yaş: hayvan şifresi
    private val animalButtons = ArrayList<Button>()
    private var dots: TextView? = null
    private val picked = StringBuilder()
    private var pickFirst: String? = null
    private var note = ""

    private val poll = object : Runnable {
        override fun run() {
            recheck()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = Store(this)
        store.refresh()
        hwMode = store.homeworkActive() != null
        if (!hwMode && store.isActive()) {
            finish()
            return
        }
        user = store.next
        build()
    }

    override fun onResume() {
        super.onResume()
        visible = true
        recheck()
        handler.removeCallbacks(poll)
        handler.postDelayed(poll, 1000)
    }

    override fun onPause() {
        visible = false
        handler.removeCallbacks(poll)
        super.onPause()
    }

    // Geri tuşu kapalı: şifre girmeden bu ekrandan çıkılamaz.
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
    }

    /** Her saniye: ödev başladı/bitti mi, sıra değişti mi, oturum başladı mı? */
    private fun recheck() {
        if (isFinishing) return
        store.refresh()
        val hw = store.homeworkActive() != null
        if (!hw && store.isActive()) {
            finish()
            return
        }
        if (hw != hwMode || (!hw && store.next != user)) {
            hwMode = hw
            user = store.next
            pickFirst = null
            picked.setLength(0)
            build()
        }
        if (!hwMode) updateLockout()
    }

    // ---------- Görünüm yardımcıları ----------

    private val k get() = if (group == Store.Group.SMALL) 1.25f else 1f

    private fun bgColor() = when (group) {
        Store.Group.SMALL -> 0xFF2B1B5E.toInt()
        Store.Group.MID -> Ui.BG
        Store.Group.TEEN -> 0xFF14171C.toInt()
    }

    private fun muted() = when (group) {
        Store.Group.SMALL -> 0xFFD9CFFF.toInt()
        else -> Ui.MUTED
    }

    private fun big(b: Button): Button {
        if (group == Store.Group.SMALL) {
            b.textSize = 20f
            b.minHeight = Ui.dp(this, 60)
        }
        return b
    }

    private fun newRoot(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(bgColor())
        val pad = Ui.dp(this@LockActivity, 32)
        setPadding(pad, pad, pad, pad)
    }

    private fun build() {
        val c = store.child(user)
        val hw = store.homeworkActive()
        // Ödevde sıradaki çocuğun yaş grubuna göre görünür; çocuk yoksa orta grup.
        group = (c ?: store.child(store.next))?.group ?: Store.Group.MID
        val root = newRoot()

        err = null
        pw = null
        pw2 = null
        go = null
        dots = null
        animalButtons.clear()

        // ---------- Çocuk tanımlı değil ----------
        if (store.children().isEmpty()) {
            root.addView(Ui.tv(this, "KURULUM BEKLENİYOR", 28f, bold = true), Ui.lp(this, widthDp = 0))
            root.addView(
                Ui.tv(this, "Ebeveyn düğmesinden girip çocukları ekleyin.", 16f, muted()),
                Ui.lp(this, widthDp = 0, topDp = 12)
            )
            root.addView(parentButton(), Ui.lp(this, topDp = 40))
            setContentView(root)
            return
        }

        // ---------- Ödev zamanı ----------
        if (hw != null) {
            val title = when (group) {
                Store.Group.SMALL -> "📚 ÖDEV ZAMANI"
                else -> "ÖDEV ZAMANI"
            }
            val text = when (group) {
                Store.Group.SMALL ->
                    "${Store.hm(hw.end)} olunca oynayabilirsin.\nŞimdi ödevini yapalım!"
                Store.Group.MID ->
                    "${Store.hm(hw.end)} saatine kadar hiçbir uygulama açılamaz.\nÖdevini yap!"
                Store.Group.TEEN ->
                    "Ödev saati. ${Store.hm(hw.end)} saatine kadar uygulamalar kapalı."
            }
            root.addView(Ui.tv(this, title, 34f * k, bold = true), Ui.lp(this, widthDp = 0))
            root.addView(Ui.tv(this, text, 18f * k, muted()), Ui.lp(this, widthDp = 0, topDp = 12))
            root.addView(big(parentButton()), Ui.lp(this, topDp = 48))
            addShortcuts(root)
            setContentView(root)
            return
        }

        // ---------- Şifre girişi / oluşturma ----------
        val creating = !store.hasPassword(user)

        root.addView(
            Ui.tv(
                this,
                (if (group == Store.Group.SMALL) "🌟 " else "") +
                    (if (creating) store.createPrompt(user) else store.enterPrompt(user)),
                26f * k,
                bold = true
            ),
            Ui.lp(this, widthDp = 0)
        )

        if (group == Store.Group.SMALL) {
            buildAnimals(root, c, creating)
        } else {
            buildText(root, c, creating)
        }

        root.addView(big(parentButton()), Ui.lp(this, topDp = 40))
        addShortcuts(root)
        setContentView(root)
    }

    private fun parentButton(): Button = Ui.button(this, "Ebeveyn") {
        startActivity(Intent(this, MainActivity::class.java))
    }

    private fun buildText(root: LinearLayout, c: Store.Child?, creating: Boolean) {
        val mins = c?.durationMin ?: store.durationMin
        root.addView(
            Ui.tv(
                this,
                if (creating) "İlk giriş: kendi şifreni belirle (en az ${Store.MIN_LEN} karakter)"
                else "Giriş yapınca ${Store.fmt(mins * 60_000L)} kullanabilirsin",
                15f,
                muted()
            ),
            Ui.lp(this, widthDp = 0, topDp = 8)
        )

        val first = Ui.pwField(this, "Şifre")
        pw = first
        root.addView(first, Ui.lp(this, topDp = 24))

        var second: EditText? = null
        if (creating) {
            val again = Ui.pwField(this, "Şifre (tekrar)")
            second = again
            root.addView(again, Ui.lp(this, topDp = 8))
        }
        pw2 = second

        val last = second ?: first
        last.imeOptions = EditorInfo.IME_ACTION_DONE
        last.setOnEditorActionListener { _, _, _ ->
            submit()
            true
        }

        val e = Ui.tv(this, "", 14f, Ui.ERROR)
        err = e
        root.addView(e, Ui.lp(this, topDp = 8))

        val g = Ui.button(this, if (creating) "Şifreyi kaydet ve gir" else "Giriş") { submit() }
        go = g
        root.addView(g, Ui.lp(this, topDp = 16))
    }

    /** 5-8 yaş: klavye yok; 8 hayvandan 4 tanesini sırayla seçer. */
    private fun buildAnimals(root: LinearLayout, c: Store.Child?, creating: Boolean) {
        val mins = c?.durationMin ?: store.durationMin
        val sub = when {
            creating && pickFirst == null ->
                "Bu senin gizli şifren! 4 hayvan seç, sonra aynısını bir daha seçeceksin."
            creating -> "Şimdi aynı 4 hayvanı aynı sırayla bir daha seç."
            else -> "Giriş yapınca ${Store.fmt(mins * 60_000L)} oynayabilirsin."
        }
        root.addView(Ui.tv(this, sub, 17f, muted()), Ui.lp(this, widthDp = 0, topDp = 10))

        val d = Ui.tv(this, "", 30f, Color.WHITE)
        dots = d
        root.addView(d, Ui.lp(this, widthDp = 0, topDp = 16))
        updateDots()

        for (r in 0..1) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }
            for (col in 0..3) {
                val i = r * 4 + col
                val b = Ui.button(this, Store.ANIMALS[i]) { pickAnimal(i) }
                b.textSize = 34f
                animalButtons.add(b)
                val lp = LinearLayout.LayoutParams(Ui.dp(this, 84), Ui.dp(this, 84))
                lp.setMargins(Ui.dp(this, 6), Ui.dp(this, 6), Ui.dp(this, 6), Ui.dp(this, 6))
                row.addView(b, lp)
            }
            root.addView(row, Ui.lp(this, widthDp = 0, topDp = if (r == 0) 12 else 0))
        }

        val e = Ui.tv(this, note, 16f, Ui.ERROR)
        note = ""
        err = e
        root.addView(e, Ui.lp(this, topDp = 8))

        root.addView(
            big(Ui.button(this, "⌫ Sil") {
                if (picked.isNotEmpty()) picked.setLength(picked.length - 1)
                updateDots()
            }),
            Ui.lp(this, widthDp = 160, topDp = 4)
        )
    }

    private fun updateDots() {
        dots?.text = (0 until Store.ANIMAL_PIN_LEN).joinToString("  ") { if (it < picked.length) "●" else "○" }
    }

    private fun pickAnimal(i: Int) {
        if (store.lockoutLeftMs() > 0) {
            updateLockout()
            return
        }
        picked.append(i)
        updateDots()
        if (picked.length >= Store.ANIMAL_PIN_LEN) {
            val v = picked.toString()
            picked.setLength(0)
            onAnimalPin(v)
        }
    }

    private fun onAnimalPin(v: String) {
        // Ödev saati bu arada başladıysa giriş yapılamaz.
        if (store.homeworkActive() != null) {
            recheck()
            return
        }
        if (!store.hasPassword(user)) {
            val first = pickFirst
            if (first == null) {
                pickFirst = v
                build()
            } else if (first == v) {
                pickFirst = null
                store.setPassword(user, v)
                enter()
            } else {
                pickFirst = null
                note = "Aynı olmadı. Baştan seç."
                build()
            }
        } else if (store.check(user, v)) {
            store.resetFails()
            enter()
        } else {
            store.registerFail()
            updateDots()
            err?.text = "Olmadı, tekrar dene"
            updateLockout()
        }
    }

    /** Güvenlik: Arama ve WhatsApp şifresiz, ödev saatinde de açılır. */
    private fun addShortcuts(root: LinearLayout) {
        root.addView(
            Ui.tv(this, "Şifresiz açılır (güvenlik):", 14f, muted()),
            Ui.lp(this, widthDp = 0, topDp = 32)
        )
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val lp = LinearLayout.LayoutParams(Ui.dp(this, 150), LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.setMargins(Ui.dp(this, 6), 0, Ui.dp(this, 6), 0)
        row.addView(big(Ui.button(this, "📞 Ara") { Shortcuts.open(this, store, "call") }), lp)
        row.addView(big(Ui.button(this, "💬 WhatsApp") { Shortcuts.open(this, store, "wa") }), lp)
        root.addView(row, Ui.lp(this, widthDp = 0, topDp = 8))
    }

    private fun updateLockout() {
        val e = err ?: return
        val left = store.lockoutLeftMs()
        val g = go
        if (g != null) {
            if (left > 0) {
                g.isEnabled = false
                e.text = "Çok fazla yanlış deneme. ${(left + 999) / 1000} sn bekle"
            } else if (!g.isEnabled) {
                g.isEnabled = true
                e.text = ""
            }
        }
        if (animalButtons.isNotEmpty()) {
            if (left > 0) {
                animalButtons.forEach { it.isEnabled = false }
                e.text = "Biraz bekle: ${(left + 999) / 1000} sn"
            } else if (!animalButtons[0].isEnabled) {
                animalButtons.forEach { it.isEnabled = true }
                e.text = ""
            }
        }
    }

    private fun submit() {
        val field = pw ?: return
        if (store.lockoutLeftMs() > 0) {
            updateLockout()
            return
        }
        // Ödev saati bu arada başladıysa giriş yapılamaz.
        if (store.homeworkActive() != null) {
            recheck()
            return
        }
        val a = field.text.toString()
        val e = err

        if (!store.hasPassword(user)) {
            val b = pw2?.text?.toString() ?: ""
            if (a.length < Store.MIN_LEN) {
                e?.text = "En az ${Store.MIN_LEN} karakter olmalı"
                return
            }
            if (a != b) {
                e?.text = "Şifreler aynı değil"
                return
            }
            store.setPassword(user, a)
            enter()
        } else if (store.check(user, a)) {
            store.resetFails()
            enter()
        } else {
            store.registerFail()
            field.text.clear()
            e?.text = "Şifre yanlış"
            updateLockout()
        }
    }

    private fun enter() {
        store.startSession(user)
        finish()
    }
}
