package com.beranmeva.kilit

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.text.InputType
import android.view.Gravity
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
    }

    fun button(c: Context, t: String, onClick: () -> Unit): Button = Button(c).apply {
        text = t
        isAllCaps = false
        setOnClickListener { onClick() }
    }
}
