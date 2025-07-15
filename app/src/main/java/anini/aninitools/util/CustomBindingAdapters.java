package anini.aninitools.util;

import android.view.View;
import androidx.databinding.BindingAdapter;

public class CustomBindingAdapters {
    
    @BindingAdapter("app:customVisibility")
    public static void setCustomVisibility(View view, Object visible) {
        boolean isVisible = false;
        if (visible instanceof Boolean) {
            isVisible = (Boolean) visible;
        }
        view.setVisibility(isVisible ? View.VISIBLE : View.GONE);
    }
} 