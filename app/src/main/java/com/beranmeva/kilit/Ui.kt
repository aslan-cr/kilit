package com.beranmeva.kilit

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Küçük arayüz yardımcıları (XML layout kullanmıyoruz).
 * Tasarım: "gece lambası". Koyu mavi-yeşil zemin, tek sıcak vurgu (kehribar),
 * her çocuğun kendi sayaç rengiyle çizilen halka.
 */
object Ui {
    const val BG = 0xFF14202E.toInt()
    const val SURFACE = 0xFF1E2E40.toInt()
    const val LINE = 0xFF3A4F66.toInt()
    const val TEXT = 0xFFF2F5F8.toInt()
    const val MUTED = 0xFFA9BACB.toInt()
    const val ACCENT = 0xFFF5B642.toInt()
    const val ACCENT_PRESSED = 0xFFD99A26.toInt()
    const val ON_ACCENT = 0xFF14202E.toInt()
    const val ERROR = 0xFFFF9488.toInt()

    const val RADIUS_DP = 14
    const val MIN_TOUCH_DP = 52

    fun dp(c: Context, v: Int): Int = (v * c.resources.displayMetrics.density).toInt()

    fun lp(c: Context, widthDp: Int = 320, topDp: Int = 0): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            if (widthDp > 0) dp(c, widthDp) else ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(c, topDp)
            gravity = Gravity.CENTER_HORIZONTAL
        }

    /** Yuvarlak köşeli dolgu, istenirse çerçeveli arka plan. */
    fun shape(c: Context, fill: Int, stroke: Int = 0, radiusDp: Int = RADIUS_DP): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(c, radiusDp).toFloat()
            setColor(fill)
            if (stroke != 0) setStroke(dp(c, 1), stroke)
        }

    fun tv(
        c: Context,
        t: String,
        size: Float,
        color: Int = TEXT,
        bold: Boolean = false
    ): TextView = TextView(c).apply {
        text = t
        textSize = size
        setTextColor(color)
        gravity = Gravity.CENTER
        setLineSpacing(0f, 1.15f)
        typeface = Typeface.create(if (bold) "sans-serif-medium" else "sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL)
    }

    /** Büyük başlık: sıkı, kalın. */
    fun title(c: Context, t: String, size: Float = 28f): TextView =
        tv(c, t, size, TEXT, true).apply {
            typeface = Typeface.create("sans-serif-black", Typeface.NORMAL)
            letterSpacing = -0.01f
        }

    /** Çocuğun renginde halka içinde baş harf: kilit ekranının ve sayacın ortak işareti. */
    fun disc(c: Context, letter: String, color: Int, sizeDp: Int = 104): TextView =
        TextView(c).apply {
            text = letter
            textSize = sizeDp * 0.4f
            setTextColor(color)
            gravity = Gravity.CENTER
            typeface = Typeface.create("sans-serif-black", Typeface.NORMAL)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(SURFACE)
                setStroke(dp(c, 7), color)
            }
            layoutParams = LinearLayout.LayoutParams(dp(c, sizeDp), dp(c, sizeDp)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(c, 24)
            }
        }

    fun pwField(c: Context, hint: String): EditText = EditText(c).apply {
        this.hint = hint
        inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        setTextColor(TEXT)
        setHintTextColor(0xFF7F93A8.toInt())
        gravity = Gravity.CENTER
        textSize = 22f
        minHeight = dp(c, 56)
        val h = dp(c, 16)
        setPadding(h, 0, h, 0)
        background = shape(c, SURFACE, LINE)
    }

    private fun styled(c: Context, t: String, primary: Boolean, onClick: () -> Unit): Button =
        Button(c).apply {
            text = t
            isAllCaps = false
            textSize = 16f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            minHeight = dp(c, MIN_TOUCH_DP)
            minimumHeight = dp(c, MIN_TOUCH_DP)
            stateListAnimator = null
            val h = dp(c, 20)
            setPadding(h, 0, h, 0)
            val normal = if (primary) shape(c, ACCENT) else shape(c, SURFACE, LINE)
            val pressed = if (primary) shape(c, ACCENT_PRESSED) else shape(c, LINE, LINE)
            val off = shape(c, SURFACE, LINE)
            background = StateListDrawable().apply {
                addState(intArrayOf(-android.R.attr.state_enabled), off)
                addState(intArrayOf(android.R.attr.state_pressed), pressed)
                addState(intArrayOf(), normal)
            }
            setTextColor(
                ColorStateList(
                    arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()),
                    intArrayOf(0xFF7F93A8.toInt(), if (primary) ON_ACCENT else TEXT)
                )
            )
            setOnClickListener { onClick() }
        }

    /** Ana eylem: kehribar dolgu. */
    fun button(c: Context, t: String, onClick: () -> Unit): Button = styled(c, t, true, onClick)

    /** İkincil eylem: çerçeveli. */
    fun ghost(c: Context, t: String, onClick: () -> Unit): Button = styled(c, t, false, onClick)
}
