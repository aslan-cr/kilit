package com.beranmeva.kilit

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Point
import android.graphics.RectF
import android.hardware.display.DisplayManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * "Kedi" ayarı açıkken:
 * - Kedi partisi: dokunulan yerden konfeti ve kedi emojileri fışkırır, miyav sesi çalar.
 * - Ekranın altında 3 minik kedi dolaşır. Parmakla havaya kaldırılıp bırakılabilir.
 * - Ekran dönünce kediler yukarıdan düşer, yere değmeden hemen önce 4 ayak üstüne döner.
 * Her kedi kendi küçük penceresindedir; bu yüzden kedilerin dışında kalan yere dokunmalar
 * altındaki uygulamaya geçer.
 */
class CatOverlay(private val ctx: Context) {

    private companion object {
        const val WALK = 0
        const val CARRY = 1
        const val FALL = 2
        const val LAND = 3
        const val CAT_COUNT = 3
    }

    private val wm = ctx.getSystemService(WindowManager::class.java)
    private val dmgr = ctx.getSystemService(DisplayManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val density = ctx.resources.displayMetrics.density
    private val catPx = (60 * density).toInt()
    private val gravity = 1500f * density
    private val cats = ArrayList<Cat>()
    private var running = false
    private var lastRotation = -1
    private var party: PartyView? = null
    private var lastMeow = 0L

    private val palette = intArrayOf(0xFFF2994A.toInt(), 0xFF9E9E9E.toInt(), 0xFF4E4E55.toInt())
    private val bellies = intArrayOf(0xFFFFE0B8.toInt(), 0xFFEDEDED.toInt(), 0xFFB9B9C2.toInt())

    private fun screen(): Point {
        val m = DisplayMetrics()
        @Suppress("DEPRECATION")
        dmgr.getDisplay(Display.DEFAULT_DISPLAY).getRealMetrics(m)
        return Point(m.widthPixels, m.heightPixels)
    }

    private fun rotation(): Int = dmgr.getDisplay(Display.DEFAULT_DISPLAY).rotation

    private fun floorY(h: Int): Float = h - catPx - 8 * density

    // ---------------------------------------------------------------- yaşam döngüsü

    fun start() {
        if (running) return
        running = true
        lastRotation = rotation()
        val sc = screen()
        val floor = floorY(sc.y)
        for (i in 0 until CAT_COUNT) {
            val c = Cat(palette[i], bellies[i])
            c.x = (sc.x - catPx) * (0.15f + 0.3f * i)
            c.y = floor
            c.dir = if (i % 2 == 0) 1 else -1
            c.speed = (26 + 14 * i) * density
            c.pause = 0.3f * i
            if (!addCat(c)) {
                running = false
                stop()
                return
            }
            cats.add(c)
        }
        handler.post(tick)
    }

    fun stop() {
        running = false
        handler.removeCallbacks(tick)
        for (c in cats) {
            try {
                wm.removeView(c.view)
            } catch (_: Exception) {
            }
        }
        cats.clear()
        removeParty()
    }

    private fun addCat(c: Cat): Boolean {
        val lp = WindowManager.LayoutParams(
            catPx,
            catPx,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = c.x.toInt()
        lp.y = c.y.toInt()
        val v = CatView(ctx, c)
        c.view = v
        c.lp = lp
        return try {
            wm.addView(v, lp)
            true
        } catch (_: Exception) {
            false
        }
    }

    // ---------------------------------------------------------------- parti

    /** Dokunulan noktadan parti başlatır: konfeti, miyav, zıplayan kediler. */
    fun party(x: Float, y: Float) {
        meow(1f)
        removeParty()
        val sc = screen()
        val lp = WindowManager.LayoutParams(
            sc.x,
            sc.y,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = 0
        lp.y = 0
        val pv = PartyView(ctx, x, y)
        try {
            wm.addView(pv, lp)
            party = pv
            handler.post(partyTick)
        } catch (_: Exception) {
        }
        // Kediler de parti için zıplayıp takla atsın.
        handler.postDelayed({
            if (running) for ((i, c) in cats.withIndex()) handler.postDelayed({ hop(c) }, 120L * i)
        }, 250L)
    }

    private fun removeParty() {
        handler.removeCallbacks(partyTick)
        party?.let {
            try {
                wm.removeView(it)
            } catch (_: Exception) {
            }
        }
        party = null
    }

    private val partyTick = object : Runnable {
        override fun run() {
            val pv = party ?: return
            if (pv.step(0.033f)) {
                handler.postDelayed(this, 33)
            } else {
                removeParty()
            }
        }
    }

    private fun hop(c: Cat) {
        if (c.mode != WALK && c.mode != LAND) return
        c.mode = FALL
        c.vy = -700f * density
        c.startH = 140f * density
        c.spin = if (Math.random() < 0.5) 360f else -360f
    }

    // ---------------------------------------------------------------- ses

    /** Miyav sesi üretir (dosya gerekmez): yükselip alçalan perde, armonikli. */
    private fun meow(pitch: Float) {
        val now = System.currentTimeMillis()
        if (now - lastMeow < 500L) return
        lastMeow = now
        try {
            val sr = 22050
            val n = (sr * 0.7).toInt()
            val buf = ShortArray(n)
            var ph = 0.0
            for (i in 0 until n) {
                val t = i / n.toDouble()
                val f = pitch * (420.0 + 400.0 * sin(PI * t.pow(0.8))) *
                    (1.0 + 0.012 * sin(2 * PI * 28 * t))
                ph += 2 * PI * f / sr
                val env = sin(PI * t).pow(0.6) * (0.78 + 0.22 * cos(2 * PI * 2.2 * t))
                val s = sin(ph) + 0.5 * sin(2 * ph) + 0.28 * sin(3 * ph)
                buf[i] = (s * env * 0.32 * Short.MAX_VALUE).toInt().toShort()
            }
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sr)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(n * 2)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
            track.write(buf, 0, n)
            track.play()
            handler.postDelayed({
                try {
                    track.release()
                } catch (_: Exception) {
                }
            }, 1200L)
        } catch (_: Exception) {
        }
    }

    // ---------------------------------------------------------------- hareket

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            try {
                step(0.033f)
            } catch (_: Exception) {
            }
            handler.postDelayed(this, 33)
        }
    }

    private fun step(dt: Float) {
        val sc = screen()
        val floor = floorY(sc.y)
        val maxX = (sc.x - catPx).toFloat().coerceAtLeast(0f)

        // Ekran döndüyse: kediler yukarıdan düşsün.
        val r = rotation()
        if (r != lastRotation) {
            lastRotation = r
            for (c in cats) {
                c.x = (Math.random() * maxX).toFloat()
                c.y = -catPx - (Math.random() * 80 * density).toFloat()
                c.vy = 0f
                c.mode = FALL
                c.startH = floor - c.y
                c.spin = if (Math.random() < 0.5) 540f else -540f
            }
        }

        for (c in cats) {
            when (c.mode) {
                WALK -> {
                    c.y = floor
                    c.angle = 0f
                    c.tailT += dt * 4f
                    if (c.pause > 0f) {
                        c.pause -= dt
                    } else {
                        c.x += c.dir * c.speed * dt
                        c.phase += dt * 9f
                        if (c.x < 0f) {
                            c.x = 0f
                            c.dir = 1
                        } else if (c.x > maxX) {
                            c.x = maxX
                            c.dir = -1
                        }
                        if (Math.random() < 0.006) c.pause = 0.6f + (Math.random() * 1.8).toFloat()
                        if (Math.random() < 0.004) c.dir = -c.dir
                    }
                }
                CARRY -> {
                    c.phase += dt * 12f
                    c.angle = sin(c.phase) * 6f
                }
                FALL -> {
                    c.vy += gravity * dt
                    c.y += c.vy * dt
                    c.x = c.x.coerceIn(0f, maxX)
                    if (c.vy > 0f && c.y >= floor) {
                        c.y = floor
                        c.angle = 0f
                        c.mode = LAND
                        c.squash = 1f
                    } else {
                        // Yere yaklaştıkça dönüş sıfırlanır: son anda 4 ayak üstüne iner.
                        val rem = ((floor - c.y) / c.startH).coerceIn(0f, 1f)
                        c.angle = c.spin * rem * rem
                    }
                }
                LAND -> {
                    c.y = floor
                    c.angle = 0f
                    c.squash -= dt * 4f
                    if (c.squash <= 0f) {
                        c.squash = 0f
                        c.mode = WALK
                        c.pause = 0.4f
                    }
                }
            }
            c.lp.x = c.x.toInt()
            c.lp.y = c.y.toInt()
            try {
                wm.updateViewLayout(c.view, c.lp)
            } catch (_: Exception) {
            }
            c.view.invalidate()
        }
    }

    private fun release(c: Cat) {
        val floor = floorY(screen().y)
        if (c.y >= floor - 2f) {
            c.y = floor
            c.mode = WALK
            c.pause = 0.3f
            return
        }
        c.mode = FALL
        c.vy = 0f
        c.startH = (floor - c.y).coerceAtLeast(1f)
        val k = min(1f, c.startH / (150f * density))
        c.spin = (if (Math.random() < 0.5) 1f else -1f) * 540f * k
    }

    // ---------------------------------------------------------------- kedi

    private inner class Cat(val color: Int, val belly: Int) {
        var x = 0f
        var y = 0f
        var vy = 0f
        var dir = 1
        var mode = WALK
        var phase = 0f
        var angle = 0f
        var spin = 0f
        var startH = 1f
        var squash = 0f
        var pause = 0f
        var speed = 30f
        var tailT = 0f
        var grabDx = 0f
        var grabDy = 0f
        lateinit var view: CatView
        lateinit var lp: WindowManager.LayoutParams

        private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        private val path = Path()
        private val oval = RectF()

        fun draw(c: Canvas, s: Float) {
            val u = s / 60f
            c.save()
            if (dir < 0) c.scale(-1f, 1f, s / 2, s / 2)
            val sq = if (mode == LAND) squash else 0f
            c.scale(1f + 0.15f * sq, 1f - 0.2f * sq, s / 2, s)
            c.rotate(angle, s / 2, s * 0.55f)

            // Kuyruk
            val wig = sin(tailT) * 4f * u
            line.color = color
            line.strokeWidth = 5f * u
            path.reset()
            path.moveTo(14f * u, 36f * u)
            path.quadTo(1f * u, 36f * u + wig, 6f * u, 17f * u + wig)
            c.drawPath(path, line)

            // Bacaklar (gövdeden önce çizilir, üstleri gövdenin altında kalır)
            line.strokeWidth = 5f * u
            val xs = floatArrayOf(17f, 23f, 36f, 42f)
            for (i in 0..3) {
                val bx = xs[i] * u
                var fx = bx
                var fy = 53f * u
                when (mode) {
                    WALK -> {
                        val sw = sin(phase + (i % 2) * PI.toFloat())
                        fx += sw * 5f * u
                        if (sw > 0.6f) fy -= 3f * u
                    }
                    CARRY -> {
                        fx += sin(phase * 1.3f + i) * 3f * u
                        fy = 58f * u
                    }
                    FALL -> fx += (i - 1.5f) * 3.5f * u
                    else -> {}
                }
                c.drawLine(bx, 42f * u, fx, fy, line)
            }

            // Gövde ve karın
            fill.color = color
            oval.set(10f * u, 26f * u, 44f * u, 46f * u)
            c.drawOval(oval, fill)
            fill.color = belly
            oval.set(17f * u, 36f * u, 37f * u, 46f * u)
            c.drawOval(oval, fill)

            // Baş
            fill.color = color
            c.drawCircle(46f * u, 26f * u, 10f * u, fill)
            path.reset()
            path.moveTo(38f * u, 21f * u)
            path.lineTo(40f * u, 8f * u)
            path.lineTo(46f * u, 17f * u)
            path.close()
            path.moveTo(46f * u, 17f * u)
            path.lineTo(52f * u, 8f * u)
            path.lineTo(54f * u, 21f * u)
            path.close()
            c.drawPath(path, fill)

            // Yüz
            fill.color = Color.rgb(35, 35, 40)
            c.drawCircle(43f * u, 24f * u, 1.8f * u, fill)
            c.drawCircle(50f * u, 24f * u, 1.8f * u, fill)
            fill.color = Color.rgb(240, 130, 150)
            c.drawCircle(54f * u, 28f * u, 1.5f * u, fill)
            line.color = Color.argb(160, 30, 30, 35)
            line.strokeWidth = 1f * u
            c.drawLine(52f * u, 29f * u, 59f * u, 27f * u, line)
            c.drawLine(52f * u, 30f * u, 59f * u, 31f * u, line)
            c.restore()
        }
    }

    private inner class CatView(c: Context, val cat: Cat) : View(c) {
        init {
            setOnTouchListener { _, e ->
                when (e.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        cat.mode = CARRY
                        cat.grabDx = e.rawX - cat.x
                        cat.grabDy = e.rawY - cat.y
                        meow(0.9f + (Math.random() * 0.4).toFloat())
                    }
                    MotionEvent.ACTION_MOVE -> {
                        if (cat.mode == CARRY) {
                            val sc = screen()
                            cat.x = (e.rawX - cat.grabDx)
                                .coerceIn(-catPx / 2f, sc.x - catPx / 2f)
                            cat.y = (e.rawY - cat.grabDy).coerceIn(0f, floorY(sc.y))
                            cat.lp.x = cat.x.toInt()
                            cat.lp.y = cat.y.toInt()
                            try {
                                wm.updateViewLayout(this, cat.lp)
                            } catch (_: Exception) {
                            }
                        }
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        if (cat.mode == CARRY) release(cat)
                    }
                }
                true
            }
        }

        override fun onDraw(canvas: Canvas) {
            cat.draw(canvas, width.toFloat())
        }
    }

    // ---------------------------------------------------------------- parti görünümü

    private inner class PartyView(c: Context, private val ox: Float, private val oy: Float) : View(c) {
        private inner class P(
            var x: Float, var y: Float, var vx: Float, var vy: Float,
            var rot: Float, var vr: Float, val emoji: String?, val color: Int, val size: Float,
            val life: Float
        )

        private val ps = ArrayList<P>()
        private var t = 0f
        private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
        private val box = Paint(Paint.ANTI_ALIAS_FLAG)
        private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 6f * density
        }

        init {
            val emojis = arrayOf("🐱", "🐾", "😸", "⭐", "🎉", "🐈")
            val colors = intArrayOf(
                0xFFEB5757.toInt(), 0xFFF2C94C.toInt(), 0xFF27AE60.toInt(),
                0xFF2D9CDB.toInt(), 0xFFBB6BD9.toInt(), 0xFFE91E8C.toInt()
            )
            repeat(46) { i ->
                val a = -PI / 2 + (Math.random() - 0.5) * PI * 1.5
                val sp = (350 + Math.random() * 950).toFloat() * density
                val isEmoji = i % 3 == 0
                ps.add(
                    P(
                        ox, oy,
                        (cos(a) * sp).toFloat(), (sin(a) * sp).toFloat(),
                        (Math.random() * 360).toFloat(), ((Math.random() - 0.5) * 540).toFloat(),
                        if (isEmoji) emojis[(Math.random() * emojis.size).toInt()] else null,
                        colors[(Math.random() * colors.size).toInt()],
                        (if (isEmoji) 26 + Math.random() * 16 else 7 + Math.random() * 7).toFloat() * density,
                        (1.8 + Math.random() * 1.0).toFloat()
                    )
                )
            }
        }

        /** false dönerse parti bitti. */
        fun step(dt: Float): Boolean {
            t += dt
            for (p in ps) {
                p.vy += 1100f * density * dt
                p.vx *= 0.992f
                p.x += p.vx * dt
                p.y += p.vy * dt
                p.rot += p.vr * dt
            }
            invalidate()
            return t < 3f
        }

        override fun onDraw(canvas: Canvas) {
            if (t < 0.5f) {
                val k = t / 0.5f
                ring.color = Color.argb(((1f - k) * 200).toInt(), 255, 200, 60)
                canvas.drawCircle(ox, oy, 20f * density + k * 120f * density, ring)
            }
            for (p in ps) {
                val a = ((p.life - t) / 0.6f).coerceIn(0f, 1f)
                if (a <= 0f) continue
                canvas.save()
                canvas.rotate(p.rot, p.x, p.y)
                if (p.emoji != null) {
                    text.textSize = p.size
                    text.alpha = (a * 255).toInt()
                    canvas.drawText(p.emoji, p.x, p.y + p.size / 3f, text)
                } else {
                    box.color = (p.color and 0x00FFFFFF) or ((a * 255).toInt() shl 24)
                    canvas.drawRect(p.x - p.size / 2, p.y - p.size / 4, p.x + p.size / 2, p.y + p.size / 4, box)
                }
                canvas.restore()
            }
        }
    }
}
