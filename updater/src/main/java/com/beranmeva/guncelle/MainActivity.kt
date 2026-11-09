package com.beranmeva.guncelle

import android.app.Activity
import android.app.AlertDialog
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
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
        private const val BG = 0xFF101820.toInt()
        private const val MUTED = 0xFFAABBCC.toInt()
        private const val CARD = 0xFF1B2733.toInt()
        private const val GOOD = 0xFF7BE495.toInt()
        private const val WARN = 0xFFFFC857.toInt()
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
            setBackgroundColor(BG)
            val pad = dp(20)
            setPadding(pad, pad, pad, pad)
        }
        root.addView(text("Güncelleyici", 26f, Color.WHITE, true))
        root.addView(
            text(
                "APK dosyalarını buraya ekle. Yeni sürümü tekrar eklersen eskisinin yerine geçer " +
                    "ve kurulum başlar. Android her kurulumda onay ister, sessiz kurulum mümkün değil.",
                14f, MUTED, false
            ).also { (it.layoutParams as LinearLayout.LayoutParams).topMargin = dp(6) }
        )

        statusView = text("Hazır.", 14f, GOOD, true)
        root.addView(statusView, lp(top = 10))

        val add = Button(this).apply {
            text = "+ APK ekle / güncelle"
            isAllCaps = false
            setOnClickListener { pick() }
        }
        root.addView(add, lp(top = 16))

        val check = Button(this).apply {
            text = "Güncellemeleri kontrol et (internet)"
            isAllCaps = false
            setOnClickListener { checkUpdates() }
        }
        root.addView(check, lp(top = 4))

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
                text("Henüz APK eklenmedi. Yukarıdan ekle.", 16f, MUTED, false)
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
            setBackgroundColor(CARD)
            val p = dp(14)
            setPadding(p, p, p, p)
        }
        c.addView(text(e.label, 18f, Color.WHITE, true).also { it.gravity = Gravity.START })
        c.addView(
            text("${e.pkg}\nDosyadaki sürüm: ${e.vName} (kod ${e.vCode})", 13f, MUTED, false)
                .also { it.gravity = Gravity.START }
        )
        c.addView(text(status, 15f, color, true).also { it.gravity = Gravity.START })

        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        if (action != null) {
            row.addView(Button(this).apply {
                text = action
                isAllCaps = false
                setOnClickListener { install(e) }
            })
        }
        if (inst != null && packageManager.getLaunchIntentForPackage(e.pkg) != null) {
            row.addView(Button(this).apply {
                text = "Aç"
                isAllCaps = false
                setOnClickListener {
                    packageManager.getLaunchIntentForPackage(e.pkg)?.let { startActivity(it) }
                }
            })
        }
        row.addView(Button(this).apply {
            text = "Dosyayı sil"
            isAllCaps = false
            setOnClickListener { confirmDelete(e) }
        })
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
                if (tag == prefs.getString("tag2", "") && entries().isNotEmpty()) {
                    setStatus("Kontrol edildi: en son yayın ($tag) zaten indirilmiş. Listeden kurabilirsin.")
                    runOnUiThread { refresh() }
                    return@Thread
                }

                val assets = json.getJSONArray("assets")
                val added = mutableListOf<Entry>()
                var failed = 0
                val total = (0 until assets.length()).count { assets.getJSONObject(it).getString("name").lowercase().endsWith(".apk") }
                var n = 0
                for (i in 0 until assets.length()) {
                    val a = assets.getJSONObject(i)
                    if (!a.getString("name").lowercase().endsWith(".apk")) continue
                    n++
                    setStatus("Yayın $tag: indiriliyor $n/$total - ${a.getString("name")}", WARN)
                    // Aynı boyutta dosya zaten varsa yeniden indirme.
                    val have = dir.listFiles { f -> f.name.endsWith(".apk") }
                        ?.firstOrNull { it.length() == a.optLong("size", -1) }
                    if (have != null) continue
                    // Bir APK inmezse diğerleri yine denensin; hiçbiri sessizce atlanmasın.
                    try {
                        val dl = URL(a.getString("browser_download_url"))
                            .openConnection() as HttpURLConnection
                        dl.connectTimeout = 15000
                        dl.readTimeout = 60000
                        dl.instanceFollowRedirects = true
                        if (dl.responseCode == 200) {
                            val e = dl.inputStream.use { importStream(it, warn = false) }
                            if (e != null) { added.add(e); runOnUiThread { refresh() } }
                        } else {
                            failed++
                        }
                        dl.disconnect()
                    } catch (_: Exception) {
                        failed++
                    }
                }
                // Etiket yalnızca hepsi indiyse kaydedilir; yoksa sonraki açılışta yeniden denenir.
                if (failed == 0) prefs.edit().putString("tag2", tag).apply()
                setStatus(
                    if (failed > 0) "Yayın $tag: $failed dosya indirilemedi, tekrar dene."
                    else "Yayın $tag kontrol edildi: ${added.size} yeni dosya indi.",
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
        statusView.setTextColor(color)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_LONG).show()

    private fun toastUi(msg: String) = runOnUiThread { toast(msg) }
}
