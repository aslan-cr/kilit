package com.beranmeva.kilit

import android.content.Context
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.Locale
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/**
 * Şifreler (PBKDF2 ile hash'li), çocuk listesi ve oturum durumu burada tutulur.
 * 1-4 çocuk tanımlanabilir; sıra çocuklar arasında sırayla döner.
 */
class Store(context: Context) {

    private val p = context.applicationContext
        .getSharedPreferences("kilit", Context.MODE_PRIVATE)

    /** Yaş grupları: ekran dili ve hazır süreler buna göre seçilir. */
    enum class Group { SMALL, MID, TEEN }

    /** id: kalıcı kimlik ("c1".."c4"; eski kurulumlarda "beran"/"meva"). */
    data class Child(val id: String, val name: String, val age: Int, val durationMin: Int) {
        val group: Group get() = groupOf(age)
    }

    companion object {
        const val PARENT = "parent"
        const val MIN_LEN = 4

        const val MAX_KIDS = 4
        const val MIN_AGE = 5
        const val MAX_AGE = 15
        const val MAX_NAME = 10

        /** Eski (sadece iki çocuklu) kurulumlardaki kimlikler; veriyi taşımak için. */
        private const val LEGACY_A = "beran"
        private const val LEGACY_B = "meva"

        /** Sayaç renkleri: mavi, yeşil, turuncu, kırmızı, mor, pembe, sarı, turkuaz. */
        val COLORS = intArrayOf(
            0xFF2D9CDB.toInt(), 0xFF27AE60.toInt(), 0xFFF2994A.toInt(), 0xFFEB5757.toInt(),
            0xFFBB6BD9.toInt(), 0xFFE91E8C.toInt(), 0xFFF2C94C.toInt(), 0xFF2EC4B6.toInt()
        )

        /** Çocukların sırasına göre başlangıç renkleri: mavi, pembe, yeşil, mor. */
        private val DEFAULT_COLOR_ORDER = intArrayOf(0, 5, 1, 4)

        val IDLE_COLOR = 0xFF607D8B.toInt()
        val HW_COLOR = 0xFFD35400.toInt()

        /** Küçüklerin şifresi: 4 hayvan seçmek (her hayvan 0-7 arası bir rakam). */
        val ANIMALS = arrayOf("🐱", "🐶", "🐸", "🦊", "🐼", "🐰", "🦁", "🐵")
        const val ANIMAL_PIN_LEN = 4

        private val TR = Locale.forLanguageTag("tr-TR")

        fun groupOf(age: Int): Group = when {
            age <= 8 -> Group.SMALL
            age <= 12 -> Group.MID
            else -> Group.TEEN
        }

        fun groupName(g: Group) = when (g) {
            Group.SMALL -> "5-8 yaş"
            Group.MID -> "9-12 yaş"
            Group.TEEN -> "13-15 yaş"
        }

        /**
         * Yaş grubuna göre önerilen günlük süre (dakika). Bu bir başlangıç önerisidir;
         * ebeveyn her çocuk için değiştirebilir. Her çocuk kendi sırasında bu kadar kullanır.
         */
        fun defaultMinutes(age: Int): Int = when (groupOf(age)) {
            Group.SMALL -> 60
            Group.MID -> 90
            Group.TEEN -> 120
        }

        /** Yaş grubuna göre önerilen ödev saati (hafta içi). */
        fun suggestedHomework(age: Int): Hw = when (groupOf(age)) {
            Group.SMALL -> Hw("12345", 17 * 60, 17 * 60 + 30)
            Group.MID -> Hw("12345", 16 * 60 + 30, 18 * 60)
            Group.TEEN -> Hw("12345", 17 * 60, 19 * 60)
        }

        /** Ad alanında kayıt biçimini bozacak karakterleri temizler. */
        fun cleanName(s: String): String =
            s.replace(Regex("[|;\\r\\n]"), " ").trim().take(MAX_NAME).trim()

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

    // ---------- Çocuklar ----------

    /**
     * Kayıt biçimi: "id|ad|yaş|süre;id|ad|yaş|süre".
     * "kids" anahtarı hiç yoksa ve cihazda eski (Bera-Meva) kurulumun izi varsa, iki çocuk
     * olarak otomatik taşınır; böylece güncelleyen aileler şifrelerini kaybetmez.
     */
    private fun migrateIfNeeded() {
        if (p.contains("kids")) return
        // Yeni sihirbaz ebeveyn şifresiyle birlikte "kids" anahtarını da yazar; bu yüzden
        // "kids" olmadan ebeveyn/çocuk şifresi varsa kurulum eski sürümden kalmadır.
        val legacy = p.contains("h_$LEGACY_A") || p.contains("h_$LEGACY_B") || p.contains("h_$PARENT")
        if (!legacy) return
        val dur = p.getInt("durationMin", 120)
        val raw = "$LEGACY_A|Bera|10|$dur;$LEGACY_B|Meva|10|$dur"
        p.edit().putString("kids", raw).apply()
    }

    private fun parseKids(raw: String): List<Child> =
        raw.split(";").mapNotNull { s ->
            val a = s.split("|")
            if (a.size != 4) return@mapNotNull null
            val age = a[2].toIntOrNull() ?: return@mapNotNull null
            val dur = a[3].toIntOrNull() ?: return@mapNotNull null
            Child(a[0], a[1], age, dur)
        }

    private fun saveKids(list: List<Child>) {
        p.edit().putString("kids", list.joinToString(";") { "${it.id}|${it.name}|${it.age}|${it.durationMin}" })
            .apply()
    }

    /** Kurulum sihirbazı ebeveyn şifresini yazarken çağrılır: boş bir çocuk listesi başlatır. */
    fun initKids() {
        if (!p.contains("kids")) p.edit().putString("kids", "").apply()
    }

    fun children(): List<Child> {
        migrateIfNeeded()
        return parseKids(p.getString("kids", "") ?: "")
    }

    fun child(id: String): Child? = children().firstOrNull { it.id == id }

    fun addChild(name: String, age: Int): Child? {
        val list = children()
        if (list.size >= MAX_KIDS) return null
        val n = cleanName(name)
        if (n.isEmpty()) return null
        val a = age.coerceIn(MIN_AGE, MAX_AGE)
        var i = 1
        while (list.any { it.id == "c$i" }) i++
        val c = Child("c$i", n, a, defaultMinutes(a))
        saveKids(list + c)
        return c
    }

    /** Ad, yaş, süre değişir. Yaş grubu değişirse şifre biçimi de değiştiği için şifre sıfırlanır. */
    fun updateChild(c: Child) {
        val list = children()
        val old = list.firstOrNull { it.id == c.id } ?: return
        val clean = c.copy(
            name = cleanName(c.name).ifEmpty { old.name },
            age = c.age.coerceIn(MIN_AGE, MAX_AGE),
            durationMin = c.durationMin.coerceIn(5, 600)
        )
        if (old.group != clean.group) clearPassword(c.id)
        saveKids(list.map { if (it.id == c.id) clean else it })
    }

    fun removeChild(id: String) {
        val list = children()
        if (list.none { it.id == id }) return
        val wasCurrent = current == id
        clearPassword(id)
        p.edit().remove("ci_$id").apply()
        saveKids(list.filter { it.id != id })
        if (wasCurrent) {
            current = ""
            sessionEnd = 0L
        }
        if (next == id || children().none { it.id == next }) next = firstId()
    }

    private fun firstId(): String = children().firstOrNull()?.id ?: ""

    /** Listede bir sonraki çocuk (sondan sonra başa döner). */
    fun after(id: String): String {
        val list = children()
        if (list.isEmpty()) return ""
        val i = list.indexOfFirst { it.id == id }
        return list[(i + 1).mod(list.size)].id
    }

    fun nameOf(id: String): String = child(id)?.name ?: ""

    /** Ekranda büyük harfle gösterilen ad ("EBEVEYN" ebeveyn için). */
    fun label(id: String): String =
        if (id == PARENT) "EBEVEYN" else nameOf(id).uppercase(TR)

    fun enterPrompt(id: String): String = when {
        id == PARENT -> "EBEVEYN ŞİFRESİNİ GİR"
        child(id)?.group == Group.SMALL -> "${label(id)}, 4 HAYVANINI SEÇ"
        else -> "${label(id)}, ŞİFRENİ GİR"
    }

    fun createPrompt(id: String): String = when {
        id == PARENT -> "EBEVEYN ŞİFRESİ OLUŞTUR"
        child(id)?.group == Group.SMALL -> "${label(id)}, GİZLİ 4 HAYVANINI SEÇ"
        else -> "${label(id)}, ŞİFRENİ OLUŞTUR"
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

    /** Şu an kullanan çocuk ("" = kimse). */
    var current: String
        get() = p.getString("current", "") ?: ""
        set(v) = p.edit().putString("current", v).apply()

    var sessionEnd: Long
        get() = p.getLong("sessionEnd", 0L)
        set(v) = p.edit().putLong("sessionEnd", v).apply()

    /** Sıradaki çocuk. Kayıtlı kişi artık listede yoksa ilk çocuğa döner. */
    var next: String
        get() {
            val v = p.getString("next", "") ?: ""
            return if (v.isNotEmpty() && child(v) != null) v else firstId()
        }
        set(v) = p.edit().putString("next", v).apply()

    var lastDay: String
        get() = p.getString("lastDay", "") ?: ""
        set(v) = p.edit().putString("lastDay", v).apply()

    /** Eski tek süre ayarı; yalnızca eski kurulumlardan taşımak için okunur. */
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

    /** Süresi dolan oturumu kapatır, sırayı ayarlar. Her yeni gün sıra listedeki ilk çocuktan başlar. */
    fun refresh() {
        if (current.isNotEmpty() && System.currentTimeMillis() >= sessionEnd) {
            next = after(current)
            current = ""
            sessionEnd = 0L
        }
        if (current.isEmpty() && lastDay != LocalDate.now().toString()) {
            next = firstId()
        }
    }

    fun startSession(u: String) {
        val min = child(u)?.durationMin ?: durationMin
        current = u
        sessionEnd = System.currentTimeMillis() + min * 60_000L
        sessionTotal = min * 60_000L
        lastDay = LocalDate.now().toString()
        next = after(u)
    }

    fun endSessionNow() {
        if (current.isNotEmpty()) {
            next = after(current)
        }
        current = ""
        sessionEnd = 0L
    }

    // ---------- Sayaç (ekrandaki yuvarlak) ----------

    var sessionTotal: Long
        get() = p.getLong("sessionTotal", 0L)
        set(v) = p.edit().putLong("sessionTotal", v).apply()

    /** Çocuğun seçtiği renk. Seçmediyse sırasına göre mavi, pembe, yeşil, mor. */
    fun colorIndex(u: String): Int {
        val pos = children().indexOfFirst { it.id == u }.coerceAtLeast(0)
        val def = DEFAULT_COLOR_ORDER[pos % DEFAULT_COLOR_ORDER.size]
        return p.getInt("ci_$u", def).mod(COLORS.size)
    }

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

    /**
     * Sayaçta "Kedi" kutusu görünsün mü (ebeveyn paneli / kurulum). Daha önce kurulu olanlarda
     * açık kalır; yeni kurulumda sadece 13 yaş altı çocuk varsa açık başlar.
     */
    var catVisible: Boolean
        get() = p.getBoolean("catVisible", true)
        set(v) = p.edit().putBoolean("catVisible", v).apply()

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
