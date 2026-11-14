package com.beranmeva.hackeryardimcisi

import android.annotation.SuppressLint
import android.app.Activity
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

            // Vikipedi'den bilgi getirir: internet varsa canlı (tr.wikipedia.org), yoksa uygulamaya gömülü
            // çevrimdışı bilgi tabanından (assets/kb). Sonuç: __wikiDone(id, "on"|"off"|"", başlık, metin)
            @JavascriptInterface
            fun wiki(id: Int, query: String) {
                Thread {
                    var src = ""
                    var title = ""
                    var text = ""
                    val topic = WikiKb.topicWords(query).joinToString(" ")
                    if (topic.isNotEmpty()) {
                        val on = try { wikiOnline(topic) } catch (_: Exception) { null }
                        if (on != null) { src = "on"; title = on.first; text = on.second }
                        else {
                            val hit = try { kb.search(query) } catch (_: Exception) { null }
                            if (hit != null) { src = "off"; title = hit.title; text = hit.text }
                        }
                    }
                    val code = "window.__wikiDone(" + id + "," + JSONObject.quote(src) + "," + JSONObject.quote(title) + "," + JSONObject.quote(text) + ")"
                    runOnUiThread { js(code) }
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

    private val kb by lazy { WikiKb { name -> assets.open(name) } }

    /** Canlı Vikipedi: konuyu arar, en iyi maddenin giriş bölümünü döndürür. İnternet yoksa hata fırlatır. */
    private fun wikiOnline(topic: String): Pair<String, String>? {
        val u = "https://tr.wikipedia.org/w/api.php?action=query&format=json&generator=search&gsrnamespace=0&gsrlimit=1" +
            "&prop=extracts&exintro=1&explaintext=1&redirects=1&gsrsearch=" + URLEncoder.encode(topic, "UTF-8")
        val c = URL(u).openConnection() as HttpURLConnection
        try {
            c.connectTimeout = 4000
            c.readTimeout = 6000
            c.setRequestProperty("User-Agent", "HackerYardimcisiSikru/1.9 (Android uygulamasi)")
            if (c.responseCode !in 200..299) return null
            val pages = JSONObject(c.inputStream.bufferedReader().readText()).optJSONObject("query")?.optJSONObject("pages") ?: return null
            val k = pages.keys()
            if (!k.hasNext()) return null
            val pg = pages.getJSONObject(k.next())
            var t = pg.optString("extract").replace(Regex("\\s+"), " ").trim()
            if (t.length < 20) return null
            if (t.length > 600) {
                val cut = t.substring(0, 600)
                val m = cut.lastIndexOf(". ")
                t = if (m >= 160) cut.substring(0, m + 1) else cut.substring(0, cut.lastIndexOf(' ').coerceAtLeast(1)) + "…"
            }
            return Pair(pg.optString("title"), t)
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
