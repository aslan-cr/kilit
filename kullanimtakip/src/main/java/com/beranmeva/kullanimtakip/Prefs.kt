package com.beranmeva.kullanimtakip

import android.content.Context

/** Bu cihazın kodu ve gönderim durumu. */
class Prefs(ctx: Context) {
    private val sp = ctx.applicationContext.getSharedPreferences("takip", Context.MODE_PRIVATE)

    var code: String
        get() {
            var c = sp.getString("code", null)
            if (c == null) { c = Crypto.newCode(); sp.edit().putString("code", c).apply() }
            return c
        }
        set(v) { sp.edit().putString("code", v).apply() }

    var lastOk: Long
        get() = sp.getLong("lastOk", 0L)
        set(v) { sp.edit().putLong("lastOk", v).apply() }

    var lastErr: String
        get() = sp.getString("lastErr", "") ?: ""
        set(v) { sp.edit().putString("lastErr", v).apply() }
}
