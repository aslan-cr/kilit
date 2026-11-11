package com.beranmeva.hackeryardimcisi

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import org.json.JSONObject
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.JavascriptInterface
import android.webkit.WebViewClient

/** Sayfa uygulamanın içinde (assets/index.html). İnternet gerekmez. */
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

            @JavascriptInterface
            fun stopListen() { runOnUiThread { try { rec?.stopListening() } catch (e: Exception) {} } }
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

    private var rec: SpeechRecognizer? = null

    private fun js(code: String) = web.evaluateJavascript(code, null)

    private fun startListen() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 77)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            js("window.__srError('ses tanima servisi yok (Google uygulamasi gerekli)');window.__srEnd()")
            return
        }
        rec?.destroy()
        val r = SpeechRecognizer.createSpeechRecognizer(this)
        rec = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onResults(b: Bundle?) {
                val t = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (t != null) js("window.__srResult(" + JSONObject.quote(t) + ")")
                js("window.__srEnd()")
            }
            override fun onError(code: Int) {
                js("window.__srError('kod " + code + "');window.__srEnd()")
            }
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(b: Bundle?) {}
            override fun onEvent(t: Int, b: Bundle?) {}
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "tr-TR")
        i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        r.startListening(i)
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, res: IntArray) {
        super.onRequestPermissionsResult(code, perms, res)
        if (code == 77) {
            if (res.isNotEmpty() && res[0] == PackageManager.PERMISSION_GRANTED) startListen()
            else js("window.__srError('mikrofon izni verilmedi');window.__srEnd()")
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
        // Sayfadaki Web Speech çağrısını uygulamanın kendi ses tanıyıcısına bağlar.
        private const val BRIDGE_JS = "navigator.app={exitApp:function(){AndroidApp.exit()}};" +
            "window.SpeechRecognition=function(){var s=this;s.lang='tr-TR';s.onresult=null;s.onerror=null;s.onend=null;" +
            "s.start=function(){window.__sr=s;AndroidApp.listen(s.lang)};s.stop=function(){AndroidApp.stopListen()}};" +
            "window.__srResult=function(t){var s=window.__sr;if(s&&s.onresult)s.onresult({results:[[{transcript:t}]]})};" +
            "window.__srError=function(e){var s=window.__sr;if(s&&s.onerror)s.onerror({error:e})};" +
            "window.__srEnd=function(){var s=window.__sr;if(s&&s.onend)s.onend()};"
    }
}
