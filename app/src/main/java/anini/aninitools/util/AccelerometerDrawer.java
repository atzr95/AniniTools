package anini.aninitools.util;

import android.content.Context;
import android.content.res.Resources;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Point;
import android.graphics.PointF;
import android.util.TypedValue;
import anini.aninitools.R;

public class AccelerometerDrawer implements ViewDrawer<PointF> {

    private Paint pathPaint;
    private Paint ballPaint;
    private Path path;

    private float xPos;
    private float yPos;

    private Point CENTER;
    private int RADIUS;

    private boolean isSimple;


    public AccelerometerDrawer(Context context, boolean isSimple) {
        this.isSimple = isSimple;
        int gridColor;
        int ballColor;

        //If failed to read View attributes, then read app theme attributes for for view colors.
        TypedValue typedValue = new TypedValue();
        Resources.Theme theme = context.getTheme();
        if (theme.resolveAttribute(R.attr.accelerometerGridColor, typedValue, true)) {
            gridColor = typedValue.data;
        } else {
            gridColor = context.getResources().getColor(R.color.md_white_1000);
        }
        if (theme.resolveAttribute(R.attr.accelerometerBallColor, typedValue, true)) {
            ballColor = typedValue.data;
        } else {
            ballColor = context.getResources().getColor(R.color.md_white_1000);
        }


        pathPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        pathPaint.setStrokeWidth(1);
        pathPaint.setStyle(Paint.Style.STROKE);
        pathPaint.setColor(gridColor);

        ballPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        ballPaint.setStyle(Paint.Style.FILL);
        ballPaint.setColor(ballColor);

        CENTER = new Point(0, 0);
    }

    @Override
    public void layout(int width, int height) {
        RADIUS = width / 8;
        CENTER.set(width / 2, height / 2);

        //Layout grid
        if (path == null) {
            float radius = width / 2f - width * 0.03f;
            path = new Path();
            path.moveTo(CENTER.x - radius, CENTER.y);
            path.lineTo(CENTER.x + radius, CENTER.y);
            path.moveTo(CENTER.x, CENTER.y - radius);
            path.lineTo(CENTER.x, CENTER.y + radius);
            if (!isSimple) {
                path.addCircle(CENTER.x, CENTER.y, radius, Path.Direction.CCW);
            }
        }
    }

    @Override
    public void draw(Canvas canvas) {
        //Draw grid
        canvas.drawPath(path, pathPaint);
        //Draw ball
        canvas.drawCircle(CENTER.x - xPos, CENTER.y + yPos, RADIUS, ballPaint);
    }

    @Override
    public void update(PointF p) {
        this.xPos = p.x;
        this.yPos = p.y;
    }
}
