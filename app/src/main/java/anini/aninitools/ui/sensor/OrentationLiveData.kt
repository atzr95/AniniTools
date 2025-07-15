package anini.aninitools.ui.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.lifecycle.LiveData

class OrentationLiveData(context: Context) : LiveData<List<Float>>(), SensorEventListener {

    private val sensorManager: SensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var orientationSensor: Sensor?

    init {
        orientationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    }

    /**
     * Registers to listen to sensor value updates when there are active observers.
     */
    override fun onActive() {
        super.onActive()
        sensorManager.registerListener(this, orientationSensor, SensorManager.SENSOR_DELAY_NORMAL)
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
        value = mutableListOf(event.values[0],event.values[1],event.values[3])
    }
}