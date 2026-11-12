package com.beranmeva.guncelle

import android.app.Activity
import android.app.AlertDialog
import android.app.PendingIntent
import android.content.Intent
import android.content.res.ColorStateList
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

/**
 * Güncelleyici: içine eklediğin APK dosyalarını listeler, kurulu sürümle karşılaştırır,
 * "Kur / Güncelle" der. Yeni sürüm dosyasını tekrar eklersen eskisinin yerine geçer.
 */
class MainActivity : Activity() {

    companion object {
        private const val REQ_PICK = 11
        private const val REPO = "aslan-cr/kilit"
        // Çizim kâğıdı teması: mürekkep mavisi, kâğıt, kırmızı kalem, sarı fosforlu
        private const val INK = 0xFF1D4A73.toInt()
        private const val BG = 0xFFE6EEF3.toInt()
        private const val GRID = 0xFFC6D6E1.toInt()
        private const val TEXT = 0xFF14283A.toInt()
        private const val MUTED = 0xFF4A6275.toInt()
        private const val CARD = 0xFFFFFFFF.toInt()
        private const val GOOD = 0xFF17653F.toInt()
        private const val WARN = 0xFF8A5A00.toInt()
        private const val RED = 0xFFD93A45.toInt()
    }

    data class Entry(
        val file: File,
        val pkg: String,
        val label: String,
        val vName: String,
        val vCode: Long
    )

    private lateinit var listBox: LinearLayout
    private lateinit var statusView: TextView

    private val dir: File
        get() = File(filesDir, "apks").also { it.mkdirs() }

    // ---------- Arayüz ----------

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GridPaper(BG, GRID, dp(48).toFloat())
            val pad = dp(20)
            setPadding(pad, pad, pad, pad)
        }
        root.addView(
            text("Güncelleyici", 30f, INK, true).also {
                it.typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            }
        )
        root.addView(
            text(
                "Önce internetten kontrol et. İstersen APK dosyasını elle de ekleyebilirsin. " +
                    "Android her kurulumda onay ister.",
                15f, MUTED, false
            ).also { (it.layoutParams as LinearLayout.LayoutParams).topMargin = dp(4) }
        )

        statusView = text("Hazır.", 15f, GOOD, true)
        paintChip(statusView, GOOD)
        root.addView(statusView, lp(top = 14))

        val check = Button(this).apply {
            text = "Güncellemeleri kontrol et"
            setOnClickListener { checkUpdates() }
        }
        styleButton(check, 0)
        root.addView(check, lp(top = 14))

        val add = Button(this).apply {
            text = "APK dosyası ekle"
            setOnClickListener { pick() }
        }
        styleButton(add, 1)
        root.addView(add, lp(top = 8))

        listBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(
            ScrollView(this).apply { addView(listBox) },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
            ).apply { topMargin = dp(12) }
        )
        setContentView(root)

        // Açılınca kendiliğinden yeni uygulama/sürüm var mı diye bakar (internet varsa).
        checkUpdates(true)
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        listBox.removeAllViews()
        val items = entries()
        if (items.isEmpty()) {
            listBox.addView(
                text("Henüz APK yok. \"Güncellemeleri kontrol et\" ile başla.", 16f, MUTED, false)
                    .also { it.gravity = Gravity.CENTER }, lp(top = 32)
            )
            return
        }
        for (e in items) listBox.addView(card(e), lp(top = 10))
    }

    private fun card(e: Entry): LinearLayout {
        val inst = installed(e.pkg)
        val status: String
        val color: Int
        var action: String? = null
        if (inst == null) {
            status = "Kurulu değil"
            color = WARN
            action = "Kur"
        } else {
            val ic = versionCodeOf(inst)
            when {
                e.vCode > ic -> {
                    status = "Kurulu: ${inst.versionName} → yeni sürüm hazır"
                    color = WARN
                    action = "Güncelle"
                }
                e.vCode == ic -> {
                    status = "Güncel (kurulu: ${inst.versionName})"
                    color = GOOD
                }
                else -> {
                    status = "Kurulu sürüm daha yeni (${inst.versionName})"
                    color = MUTED
                }
            }
        }

        val c = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = box(CARD, INK, 12)
            val p = dp(16)
            setPadding(p, p, p, p)
        }
        c.addView(
            text(e.label, 20f, INK, true).also {
                it.gravity = Gravity.START
                it.typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            }
        )
        c.addView(
            text("${e.pkg}\nDosyadaki sürüm: ${e.vName} (kod ${e.vCode})", 13f, MUTED, false)
                .also { it.gravity = Gravity.START }
        )
        val chip = text(status, 14f, color, true)
        paintChip(chip, color)
        c.addView(
            chip,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(10) }
        )

        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        fun addBtn(label: String, kind: Int, onClick: () -> Unit) {
            val b = Button(this).apply {
                text = label
                setOnClickListener { onClick() }
            }
            styleButton(b, kind)
            row.addView(
                b,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(12); marginEnd = dp(8) }
            )
        }
        val act = action
        if (act != null) addBtn(act, 0) { install(e) }
        if (inst != null && packageManager.getLaunchIntentForPackage(e.pkg) != null) {
            addBtn("Aç", 1) {
                packageManager.getLaunchIntentForPackage(e.pkg)?.let { startActivity(it) }
            }
        }
        addBtn("Dosyayı sil", 2) { confirmDelete(e) }
        c.addView(row)
        return c
    }

    private fun confirmDelete(e: Entry) {
        AlertDialog.Builder(this)
            .setTitle("${e.label} dosyası silinsin mi?")
            .setMessage("Sadece buradaki APK dosyası silinir, kurulu uygulamaya dokunulmaz.")
            .setPositiveButton("Sil") { _, _ ->
                e.file.delete()
                refresh()
            }
            .setNegativeButton("İptal", null)
            .show()
    }

    // ---------- APK ekleme ----------

    private fun pick() {
        val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(i, REQ_PICK)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK || resultCode != RESULT_OK || data == null) return

        val uris = mutableListOf<Uri>()
        data.clipData?.let { c ->
            for (i in 0 until c.itemCount) uris.add(c.getItemAt(i).uri)
        }
        data.data?.let { uris.add(it) }
        if (uris.isEmpty()) return

        Thread {
            val added = uris.mapNotNull { importOne(it) }
            runOnUiThread {
                refresh()
                afterImport(added)
            }
        }.start()
    }

    /** Dosyayı uygulamanın özel klasörüne kopyalar. Geçerli APK değilse reddeder. */
    private fun importOne(uri: Uri): Entry? {
        val stream: InputStream? = try {
            contentResolver.openInputStream(uri)
        } catch (_: Exception) {
            null
        }
        if (stream == null) return null
        return stream.use { importStream(it) }
    }

    /** warn=false: otomatik kontrolde APK olmayan/bozuk dosya sessizce atlanır, uyarı çıkmaz. */
    private fun importStream(ins: InputStream, warn: Boolean = true): Entry? {
        val tmp = File.createTempFile("yeni", ".apk", cacheDir)
        try {
            FileOutputStream(tmp).use { out -> ins.copyTo(out) }
            // APK bir zip dosyasıdır ("PK" ile başlar); değilse hiç deneme.
            val magic = ByteArray(2)
            val okMagic = tmp.inputStream().use { it.read(magic) == 2 } &&
                magic[0] == 'P'.code.toByte() && magic[1] == 'K'.code.toByte()
            val e = if (okMagic) parse(tmp) else null
            if (e == null) {
                if (warn) toastUi("Bu dosya geçerli bir APK değil")
                return null
            }
            val dest = File(dir, "${e.pkg}.apk")
            val old = if (dest.exists()) parse(dest) else null
            if (old != null && old.vCode > e.vCode) {
                skippedOld = true
                if (warn) toastUi("${e.label}: dosya eski sürüm, atlandı")
                return null
            }
            tmp.copyTo(dest, overwrite = true)
            return parse(dest)
        } catch (ex: Exception) {
            if (warn) toastUi("Dosya eklenemedi: ${ex.message}")
            return null
        } finally {
            tmp.delete()
        }
    }

    private fun afterImport(added: List<Entry>) {
        if (added.size == 1) {
            val e = added[0]
            val inst = installed(e.pkg)
            if (inst == null || e.vCode > versionCodeOf(inst)) {
                install(e)
            } else {
                toast("${e.label} zaten güncel")
            }
        } else if (added.size > 1) {
            toast("${added.size} uygulama eklendi, listeden kur")
        }
    }

    // ---------- Otomatik güncelleme (GitHub Release) ----------

    @Volatile private var skippedOld = false
    private val checking = java.util.concurrent.atomic.AtomicBoolean(false)

    private fun checkUpdates(silent: Boolean = false) {
        if (!checking.compareAndSet(false, true)) {
            if (!silent) toast("Kontrol zaten sürüyor, biraz bekle")
            return
        }
        setStatus("Kontrol ediliyor... (GitHub\u0027a bağlanılıyor)", WARN)
        Thread {
            try {
                val con = URL("https://api.github.com/repos/$REPO/releases/latest")
                    .openConnection() as HttpURLConnection
                con.connectTimeout = 15000
                con.readTimeout = 30000
                con.setRequestProperty("Accept", "application/vnd.github+json")
                con.setRequestProperty("User-Agent", "guncelle-app")
                val code = con.responseCode
                if (code == 404) {
                    setStatus("Yayınlanmış sürüm bulunamadı (404). Derleme bitti mi?", WARN)
                    return@Thread
                }
                if (code != 200) {
                    setStatus("GitHub hatası: $code" + if (code == 403) " (istek sınırı, biraz sonra tekrar dene)" else "", WARN)
                    return@Thread
                }
                val body = con.inputStream.bufferedReader().use { it.readText() }
                con.disconnect()

                val json = JSONObject(body)
                val tag = json.optString("tag_name")
                val prefs = getSharedPreferences("guncelle", MODE_PRIVATE)
                val assets = json.getJSONArray("assets")
                val added = mutableListOf<Entry>()
                var failed = 0
                var unchanged = 0
                val failedNames = mutableListOf<String>()
                val total = (0 until assets.length()).count { assets.getJSONObject(it).getString("name").lowercase().endsWith(".apk") }
                var n = 0
                for (i in 0 until assets.length()) {
                    val a = assets.getJSONObject(i)
                    if (!a.getString("name").lowercase().endsWith(".apk")) continue
                    n++
                    setStatus("Yayın $tag: bakılıyor $n/$total - ${a.getString("name")}", WARN)
                    val aname = a.getString("name")
                    val asize = a.optLong("size", -1)
                    val adigest = a.optString("digest", "")
                    // Her derleme yeni bir Release açar, dosya kimlikleri (id) hep değişir. Bu yüzden
                    // kimliğe değil içeriğe bakılır: aynı boyutta ve (varsa) aynı özette dosya zaten
                    // cihazdaysa tekrar indirilmez. Sadece değişen/yeni dosyalar iner.
                    val knownPkg = prefs.getString("p_$aname", null)
                    val local = if (knownPkg != null) File(dir, "$knownPkg.apk") else null
                    if (local != null && local.exists() && asize > 0 && local.length() == asize) {
                        val oldDigest = prefs.getString("d_$aname", "") ?: ""
                        if (oldDigest.isEmpty() || adigest.isEmpty() || oldDigest == adigest) {
                            if (adigest.isNotEmpty()) prefs.edit().putString("d_$aname", adigest).apply()
                            unchanged++
                            continue
                        }
                    }
                    // Bir APK inmezse diğerleri yine denensin; hiçbiri sessizce atlanmasın.
                    try {
                        val dl = URL(a.getString("browser_download_url"))
                            .openConnection() as HttpURLConnection
                        dl.connectTimeout = 15000
                        dl.readTimeout = 60000
                        dl.instanceFollowRedirects = true
                        if (dl.responseCode == 200) {
                            skippedOld = false
                            val e = dl.inputStream.use { importStream(it, warn = false) }
                            if (e != null) {
                                added.add(e)
                                prefs.edit().putString("d_$aname", adigest).putString("p_$aname", e.pkg).apply()
                                runOnUiThread { refresh() }
                            } else if (!skippedOld) {
                                failed++; failedNames.add("$aname (geçersiz dosya)")
                            }
                        } else {
                            failed++; failedNames.add("$aname (HTTP ${dl.responseCode})")
                        }
                        dl.disconnect()
                    } catch (ex: Exception) {
                        failed++; failedNames.add("$aname (${ex.message ?: ex.javaClass.simpleName})")
                    }
                }
                setStatus(
                    if (failed > 0) "Yayın $tag: indirilemeyen: ${failedNames.joinToString(", ")}. Tekrar dene."
                    else "Yayın $tag kontrol edildi: ${added.size} yeni/değişen dosya indi, $unchanged dosya aynı olduğu için atlandı.",
                    if (failed > 0) WARN else GOOD
                )
                runOnUiThread {
                    refresh()
                    afterCheck(added, silent)
                }
            } catch (ex: Exception) {
                setStatus("Kontrol edilemedi: ${ex.message ?: ex.javaClass.simpleName}. İnternet var mı?", WARN)
            } finally {
                checking.set(false)
            }
        }.start()
    }

    private fun afterCheck(added: List<Entry>, silent: Boolean) {
        val need = added.filter { e ->
            val inst = installed(e.pkg)
            inst == null || e.vCode > versionCodeOf(inst)
        }
        if (silent) {
            // Açılışta otomatik kontrol: listeye eklenir, kurulum için kullanıcı dokunur.
            if (need.isNotEmpty()) {
                toast("${need.size} uygulama kurulmaya/güncellenmeye hazır, listeden bas")
            }
            return
        }
        when {
            need.isEmpty() -> toast("Her şey güncel")
            need.size == 1 -> install(need[0])
            else -> toast("${need.size} güncelleme hazır, listeden Güncelle'ye bas")
        }
    }

    // ---------- Kurulum ----------

    /** APK'nın zip içeriği okunabiliyor mu (bozuk indirme tespiti). */
    private fun intact(f: File): Boolean = try {
        java.util.zip.ZipFile(f).use { z ->
            val buf = ByteArray(8192)
            for (en in z.entries()) {
                z.getInputStream(en).use { while (it.read(buf) > 0) { /* CRC doğrulanır */ } }
            }
        }
        true
    } catch (_: Exception) {
        false
    }

    private fun install(e: Entry) {
        if (!intact(e.file)) {
            e.file.delete()
            refresh()
            toast("${e.label} dosyası bozuk inmiş, silindi. \"Güncellemeleri kontrol et\"e basıp yeniden indir.")
            return
        }
        if (!packageManager.canRequestPackageInstalls()) {
            toast("Önce açılan ekranda bu uygulamaya yükleme izni ver, sonra tekrar dene")
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
            return
        }
        try {
            val installer = packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL
            )
            params.setAppPackageName(e.pkg)
            val id = installer.createSession(params)
            installer.openSession(id).use { session ->
                e.file.inputStream().use { ins ->
                    session.openWrite("apk", 0, e.file.length()).use { out ->
                        ins.copyTo(out)
                        session.fsync(out)
                    }
                }
                var flags = PendingIntent.FLAG_UPDATE_CURRENT
                if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE
                val pending = PendingIntent.getBroadcast(
                    this, id, Intent(this, InstallReceiver::class.java), flags
                )
                session.commit(pending.intentSender)
            }
        } catch (ex: Exception) {
            toast("Kurulum başlatılamadı: ${ex.message}")
        }
    }

    // ---------- APK / paket bilgisi ----------

    private fun entries(): List<Entry> =
        (dir.listFiles { f -> f.name.endsWith(".apk") } ?: emptyArray())
            .mapNotNull { parse(it) }
            .sortedBy { it.label.lowercase() }

    private fun parse(f: File): Entry? {
        val pi = packageManager.getPackageArchiveInfo(f.absolutePath, 0) ?: return null
        val ai = pi.applicationInfo ?: return null
        ai.sourceDir = f.absolutePath
        ai.publicSourceDir = f.absolutePath
        val label = try {
            ai.loadLabel(packageManager).toString()
        } catch (_: Exception) {
            pi.packageName
        }
        return Entry(f, pi.packageName, label, pi.versionName ?: "?", versionCodeOf(pi))
    }

    private fun installed(pkg: String): PackageInfo? =
        try {
            packageManager.getPackageInfo(pkg, 0)
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }

    @Suppress("DEPRECATION")
    private fun versionCodeOf(pi: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else pi.versionCode.toLong()

    // ---------- Küçük yardımcılar ----------

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun lp(top: Int = 0) = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
    ).apply { topMargin = dp(top) }

    private fun text(t: String, size: Float, color: Int, bold: Boolean): TextView =
        TextView(this).apply {
            text = t
            textSize = size
            setTextColor(color)
            if (bold) setTypeface(typeface, Typeface.BOLD)
            layoutParams = lp()
        }

    private fun setStatus(msg: String, color: Int = GOOD) = runOnUiThread {
        statusView.text = msg
        paintChip(statusView, color)
    }

    // ---------- Tema yardımcıları ----------

    private fun box(fill: Int, stroke: Int, radiusDp: Int, strokeDp: Int = 2): GradientDrawable =
        GradientDrawable().apply {
            setColor(fill)
            cornerRadius = dp(radiusDp).toFloat()
            setStroke(dp(strokeDp), stroke)
        }

    /** kind: 0 = ana düğme (dolu mavi), 1 = ikincil (beyaz, mavi çerçeve), 2 = silme (kırmızı). */
    private fun styleButton(b: Button, kind: Int) {
        b.isAllCaps = false
        b.textSize = 16f
        b.setTypeface(b.typeface, Typeface.BOLD)
        b.minHeight = dp(52)
        b.minimumHeight = dp(52)
        b.stateListAnimator = null
        val fill = if (kind == 0) INK else CARD
        val fg = when (kind) {
            0 -> Color.WHITE
            2 -> RED
            else -> INK
        }
        val line = if (kind == 2) RED else INK
        b.setTextColor(fg)
        b.background = RippleDrawable(ColorStateList.valueOf(0x331D4A73), box(fill, line, 10), null)
        b.setPadding(dp(18), 0, dp(18), 0)
    }

    /** Durum etiketi: metin rengine göre açık zemin ve ince çerçeve. */
    private fun paintChip(tv: TextView, color: Int) {
        val fill = when (color) {
            WARN -> 0xFFFDF0C2.toInt()
            GOOD -> 0xFFD9F0E2.toInt()
            else -> BG
        }
        tv.setTextColor(color)
        tv.background = box(fill, color, 8, 1)
        tv.setPadding(dp(12), dp(8), dp(12), dp(8))
    }

    /** Çizim kâğıdı: düz kâğıt rengi üzerine ince mavi ızgara. */
    private class GridPaper(paper: Int, line: Int, private val step: Float) : Drawable() {
        private val bg = Paint().apply { color = paper }
        private val ln = Paint().apply {
            color = line
            strokeWidth = 1f
        }

        override fun draw(canvas: Canvas) {
            val r = bounds
            canvas.drawRect(r, bg)
            var x = r.left.toFloat()
            while (x <= r.right) {
                canvas.drawLine(x, r.top.toFloat(), x, r.bottom.toFloat(), ln)
                x += step
            }
            var y = r.top.toFloat()
            while (y <= r.bottom) {
                canvas.drawLine(r.left.toFloat(), y, r.right.toFloat(), y, ln)
                y += step
            }
        }

        override fun setAlpha(alpha: Int) {}
        override fun setColorFilter(colorFilter: ColorFilter?) {}

        @Deprecated("Deprecated in Java")
        override fun getOpacity(): Int = PixelFormat.OPAQUE
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_LONG).show()

    private fun toastUi(msg: String) = runOnUiThread { toast(msg) }
}
