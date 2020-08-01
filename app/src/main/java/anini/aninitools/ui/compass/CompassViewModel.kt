package anini.aninitools.ui.compass

import android.app.Application
import androidx.lifecycle.*
import anini.aninitools.util.Prefs
import java.math.BigDecimal
import java.math.RoundingMode

class CompassViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = Prefs(application.applicationContext)
    val compass = MediatorLiveData<Float>()
    val magnetic = MediatorLiveData<Float>()
    val azimuth = MediatorLiveData<Float>()

    init {
        if (prefs.sensorMagnetic) {
            magnetic.addSource(CompassLiveData(application.applicationContext)) { result ->
                result?.let {
                    magnetic.value = BigDecimal(it[1].toDouble()).setScale(1, RoundingMode.HALF_EVEN).toFloat()
                    if(it[0].toDouble() < 0){
                        azimuth.value = 360.0f + BigDecimal(it[0].toDouble()).setScale(1, RoundingMode.HALF_EVEN).toFloat()
                    }else{
                        azimuth.value = BigDecimal(it[0].toDouble()).setScale(1, RoundingMode.HALF_EVEN).toFloat()
                    }
                }
            }
        }
    }
}