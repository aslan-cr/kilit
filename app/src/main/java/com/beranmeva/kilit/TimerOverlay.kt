package com.beranmeva.kilit

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.min

/**
 * Ekranda her uygulamanın üstünde duran yuvarlak sayaç.
 * - Parmakla istenen yere sürüklenir (konum kaydedilir).
 * - Üstünde kapatma düğmesi yoktur, kapatılamaz.
 * - Dokununca sıradaki kullanıcının rengi değişir.
 * - Boyut: iki parmakla büyütüp küçült, ya da basılı tutunca hazır boyutlar arasında geç
 *   (ebeveyn panelinden de ayarlanır).
 * - Ekranın bir kenarına bırakılınca küçülür, yarı saydam olur ve yarısı ekran dışında kalır;
 *   dokununca açılır, 4 sn sonra tekrar kenara çekilir.
 * - Kenarda değilken dokununca biraz genişleyip yanında "Kedi" anahtarı çıkar; açılınca
 *   dokunulan yerden kedi partisi başlar ve altta kediler dolaşır (CatOverlay).
 *   Genişlemişken sayacın kendisine dokunmak rengi değiştirir. 5 sn sonra kapanır.
 * Servis tarafından yönetilir (GuardService).
 */
class TimerOverlay(private val ctx: Context, private val store: Store) {

    private val wm = ctx.getSystemService(WindowManager::class.java)
    private var view: CircleView? = null
    private var params: WindowManager.LayoutParams? = null
    private val density = ctx.resources.displayMetrics.density
    private var appliedDp = 0
    private var size = (96 * density).toInt()
    private val slop = ViewConfiguration.get(ctx).scaledTouchSlop
    private val handler = Handler(Looper.getMainLooper())
    private val cats = CatOverlay(ctx)

    /** "Kedi" paneli açık mı; açıkken pencere genişler. */
    private var panelOpen = false
    private var panelRestoreX = 0
    private val collapsePanel = Runnable { closePanel() }

    /** Şu an görünüşte kenara yapışık mı (0 = değil). */
    private var docked = 0

    private val dockSize get() = (size * 0.55f).toInt()

    private val redock = Runnable {
        val p = params
        if (p != null && store.overlayDock != 0 && docked == 0) {
            closePanel()
            applyDock(store.overlayDock)
        }
    }

    fun update(main: String, sub: String, progress: Float, color: Int) {
        if (view != null && appliedDp != store.overlaySizeDp) hideView()
        val v = view ?: create()
        v.set(main, sub, progress, color)
        if (store.catOn && store.catVisible) cats.start() else cats.stop()
    }

    fun hide() {
        hideView()
        cats.stop()
    }

    private fun hideView() {
        handler.removeCallbacks(redock)
        handler.removeCallbacks(collapsePanel)
        panelOpen = false
        val v = view
        if (v != null) {
            try {
                wm.removeView(v)
            } catch (_: Exception) {
            }
        }
        view = null
        params = null
        docked = 0
    }

    private fun clampFree(p: WindowManager.LayoutParams) {
        val dm = ctx.resources.displayMetrics
        p.x = p.x.coerceIn(0, (dm.widthPixels - size).coerceAtLeast(0))
        p.y = p.y.coerceIn(0, (dm.heightPixels - size).coerceAtLeast(0))
    }

    private fun push(v: View, p: WindowManager.LayoutParams) {
        try {
            wm.updateViewLayout(v, p)
        } catch (_: Exception) {
        }
    }

    private var curDp = 96f

    private fun panelW() = (size * 1.3f).toInt()

    /** Sayacı biraz genişletip yanında "Kedi" anahtarını gösterir (sığmazsa sola açılır). */
    private fun openPanel() {
        val p = params ?: return
        val v = view ?: return
        val dm = ctx.resources.displayMetrics
        val pw = panelW()
        panelOpen = true
        panelRestoreX = p.x
        val left = p.x + size + pw > dm.widthPixels
        p.width = size + pw
        if (left) p.x -= pw
        v.setPanel(true, left, store.catOn, pw)
        push(v, p)
        handler.removeCallbacks(collapsePanel)
        handler.postDelayed(collapsePanel, 5000L)
    }

    private fun closePanel() {
        if (!panelOpen) return
        panelOpen = false
        handler.removeCallbacks(collapsePanel)
        val p = params ?: return
        val v = view ?: return
        p.width = size
        p.x = panelRestoreX
        v.setPanel(false, false, store.catOn, 0)
        push(v, p)
    }

    private fun toggleCat(rx: Float, ry: Float) {
        val on = !store.catOn
        store.catOn = on
        view?.setPanel(panelOpen, view?.chipLeft == true, on, panelW())
        if (on) {
            cats.start()
            cats.party(rx, ry)
        } else {
            cats.stop()
        }
        handler.removeCallbacks(collapsePanel)
        handler.postDelayed(collapsePanel, 5000L)
    }

    /** Boyutu değiştirir, merkezi korur. Kenarda yapışıkken çağrılmaz. */
    private fun setSizeDp(dp: Float) {
        val p = params ?: return
        val v = view ?: return
        curDp = dp.coerceIn(56f, 200f)
        val ndp = curDp.toInt()
        val nsize = (ndp * density).toInt()
        if (nsize == size) return
        p.x += (size - nsize) / 2
        p.y += (size - nsize) / 2
        size = nsize
        appliedDp = ndp
        store.overlaySizeDp = ndp
        p.width = size
        p.height = size
        clampFree(p)
        push(v, p)
    }

    /** Kenara yapış: küçül, saydamlaş, yarısı ekran dışında. */
    private fun applyDock(edge: Int) {
        val p = params ?: return
        val v = view ?: return
        val dm = ctx.resources.displayMetrics
        val w = dm.widthPixels
        val h = dm.heightPixels
        val ds = dockSize
        p.width = ds
        p.height = ds
        when (edge) {
            1 -> { p.x = -ds / 2; p.y = p.y.coerceIn(0, (h - ds).coerceAtLeast(0)) }
            2 -> { p.x = w - ds / 2; p.y = p.y.coerceIn(0, (h - ds).coerceAtLeast(0)) }
            3 -> { p.y = -ds / 2; p.x = p.x.coerceIn(0, (w - ds).coerceAtLeast(0)) }
            else -> { p.y = h - ds / 2; p.x = p.x.coerceIn(0, (w - ds).coerceAtLeast(0)) }
        }
        v.alpha = 0.5f
        docked = edge
        store.overlayDock = edge
        push(v, p)
    }

    /** Kenardaki sayacı tam boyuta aç (ekranın içinde), kısa süre sonra tekrar yapışır. */
    private fun expand(edge: Int) {
        val p = params ?: return
        val v = view ?: return
        val dm = ctx.resources.displayMetrics
        p.width = size
        p.height = size
        when (edge) {
            1 -> p.x = 0
            2 -> p.x = dm.widthPixels - size
            3 -> p.y = 0
            else -> p.y = dm.heightPixels - size
        }
        clampFree(p)
        v.alpha = 1f
        docked = 0
        push(v, p)
        handler.removeCallbacks(redock)
        handler.postDelayed(redock, 4000L)
    }

    private fun create(): CircleView {
        val dm = ctx.resources.displayMetrics
        appliedDp = store.overlaySizeDp
        curDp = appliedDp.toFloat()
        size = (appliedDp * density).toInt()
        val p = WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        p.gravity = Gravity.TOP or Gravity.START
        val sx = store.overlayX
        val sy = store.overlayY
        p.x = if (sx >= 0) sx else dm.widthPixels - size - (16 * density).toInt()
        p.y = if (sy >= 0) sy else (80 * density).toInt()
        clampFree(p)

        val v = CircleView(ctx)
        v.setOnTouchListener(DragListener())
        wm.addView(v, p)
        view = v
        params = p
        docked = 0
        if (store.overlayDock != 0) applyDock(store.overlayDock)
        return v
    }

    /** Sürükleme bitince: kenara yakınsa yapıştır, değilse olduğu yerde bırak. */
    private fun drop(p: WindowManager.LayoutParams) {
        clampFree(p)
        store.overlayX = p.x
        store.overlayY = p.y
        val dm = ctx.resources.displayMetrics
        val dl = p.x
        val dr = dm.widthPixels - (p.x + size)
        val dt = p.y
        val db = dm.heightPixels - (p.y + size)
        val m = min(min(dl, dr), min(dt, db))
        if (m <= (24 * density).toInt()) {
            val edge = when (m) {
                dl -> 1
                dr -> 2
                dt -> 3
                else -> 4
            }
            applyDock(edge)
        } else {
            store.overlayDock = 0
        }
    }

    private inner class DragListener : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var downX = 0f
        private var downY = 0f
        private var moved = false
        private var scaling = false
        private var longFired = false

        private val presets = intArrayOf(64, 96, 140, 190)
        private val longPress = Runnable {
            if (!moved && !scaling && docked == 0) {
                closePanel()
                longFired = true
                // Hazır boyutlar arasında geç: küçük, orta, büyük, çok büyük.
                val next = presets.firstOrNull { it > appliedDp + 4 } ?: presets[0]
                setSizeDp(next.toFloat())
            }
        }

        private val detector = ScaleGestureDetector(ctx, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(d: ScaleGestureDetector): Boolean {
                if (docked != 0) return true
                handler.removeCallbacks(longPress)
                closePanel()
                setSizeDp(curDp * d.scaleFactor)
                return true
            }
        })

        override fun onTouch(v: View, e: MotionEvent): Boolean {
            val p = params ?: return false
            detector.onTouchEvent(e)
            when (e.actionMasked) {
                MotionEvent.ACTION_POINTER_DOWN -> {
                    closePanel()
                    scaling = true
                    moved = true
                    handler.removeCallbacks(longPress)
                }
                MotionEvent.ACTION_DOWN -> {
                    handler.removeCallbacks(redock)
                    longFired = false
                    scaling = false
                    handler.removeCallbacks(longPress)
                    handler.postDelayed(longPress, 650L)
                    startX = p.x
                    startY = p.y
                    downX = e.rawX
                    downY = e.rawY
                    moved = false
                }
                MotionEvent.ACTION_MOVE -> {
                    if (scaling || e.pointerCount > 1) return true
                    val dx = (e.rawX - downX).toInt()
                    val dy = (e.rawY - downY).toInt()
                    if (!moved && (abs(dx) > slop || abs(dy) > slop)) {
                        moved = true
                        handler.removeCallbacks(longPress)
                        if (panelOpen) {
                            closePanel()
                            startX = p.x
                            startY = p.y
                        }
                        if (docked != 0) {
                            // Kenardan sürüklenince tam boyuta dönüp parmağı takip eder.
                            docked = 0
                            store.overlayDock = 0
                            p.width = size
                            p.height = size
                            p.x = (e.rawX - size / 2f).toInt()
                            p.y = (e.rawY - size / 2f).toInt()
                            v.alpha = 1f
                            startX = p.x
                            startY = p.y
                            downX = e.rawX
                            downY = e.rawY
                            clampFree(p)
                            push(v, p)
                            return true
                        }
                    }
                    if (moved) {
                        p.x = startX + dx
                        p.y = startY + dy
                        clampFree(p)
                        push(v, p)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    handler.removeCallbacks(longPress)
                    if (longFired) {
                        longFired = false
                        if (store.overlayDock != 0) handler.postDelayed(redock, 4000L)
                    } else if (moved) {
                        drop(p)
                        scaling = false
                    } else if (docked != 0) {
                        expand(docked)
                    } else {
                        val cv = view
                        if (!panelOpen && store.catVisible) {
                            openPanel()
                        } else if (!panelOpen) {
                            // Kedi ayarı kapalıysa sayaç genişlemez; dokunmak sadece rengi değiştirir.
                            if (store.current.isNotEmpty()) {
                                store.nextColor(store.current)
                                cv?.set(
                                    null, null, null,
                                    Store.COLORS[store.colorIndex(store.current)]
                                )
                            }
                        } else if (cv != null && cv.hitChip(e.x)) {
                            toggleCat(e.rawX, e.rawY)
                        } else {
                            if (store.current.isNotEmpty()) {
                                // Genişlemişken sayaca dokununca renk değişir (kullanıcı girişliyken).
                                store.nextColor(store.current)
                                cv?.set(
                                    null, null, null,
                                    Store.COLORS[store.colorIndex(store.current)]
                                )
                            }
                            handler.removeCallbacks(collapsePanel)
                            handler.postDelayed(collapsePanel, 5000L)
                        }
                        if (store.overlayDock != 0) {
                            handler.postDelayed(redock, 4000L)
                        }
                    }
                }
                MotionEvent.ACTION_CANCEL -> {
                    handler.removeCallbacks(longPress)
                    scaling = false
                    if (store.overlayDock != 0 && docked == 0) handler.postDelayed(redock, 4000L)
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

        // "Kedi" paneli
        private var panel = false
        var chipLeft = false
            private set
        private var catOn = false
        private var chipW = 0

        private val chipFill = Paint(Paint.ANTI_ALIAS_FLAG)
        private val chipText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT_BOLD
            color = 0xFF333333.toInt()
        }
        private val chipRect = RectF()

        fun setPanel(open: Boolean, left: Boolean, on: Boolean, w: Int) {
            panel = open
            chipLeft = left
            catOn = on
            chipW = w
            invalidate()
        }

        /** Dokunma (görünüm içi x) "Kedi" kutusunun üstünde mi. */
        fun hitChip(x: Float): Boolean =
            if (chipLeft) x < chipW else x > width - chipW

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
            val w = height.toFloat()
            val h = height.toFloat()
            val f = w / (96 * d)
            if (panel) drawChip(canvas, h, f)
            canvas.save()
            if (panel && chipLeft) canvas.translate(chipW.toFloat(), 0f)
            track.strokeWidth = 7 * d * f
            arc.strokeWidth = 7 * d * f
            t1.textSize = 21 * d * f
            t2.textSize = 11 * d * f
            fill.color = (color and 0x00FFFFFF) or (0xE6 shl 24)
            canvas.drawCircle(w / 2, h / 2, w / 2 - 1, fill)
            val sw = arc.strokeWidth
            val r = RectF(sw, sw, w - sw, h - sw)
            canvas.drawArc(r, 0f, 360f, false, track)
            canvas.drawArc(r, -90f, 360f * progress, false, arc)
            canvas.drawText(main, w / 2, h * 0.52f, t1)
            canvas.drawText(sub, w / 2, h * 0.52f + t2.textSize + 2 * d, t2)
            canvas.restore()
        }

        /** Sayacın yanındaki "Kedi" anahtarı. */
        private fun drawChip(canvas: Canvas, h: Float, f: Float) {
            val left = if (chipLeft) 2f else h + 4 * d * f
            val right = if (chipLeft) chipW - 4 * d * f else width - 2f
            chipRect.set(left, h * 0.18f, right, h * 0.82f)
            chipFill.color = 0xF2FFFFFF.toInt()
            canvas.drawRoundRect(chipRect, h * 0.32f, h * 0.32f, chipFill)

            chipText.textSize = 15 * d * f
            canvas.drawText("Kedi", left + 12 * d * f, chipRect.centerY() + chipText.textSize * 0.35f, chipText)

            // Anahtar
            val tw = 34 * d * f
            val th = 18 * d * f
            val tx = right - 10 * d * f - tw
            val ty = chipRect.centerY() - th / 2
            chipFill.color = if (catOn) 0xFF27AE60.toInt() else 0xFFB0B0B0.toInt()
            chipRect.set(tx, ty, tx + tw, ty + th)
            canvas.drawRoundRect(chipRect, th / 2, th / 2, chipFill)
            chipFill.color = Color.WHITE
            val kx = if (catOn) tx + tw - th / 2 else tx + th / 2
            canvas.drawCircle(kx, ty + th / 2, th / 2 - 2 * d * f, chipFill)
        }
    }
}
