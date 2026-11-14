package com.beranmeva.kilit

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.Typeface
import android.text.InputType
import android.view.Gravity
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView

/** Küçük arayüz yardımcıları (XML layout kullanmıyoruz). */
object Ui {
    const val BG = 0xFF101820.toInt()
    const val MUTED = 0xFFAABBCC.toInt()
    const val ERROR = 0xFFFF6B6B.toInt()

    /** Android 15+ ekranı kenardan kenara çizer: içeriği durum/gezinme çubuklarının dışında tutar. */
    fun fitSystemBars(v: View) {
        val l = v.paddingLeft
        val t = v.paddingTop
        val r = v.paddingRight
        val b = v.paddingBottom
        ViewCompat.setOnApplyWindowInsetsListener(v) { view, insets ->
            val s = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
            )
            view.setPadding(l + s.left, t + s.top, r + s.right, b + s.bottom)
            insets
        }
        ViewCompat.requestApplyInsets(v)
    }

    fun dp(c: Context, v: Int): Int = (v * c.resources.displayMetrics.density).toInt()

    fun lp(c: Context, widthDp: Int = 320, topDp: Int = 0): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            if (widthDp > 0) dp(c, widthDp) else ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(c, topDp)
            gravity = Gravity.CENTER_HORIZONTAL
        }

    fun tv(
        c: Context,
        t: String,
        size: Float,
        color: Int = Color.WHITE,
        bold: Boolean = false
    ): TextView = TextView(c).apply {
        text = t
        textSize = size
        setTextColor(color)
        gravity = Gravity.CENTER
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    fun pwField(c: Context, hint: String): EditText = EditText(c).apply {
        this.hint = hint
        inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        setTextColor(Color.WHITE)
        setHintTextColor(0xFF8899AA.toInt())
        gravity = Gravity.CENTER
        textSize = 22f
        // Yuvarlak köşeli koyu kutu (eski alt çizgili düz alan yerine)
        background = rounded(c, 0x22FFFFFF, 14, 0x55AABBCC)
        setPadding(dp(c, 14), dp(c, 12), dp(c, 14), dp(c, 12))
    }

    /** Köşeleri yuvarlak dolgu; strokeColor verilirse ince kenarlık. */
    fun rounded(c: Context, color: Int, radiusDp: Int, strokeColor: Int = 0): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(c, radiusDp).toFloat()
            if (strokeColor != 0) setStroke(dp(c, 1), strokeColor)
        }

    fun button(c: Context, t: String, onClick: () -> Unit): Button = (object : Button(c) {
        // Devre dışıyken soluk görünsün (özel arka planda sistem bunu kendisi yapmaz)
        override fun setEnabled(enabled: Boolean) {
            super.setEnabled(enabled)
            alpha = if (enabled) 1f else 0.45f
        }
    } as Button).apply {
        text = t
        isAllCaps = false
        // Yuvarlak, renk geçişli, basınca dalgalanan düğme (eski gri sistem düğmesi yerine)
        setTextColor(Color.WHITE)
        setTypeface(typeface, Typeface.BOLD)
        textSize = 16f
        stateListAnimator = null
        minHeight = dp(c, 50)
        setPadding(dp(c, 14), dp(c, 10), dp(c, 14), dp(c, 10))
        val fill = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(0xFF3B82F6.toInt(), 0xFF2563EB.toInt())
        ).apply { cornerRadius = dp(c, 14).toFloat() }
        background = RippleDrawable(ColorStateList.valueOf(0x55FFFFFF), fill, rounded(c, Color.WHITE, 14))
        setOnClickListener { onClick() }
    }
}
