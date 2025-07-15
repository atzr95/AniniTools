package anini.aninitools.util

import android.view.View
import androidx.databinding.BindingAdapter
import anini.aninitools.ui.sensor.ExpandState
import com.github.mikephil.charting.charts.LineChart


@BindingAdapter(value = ["app:chartVisibility"], requireAll = true)
fun setExpandCard(view: LineChart, expand: ExpandState) {
    when (expand) {
        ExpandState.ON -> {
            view.visibility = View.VISIBLE
        }
        ExpandState.OFF -> {
            view.visibility = View.GONE
        }
        ExpandState.START -> {
            view.visibility = View.GONE
        }

        ExpandState.PERMISSION -> TODO()
        ExpandState.ENABLED -> TODO()
    }
}
