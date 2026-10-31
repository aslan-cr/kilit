package com.beranmeva.kilit

import android.app.Activity
import android.content.Intent
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
 * Üç hali var:
 *  - ÖDEV ZAMANI: şifre alanı yok, kimse giremez (sadece Ebeveyn düğmesi).
 *  - "BERANIN ŞİFRESİNİ GİR" / "MEVANIN ŞİFRESİNİ GİR": normal giriş.
 *  - İlk giriş: şifre oluşturma.
 */
class LockActivity : Activity() {

    companion object {
        @Volatile
        var visible = false
    }

    private lateinit var store: Store
    private var user = ""
    private var hwMode = false
    private var err: TextView? = null
    private var pw: EditText? = null
    private var pw2: EditText? = null
    private var go: Button? = null
    private val handler = Handler(Looper.getMainLooper())

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
            build()
        }
        if (!hwMode) updateLockout()
    }

    private fun build() {
        val hw = store.homeworkActive()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Ui.BG)
            val pad = Ui.dp(this@LockActivity, 32)
            setPadding(pad, pad, pad, pad)
        }

        // ---------- Ödev zamanı ----------
        if (hw != null) {
            err = null
            pw = null
            pw2 = null
            go = null
            root.addView(Ui.tv(this, "ÖDEV ZAMANI", 34f, bold = true), Ui.lp(this, widthDp = 0))
            root.addView(
                Ui.tv(
                    this,
                    "${Store.hm(hw.end)} saatine kadar hiçbir uygulama açılamaz.\nÖdevini yap!",
                    18f,
                    Ui.MUTED
                ),
                Ui.lp(this, widthDp = 0, topDp = 12)
            )
            root.addView(
                Ui.button(this, "Ebeveyn") {
                    startActivity(Intent(this, MainActivity::class.java))
                },
                Ui.lp(this, topDp = 48)
            )
            setContentView(root)
            return
        }

        // ---------- Şifre girişi / oluşturma ----------
        val creating = !store.hasPassword(user)

        root.addView(
            Ui.tv(
                this,
                if (creating) Store.createPrompt(user) else Store.enterPrompt(user),
                26f,
                bold = true
            ),
            Ui.lp(this, widthDp = 0)
        )
        root.addView(
            Ui.tv(
                this,
                if (creating) "İlk giriş: kendi şifreni belirle (en az ${Store.MIN_LEN} karakter)"
                else "Giriş yapınca ${Store.fmt(store.durationMin * 60_000L)} kullanabilirsin",
                15f,
                Ui.MUTED
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

        root.addView(
            Ui.button(this, "Ebeveyn") {
                startActivity(Intent(this, MainActivity::class.java))
            },
            Ui.lp(this, topDp = 48)
        )

        setContentView(root)
    }

    private fun updateLockout() {
        val g = go ?: return
        val e = err ?: return
        val left = store.lockoutLeftMs()
        if (left > 0) {
            g.isEnabled = false
            e.text = "Çok fazla yanlış deneme. ${(left + 999) / 1000} sn bekle"
        } else if (!g.isEnabled) {
            g.isEnabled = true
            e.text = ""
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
