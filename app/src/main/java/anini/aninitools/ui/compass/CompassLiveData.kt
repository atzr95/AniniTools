package anini.aninitools.ui.compass

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.lifecycle.LiveData
import java.lang.Math.toDegrees
import kotlin.math.sqrt


class CompassLiveData(context: Context) : LiveData<List<Float>>(), SensorEventListener {

    private val sensorManager: SensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var accelerationSensor: Sensor
    private var magnetometerSensor: Sensor

    private val accelerometerReading = FloatArray(3)
    private val magnetometerReading = FloatArray(3)
    private val rotationMatrix = FloatArray(9)
    private var orientationAngles = FloatArray(3)
    private var magnetic = 0.0f
    private var accelsFilled: Boolean = false
    private var magsFilled: Boolean = false

    init {
        accelerationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        magnetometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    }

    /**
     * Registers to listen to sensor value updates when there are active observers.
     */
    override fun onActive() {
        super.onActive()
        sensorManager.registerListener(this, accelerationSensor, SensorManager.SENSOR_DELAY_GAME)
        sensorManager.registerListener(this, magnetometerSensor, SensorManager.SENSOR_DELAY_GAME)
    }

    /**
     * Un-registers listening to sensor value updates as there no active observers.
     */
    override fun onInactive() {
        super.onInactive()
        sensorManager.unregisterListener(this)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    /**
     * Triggered when sensor value changes.
     */
    override fun onSensorChanged(event: SensorEvent) {

        val ALPHA = 0.96f

        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                // Update acceleration array.
                accelerometerReading[0] = ALPHA * accelerometerReading[0] + (1 - ALPHA) * event.values[0]
                accelerometerReading[1] = ALPHA * accelerometerReading[1] + (1 - ALPHA) * event.values[1]
                accelerometerReading[2] = ALPHA * accelerometerReading[2] + (1 - ALPHA) * event.values[2]

                //System.arraycopy(event.values, 0, accelerometerReading, 0, 3)
                accelsFilled = true
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                // Update magnetic field array.
                magnetic = sqrt(Math.pow(event.values[0].toDouble(), 2.0) + Math.pow(event.values[1].toDouble(), 2.0) + Math.pow(event.values[2].toDouble(), 2.0)).toFloat()
                magnetometerReading[0] = ALPHA * magnetometerReading[0] + (1 - ALPHA) * event.values[0]
                magnetometerReading[1] = ALPHA * magnetometerReading[1] + (1 - ALPHA) * event.values[1]
                magnetometerReading[2] = ALPHA * magnetometerReading[2] + (1 - ALPHA) * event.values[2]
                magsFilled = true
            }
            else -> {
                return
            }
        }

            if (SensorManager.getRotationMatrix(
                    rotationMatrix,
                    null,
                    accelerometerReading,
                    magnetometerReading
                )
            ) {
                orientationAngles = SensorManager.getOrientation(rotationMatrix, orientationAngles)

                value = listOf(
                    toDegrees(orientationAngles[0].toDouble()).toFloat(),
                    magnetic
                )
            }

    }


}