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

/** "BERANIN ŞİFRESİNİ GİR" / "MEVANIN ŞİFRESİNİ GİR" ekranı. */
class LockActivity : Activity() {

    companion object {
        @Volatile
        var visible = false
    }

    private lateinit var store: Store
    private var user = ""
    private lateinit var err: TextView
    private lateinit var pw: EditText
    private var pw2: EditText? = null
    private lateinit var go: Button
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = Store(this)
        store.refresh()
        if (store.isActive()) {
            finish()
            return
        }
        user = store.next
        build()
    }

    override fun onResume() {
        super.onResume()
        visible = true
        store.refresh()
        if (store.isActive()) {
            finish()
            return
        }
        // Gün değiştiyse / sıra değiştiyse ekranı yenile.
        if (store.next != user) {
            user = store.next
            build()
        }
        if (::go.isInitialized) updateLockout()
    }

    override fun onPause() {
        visible = false
        super.onPause()
    }

    // Geri tuşu kapalı: şifre girmeden bu ekrandan çıkılamaz.
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
    }

    private fun build() {
        val creating = !store.hasPassword(user)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Ui.BG)
            val pad = Ui.dp(this@LockActivity, 32)
            setPadding(pad, pad, pad, pad)
        }

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

        pw = Ui.pwField(this, "Şifre")
        root.addView(pw, Ui.lp(this, topDp = 24))

        pw2 = null
        if (creating) {
            val again = Ui.pwField(this, "Şifre (tekrar)")
            pw2 = again
            root.addView(again, Ui.lp(this, topDp = 8))
        }

        val last = pw2 ?: pw
        last.imeOptions = EditorInfo.IME_ACTION_DONE
        last.setOnEditorActionListener { _, _, _ ->
            submit()
            true
        }

        err = Ui.tv(this, "", 14f, Ui.ERROR)
        root.addView(err, Ui.lp(this, topDp = 8))

        go = Ui.button(this, if (creating) "Şifreyi kaydet ve gir" else "Giriş") { submit() }
        root.addView(go, Ui.lp(this, topDp = 16))

        val parent = Ui.button(this, "Ebeveyn") {
            startActivity(Intent(this, MainActivity::class.java))
        }
        root.addView(parent, Ui.lp(this, topDp = 48))

        setContentView(root)
    }

    private fun updateLockout() {
        val left = store.lockoutLeftMs()
        if (left > 0) {
            go.isEnabled = false
            err.text = "Çok fazla yanlış deneme. ${(left + 999) / 1000} sn bekle"
            handler.postDelayed({ updateLockout() }, 500)
        } else if (!go.isEnabled) {
            go.isEnabled = true
            err.text = ""
        }
    }

    private fun submit() {
        if (store.lockoutLeftMs() > 0) {
            updateLockout()
            return
        }
        val a = pw.text.toString()

        if (!store.hasPassword(user)) {
            val b = pw2?.text?.toString() ?: ""
            if (a.length < Store.MIN_LEN) {
                err.text = "En az ${Store.MIN_LEN} karakter olmalı"
                return
            }
            if (a != b) {
                err.text = "Şifreler aynı değil"
                return
            }
            store.setPassword(user, a)
            enter()
        } else if (store.check(user, a)) {
            store.resetFails()
            enter()
        } else {
            store.registerFail()
            pw.text.clear()
            err.text = "Şifre yanlış"
            updateLockout()
        }
    }

    private fun enter() {
        store.startSession(user)
        finish()
    }
}
