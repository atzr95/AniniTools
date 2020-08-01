package anini.aninitools.ui.sensor;

/** Computes moving average using a circular buffer. */
class MovingAverage {
    private final int bufferSize;
    private final double[] buffer;
    private double sum;
    private int size;
    private int next;

    MovingAverage(int size) {
        bufferSize = size;
        buffer = new double[bufferSize];
    }

    /** Clears this MovingAverage of previous entries. */
    void clear() {
        sum = 0;
        size = 0;
        next = 0;
    }

    /** Inserts the given number and returns the moving average. */
    double insertAndReturnAverage(double n) {
        if (size == bufferSize) {
            double removed = buffer[next];
            sum = sum - removed;
        }
        buffer[next] = n;
        sum += n;
        next = (next + 1) % bufferSize;
        if (size < bufferSize) {
            size++;
        }
        return sum / size;
    }
}