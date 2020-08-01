package anini.aninitools.ui.flashlight

import android.app.Application
import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraManager
import android.os.Handler
import androidx.lifecycle.*
import anini.aninitools.util.Prefs
import android.content.pm.PackageManager
import android.Manifest.permission
import androidx.core.content.ContextCompat

class FlashViewModel(
    application:Application)
    : AndroidViewModel(application) {

    private val prefs = Prefs(application.applicationContext)
    private var strobeHandler  = Handler()
    private val context : Context = application.applicationContext
    private val packageManager = application.packageManager
    var status = MutableLiveData<Boolean?>()

    private val _flashEnable = MutableLiveData<Int>().apply {
        value= prefs.buttonState
    }

    val buttonstate:LiveData<ButtonState> = Transformations.map(_flashEnable){
        when (it) {
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

    //time for strobe
    private var time = MutableLiveData<Long>().apply {
        value= prefs.flashStrobe.toLong()
    }

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

    override fun onCleared() {
        super.onCleared()
        strobeHandler.removeCallbacks(onRunner)
        strobeHandler.removeCallbacks(offRunner)
    }
}

enum class ButtonState{
    START,
    ON,
    OFF
}