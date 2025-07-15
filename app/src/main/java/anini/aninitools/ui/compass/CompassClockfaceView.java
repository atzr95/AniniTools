package anini.aninitools.ui.compass;

import android.content.Context;
import android.content.res.Resources;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Point;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.View;
import anini.aninitools.R;
import anini.aninitools.util.AndroidUtils;

public class CompassClockfaceView extends View {

    public static final float SMALL_MARK_INNER_RADIUS = 0.35f;
    public static final float SMALL_MARK_OUTER_RADIUS = 0.38f;
    public static final float BIG_MARK_INNER_RADIUS = 0.34f;
    public static final float BIG_MARK_OUTER_RADIUS = 0.38f;
    public static final float NORTH_MARK_INNER_RADIUS = 0.30f;
    public static final float NORTH_MARK_OUTER_RADIUS = 0.4f;
    public static final float DIRECTION_RADIUS = 0.24f;

    private String n;
    private String e;
    private String s;
    private String w;
    private Paint smallMarkPaint;
    private Paint bigMarkPaint;
    private Paint northMarkPaint;
    private Paint northMarkTextPaint;
    private Paint northMarkStaticPaint;
    private Paint directionTextMainPaint;

    private Point CENTER;
    private float WIDTH;

    private Path smallMarkPath = null;
    private Path bigMarkPath = null;
    private Path northMarkPath = null;
    private Path northMarkPath2 = null;

    private float azimuth;
    private static final float SMOOTHING_THRESHOLD = 0.5f; // More sensitive threshold for updates

    public CompassClockfaceView(Context context) {
        super(context);
        init(context, null);
    }

    public CompassClockfaceView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context, attrs);
    }


    public CompassClockfaceView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context, attrs);
    }

    private void init(Context context, AttributeSet attrs) {
        Typeface typeface = Typeface.create("google_sans", Typeface.NORMAL);
        Typeface typeface2 = Typeface.create("google_sans", Typeface.BOLD);

        Resources res = context.getResources();
        n = res.getString(R.string.n);
        e = res.getString(R.string.e);
        s = res.getString(R.string.s);
        w = res.getString(R.string.w);

        int smallMarkColor;
        int bigMarkColor;
        int northMarkColor;
        int primaryTextColor;

        if (attrs != null) {
            TypedArray ta = context.obtainStyledAttributes(attrs, R.styleable.CompassClockfaceView);
            //Read View custom attributes
            smallMarkColor  = ta.getColor(R.styleable.CompassClockfaceView_smallMark, res.getColor(R.color.md_indigo_200));
            bigMarkColor = ta.getColor(R.styleable.CompassClockfaceView_bigMark, res.getColor(R.color.md_indigo_50));
            northMarkColor = ta.getColor(R.styleable.CompassClockfaceView_northMark,  res.getColor(R.color.md_red_400));
            primaryTextColor = ta.getColor(R.styleable.CompassClockfaceView_primaryText,  res.getColor(R.color.md_indigo_50));
            ta.recycle();
        } else {
            //If failed to read View attributes, then read app theme attributes for for view colors.
            TypedValue typedValue = new TypedValue();
            Resources.Theme theme = context.getTheme();
            theme.resolveAttribute(R.attr.smallMarkColor, typedValue, true);
            smallMarkColor = typedValue.data;
            theme.resolveAttribute(R.attr.bigMarkColor, typedValue, true);
            bigMarkColor = typedValue.data;
            theme.resolveAttribute(R.attr.northMarkColor, typedValue, true);
            northMarkColor = typedValue.data;
            theme.resolveAttribute(R.attr.primaryTextColor, typedValue, true);
            primaryTextColor = typedValue.data;
            theme.resolveAttribute(R.attr.secondaryTextColor, typedValue, true);
        }

        CENTER = new Point(0, 0);


        //Clock marks
        smallMarkPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        smallMarkPaint.setStrokeCap(Paint.Cap.ROUND);
        smallMarkPaint.setColor(smallMarkColor);
        smallMarkPaint.setStyle(Paint.Style.STROKE);
        smallMarkPaint.setStrokeWidth(AndroidUtils.dpToPx(0.8f));

        bigMarkPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        bigMarkPaint.setStrokeCap(Paint.Cap.ROUND);
        bigMarkPaint.setColor(bigMarkColor);
        bigMarkPaint.setStyle(Paint.Style.STROKE);
        bigMarkPaint.setStrokeWidth(AndroidUtils.dpToPx(2f));

        //NorthMark
        northMarkStaticPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        northMarkStaticPaint.setStyle(Paint.Style.FILL);
        northMarkStaticPaint.setColor(northMarkColor);

        northMarkPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        northMarkPaint.setStrokeCap(Paint.Cap.ROUND);
        northMarkPaint.setColor(northMarkColor);
        northMarkPaint.setStyle(Paint.Style.STROKE);
        northMarkPaint.setStrokeWidth(AndroidUtils.dpToPx(4f));

        northMarkTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        northMarkTextPaint.setColor(northMarkColor);
        northMarkTextPaint.setTypeface(typeface2);
        northMarkTextPaint.setTextSize(AndroidUtils.dpToPx(28));
        northMarkTextPaint.setTextAlign(Paint.Align.CENTER);


        directionTextMainPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        directionTextMainPaint.setColor(primaryTextColor);
        directionTextMainPaint.setTextSize(AndroidUtils.dpToPx(28));
        directionTextMainPaint.setTypeface(typeface2);
        directionTextMainPaint.setTextAlign(Paint.Align.CENTER);


    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);

        int w = MeasureSpec.getSize(widthMeasureSpec);
        int h = MeasureSpec.getSize(heightMeasureSpec);

        if (w > h) {
            w = h;
        } else {
            h = w;
        }

        setMeasuredDimension(
                resolveSize(w, widthMeasureSpec),
                resolveSize(h, heightMeasureSpec));
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        initConstants();

        layoutSmallClockMarks();
        layoutBigClockMarks();
        layoutNorthMark();

    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        canvas.save();
        canvas.rotate(-azimuth, CENTER.x, CENTER.y);

        //Draw small clock marks
        canvas.drawPath(smallMarkPath, smallMarkPaint);
        //Draw big clock marks
        canvas.drawPath(bigMarkPath, bigMarkPaint);
        //Draw north mark
        canvas.drawPath(northMarkPath, northMarkPaint);
        canvas.drawPath(northMarkPath2, northMarkStaticPaint);

        //Draw directions texts
        float radiusPx = WIDTH*DIRECTION_RADIUS;
        drawText(canvas, 270, n, radiusPx, northMarkTextPaint);
        drawText(canvas, 0, e, radiusPx, directionTextMainPaint);
        drawText(canvas, 90, s, radiusPx, directionTextMainPaint);
        drawText(canvas, 180, w, radiusPx, directionTextMainPaint);

        canvas.restore();
    }

    private void initConstants() {
        WIDTH = getWidth();
        CENTER.set((int)WIDTH/2, getHeight()/2);
    }

    private void layoutSmallClockMarks() {
        if (smallMarkPath == null) {
            float inner = WIDTH*SMALL_MARK_INNER_RADIUS;
            float outer = WIDTH*SMALL_MARK_OUTER_RADIUS;
            smallMarkPath = new Path();
            float degreeStep = 5f;
            for (float step = 0.0f; step < 2 * Math.PI; step += Math.toRadians(degreeStep)) {
                float cos = (float) Math.cos(step);
                float sin = (float) Math.sin(step);

                float x = inner * cos;
                float y = inner * sin;
                smallMarkPath.moveTo(x + ((float) CENTER.x), y + ((float) CENTER.y));

                x = outer * cos;
                y = outer * sin;
                smallMarkPath.lineTo(x + ((float) CENTER.x), y + ((float) CENTER.y));
            }
        }
    }

    private void layoutBigClockMarks() {
        if (bigMarkPath == null) {
            float inner = WIDTH*BIG_MARK_INNER_RADIUS;
            float outer = WIDTH*BIG_MARK_OUTER_RADIUS;
            bigMarkPath = new Path();
            float degreeStep = 30.0f;
            for (float step = 0.0f; step < 2 * Math.PI; step += Math.toRadians(degreeStep)) {
                float cos = (float) Math.cos(step);
                float sin = (float) Math.sin(step);

                float x = inner * cos;
                float y = inner * sin;
                bigMarkPath.moveTo(x + ((float) CENTER.x), y + ((float) CENTER.y));

                cos *= outer;
                sin *= outer;
                bigMarkPath.lineTo(cos + ((float) CENTER.x), sin + ((float) CENTER.y));
            }
        }
    }

    private void layoutNorthMark() {
        if (northMarkPath == null) {
            northMarkPath = new Path();
            float radian = (float) Math.toRadians(270.0d);

            float cos = (float) Math.cos((double) radian);
            float sin = (float) Math.sin((double) radian);

            float inner = WIDTH*NORTH_MARK_INNER_RADIUS;
            float outer = WIDTH*NORTH_MARK_OUTER_RADIUS;

            float x = inner * cos;
            float y = inner * sin;

            northMarkPath.moveTo(((float) CENTER.x) + x, ((float) CENTER.y) + y);

            x = outer * cos;
            y = outer * sin;
            northMarkPath.lineTo(x + ((float) CENTER.x), y + ((float) CENTER.y));
        }

        if (northMarkPath2 == null) {
            float length = AndroidUtils.dpToPx(15);
            float x = CENTER.x;
            float y = (CENTER.y - WIDTH*BIG_MARK_OUTER_RADIUS);
            northMarkPath2 = new Path();
            northMarkPath2.moveTo(x - length/2.0f, y);
            northMarkPath2.lineTo(x + length/2.0f, y);
            northMarkPath2.lineTo(x, CENTER.y - WIDTH*0.41f);
            northMarkPath2.lineTo(x - length/2.0f, y);
        }
    }

    private void drawText(Canvas canvas, float degree, String text, float radius, Paint paint) {
        canvas.save();
        canvas.translate(
                ((float) Math.cos(Math.toRadians(degree)) * radius) + CENTER.x,
                ((float) Math.sin(Math.toRadians(degree)) * radius) + CENTER.y
        );
        canvas.rotate(90.0f + degree);
        canvas.drawText(text, 0, 0, paint);
        canvas.restore();
    }

    public void updateAzimuth(float azimuth) {
        // Use more precise threshold for smoother updates
        if (Math.abs(this.azimuth - azimuth) > SMOOTHING_THRESHOLD) {
            // Handle angle wrapping around 0/360 degrees for smooth transition
            float diff = azimuth - this.azimuth;
            if (diff > 180) {
                diff -= 360;
            } else if (diff < -180) {
                diff += 360;
            }
            
            // Apply gentle smoothing to prevent sudden jumps
            this.azimuth += diff * 0.3f; // Interpolation factor for smoothness
            
            // Normalize angle to 0-360 range
            if (this.azimuth < 0) {
                this.azimuth += 360;
            } else if (this.azimuth >= 360) {
                this.azimuth -= 360;
            }
            
            invalidate();
        }
    }

}