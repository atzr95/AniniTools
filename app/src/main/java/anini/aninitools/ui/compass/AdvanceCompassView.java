package anini.aninitools.ui.compass;

import android.content.Context;
import android.content.res.Resources;
import android.util.AttributeSet;
import android.widget.FrameLayout;
import android.widget.TextView;
import anini.aninitools.R;

public class AdvanceCompassView extends FrameLayout {

    public static final String DEGREE_SIGN = "°";
    private static final int UPDATE_INTERVAL_DIRECTION = 120; //mills
    private long directionUpdatePrevTime = 0;
    private static final float SMOOTHING_THRESHOLD = 0.5f; // Threshold for smooth updates
    private float currentAzimuth = 0f; // Track current azimuth for smooth interpolation

    private CompassClockfaceView compassClockfaceView;
    private TextView txtDirection;

    private String n;
    private String e;
    private String s;
    private String w;
    private String ne;
    private String se;
    private String sw;
    private String nw;

    public AdvanceCompassView(Context context) {
        super(context);
        init(context);
    }

    public AdvanceCompassView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    public AdvanceCompassView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }

    private void init(Context context) {
        inflate(context, R.layout.compass_view_compound, this);

        compassClockfaceView = findViewById(R.id.compass_clockface_view);
        txtDirection = findViewById(R.id.txt_direction);

        Resources res = context.getResources();
        n = res.getString(R.string.n);
        e = res.getString(R.string.e);
        s = res.getString(R.string.s);
        w = res.getString(R.string.w);
        ne = res.getString(R.string.ne);
        se = res.getString(R.string.se);
        sw = res.getString(R.string.sw);
        nw = res.getString(R.string.nw);
    }

    public void updateRotation(float azimuth) {
        // Handle angle wrapping for smooth transition near 0/360 degrees
        float diff = azimuth - currentAzimuth;
        if (diff > 180) {
            diff -= 360;
        } else if (diff < -180) {
            diff += 360;
        }
        
        // Apply smooth interpolation only if the difference is significant
        if (Math.abs(diff) > SMOOTHING_THRESHOLD) {
            // Interpolate for smoother movement
            currentAzimuth += diff * 0.4f; // Interpolation factor for smoothness
            
            // Normalize angle to 0-360 range
            if (currentAzimuth < 0) {
                currentAzimuth += 360;
            } else if (currentAzimuth >= 360) {
                currentAzimuth -= 360;
            }
        } else {
            // For small changes, use the exact value to avoid drift
            currentAzimuth = azimuth;
        }
        
        compassClockfaceView.updateAzimuth(currentAzimuth);
        
        long curTime = System.currentTimeMillis();
        if (curTime - directionUpdatePrevTime > UPDATE_INTERVAL_DIRECTION) {
            String str = ((int) currentAzimuth) + DEGREE_SIGN + " " + getDirectionText(currentAzimuth);
            txtDirection.setText(str);
            directionUpdatePrevTime = curTime;
        }
    }

    private String getDirectionText(float degree) {
        final float step = 22.5f;
        if (degree >= 0 && degree < step || degree > 360 - step) {
            return n;
        }
        if (degree >= step && degree < step * 3) {
            return ne;
        }
        if (degree >= step * 3 && degree < step * 5) {
            return e;
        }
        if (degree >= step * 5 && degree < step * 7) {
            return se;
        }
        if (degree >= step * 7 && degree < step * 9) {
            return s;
        }
        if (degree >= step * 9 && degree < step * 11) {
            return sw;
        }
        if (degree >= step * 11 && degree < step * 13) {
            return w;
        }
        if (degree >= step * 13 && degree < step * 15) {
            return nw;
        }
        return "";
    }
}