package com.beranmeva.kilit

import android.content.Context
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.LocalDate
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/** Şifreler (PBKDF2 ile hash'li) ve oturum durumu burada tutulur. */
class Store(context: Context) {

    private val p = context.applicationContext
        .getSharedPreferences("kilit", Context.MODE_PRIVATE)

    companion object {
        const val BERAN = "beran"
        const val MEVA = "meva"
        const val PARENT = "parent"
        const val MIN_LEN = 4

        fun other(u: String) = if (u == BERAN) MEVA else BERAN

        fun label(u: String) = when (u) {
            BERAN -> "BERAN"
            MEVA -> "MEVA"
            else -> "EBEVEYN"
        }

        fun enterPrompt(u: String) = when (u) {
            BERAN -> "BERANIN ŞİFRESİNİ GİR"
            MEVA -> "MEVANIN ŞİFRESİNİ GİR"
            else -> "EBEVEYN ŞİFRESİNİ GİR"
        }

        fun createPrompt(u: String) = when (u) {
            BERAN -> "BERAN İÇİN ŞİFRE OLUŞTUR"
            MEVA -> "MEVA İÇİN ŞİFRE OLUŞTUR"
            else -> "EBEVEYN ŞİFRESİ OLUŞTUR"
        }

        fun fmt(ms: Long): String {
            val totalMin = (ms + 59_999L) / 60_000L
            val h = totalMin / 60
            val m = totalMin % 60
            return if (h > 0) "$h sa $m dk" else "$m dk"
        }
    }

    // ---------- Şifreler ----------

    private fun hash(pw: String, salt: ByteArray): String {
        val spec = PBEKeySpec(pw.toCharArray(), salt, 20000, 256)
        val bytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA1")
            .generateSecret(spec).encoded
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    fun hasPassword(u: String) = p.contains("h_$u")

    fun setPassword(u: String, pw: String) {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        p.edit()
            .putString("s_$u", Base64.encodeToString(salt, Base64.NO_WRAP))
            .putString("h_$u", hash(pw, salt))
            .apply()
    }

    fun clearPassword(u: String) {
        p.edit().remove("s_$u").remove("h_$u").apply()
    }

    fun check(u: String, pw: String): Boolean {
        val s = p.getString("s_$u", null) ?: return false
        val h = p.getString("h_$u", null) ?: return false
        val calc = hash(pw, Base64.decode(s, Base64.NO_WRAP))
        return MessageDigest.isEqual(calc.toByteArray(), h.toByteArray())
    }

    // ---------- Yanlış deneme koruması ----------

    private var fails: Int
        get() = p.getInt("fails", 0)
        set(v) = p.edit().putInt("fails", v).apply()

    private var lockoutUntil: Long
        get() = p.getLong("lockoutUntil", 0L)
        set(v) = p.edit().putLong("lockoutUntil", v).apply()

    fun lockoutLeftMs(): Long =
        (lockoutUntil - System.currentTimeMillis()).coerceAtLeast(0L)

    fun registerFail() {
        fails += 1
        if (fails >= 5) {
            lockoutUntil = System.currentTimeMillis() + 30_000L
            fails = 0
        }
    }

    fun resetFails() {
        fails = 0
    }

    // ---------- Oturum ----------

    /** Şu an kullanan kişi ("" = kimse). */
    var current: String
        get() = p.getString("current", "") ?: ""
        set(v) = p.edit().putString("current", v).apply()

    var sessionEnd: Long
        get() = p.getLong("sessionEnd", 0L)
        set(v) = p.edit().putLong("sessionEnd", v).apply()

    /** Sıradaki kişi. */
    var next: String
        get() = p.getString("next", BERAN) ?: BERAN
        set(v) = p.edit().putString("next", v).apply()

    var lastDay: String
        get() = p.getString("lastDay", "") ?: ""
        set(v) = p.edit().putString("lastDay", v).apply()

    var durationMin: Int
        get() = p.getInt("durationMin", 120)
        set(v) = p.edit().putInt("durationMin", v).apply()

    /** Ebeveyn paneli açıkken kilidin araya girmemesi için geçici süre. */
    var parentUntil: Long
        get() = p.getLong("parentUntil", 0L)
        set(v) = p.edit().putLong("parentUntil", v).apply()

    fun parentGraceActive() = System.currentTimeMillis() < parentUntil

    fun isActive() = current.isNotEmpty() && System.currentTimeMillis() < sessionEnd

    fun remainingMs(): Long =
        if (current.isEmpty()) 0L
        else (sessionEnd - System.currentTimeMillis()).coerceAtLeast(0L)

    /** Süresi dolan oturumu kapatır, sırayı ayarlar. Her yeni gün sıra BERAN'dan başlar. */
    fun refresh() {
        if (current.isNotEmpty() && System.currentTimeMillis() >= sessionEnd) {
            next = other(current)
            current = ""
            sessionEnd = 0L
        }
        if (current.isEmpty() && lastDay != LocalDate.now().toString()) {
            next = BERAN
        }
    }

    fun startSession(u: String) {
        current = u
        sessionEnd = System.currentTimeMillis() + durationMin * 60_000L
        lastDay = LocalDate.now().toString()
        next = other(u)
    }

    fun endSessionNow() {
        if (current.isNotEmpty()) {
            next = other(current)
        }
        current = ""
        sessionEnd = 0L
    }
}
