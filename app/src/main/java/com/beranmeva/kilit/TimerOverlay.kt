package com.beranmeva.kilit

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import kotlin.math.abs

/**
 * Ekranda her uygulamanın üstünde duran yuvarlak sayaç.
 * - Parmakla istenen yere sürüklenir (konum kaydedilir).
 * - Üstünde kapatma düğmesi yoktur, kapatılamaz.
 * - Dokununca sıradaki kullanıcının rengi değişir.
 * Servis tarafından yönetilir (GuardService).
 */
class TimerOverlay(private val ctx: Context, private val store: Store) {

    private val wm = ctx.getSystemService(WindowManager::class.java)
    private var view: CircleView? = null
    private var params: WindowManager.LayoutParams? = null
    private val density = ctx.resources.displayMetrics.density
    private val size = (96 * density).toInt()
    private val slop = ViewConfiguration.get(ctx).scaledTouchSlop

    fun update(main: String, sub: String, progress: Float, color: Int) {
        val v = view ?: create()
        v.set(main, sub, progress, color)
    }

    fun hide() {
        val v = view
        if (v != null) {
            try {
                wm.removeView(v)
            } catch (_: Exception) {
            }
        }
        view = null
        params = null
    }

    private fun clamp(p: WindowManager.LayoutParams) {
        val dm = ctx.resources.displayMetrics
        p.x = p.x.coerceIn(0, (dm.widthPixels - size).coerceAtLeast(0))
        p.y = p.y.coerceIn(0, (dm.heightPixels - size).coerceAtLeast(0))
    }

    private fun create(): CircleView {
        val dm = ctx.resources.displayMetrics
        val p = WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        p.gravity = Gravity.TOP or Gravity.START
        val sx = store.overlayX
        val sy = store.overlayY
        p.x = if (sx >= 0) sx else dm.widthPixels - size - (16 * density).toInt()
        p.y = if (sy >= 0) sy else (80 * density).toInt()
        clamp(p)

        val v = CircleView(ctx)
        v.setOnTouchListener(DragListener())
        wm.addView(v, p)
        view = v
        params = p
        return v
    }

    private inner class DragListener : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var downX = 0f
        private var downY = 0f
        private var moved = false

        override fun onTouch(v: View, e: MotionEvent): Boolean {
            val p = params ?: return false
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = p.x
                    startY = p.y
                    downX = e.rawX
                    downY = e.rawY
                    moved = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - downX).toInt()
                    val dy = (e.rawY - downY).toInt()
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (moved) {
                        p.x = startX + dx
                        p.y = startY + dy
                        clamp(p)
                        try {
                            wm.updateViewLayout(v, p)
                        } catch (_: Exception) {
                        }
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (moved) {
                        store.overlayX = p.x
                        store.overlayY = p.y
                    } else if (store.current.isNotEmpty()) {
                        // Dokununca renk değişir (sadece kullanıcı girişliyken).
                        store.nextColor(store.current)
                        view?.set(
                            null, null, null,
                            Store.COLORS[store.colorIndex(store.current)]
                        )
                    }
                }
            }
            return true
        }
    }

    private inner class CircleView(c: Context) : View(c) {
        private var main = ""
        private var sub = ""
        private var progress = 0f
        private var color = Store.IDLE_COLOR

        private val d = c.resources.displayMetrics.density
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 7 * d
            color = 0x55FFFFFF
        }
        private val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 7 * d
            color = Color.WHITE
            strokeCap = Paint.Cap.ROUND
        }
        private val t1 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
            textSize = 21 * d
        }
        private val t2 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xDDFFFFFF.toInt()
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
            textSize = 11 * d
        }

        /** null verilen alan değişmez. */
        fun set(m: String?, s: String?, pr: Float?, col: Int) {
            var changed = false
            if (m != null && m != main) {
                main = m
                changed = true
            }
            if (s != null && s != sub) {
                sub = s
                changed = true
            }
            if (pr != null && abs(pr - progress) > 0.002f) {
                progress = pr
                changed = true
            }
            if (col != color) {
                color = col
                changed = true
            }
            if (changed) invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            val w = width.toFloat()
            val h = height.toFloat()
            fill.color = (color and 0x00FFFFFF) or (0xE6 shl 24)
            canvas.drawCircle(w / 2, h / 2, w / 2 - 1, fill)
            val sw = arc.strokeWidth
            val r = RectF(sw, sw, w - sw, h - sw)
            canvas.drawArc(r, 0f, 360f, false, track)
            canvas.drawArc(r, -90f, 360f * progress, false, arc)
            canvas.drawText(main, w / 2, h * 0.52f, t1)
            canvas.drawText(sub, w / 2, h * 0.52f + t2.textSize + 2 * d, t2)
        }
    }
}
