package anini.aninitools.ui.flashlight

import android.app.Application
import android.content.Context
import android.graphics.Color
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.*
import anini.aninitools.util.Prefs
import anini.aninitools.util.ScreenBrightnessUtil
import android.content.pm.PackageManager
import android.Manifest.permission
import androidx.core.content.ContextCompat

class FlashViewModel(
    application:Application)
    : AndroidViewModel(application) {

    private val prefs = Prefs(application.applicationContext)
    private var strobeHandler  = Handler(Looper.getMainLooper())
    private var screenFlashHandler = Handler(Looper.getMainLooper())

    private val context : Context = application.applicationContext
    private val packageManager = application.packageManager
    private val screenBrightnessUtil = ScreenBrightnessUtil(context)
    var status = MutableLiveData<Boolean?>()

    // Screen Flash Properties
    private val _screenFlashEnabled = MutableLiveData<Boolean>().apply { value = false }
    val screenFlashEnabled: LiveData<Boolean> = _screenFlashEnabled
    
    private val _screenFlashColor = MutableLiveData<Int>().apply { value = Color.WHITE }
    val screenFlashColor: LiveData<Int> = _screenFlashColor
    
    private val _screenFlashActive = MutableLiveData<Boolean>().apply { value = false }
    val screenFlashActive: LiveData<Boolean> = _screenFlashActive

    // Store original strobe time when screen flash is enabled
    private var originalStrobeTime: Long = -1L

    // Text size for concert mode
    private var textSize: Float = 96f

    // Color Picker Dialog
    private val _openColorPicker = MutableLiveData<Boolean>().apply { value = false }
    val openColorPicker: LiveData<Boolean> = _openColorPicker

    // Navigation Events
    private val _navigateToConcertMode = MutableLiveData<Boolean>().apply { value = false }
    val navigateToConcertMode: LiveData<Boolean> = _navigateToConcertMode

    private val _flashEnable = MutableLiveData<Int>().apply {
        value= prefs.buttonState
    }

    val buttonstate:LiveData<ButtonState> = _flashEnable.map { value ->
        when (value) {
            1 -> ButtonState.ON
            2 -> ButtonState.OFF
            else -> ButtonState.START
        }
    }

    //set button state to know if flash is on after reopen
    //for flash morph view
    fun saveButtonState(value:Int){
        prefs.buttonState = value
    }

    //set flash strobe bar
    fun saveFlashStrobe(value:Long){
        prefs.flashStrobe = value.toInt()
    }

    //Button input in xml
    //Check if flash avaiable, turn on/off flash
    fun enableFlash(){
        // Check if screen flash is enabled and handle accordingly
        if (_screenFlashEnabled.value == true) {
            enableScreenFlash()
        } else {
            enableCameraFlash()
        }
    }
    
    // Original flashlight control logic
    private fun enableCameraFlash(){
        val hasCameraFlash = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)
        val isEnabled = ContextCompat.checkSelfPermission(context, permission.CAMERA) == PackageManager.PERMISSION_GRANTED

        if (hasCameraFlash && isEnabled) {
            status.value = true
            when {
                _flashEnable.value == 0 -> {
                    flashLightOff()
                    flashLightOn(time.value!!)
                    _flashEnable.value = 1

                }
                _flashEnable.value == 1 -> {
                    flashLightOff()
                    _flashEnable.value = 2
                }
                _flashEnable.value == 2 -> {
                    flashLightOn(time.value!!)
                    _flashEnable.value = 1
                }
            }
            saveButtonState(_flashEnable.value!!)
        }
        else{
            status.value = false
        }
    }
    
    // Screen flash control logic
    private fun enableScreenFlash(){
        when {
            _flashEnable.value == 0 -> {
                screenFlashOff()
                screenFlashOn(time.value!!)
                _flashEnable.value = 1
            }
            _flashEnable.value == 1 -> {
                screenFlashOff()
                _flashEnable.value = 2
            }
            _flashEnable.value == 2 -> {
                screenFlashOn(time.value!!)
                _flashEnable.value = 1
            }
        }
        saveButtonState(_flashEnable.value!!)
    }
    
    // Screen flash strobing functions
    private fun screenFlashOn(tim: Long) {
        time.value = tim
        if (tim == 0L) {
            // Continuous screen flash
            _screenFlashActive.value = true
        } else {
            // Strobing screen flash
            screenFlashStrobeState = true
            screenFlashHandler.post(screenFlashStrobeRunner)
        }
    }
    
    private fun screenFlashOff() {
        screenFlashHandler.removeCallbacks(screenFlashStrobeRunner)
        _screenFlashActive.value = false
    }
    
    // State tracking for screen flash strobing
    private var screenFlashStrobeState = true
    
    // Single runnable for screen flash strobing that alternates between on/off
    private val screenFlashStrobeRunner: Runnable = object : Runnable {
        override fun run() {
            if (screenFlashStrobeState) {
                _screenFlashActive.value = true
                screenFlashStrobeState = false
            } else {
                _screenFlashActive.value = false
                screenFlashStrobeState = true
            }
            
            if (time.value!! > 0) {
                screenFlashHandler.postDelayed(this, time.value!!)
            }
        }
    }

    //time for strobe
    private var time = MutableLiveData<Long>().apply {
        value= prefs.flashStrobe.toLong()
    }
    
    // Public getter for strobe time
    fun getStrobeTime(): LiveData<Long> = time

    //set strobe time base on seekbar
    fun setStrobeTime(value: Int){
        when {
            value == 0 -> {
                time.value = 0
                if(_flashEnable.value == 1){
                    flashLightOff()
                    flashLightOn(time.value!!)
                }
            }
            value < 99 -> {
                time.value = 1000- value.toLong()*10
                if(_flashEnable.value == 1){
                    flashLightOff()
                    flashLightOn(time.value!!)
                }
            }
            value >= 99 -> {
                time.value = 31
                if(_flashEnable.value == 1){
                    flashLightOff()
                    flashLightOn(time.value!!)
                }
            }
        }

        saveFlashStrobe(time.value!!)

    }

    // Screen Flash Functions
    fun setScreenFlashEnabled(enabled: Boolean) {
        if (enabled) {
            // Store current strobe time and reset to 0 (continuous flash)
            if (originalStrobeTime == -1L) {
                originalStrobeTime = time.value ?: 0L
            }
            time.value = 0L
            saveFlashStrobe(0L)
            
            // If flash is currently on, restart it with no strobing
            if (_flashEnable.value == 1) {
                screenFlashOff()
                screenFlashOn(0L)
            }
        } else {
            // Restore original strobe time
            if (originalStrobeTime != -1L) {
                time.value = originalStrobeTime
                saveFlashStrobe(originalStrobeTime)
                originalStrobeTime = -1L
                
                // If flash is currently on, restart it with restored strobing
                if (_flashEnable.value == 1) {
                    screenFlashOff()
                    screenFlashOn(time.value!!)
                }
            }
        }
        
        _screenFlashEnabled.value = enabled
    }

    fun setScreenFlashColor(color: Int) {
        _screenFlashColor.value = color
    }

    fun testScreenFlash() {
        if (_screenFlashEnabled.value == true) {
            _screenFlashActive.value = true
            screenFlashHandler.postDelayed({
                _screenFlashActive.value = false
            }, 500)
        }
    }

    fun getScreenBrightnessUtil(): ScreenBrightnessUtil = screenBrightnessUtil

    fun getScreenFlashColorValue(): Int {
        return _screenFlashColor.value!!
    }

    // Color Picker Functions
    fun openColorPicker() {
        _openColorPicker.value = true
    }

    fun onColorPickerOpened() {
        _openColorPicker.value = false
    }

    // Navigation Functions
    fun openConcertMode() {
        _navigateToConcertMode.value = true
    }

    fun onConcertModeNavigated() {
        _navigateToConcertMode.value = false
    }

    //function to turn on flashlight
    private fun flashLightOn(tim : Long){
        time.value = tim
        strobeHandler.post(onRunner)
    }

    //function to turn off flash
    private fun flashLightOff(){
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            strobeHandler.removeCallbacks(onRunner)
            strobeHandler.removeCallbacks(offRunner)
            val cameraId = cameraManager.cameraIdList[0]
            cameraManager.setTorchMode(cameraId, false)
        } catch (e: CameraAccessException) {
        }
    }

    //Runnable to Turn Off Lights
    private val offRunner = Runnable {
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList[0]
            cameraManager.setTorchMode(cameraId, false)
        } catch (e: CameraAccessException) {
        }
    }

    //Runnable to Turn On Lights
    private val onRunner = object :Runnable {
        override fun run() {
            try {
                val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val cameraId = cameraManager.cameraIdList[0]
                cameraManager.setTorchMode(cameraId, true)
                if (time.value!! > 0) {
                    strobeHandler.postDelayed(offRunner, time.value!!)
                    strobeHandler.postDelayed(this, time.value!! * 2)
                }
            } catch (e: CameraAccessException) {
            }
        }
    }

    fun setTextSize(size: Float) {
        textSize = size
    }

    fun getTextSize(): Float = textSize

    override fun onCleared() {
        super.onCleared()
        strobeHandler.removeCallbacks(onRunner)
        strobeHandler.removeCallbacks(offRunner)
        screenFlashHandler.removeCallbacks(screenFlashStrobeRunner)
    }
}

enum class ButtonState{
    START,
    ON,
    OFF
}