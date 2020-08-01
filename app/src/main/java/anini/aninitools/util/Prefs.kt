package anini.aninitools.util

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color

class Prefs (context: Context) {

    val PREFS_FILENAME = "aninitools.prefs"
    val prefs: SharedPreferences = context.getSharedPreferences(PREFS_FILENAME, 0)

    //flash fragment
    val BACKGROUND_COLOR = "background_color"
    val BUTTON_STATE = "button_state"
    val FLASH_STROBE = "flash_strobe"

    //sensor fragment
    val ACCELEROMETER = "sensor_accelerometer"
    val AMBIENTTEMP = "sensor_ambienttemp"
    val LIGHT = "sensor_light"
    val MAGNETIC = "sensor_magnetic"
    val PROXIMITY = "sensor_proximity"
    val ORIENTATION = "sensor_orientation"
    val GPS = "sensor_gps"
    val PRESSURE = "sensor_pressure"
    val SOUND = "sensor_sound"

    val GPSPERMISSION = "gps_permission"
    val AUDIOPERMISSION = "audio_permission"
    val CAMERAPERMISSION = "camera_permission"


    var bgColor: Int
        get() = prefs.getInt(BACKGROUND_COLOR, Color.WHITE)
        set(value) = prefs.edit().putInt(BACKGROUND_COLOR, value).apply()

    var buttonState: Int
        get() = prefs.getInt(BUTTON_STATE, 0)
        set(value)=prefs.edit().putInt(BUTTON_STATE,value).apply()

    var flashStrobe : Int
        get() = prefs.getInt(FLASH_STROBE, 0)
        set(value) = prefs.edit().putInt(FLASH_STROBE,value).apply()

    var sensorAccelerometer : Boolean
        get() = prefs.getBoolean(ACCELEROMETER, false)
        set(value) = prefs.edit().putBoolean(ACCELEROMETER,value).apply()

    var sensorAmbientTemp : Boolean
        get() = prefs.getBoolean(AMBIENTTEMP, false)
        set(value) = prefs.edit().putBoolean(AMBIENTTEMP,value).apply()

    var sensorLight : Boolean
        get() = prefs.getBoolean(LIGHT, false)
        set(value) = prefs.edit().putBoolean(LIGHT,value).apply()

    var sensorMagnetic : Boolean
        get() = prefs.getBoolean(MAGNETIC, false)
        set(value) = prefs.edit().putBoolean(MAGNETIC,value).apply()

    var sensorProximity : Boolean
        get() = prefs.getBoolean(PROXIMITY, false)
        set(value) = prefs.edit().putBoolean(PROXIMITY,value).apply()

    var sensorOrientation : Boolean
        get() = prefs.getBoolean(ORIENTATION, false)
        set(value) = prefs.edit().putBoolean(ORIENTATION,value).apply()

    var sensorGPS : Boolean
        get() = prefs.getBoolean(GPS, false)
        set(value) = prefs.edit().putBoolean(GPS,value).apply()

    var sensorPressure : Boolean
        get() = prefs.getBoolean(PRESSURE, false)
        set(value) = prefs.edit().putBoolean(PRESSURE,value).apply()

    var sensorSound : Boolean
        get() = prefs.getBoolean(SOUND, false)
        set(value) = prefs.edit().putBoolean(SOUND,value).apply()

    var gpsPermission : Boolean
        get() = prefs.getBoolean(GPSPERMISSION,false)
        set(value)=prefs.edit().putBoolean(GPSPERMISSION,value).apply()

    var audioPermission : Boolean
        get() = prefs.getBoolean(AUDIOPERMISSION,false)
        set(value)=prefs.edit().putBoolean(AUDIOPERMISSION,value).apply()

    var cameraPermission : Boolean
        get() = prefs.getBoolean(CAMERAPERMISSION,false)
        set(value)=prefs.edit().putBoolean(CAMERAPERMISSION,value).apply()
}