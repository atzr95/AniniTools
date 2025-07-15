package anini.aninitools.ui.flashlight

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.animation.ValueAnimator
import android.view.View
import android.view.animation.LinearInterpolator

class SmoothMarqueeTextView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 96f * resources.displayMetrics.scaledDensity
        typeface = Typeface.DEFAULT_BOLD
        isLinearText = true // Enable optimized text rendering
    }

    private var text = ""
    private var textWidth = 0f
    private var translateX = 0f
    private var animator: ValueAnimator? = null
    private var animationDuration = 10000L // Default 10 seconds
    private var isScrolling = false

    fun setText(newText: String) {
        text = newText
        textWidth = textPaint.measureText(text)
        invalidate()
    }

    fun setTextSize(size: Float) {
        textPaint.textSize = size * resources.displayMetrics.scaledDensity
        textWidth = textPaint.measureText(text)
        invalidate()
    }

    fun setTextColor(color: Int) {
        textPaint.color = color
        invalidate()
    }

    fun setSpeed(speedPercent: Int) {
        // Convert speed (0-100) to duration (20s to 2s)
        animationDuration = (20000L - (speedPercent * 180L)).coerceAtLeast(2000L)
        if (isScrolling) {
            startScrolling() // Restart with new speed
        }
    }

    fun startScrolling() {
        if (text.isEmpty() || width <= 0) return
        
        stopScrolling()
        isScrolling = true
        
        // Calculate total distance: from right edge to completely off left
        val startX = width.toFloat()
        val endX = -textWidth
        val totalDistance = startX - endX
        
        animator = ValueAnimator.ofFloat(startX, endX).apply {
            duration = animationDuration
            interpolator = LinearInterpolator()
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            
            addUpdateListener { animation ->
                translateX = animation.animatedValue as Float
                invalidate()
            }
            
            start()
        }
    }

    fun stopScrolling() {
        animator?.cancel()
        animator = null
        isScrolling = false
        translateX = 0f
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        if (text.isEmpty()) return

        // Calculate vertical center position
        val fontMetrics = textPaint.fontMetrics
        val textHeight = fontMetrics.descent - fontMetrics.ascent
        val y = (height - textHeight) / 2 - fontMetrics.ascent

        canvas.save()
        
        if (isScrolling) {
            canvas.drawText(text, translateX, y, textPaint)
        } else {
            // Draw centered static text
            val x = (width - textWidth) / 2
            canvas.drawText(text, x, y, textPaint)
        }
        
        canvas.restore()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // Restart animation if it was running
        if (isScrolling) {
            post { startScrolling() }
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopScrolling()
    }

    override fun onVisibilityChanged(changedView: View, visibility: Int) {
        super.onVisibilityChanged(changedView, visibility)
        if (visibility != View.VISIBLE) {
            stopScrolling()
        }
    }
} 