package anini.aninitools.ui.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.lifecycle.LiveData

class PressureLiveData(context: Context) : LiveData<Float>(), SensorEventListener {

    private val sensorManager: SensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var pressureSensor: Sensor

    init {
        pressureSensor = sensorManager.getDefaultSensor(Sensor.TYPE_PRESSURE)
    }

    /**
     * Registers to listen to sensor value updates when there are active observers.
     */
    override fun onActive() {
        super.onActive()
        sensorManager.registerListener(this, pressureSensor, SensorManager.SENSOR_DELAY_NORMAL)
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
        value = event.values[0]
    }
}