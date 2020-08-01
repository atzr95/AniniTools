package anini.aninitools.util;

import android.graphics.Canvas;

public interface ViewDrawer<T> {

    void layout(int width, int height);
    void draw(Canvas canvas);
    void update(T value);
}