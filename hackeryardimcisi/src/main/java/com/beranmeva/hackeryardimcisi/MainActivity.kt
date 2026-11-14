package com.beranmeva.hackeryardimcisi

import android.annotation.SuppressLint
import android.app.Activity
import android.app.DownloadManager
import android.net.Uri
import java.io.File
import android.graphics.Color
import android.os.Build
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.JavascriptInterface
import android.webkit.WebViewClient

/** Sayfa uygulamanın içinde (assets/index.html). İnternet gerekmez; varsa Vikipedi canlı okunur. */
class MainActivity : Activity() {

    private lateinit var web: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (IMMERSIVE) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        web = WebView(this)
        web.setBackgroundColor(Color.parseColor("#020806"))
        setContentView(web)

        val s = web.settings
        s.javaScriptEnabled = true
        s.domStorageEnabled = true
        s.mediaPlaybackRequiresUserGesture = false
        s.allowFileAccess = true
        s.setSupportZoom(false)

        // "para bitti" komutu uygulamayı kapatabilsin diye (sayfa navigator.app.exitApp arar)
        web.addJavascriptInterface(object {
            @JavascriptInterface
            fun exit() { runOnUiThread { finishAffinity() } }

            @JavascriptInterface
            fun listen(lang: String) { runOnUiThread { startListen() } }

            // Gemini'ye soru sorar. İstek Android tarafında gider (WebView CORS sorunu olmasın).
            @JavascriptInterface
            fun ask(id: Int, key: String, prompt: String) {
                Thread {
                    var ok = false
                    var out = ""
                    val models = MODELS.toMutableList()
                    var listed = false
                    var i = 0
                    var retryNoThink = false
                    while (i < models.size) {
                        val model = models[i++]
                        val noThink = retryNoThink
                        retryNoThink = false
                        try {
                            val c = URL("https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent")
                                .openConnection() as HttpURLConnection
                            c.requestMethod = "POST"
                            c.connectTimeout = 10000
                            c.readTimeout = 45000
                            c.doOutput = true
                            c.setRequestProperty("Content-Type", "application/json")
                            c.setRequestProperty("x-goog-api-key", key.trim())
                            val gen = JSONObject().put("maxOutputTokens", 400).put("temperature", 0.8)
                            // Düşünmeyi kıs: yavaş cevap (zaman aşımı) yaşanmasın. Model kabul etmezse (400) bir kez düşünmesiz denenir.
                            val thinkCfg: JSONObject? = when {
                                noThink -> null
                                model.startsWith("gemini-2.5") -> JSONObject().put("thinkingBudget", 0)
                                model.startsWith("gemini-3") || model.contains("latest") -> JSONObject().put("thinkingLevel", "minimal")
                                else -> null
                            }
                            if (thinkCfg != null) gen.put("thinkingConfig", thinkCfg)
                            val body = JSONObject()
                                .put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", SYSTEM))))
                                .put("contents", JSONArray().put(JSONObject().put("role", "user").put("parts", JSONArray().put(JSONObject().put("text", prompt)))))
                                .put("generationConfig", gen)
                            c.outputStream.use { it.write(body.toString().toByteArray()) }
                            val code = c.responseCode
                            val txt = (if (code in 200..299) c.inputStream else c.errorStream)?.bufferedReader()?.readText() ?: ""
                            if (code in 200..299) {
                                out = JSONObject(txt).getJSONArray("candidates").getJSONObject(0)
                                    .getJSONObject("content").getJSONArray("parts").getJSONObject(0).getString("text")
                                ok = out.isNotBlank()
                                if (ok) break
                                out = "bos cevap"
                            } else {
                                // Gerçek hata nedenini göster (ekranda "HTTP 404 model: ..." diye görünür).
                                val msg = try { JSONObject(txt).getJSONObject("error").optString("message") } catch (_: Exception) { "" }
                                out = "HTTP " + code + " " + model + (if (msg.isNotEmpty()) ": " + msg.take(120) else "")
                                // model yok / parametre hatası: sıradaki modeli dene; kota ve anahtar hatasında dur
                                if (code == 400 && thinkCfg != null) {
                                    retryNoThink = true
                                    i--
                                    continue
                                }
                                if (code != 404 && code != 400) break
                                // Sabit modellerin hiçbiri çalışmadıysa hesabın gerçekten kullanabildiği
                                // flash modellerini listeden bulup onları dene (Google eski modelleri kapatır).
                                if (!listed && i >= models.size) {
                                    listed = true
                                    try {
                                        val lc = URL("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200")
                                            .openConnection() as HttpURLConnection
                                        lc.connectTimeout = 10000
                                        lc.readTimeout = 15000
                                        lc.setRequestProperty("x-goog-api-key", key.trim())
                                        if (lc.responseCode in 200..299) {
                                            val arr = JSONObject(lc.inputStream.bufferedReader().readText()).getJSONArray("models")
                                            val found = mutableListOf<String>()
                                            for (j in 0 until arr.length()) {
                                                val m = arr.getJSONObject(j)
                                                val n = m.optString("name").removePrefix("models/")
                                                val methods = m.optJSONArray("supportedGenerationMethods")
                                                var can = false
                                                if (methods != null) for (q in 0 until methods.length()) if (methods.getString(q) == "generateContent") can = true
                                                if (can && n.startsWith("gemini") && n.contains("flash") &&
                                                    !n.contains("image") && !n.contains("tts") && !n.contains("live") &&
                                                    !n.contains("audio") && !n.contains("thinking") && !n.contains("exp") &&
                                                    n !in models) found.add(n)
                                            }
                                            // Yeni sürümler önce; kararlı ("preview" olmayan) olanlar tercih edilir.
                                            found.sortWith(compareBy<String>({ it.contains("preview") }, { it.contains("lite") }).thenByDescending { it })
                                            models.addAll(found.take(4))
                                        }
                                        lc.disconnect()
                                    } catch (_: Exception) { }
                                }
                            }
                        } catch (e: java.net.SocketTimeoutException) {
                            // Bu model yavaş kaldı: sıradaki modeli dene.
                            out = "zaman asimi " + model
                        } catch (e: Exception) {
                            out = e.javaClass.simpleName + (e.message?.let { ": " + it.take(80) } ?: "")
                            break
                        }
                    }
                    val o = out
                    val k = ok
                    runOnUiThread { js("window.__aiDone(" + id + "," + k + "," + JSONObject.quote(o) + ")") }
                }.start()
            }

            // Vikipedi'den bilgi getirir: internet varsa canlı (tr.wikipedia.org), yoksa indirilen tam metin
            // paketlerinden, o da yoksa uygulamaya gömülü küçük tabandan (assets/kb).
            // Sonuç: __wikiDone(id, kaynak, başlık, kısa cevap, tam metin); kaynak "" ise bulunamadı.
            @JavascriptInterface
            fun wiki(id: Int, query: String) {
                Thread {
                    var hit: WikiKb.Hit? = null
                    if (WikiKb.topicWords(query).isNotEmpty()) {
                        hit = try { wikiOnline(query) } catch (_: Exception) { null }
                        if (hit == null) hit = try { kb().search(query) } catch (_: Exception) { null }
                    }
                    val h = hit
                    val full = h?.full?.let { if (it.length > 200000) it.substring(0, 200000) else it } ?: ""
                    val code = "window.__wikiDone(" + id + "," + JSONObject.quote(h?.source ?: "") + "," +
                        JSONObject.quote(h?.title ?: "") + "," + JSONObject.quote(h?.text() ?: "") + "," + JSONObject.quote(full) + ")"
                    runOnUiThread { js(code) }
                }.start()
            }

            // Tam metin Vikipedi paketleri: "indir:tr", "indir:en", "indir:hepsi", "durum", "iptal", "sil".
            // Sonuç metni __wikiPack(metin) ile döner.
            @JavascriptInterface
            fun wikiPack(cmd: String) {
                Thread {
                    val msg = try { packCommand(cmd) } catch (e: Exception) { "Hata: " + (e.message ?: e.javaClass.simpleName) }
                    runOnUiThread { js("window.__wikiPack(" + JSONObject.quote(msg) + ")") }
                }.start()
            }

            @JavascriptInterface
            fun stopListen() { runOnUiThread { stopAll() } }
        }, "AndroidApp")
        web.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String?) {
                view.evaluateJavascript(BRIDGE_JS, null)
            }
        }
        web.webChromeClient = WebChromeClient()

        if (savedInstanceState != null) web.restoreState(savedInstanceState)
        else web.loadUrl("file:///android_asset/index.html")
    }

    // ---------------------------------------------------------------- Vikipedi
    private val packDir: File by lazy { (getExternalFilesDir("vikipedi") ?: File(filesDir, "vikipedi")).also { it.mkdirs() } }
    private var kbObj: WikiKb? = null
    private var kbSig = ""

    /** Yerel paket listesi (paket.json kopyası): ad -> (dil, boyut). */
    private fun localManifest(): List<Triple<String, String, Long>> {
        val f = File(packDir, "paket.json")
        if (!f.exists()) return emptyList()
        return try {
            val arr = JSONObject(f.readText()).getJSONArray("files")
            (0 until arr.length()).map { val o = arr.getJSONObject(it); Triple(o.getString("name"), o.getString("lang"), o.getLong("size")) }
        } catch (_: Exception) { emptyList() }
    }

    /** İnmesi bitmiş paketler (boyutu paket.json ile tutan), önce Türkçe. */
    private fun readyPacks(): List<Pair<File, String>> =
        localManifest().sortedBy { if (it.second == "tr") 0 else 1 }
            .map { Pair(File(packDir, it.first), it) }
            .filter { it.first.exists() && it.first.length() == it.second.third }
            .map { Pair(it.first, it.second.second) }

    /** Bilgi tabanı; yeni paket inince kendini yeniler. */
    @Synchronized
    private fun kb(): WikiKb {
        val packs = readyPacks()
        val sig = packs.joinToString("|") { it.first.name }
        val cur = kbObj
        if (cur != null && sig == kbSig) return cur
        cur?.close()
        val src = ArrayList<WikiKb.Source>()
        for ((f, lang) in packs) try { src.add(WikiKb.PackSource(f, lang)) } catch (_: Exception) { }
        src.add(WikiKb.AssetSource { name -> assets.open(name) })
        val k = WikiKb(src)
        kbObj = k
        kbSig = sig
        return k
    }

    private fun mb(b: Long) = if (b >= 1L shl 30) String.format("%.1f GB", b / 1073741824.0) else String.format("%d MB", b / 1048576)

    private fun langName(l: String) = if (l == "tr") "Türkçe" else if (l == "en") "İngilizce" else l

    private fun packCommand(cmd: String): String {
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val prefs = getSharedPreferences("vikipedi", MODE_PRIVATE)
        val ids = prefs.getStringSet("ids", emptySet())!!.mapNotNull { it.toLongOrNull() }
        when {
            cmd.startsWith("indir:") -> {
                val want = cmd.removePrefix("indir:")
                val c = URL(MANIFEST_URL).openConnection() as HttpURLConnection
                c.connectTimeout = 10000
                c.readTimeout = 20000
                c.instanceFollowRedirects = true
                if (c.responseCode !in 200..299) return "Paket listesi alınamadı (HTTP " + c.responseCode + "). Paketler henüz yayınlanmamış olabilir."
                val txt = c.inputStream.bufferedReader().readText()
                c.disconnect()
                val arr = JSONObject(txt).getJSONArray("files")
                File(packDir, "paket.json").writeText(txt)
                val names = HashSet<String>()
                val todo = ArrayList<Triple<String, String, Long>>()
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val t = Triple(o.getString("name"), o.getString("lang"), o.getLong("size"))
                    names.add(t.first)
                    if (want != "hepsi" && t.second != want) continue
                    val f = File(packDir, t.first)
                    if (f.exists() && f.length() == t.third) continue
                    todo.add(t)
                }
                // eski tarihli paketleri sil (yer açılsın)
                packDir.listFiles()?.forEach { if (it.name.endsWith(".skb") && it.name !in names) it.delete() }
                if (todo.isEmpty()) return "İstenen Vikipedi paketleri zaten telefonda. (vikipedi durum)"
                val need = todo.sumOf { it.third }
                val free = packDir.usableSpace
                if (need > free) return "Yer yetmiyor: " + mb(need) + " gerekli, telefonda " + mb(free) + " boş."
                // önceki yarım indirmeleri temizle
                if (ids.isNotEmpty()) dm.remove(*ids.toLongArray())
                val newIds = HashSet<String>()
                for (t in todo) {
                    File(packDir, t.first).delete()
                    val r = DownloadManager.Request(Uri.parse(RELEASE_URL + t.first))
                        .setTitle("Şikru Vikipedi (" + langName(t.second) + ")")
                        .setDescription(t.first)
                        .setDestinationInExternalFilesDir(this, "vikipedi", t.first)
                        .setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
                        .setAllowedOverMetered(false)
                        .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                    newIds.add(dm.enqueue(r).toString())
                }
                prefs.edit().putStringSet("ids", newIds).apply()
                return "İndirme başladı: " + todo.size + " dosya, " + mb(need) + ". Yalnızca Wi-Fi'da iner, uygulama kapansa da sürer. " +
                    "İlerleme için: vikipedi durum"
            }
            cmd == "iptal" -> {
                if (ids.isNotEmpty()) dm.remove(*ids.toLongArray())
                prefs.edit().remove("ids").apply()
                return "Vikipedi indirmesi iptal edildi."
            }
            cmd == "sil" -> {
                if (ids.isNotEmpty()) dm.remove(*ids.toLongArray())
                prefs.edit().remove("ids").apply()
                synchronized(this) { kbObj?.close(); kbObj = null; kbSig = "" }
                var freed = 0L
                packDir.listFiles()?.forEach { if (it.name.endsWith(".skb")) { freed += it.length(); it.delete() } }
                return "Vikipedi paketleri silindi, " + mb(freed) + " yer açıldı. Gömülü küçük taban duruyor."
            }
            else -> {
                val sb = StringBuilder()
                val ready = readyPacks()
                val byLang = ready.groupBy { it.second }
                sb.append("📚 Gömülü taban: Türkçe madde girişleri (her zaman var).")
                for ((l, fs) in byLang) sb.append("\n📦 ").append(langName(l)).append(" tam metin: ").append(fs.size).append(" dosya, ")
                    .append(mb(fs.sumOf { it.first.length() }))
                if (ids.isNotEmpty()) {
                    var done = 0L
                    var total = 0L
                    var running = 0
                    var waiting = 0
                    var failed = 0
                    dm.query(DownloadManager.Query().setFilterById(*ids.toLongArray()))?.use { cur ->
                        while (cur.moveToNext()) {
                            val st = cur.getInt(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                            val so = cur.getLong(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                            val tt = cur.getLong(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                            done += so
                            if (tt > 0) total += tt
                            when (st) {
                                DownloadManager.STATUS_RUNNING -> running++
                                DownloadManager.STATUS_PENDING, DownloadManager.STATUS_PAUSED -> waiting++
                                DownloadManager.STATUS_FAILED -> failed++
                            }
                        }
                    }
                    if (running + waiting + failed > 0) {
                        sb.append("\n⬇ İndiriliyor: ").append(mb(done))
                        if (total > 0) sb.append(" / ").append(mb(total)).append(" (%").append(done * 100 / total).append(")")
                        if (waiting > 0) sb.append(" · ").append(waiting).append(" dosya sırada/Wi-Fi bekliyor")
                        if (failed > 0) sb.append(" · ").append(failed).append(" dosya hata verdi (tekrar: vikipedi indir)")
                    }
                }
                if (ready.isEmpty()) sb.append("\nTam metin için: vikipedi indir (Türkçe) · vikipedi ingilizce indir · vikipedi hepsini indir")
                return sb.toString()
            }
        }
    }

    /** Canlı Vikipedi: konuyu arar, en iyi maddenin tam metninden soruya uyan cümleyi seçer. İnternet yoksa hata fırlatır. */
    private fun wikiOnline(query: String): WikiKb.Hit? {
        val topic = WikiKb.topicWords(query).joinToString(" ")
        val u = "https://tr.wikipedia.org/w/api.php?action=query&format=json&generator=search&gsrnamespace=0&gsrlimit=1" +
            "&prop=extracts&explaintext=1&exsectionformat=plain&redirects=1&gsrsearch=" + URLEncoder.encode(topic, "UTF-8")
        val c = URL(u).openConnection() as HttpURLConnection
        try {
            c.connectTimeout = 4000
            c.readTimeout = 8000
            c.setRequestProperty("User-Agent", "HackerYardimcisiSikru/2.0 (Android uygulamasi)")
            if (c.responseCode !in 200..299) return null
            val pages = JSONObject(c.inputStream.bufferedReader().readText()).optJSONObject("query")?.optJSONObject("pages") ?: return null
            val k = pages.keys()
            if (!k.hasNext()) return null
            val pg = pages.getJSONObject(k.next())
            val t = pg.optString("extract").replace(Regex("\\s+"), " ").trim()
            if (t.length < 20) return null
            return WikiKb.online(pg.optString("title"), t, query)
        } finally {
            c.disconnect()
        }
    }

    private var rec: SpeechRecognizer? = null
    // Sürekli dinleme: kullanıcı durdurana kadar her cümleden sonra yeniden başlar.
    private var want = false
    private val h = Handler(Looper.getMainLooper())

    // Son duyulan (henüz gönderilmemiş) metin. 2 sn ses gelmezse otomatik gönderilir.
    private var pending = ""
    private val flush = Runnable { sendPending(); if (want) { try { rec?.cancel() } catch (e: Exception) {}; again(150) } }

    private fun sendPending() {
        val t = pending.trim()
        pending = ""
        if (t.isNotEmpty()) js("window.__srResult(" + JSONObject.quote(t) + ")")
    }

    private fun stopAll() {
        want = false
        pending = ""
        h.removeCallbacksAndMessages(null)
        try { rec?.cancel() } catch (e: Exception) {}
        rec?.destroy(); rec = null
        js("window.__srEnd()")
    }

    private fun again(ms: Long) {
        h.postDelayed({ if (want) begin() }, ms)
    }

    private fun js(code: String) = web.evaluateJavascript(code, null)

    private fun startListen() {
        want = true
        begin()
    }

    private fun begin() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 77)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            want = false
            js("window.__srError('ses tanima servisi yok (Google uygulamasi gerekli)');window.__srEnd()")
            return
        }
        rec?.destroy()
        val r = SpeechRecognizer.createSpeechRecognizer(this)
        rec = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onResults(b: Bundle?) {
                val t = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                h.removeCallbacks(flush)
                pending = ""
                if (t != null) js("window.__srResult(" + JSONObject.quote(t) + ")")
                if (want) again(250) else js("window.__srEnd()")
            }
            override fun onError(code: Int) {
                h.removeCallbacks(flush)
                sendPending()
                // 7 = ses yok, 6 = zaman aşımı, 8 = meşgul, 5 = iptal: dinlemeye devam et
                if (want && (code == 7 || code == 6 || code == 5)) { again(250); return }
                if (want && code == 8) { again(900); return }
                want = false
                js("window.__srError('kod " + code + "');window.__srEnd()")
            }
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(b: Bundle?) {
                val t = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (!t.isNullOrBlank()) {
                    pending = t
                    h.removeCallbacks(flush)
                    h.postDelayed(flush, SILENCE_MS)
                }
            }
            override fun onEvent(t: Int, b: Bundle?) {}
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "tr-TR")
        i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
        r.startListening(i)
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, res: IntArray) {
        super.onRequestPermissionsResult(code, perms, res)
        if (code == 77) {
            if (res.isNotEmpty() && res[0] == PackageManager.PERMISSION_GRANTED) startListen()
            else { want = false; js("window.__srError('mikrofon izni verilmedi');window.__srEnd()") }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        web.saveState(outState)
    }

    override fun onResume() {
        super.onResume()
        web.onResume()
    }

    override fun onPause() {
        web.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        want = false
        h.removeCallbacksAndMessages(null)
        rec?.destroy()
        web.destroy()
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && IMMERSIVE) hideBars()
    }

    @Suppress("DEPRECATION")
    private fun hideBars() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.let {
                it.hide(WindowInsets.Type.systemBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE)
        }
    }

    companion object {
        private const val IMMERSIVE = true
        private const val SILENCE_MS = 2000L
        private const val RELEASE_URL = "https://github.com/aslan-cr/kilit/releases/download/vikipedi/"
        private const val MANIFEST_URL = RELEASE_URL + "paket.json"
        private val MODELS = listOf("gemini-2.5-flash", "gemini-flash-latest")
        private const val SYSTEM = "Sen Hacker Yardımcısı Şikru adlı, esprili bir terminal asistanısın. " +
            "Türkçe konuş, en fazla 3 kısa cümleyle cevap ver, markdown ve yıldız kullanma."
        // Sayfadaki Web Speech çağrısını uygulamanın kendi ses tanıyıcısına bağlar.
        private const val BRIDGE_JS = "navigator.app={exitApp:function(){AndroidApp.exit()}};" +
            "window.SpeechRecognition=function(){var s=this;s.lang='tr-TR';s.onresult=null;s.onerror=null;s.onend=null;" +
            "s.start=function(){window.__sr=s;AndroidApp.listen(s.lang)};s.stop=function(){AndroidApp.stopListen()}};" +
            "window.__srResult=function(t){var s=window.__sr;if(s&&s.onresult)s.onresult({results:[[{transcript:t}]]})};" +
            "window.__srError=function(e){var s=window.__sr;if(s&&s.onerror)s.onerror({error:e})};" +
            "window.__srEnd=function(){var s=window.__sr;if(s&&s.onend)s.onend()};"
    }
}
