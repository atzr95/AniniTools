package anini.aninitools.ui.flashlight

import android.content.Context
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatImageView
import androidx.vectordrawable.graphics.drawable.AnimatedVectorDrawableCompat
import anini.aninitools.R

class FlashMorphView @JvmOverloads constructor(
        context:Context,
        attrs:AttributeSet? = null,
        defStyleAttr : Int =0) : AppCompatImageView(context, attrs, defStyleAttr){

    private var onToOff: AnimatedVectorDrawableCompat? = null
    private var offToOn: AnimatedVectorDrawableCompat? = null
    private var showingOff: Boolean = false

    init {
        showingOff = true
        onToOff = AnimatedVectorDrawableCompat.create(context, R.drawable.ic_flashlight_off)
        offToOn = AnimatedVectorDrawableCompat.create(context, R.drawable.ic_flashlight_on)
        setImageDrawable(onToOff)
    }

    fun showOff() {
        if (!showingOff) {
            morph()
        }
    }

    fun showOn() {
        if (showingOff) {
            morph()
        }
    }

    fun morph() {
        val drawable = if (showingOff) offToOn else onToOff
        setImageDrawable(drawable)
        drawable?.start()
        showingOff = !showingOff
    }

    fun morphOff(){
        val drawable = onToOff
        setImageDrawable(drawable)
        drawable?.start()
        showingOff = true
    }

    fun morphOn(){
        val drawable = offToOn
        setImageDrawable(drawable)
        drawable?.start()
        showingOff = false
    }
}