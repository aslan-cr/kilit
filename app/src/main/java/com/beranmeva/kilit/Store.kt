package com.beranmeva.kilit

import android.content.Context
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.LocalDate
import java.time.LocalDateTime
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

        /** Sayaç renkleri: mavi, yeşil, turuncu, kırmızı, mor, pembe, sarı, turkuaz. */
        val COLORS = intArrayOf(
            0xFF2D9CDB.toInt(), 0xFF27AE60.toInt(), 0xFFF2994A.toInt(), 0xFFEB5757.toInt(),
            0xFFBB6BD9.toInt(), 0xFFE91E8C.toInt(), 0xFFF2C94C.toInt(), 0xFF2EC4B6.toInt()
        )
        val IDLE_COLOR = 0xFF607D8B.toInt()
        val HW_COLOR = 0xFFD35400.toInt()

        fun other(u: String) = if (u == BERAN) MEVA else BERAN

        fun label(u: String) = when (u) {
            BERAN -> "BERA"
            MEVA -> "MEVA"
            else -> "EBEVEYN"
        }

        fun enterPrompt(u: String) = when (u) {
            BERAN -> "BERA'NIN ŞİFRESİNİ GİR"
            MEVA -> "MEVANIN ŞİFRESİNİ GİR"
            else -> "EBEVEYN ŞİFRESİNİ GİR"
        }

        fun createPrompt(u: String) = when (u) {
            BERAN -> "BERA İÇİN ŞİFRE OLUŞTUR"
            MEVA -> "MEVA İÇİN ŞİFRE OLUŞTUR"
            else -> "EBEVEYN ŞİFRESİ OLUŞTUR"
        }

        val DAY_NAMES = arrayOf(
            "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"
        )

        fun hm(min: Int): String = "%02d:%02d".format(min / 60, min % 60)

        fun hwLabel(h: Hw): String {
            val days = h.days.map { DAY_NAMES[it - '1'].take(3) }.joinToString(" ")
            return "$days  ${hm(h.start)} - ${hm(h.end)}"
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

    var screenOffAt: Long
        get() = p.getLong("screenOffAt", 0L)
        set(v) = p.edit().putLong("screenOffAt", v).apply()

    var shortcutUntil: Long
        get() = p.getLong("shortcutUntil", 0L)
        set(v) = p.edit().putLong("shortcutUntil", v).apply()

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
        sessionTotal = durationMin * 60_000L
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

    // ---------- Sayaç (ekrandaki yuvarlak) ----------

    var sessionTotal: Long
        get() = p.getLong("sessionTotal", 0L)
        set(v) = p.edit().putLong("sessionTotal", v).apply()

    /** Kullanıcının seçtiği renk sırası. Beran mavi, Meva pembe ile başlar. */
    fun colorIndex(u: String): Int =
        p.getInt("ci_$u", if (u == MEVA) 5 else 0).mod(COLORS.size)

    fun nextColor(u: String) {
        p.edit().putInt("ci_$u", (colorIndex(u) + 1) % COLORS.size).apply()
    }

    var overlayX: Int
        get() = p.getInt("ox", -1)
        set(v) = p.edit().putInt("ox", v).apply()

    var overlayY: Int
        get() = p.getInt("oy", -1)
        set(v) = p.edit().putInt("oy", v).apply()

    /** Sayaç boyutu (dp). */
    var overlaySizeDp: Int
        get() = p.getInt("osz", 96)
        set(v) = p.edit().putInt("osz", v).apply()

    /** Sayaç hangi kenara yapışık: 0 yok, 1 sol, 2 sağ, 3 üst, 4 alt. */
    var overlayDock: Int
        get() = p.getInt("odock", 0)
        set(v) = p.edit().putInt("odock", v).apply()

    /** Sayaçtaki "Kedi" ayarı: açıkken kedi partisi ve altta gezen kediler. */
    var catOn: Boolean
        get() = p.getBoolean("cat", false)
        set(v) = p.edit().putBoolean("cat", v).apply()

    /** Koruma servisinin son çalıştığı an (ebeveyn panelinde durumunu göstermek için). */
    var beat: Long
        get() = p.getLong("beat", 0L)
        set(v) = p.edit().putLong("beat", v).apply()

    // ---------- Ödev saatleri ----------

    /** days: "1".."7" rakamları (1 = Pazartesi). start/end: gün içi dakika (0-1439). */
    data class Hw(val days: String, val start: Int, val end: Int)

    private var hwRaw: String
        get() = p.getString("hw", "") ?: ""
        set(v) = p.edit().putString("hw", v).apply()

    fun homeworkSlots(): List<Hw> =
        hwRaw.split(";").mapNotNull { s ->
            val a = s.split("|")
            if (a.size != 3) return@mapNotNull null
            val st = a[1].toIntOrNull() ?: return@mapNotNull null
            val en = a[2].toIntOrNull() ?: return@mapNotNull null
            Hw(a[0], st, en)
        }

    private fun saveSlots(list: List<Hw>) {
        hwRaw = list.joinToString(";") { "${it.days}|${it.start}|${it.end}" }
    }

    fun addHomework(h: Hw) = saveSlots(homeworkSlots() + h)

    fun removeHomework(i: Int) {
        val l = homeworkSlots().toMutableList()
        if (i in l.indices) {
            l.removeAt(i)
            saveSlots(l)
        }
    }

    /** Şu an ödev saatindeyse o aralığı, değilse null döner. */
    fun homeworkActive(): Hw? {
        val n = LocalDateTime.now()
        val dow = n.dayOfWeek.value.toString()
        val m = n.hour * 60 + n.minute
        return homeworkSlots().firstOrNull {
            it.days.contains(dow) && m >= it.start && m < it.end
        }
    }
}
