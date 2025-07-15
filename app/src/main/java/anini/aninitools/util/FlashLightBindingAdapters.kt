package anini.aninitools.util

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.databinding.BindingAdapter
import anini.aninitools.R
import anini.aninitools.ui.flashlight.FlashMorphView

@BindingAdapter("screenFlashColor", "screenFlashActive")
fun setScreenFlashOverlay(view: View, color: Int?, active: Boolean) {
    if (active && color != null) {
        view.setBackgroundColor(color)
        view.visibility = View.VISIBLE
    } else {
        view.visibility = View.GONE
    }
}

@BindingAdapter("colorPickerBackground")
fun setColorPickerButtonBackground(view: View, color: Int?) {
    if (color != null) {
        // Create a layered drawable with the color and border
        val colorDrawable = android.graphics.drawable.ColorDrawable(color)
        val borderDrawable = view.context.getDrawable(anini.aninitools.R.drawable.color_swatch_border)
        
        val layerDrawable = android.graphics.drawable.LayerDrawable(arrayOf(colorDrawable, borderDrawable))
        view.background = layerDrawable
    }
}

@BindingAdapter("screenFlashButtonStyle", "flashButtonBackground")
fun setFlashButtonBackground(view: FlashMorphView, isScreenFlashEnabled: Boolean, flashColor: Int?) {
    if (isScreenFlashEnabled && flashColor != null) {
        // Create a darker version of the flash color for the button background
        val darkerColor = darkenColor(flashColor, 0.3f) // 30% darker
        
        // Create a rounded rectangle drawable with the darker color
        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(darkerColor)
            cornerRadius = 20f // Match the rounded corners
        }
        
        view.background = drawable
    } else {
        // Use default background
        view.background = ContextCompat.getDrawable(view.context, R.drawable.roundedcorneroff)
    }
}

@BindingAdapter("flashButtonIcon")
fun setFlashButtonIcon(view: FlashMorphView, flashColor: Int?) {
    if (flashColor != null) {
        // Create a slightly darker version of the flash color for the icon
        val darkerColor = darkenColor(flashColor, 0.2f) // 20% darker
        view.setColorFilter(darkerColor)
    } else {
        // Clear color filter to use default icon color
        view.clearColorFilter()
    }
}

// Helper function to darken a color
private fun darkenColor(color: Int, factor: Float): Int {
    val hsv = FloatArray(3)
    Color.colorToHSV(color, hsv)
    hsv[2] *= (1f - factor) // Reduce the brightness
    return Color.HSVToColor(hsv)
}

@BindingAdapter("rollingTextActive")
fun setRollingTextVisibility(textView: TextView, active: Boolean) {
    textView.visibility = if (active) View.VISIBLE else View.GONE
}

@BindingAdapter("conditionalVisibility")
fun setConditionalVisibility(view: View, isVisible: Boolean) {
    view.visibility = if (isVisible) View.VISIBLE else View.GONE
} 