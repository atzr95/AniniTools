package anini.aninitools.ui.compass

import android.app.Application
import androidx.lifecycle.*
import anini.aninitools.util.Prefs

class CompassViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = Prefs(application.applicationContext)
    val compass = MediatorLiveData<Float>()
    val magnetic = MediatorLiveData<Float>()
    val azimuth = MediatorLiveData<Float>()

    init {
        if (prefs.sensorMagnetic) {
            magnetic.addSource(CompassLiveData(application.applicationContext)) { result ->
                result?.let {
                    // Keep magnetic field value rounded for display
                    magnetic.value = kotlin.math.round(it[1] * 10f) / 10f
                    
                    // Use full precision for smoother azimuth animation
                    val azimuthDegrees = if(it[0] < 0) {
                        360.0f + it[0]
                    } else {
                        it[0]
                    }
                    azimuth.value = azimuthDegrees
                }
            }
        }
    }
}