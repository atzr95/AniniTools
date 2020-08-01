package anini.aninitools.util

import android.widget.SeekBar
import android.widget.SeekBar.OnSeekBarChangeListener
import androidx.databinding.InverseBindingListener
import androidx.databinding.BindingAdapter


object SeekBarBindingAdapter {

    @BindingAdapter(
        value = ["android:onStartTrackingTouch", "android:onStopTrackingTouch", "android:onProgressChanged", "android:progressAttrChanged"],
        requireAll = false
    )
    fun setOnSeekBarChangeListener(
        view: SeekBar, start: OnStartTrackingTouch?,
        stop: OnStopTrackingTouch?, progressChanged: OnProgressChanged?,
        attrChanged: InverseBindingListener?
    ) {
        if (start == null && stop == null && progressChanged == null && attrChanged == null) {
            view.setOnSeekBarChangeListener(null)
        } else {
            view.setOnSeekBarChangeListener(object : OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                    progressChanged?.onProgressChanged(seekBar, progress, fromUser)
                    attrChanged?.onChange()
                }

                override fun onStartTrackingTouch(seekBar: SeekBar) {
                    start?.onStartTrackingTouch(seekBar)
                }

                override fun onStopTrackingTouch(seekBar: SeekBar) {
                    stop?.onStopTrackingTouch(seekBar)
                }
            })
        }
    }

    interface OnStartTrackingTouch {
        fun onStartTrackingTouch(seekBar: SeekBar)
    }

    interface OnStopTrackingTouch {
        fun onStopTrackingTouch(seekBar: SeekBar)
    }

    interface OnProgressChanged {
        fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean)
    }
}