package anini.aninitools.util;

import android.content.res.Resources;

/**
 * Android related utilities methods.
 */
public class AndroidUtils {

    //Prevent object instantiation
    private AndroidUtils() {
    }

    /**
     * Convert density independent pixels value (dip) into pixels value (px).
     *
     * @param dp Value needed to convert
     * @return Converted value in pixels.
     */
    public static float dpToPx(int dp) {
        return dpToPx((float) dp);
    }

    /**
     * Convert density independent pixels value (dip) into pixels value (px).
     *
     * @param dp Value needed to convert
     * @return Converted value in pixels.
     */
    public static float dpToPx(float dp) {
        return (dp * Resources.getSystem().getDisplayMetrics().density);
    }

    /**
     * Convert pixels value (px) into density independent pixels (dip).
     *
     * @param px Value needed to convert
     * @return Converted value in pixels.
     */
    public static float pxToDp(int px) {
        return pxToDp((float) px);
    }

    /**
     * Convert pixels value (px) into density independent pixels (dip).
     *
     * @param px Value needed to convert
     * @return Converted value in pixels.
     */
    public static float pxToDp(float px) {
        return (px / Resources.getSystem().getDisplayMetrics().density);
    }
}