package anini.aninitools.util

import android.animation.Animator
import android.annotation.TargetApi
import android.os.Build
import android.view.View
import android.view.ViewAnimationUtils
import android.widget.LinearLayout
import androidx.cardview.widget.CardView
import androidx.core.content.ContextCompat
import androidx.databinding.BindingAdapter
import androidx.transition.TransitionManager
import anini.aninitools.R
import anini.aninitools.ui.flashlight.ButtonState
import anini.aninitools.ui.flashlight.FlashMorphView
import anini.aninitools.ui.sensor.ExpandMorphView
import anini.aninitools.ui.sensor.ExpandState


@BindingAdapter("app:circleReveal")
fun showCircleReveal(view: View,buttonState: ButtonState){
    when(buttonState) {
        ButtonState.ON -> {
            createCircularReveal(view)
        }
        ButtonState.OFF ->{
            hideCircularReveal(view)
        }
        ButtonState.START ->{
            //do nothing
        }
    }
}

@BindingAdapter("app:buttonState", "app:screenFlashEnabled", "app:flashColor", requireAll = false)
fun showFlashButtonState(flashButton: FlashMorphView, buttonState: ButtonState, screenFlashEnabled: Boolean = false, flashColor: Int? = null){

        when(buttonState) {
            ButtonState.ON ->{
                flashButton.morphOn()
                // Always use the original drawable to preserve morphing
                val drawable = ContextCompat.getDrawable(flashButton.context!!, R.drawable.roundedcorneron)
                flashButton.background = drawable
                
                if (screenFlashEnabled && flashColor != null) {
                    // Tint the background to a darker version of the flash color
                    val darkerColor = darkenColor(flashColor, 0.3f)
                    drawable?.setTint(darkerColor)
                    
                    // Also tint the icon to a slightly darker version
                    val iconColor = darkenColor(flashColor, 0.2f)
                    flashButton.setColorFilter(iconColor)
                } else {
                    // Clear any tints to use original colors
                    drawable?.setTintList(null)
                    flashButton.clearColorFilter()
                }
        }
            ButtonState.OFF ->{
                flashButton.morphOff()
                // Always use the original drawable to preserve morphing
                val drawable = ContextCompat.getDrawable(flashButton.context!!, R.drawable.roundedcorneroff)
                flashButton.background = drawable
                
                // Clear any tints and color filters for OFF state
                drawable?.setTintList(null)
                flashButton.clearColorFilter()
            }
            ButtonState.START ->{
                flashButton.clearColorFilter()
                //do nothing
            }
        }
}

// Helper function to darken a color
private fun darkenColor(color: Int, factor: Float): Int {
    val hsv = FloatArray(3)
    android.graphics.Color.colorToHSV(color, hsv)
    hsv[2] *= (1f - factor) // Reduce the brightness
    return android.graphics.Color.HSVToColor(hsv)
}

@BindingAdapter(value=["app:mainView","app:expandedView","app:morphButton","app:onExpand"],requireAll = true)
fun setExpandCard(view: CardView, mainView: LinearLayout, expandedView: LinearLayout, button: ExpandMorphView, expand: ExpandState) {
    when(expand) {
        ExpandState.ON ->{
            button.morphOn()
            TransitionManager.beginDelayedTransition(mainView)
            expandedView.visibility = View.VISIBLE
        }
        ExpandState.OFF ->{
            button.morphOff()
            TransitionManager.beginDelayedTransition(mainView)
            expandedView.visibility = View.GONE
        }
        ExpandState.START ->{
            //do nothing
        }

        ExpandState.PERMISSION -> {}
        ExpandState.ENABLED -> {}
    }
}

/*create a new circular reveal on the give view. This view is initially invisible. In this case the view covers full screen*/
@TargetApi(Build.VERSION_CODES.LOLLIPOP)
private fun createCircularReveal(view: View) {

    view.post {
        // to get the center of FAB
        val centerX = (view.x + view.width / 2).toInt()
        val centerY = (view.height/2)
        val finalRadius = Math.hypot(view.width.toDouble(), view.height.toDouble()).toFloat()
        // starts the effect at centerX, center Y and covers final radius
        val revealAnimator = ViewAnimationUtils.createCircularReveal(view,
            centerX, centerY, 0f, finalRadius)
        view.visibility = View.VISIBLE
        revealAnimator.start()
    }
}

/*hides the circular view*/
@TargetApi(Build.VERSION_CODES.LOLLIPOP)
private fun hideCircularReveal(view: View) {

    view.post{
        // get the center for the clipping circle
        val cx = (view.x + view.width / 2).toInt()
        val cy = (view.height/2)

        // get the initial radius for the clipping circle
        val initialRadius = Math.hypot(view.width.toDouble(), view.height.toDouble()).toFloat()

        // create the animation (the final radius is zero)
        val anim = ViewAnimationUtils.createCircularReveal(view, cx, cy, initialRadius, 0f)

        // make the view invisible when the animation is done
        anim.addListener(object : Animator.AnimatorListener {
            override fun onAnimationStart(animation: Animator) {

            }

            override fun onAnimationEnd(animation: Animator) {
                view.visibility = View.INVISIBLE

            }

            override fun onAnimationCancel(animation: Animator) {

            }

            override fun onAnimationRepeat(animation: Animator) {

            }
        })
        // start the animation
        anim.start()
    }

}