package anini.aninitools.util;

import android.view.View;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.PointF;
import android.util.AttributeSet;

public class OrientationView extends View {

    private float roll = 0f;
    private float pitch = 0f;

    private PointF point;

    private int MAX_MOVE = (int) AndroidUtils.dpToPx(50); //dip
    //Converted value from pixels to coefficient used in function which describes move.
    private float k = (float) (MAX_MOVE / (Math.PI/2));

    //	private ViewDrawer<PointF> drawer;
    private AccelerometerDrawer drawer;

    public OrientationView(Context context) {
        super(context);
        init(context);
    }

    public OrientationView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    public OrientationView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }

    private void init(Context context) {
        point = new PointF(0, 0);
        boolean isSimple = false;
        drawer = new AccelerometerDrawer(context, isSimple);
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

        int width = getWidth();
        MAX_MOVE = width/2;
        k = (float) (MAX_MOVE / (Math.PI/2));

        drawer.layout(getWidth(), getHeight());
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        drawer.draw(canvas);
    }

    public void updateOrientation(float pitch, float roll) {

        if ((int)this.pitch != (int)pitch || (int)this.roll != (int)roll) {
            this.pitch = pitch;
            this.roll = roll;

            point.set(
                    getWidth() * 0.37f * (float) Math.cos(Math.toRadians(90 - roll)),
                    getWidth() * 0.37f * (float) Math.cos(Math.toRadians(90 - pitch))
            );

            //Log.d("TAGGG","point " + point);
            drawer.update(point);
            invalidate();
        }
    }

}