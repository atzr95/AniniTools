package anini.aninitools.ui.sensor

import android.app.Application
import androidx.lifecycle.*
import anini.aninitools.util.GpsStatusListener
import anini.aninitools.util.MicPermissionStatusListener
import anini.aninitools.util.LocationPermissionStatusListener
import anini.aninitools.util.Prefs
import java.math.BigDecimal
import java.math.RoundingMode
import java.util.*


class SensorViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = Prefs(application.applicationContext)
    val mContext = application.applicationContext

    val batteryPercent by lazy {
        val mediatorLiveData = MediatorLiveData<String>()
        mediatorLiveData.addSource(BatteryLiveData(application)) { result ->
            result?.let {
                mediatorLiveData.postValue(it[0])
            }
        }
        return@lazy mediatorLiveData
    }

    val batteryVoltage by lazy {
        val mediatorLiveData = MediatorLiveData<String>()
        mediatorLiveData.addSource(BatteryLiveData(application)) { result ->
            result?.let {
                mediatorLiveData.postValue(it[1])
            }
        }
        return@lazy mediatorLiveData
    }

    val batteryCapacity by lazy {
        val mediatorLiveData = MediatorLiveData<String>()
        mediatorLiveData.addSource(BatteryLiveData(application)) { result ->
            result?.let {
                mediatorLiveData.postValue(it[5])
            }
        }
        return@lazy mediatorLiveData
    }

    val batteryTechnology by lazy {
        val mediatorLiveData = MediatorLiveData<String>()
        mediatorLiveData.addSource(BatteryLiveData(application)) { result ->
            result?.let {
                mediatorLiveData.postValue(it[4])
            }
        }
        return@lazy mediatorLiveData
    }

    val batteryStatus by lazy {
        val mediatorLiveData = MediatorLiveData<String>()
        mediatorLiveData.addSource(BatteryLiveData(application)) { result ->
            result?.let {
                mediatorLiveData.postValue(it[3])
            }
        }
        return@lazy mediatorLiveData
    }

    val batteryTemp by lazy {
        val mediatorLiveData = MediatorLiveData<String>()
        mediatorLiveData.addSource(BatteryLiveData(application)) { result ->
            result?.let {
                mediatorLiveData.postValue(it[2])
            }
        }
        return@lazy mediatorLiveData
    }

    val ambientTemp by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorAmbientTemp) {
            mediatorLiveData.addSource(TempLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(it)
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val light by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorLight) {
            mediatorLiveData.addSource(LightLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(BigDecimal(it.toDouble()).setScale(2, RoundingMode.HALF_EVEN).toFloat())
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val magnetic by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorMagnetic) {
            mediatorLiveData.addSource(MagneticLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(
                        BigDecimal(it.toDouble()).setScale(
                            1,
                            RoundingMode.HALF_EVEN
                        ).toFloat()
                    )
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val pressure by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorPressure) {
            mediatorLiveData.addSource(PressureLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(
                        BigDecimal(it.toDouble()).setScale(
                            2,
                            RoundingMode.HALF_EVEN
                        ).toFloat()
                    )
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val proximity by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorProximity) {
            mediatorLiveData.addSource(ProximityLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(
                        BigDecimal(it.toDouble()).setScale(
                            2,
                            RoundingMode.HALF_EVEN
                        ).toFloat()
                    )
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val linear_acceleration by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorAccelerometer) {
            mediatorLiveData.addSource(AccelerationLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(
                        BigDecimal(it.toDouble()).setScale(
                            2,
                            RoundingMode.HALF_EVEN
                        ).toFloat()
                    )
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val orientation by lazy {
        val mediatorLiveData = MediatorLiveData<List<Float>>()
        if (prefs.sensorOrientation) {
            mediatorLiveData.addSource(OrientationLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(result)
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val orientationX by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorOrientation) {
            mediatorLiveData.addSource(OrentationLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(
                        BigDecimal(it[0].toDouble()).setScale(
                            2,
                            RoundingMode.HALF_EVEN
                        ).toFloat()
                    )
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val orientationY by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorOrientation) {
            mediatorLiveData.addSource(OrentationLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(
                        BigDecimal(it[1].toDouble()).setScale(
                            2,
                            RoundingMode.HALF_EVEN
                        ).toFloat()
                    )
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val orientationZ by lazy {
        val mediatorLiveData = MediatorLiveData<Float>()
        if (prefs.sensorOrientation) {
            mediatorLiveData.addSource(OrentationLiveData(application.applicationContext)) { result ->
                result?.let {
                    mediatorLiveData.postValue(
                        BigDecimal(it[2].toDouble()).setScale(
                            2,
                            RoundingMode.HALF_EVEN
                        ).toFloat()
                    )
                }
            }
        }
        return@lazy mediatorLiveData
    }

    val audioIntesity = MediatorLiveData<String>()
    val audioPitch = MediatorLiveData<String>()
    val gpsCoordinates = MediatorLiveData<String>()

    val gpsStatus = GpsStatusListener(application)
    val gpsPermission = LocationPermissionStatusListener(application)
    val audioPermission = MicPermissionStatusListener(application)

    private var _audioPermission = false
    private var _gpsPermission = false
    private var _gpsEnabled = false

    val lightGraph = MediatorLiveData<Float>()
    val magneticGraph = MediatorLiveData<Float>()
    val linearAccGraph = MediatorLiveData<Float>()
    val audioIntesityGraph = MediatorLiveData<Float>()
    val audioPitchGraph = MediatorLiveData<Float>()

    private var pastLightData: Float? = 0.0f

    fun lightDataRefresh() {
        lightGraph.removeSource(light)
        lightGraph.addSource(light) { result ->
            result?.let {
                pastLightData = it
            }
        }

        // Update the elapsed time every second.
        Timer().scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                lightGraph.postValue(pastLightData)
            }
        }, 0, 800)
    }

    fun magneticGraphSource() {
        magneticGraph.removeSource(magnetic)
        magneticGraph.addSource(magnetic) { result ->
            result?.let { magneticGraph.value = it }
        }
    }

    fun sounddBGraphSource() {
        audioIntesityGraph.removeSource(audioIntesity)
        audioIntesityGraph.addSource(audioIntesity) { result ->
            result?.let {
                audioIntesityGraph.value = it.toFloat()
            }
        }
    }

    fun soundPitchGraphSource() {
        audioPitchGraph.removeSource(audioPitch)
        audioPitchGraph.addSource(audioPitch) { result ->
            result?.let {
                audioPitchGraph.value = it.toFloat()
            }
        }
    }

    fun linearAccGraphSource() {
        linearAccGraph.removeSource(linear_acceleration)
        linearAccGraph.addSource(linear_acceleration) { result ->
            result?.let {
                linearAccGraph.value = it
            }
        }
    }

    private val _audioSourced = MutableLiveData<Int>().apply {
        value = 0
    }

    private val _expandBattery = MutableLiveData<Int>().apply {
        value = 0
    }

    private val _expandLight = MutableLiveData<Int>().apply {
        value = 0
    }

    private val _expandMagnet = MutableLiveData<Int>().apply {
        value = 0
    }

    private val _expandSounddB = MutableLiveData<Int>().apply {
        value = 0
    }

    private val _expandSoundPitch = MutableLiveData<Int>().apply {
        value = 0
    }

    private val _expandGPS = MutableLiveData<Int>().apply {
        value = 0
    }

    private val _expandLinearAcc = MutableLiveData<Int>().apply {
        value = 0
    }

    val isTempVisible = MutableLiveData<Boolean>().apply {
        value = prefs.sensorAmbientTemp
    }

    val isLightVisible = MutableLiveData<Boolean>().apply {
        value = prefs.sensorLight
    }

    val isMagnetVisible = MutableLiveData<Boolean>().apply {
        value = prefs.sensorMagnetic
    }

    val isPressureVisible = MutableLiveData<Boolean>().apply {
        value = prefs.sensorPressure
    }

    val isProximityVisible = MutableLiveData<Boolean>().apply {
        value = prefs.sensorProximity
    }

    val isAccelerationVisible = MutableLiveData<Boolean>().apply {
        value = prefs.sensorAccelerometer
    }

    val isOrentationVisible = MutableLiveData<Boolean>().apply {
        value = prefs.sensorOrientation
    }

    fun expandBatteryCard() {
        when {
            _expandBattery.value == 0 -> _expandBattery.value = 1
            _expandBattery.value == 1 -> _expandBattery.value = 2
            _expandBattery.value == 2 -> _expandBattery.value = 1
        }
    }

    val expandBattery: LiveData<ExpandState> = Transformations.map(_expandBattery) {
        when (it) {
            1 -> ExpandState.ON
            2 -> ExpandState.OFF
            else -> ExpandState.START
        }
    }

    fun expandLightCard() {
        when {
            _expandLight.value == 0 -> _expandLight.value = 1
            _expandLight.value == 1 -> _expandLight.value = 2
            _expandLight.value == 2 -> _expandLight.value = 1
        }
    }

    val expandLight: LiveData<ExpandState> = Transformations.map(_expandLight) {
        when (it) {
            1 -> ExpandState.ON
            2 -> ExpandState.OFF
            else -> ExpandState.START
        }
    }

    fun expandMagnetCard() {
        when {
            _expandMagnet.value == 0 -> _expandMagnet.value = 1
            _expandMagnet.value == 1 -> _expandMagnet.value = 2
            _expandMagnet.value == 2 -> _expandMagnet.value = 1
        }
    }

    val expandMagnet: LiveData<ExpandState> = Transformations.map(_expandMagnet) {
        when (it) {
            1 -> ExpandState.ON
            2 -> ExpandState.OFF
            else -> ExpandState.START
        }
    }

    fun expandLinearAccCard() {
        when {
            _expandLinearAcc.value == 0 -> _expandLinearAcc.value = 1
            _expandLinearAcc.value == 1 -> _expandLinearAcc.value = 2
            _expandLinearAcc.value == 2 -> _expandLinearAcc.value = 1
        }
    }

    val expandLinearAcc: LiveData<ExpandState> = Transformations.map(_expandLinearAcc) {
        when (it) {
            1 -> ExpandState.ON
            2 -> ExpandState.OFF
            else -> ExpandState.START
        }
    }

    fun expandSounddBCard() {
        when {
            _expandSounddB.value == 0 -> {
                if (!_audioPermission) {
                    _expandSounddB.value = 3
                } else {
                    _expandSounddB.value = 1
                }
            }
            _expandSounddB.value == 1 -> _expandSounddB.value = 2
            _expandSounddB.value == 2 -> _expandSounddB.value = 1

            _expandSounddB.value == 3 -> {
                if (_audioPermission) {
                    _expandSounddB.value = 1
                } else {
                    _expandSounddB.value = 3
                }
            }
        }
    }

    val expandSounddB: LiveData<ExpandState> = Transformations.map(_expandSounddB) {
        when (it) {
            1 -> ExpandState.ON
            2 -> ExpandState.OFF
            3 -> ExpandState.PERMISSION
            else -> ExpandState.START
        }
    }

    fun expandSoundPitchCard() {
        when {
            _expandSoundPitch.value == 0 -> {
                if (!_audioPermission) {
                    _expandSoundPitch.value = 3
                } else {
                    _expandSoundPitch.value = 1
                }
            }
            _expandSoundPitch.value == 1 -> _expandSoundPitch.value = 2
            _expandSoundPitch.value == 2 -> _expandSoundPitch.value = 1

            _expandSoundPitch.value == 3 -> {
                if (_audioPermission) {
                    _expandSoundPitch.value = 1
                } else {
                    _expandSoundPitch.value = 3
                }
            }
        }
    }

    val expandSoundPitch: LiveData<ExpandState> = Transformations.map(_expandSoundPitch) {
        when (it) {
            1 -> ExpandState.ON
            2 -> ExpandState.OFF
            3 -> ExpandState.PERMISSION
            else -> ExpandState.START
        }
    }

    fun expandGPSCard() {
        when {
            _expandGPS.value == 0 -> {
                if (!_gpsPermission) {
                    _expandGPS.value = 3
                } else if (_gpsPermission && !_gpsEnabled) {
                    _expandGPS.value = 4
                } else {
                    _expandGPS.value = 1
                }
            }
            _expandGPS.value == 1 -> _expandGPS.value = 2
            _expandGPS.value == 2 -> _expandGPS.value = 1

            _expandGPS.value == 3 -> {
                if (_gpsPermission && _gpsEnabled) {
                    _expandGPS.value = 1
                } else if (_gpsPermission && !_gpsEnabled) {
                    _expandGPS.value = 4
                } else {
                    _expandGPS.value = 3
                }
            }

            _expandGPS.value == 4 -> {
                if (_gpsEnabled) {
                    _expandGPS.value = 1
                } else {
                    _expandGPS.value = 4
                }
            }
        }
    }

    val expandGPS: LiveData<ExpandState> = Transformations.map(_expandGPS) {
        when (it) {
            1 -> ExpandState.ON
            2 -> ExpandState.OFF
            3 -> ExpandState.PERMISSION
            4 -> ExpandState.ENABLED
            else -> ExpandState.START
        }
    }

    fun onAudioPermissionResult(permission: Boolean) {
        if (permission) {
            _audioPermission = true
            if(_audioSourced.value == 0){
                _audioSourced.value = 1
                audioIntesity.removeSource(DecibelLiveData())
                audioIntesity.addSource(DecibelLiveData()) { result ->
                    result?.let {
                        audioIntesity.postValue(
                            BigDecimal(it[0]).setScale(
                                1,
                                RoundingMode.HALF_EVEN
                            ).toString()
                        )
                        audioPitch.postValue(
                            BigDecimal(it[1]).setScale(
                                1,
                                RoundingMode.HALF_EVEN
                            ).toString()
                        )
                    }
                }
            }
        } else {
            _audioPermission = false
            audioIntesity.postValue("Audio is OFF")
            audioPitch.postValue("Audio is OFF")
        }
    }

    fun onGpsPermissionResult(permission: Boolean, gpsEnabled: Boolean) {
        if (permission) {
            if (gpsEnabled) {
                _gpsPermission = true
                _gpsEnabled = true
                gpsCoordinates.removeSource(LocationLiveData(mContext))
                gpsCoordinates.addSource(LocationLiveData(mContext)) { result ->
                    result?.let {
                        gpsCoordinates.postValue(
                            BigDecimal(it.latitude).setScale(
                                3,
                                RoundingMode.HALF_EVEN
                            ).toString() + "," +
                                    BigDecimal(it.longitude).setScale(
                                        3,
                                        RoundingMode.HALF_EVEN
                                    ).toString()
                        )
                    }
                }
            } else {
                _gpsPermission = true
                _gpsEnabled = false
                gpsCoordinates.postValue("GPS is OFF,GPS is OFF")
            }

        } else {
            _gpsPermission = false
            _gpsEnabled = false
            gpsCoordinates.postValue("No permission,No permission")
        }
    }

    fun resetCard() {
        _expandBattery.value = 0
        _expandLight.value = 0
        _expandMagnet.value = 0
        _expandSounddB.value = 0
        _expandSoundPitch.value = 0
        _expandGPS.value = 0
        _expandLinearAcc.value = 0
    }

}


enum class ExpandState {
    START,
    ON,
    OFF,
    PERMISSION,
    ENABLED
}